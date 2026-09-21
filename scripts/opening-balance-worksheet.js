/**
 * Opening balance worksheet. READ ONLY - it never writes to the database.
 *
 * Guna:
 *   node scripts/opening-balance-worksheet.js
 *   node scripts/opening-balance-worksheet.js --as-at=2026-06-30 --threshold=1000
 *
 * ── WHY THIS IS A REPORT AND NOT A MIGRATION ──
 *
 * The obvious thing to write was SQL that posts the opening balance, so production could apply it with
 * `run-sql.js` like any other migration. That was asked for and it is the wrong tool, for four reasons
 * worth recording so nobody writes it later:
 *
 *   1  AN OPENING BALANCE IS POSTED ONCE. `src/pages/api/admin/accounting/opening-balances.ts` treats a
 *      posted one as final and offers a reversal, not an edit, because a ledger corrects by reversing.
 *      A wrong figure applied by SQL leaves two entries visible for ever, in the audited year.
 *
 *   2  IT WOULD HAVE NO AUTHOR. The screen writes `posted_by` and `posted_at`, checks
 *      `gl_journals_post`, and takes its number through `takeJournalNo()`. A journal that appears by SQL
 *      has nobody who posted it, which is the first thing an audit asks of the largest entry in the books.
 *
 *   3  A MIGRATION MUST BE IDEMPOTENT and a journal has no natural unique key. `INSERT IGNORE` has
 *      nothing to ignore on, so a second run posts a second opening balance.
 *
 *   4  THE FIGURES ARE NOT ALL KNOWN. Factoring, hire purchase, creditors, the director's account, SST
 *      and paid-up capital have no source in this database. Posting the rest puts every one of those
 *      missing liabilities inside Retained earnings, where nothing will ever surface it.
 *
 * So this prints a worksheet. A person reads it, an accountant approves it, and the figures are typed into
 * Accounting > General Ledger > Opening Balances, saved as a DRAFT, checked, and posted from there.
 *
 * ── OUTPUT IS ASCII ONLY ──
 *
 * `tests/sql/ui-language.test.js` enforces it, and the reason is measured: piped through PowerShell on a
 * code page 437 console, `-` as U+2014 arrives as three mojibake characters. No em dashes, no box drawing,
 * no ticks in anything this file prints.
 */
/* eslint-disable @typescript-eslint/no-require-imports */
'use strict';

const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

const ROOT = path.join(__dirname, '..');

/* ── Defaults, overridable on the command line ──────────────────────────────── */

const DEFAULT_AS_AT = '2026-06-30';

/*
 * Capitalisation threshold, PER UNIT.
 *
 * Why it matters more than it looks: the register carries a chair at RM10.00 and a wireless mouse at
 * RM24.00. Neither is a fixed asset under any threshold, and capitalising them puts 79 register categories
 * in front of whoever has to map them onto five balance sheet accounts. Below the threshold an item is an
 * EXPENSE that was already borne in an earlier year, so it does not belong in an opening balance at all.
 *
 * 1000 is a starting point, not a recommendation. The company's own policy decides it.
 */
const DEFAULT_THRESHOLD = 1000;

/* ── Figures that come from SOURCE DOCUMENTS, not from this database ────────── */

/*
 * Each line names the document it came from. They are declared here rather than queried because the
 * database does not hold them: the bank balance lives on a bank statement and the debtors live on
 * invoices. A figure with no document beside it is a guess, and a guess does not belong in an opening
 * balance.
 *
 * EDIT THIS LIST as documents arrive. Nothing else in the file needs changing.
 */
const FROM_DOCUMENTS = [
  {
    code: '3010/020', label: 'Current account 1', side: 'debit', amount: 24175.66,
    source: 'Maybank Islamic 562807505311, statement 31/07/26, BAKI AWAL at 01/07/2026',
  },
  {
    code: '3000/000', label: 'Debtors - MRNS Construction Works', side: 'debit', amount: 34893.67,
    source: 'Invoice I-26-21 dated 30/03/2026: 75,000.00 less deposit 40,106.33',
  },
  {
    code: '3000/000', label: 'Debtors - Dewan Bandaraya Kuala Lumpur', side: 'debit', amount: 24300.00,
    source: 'Invoice I-26-34 dated 19/05/2026: 22,500.00 plus SST 8% 1,800.00',
  },
];

/*
 * Lines known to exist with NO figure yet. Printed as blanks so the worksheet shows its own holes.
 *
 * This list is the reason the worksheet cannot be posted. Every entry here is a real balance at the as-at
 * date, and leaving one out does not make it zero - it makes Retained earnings absorb it silently.
 */
const AWAITING_A_SOURCE = [
  ['3010/010', 'Petty cash', 'debit', 'Count the cash box at the as-at date'],
  ['3000/000', 'Debtors - all other unpaid invoices', 'debit',
    'Every invoice raised on or before the as-at date and not yet received'],
  ['4000/000', 'Creditors', 'credit',
    'Supplier invoices unpaid at the as-at date. MRNS, KNAS Resources and HNA Bakti at least'],
  ['(new)', 'Factoring liability - Planworth Global', 'credit',
    'Planworth statement at the as-at date. Advance drawn and not yet recovered'],
  ['(new)', 'Hire purchase - motor vehicles', 'credit',
    'Outstanding balance on standing instructions BRH000003, BRH000004, BRH000006, AFC000005'],
  ['1100/000', 'Director account - Rashid Bin Rahmat', 'either',
    'Net of personal amounts paid by the company against amounts introduced. Direction decides the side'],
  ['(new)', 'SST payable', 'credit',
    'Depends on whether service tax is accounted on invoice or on receipt. Ask the tax agent'],
  ['1000/000', 'Capital', 'credit', 'Paid up capital from the SSM records'],
];

/* ── Register category to balance sheet account. A PROPOSAL, not a decision ─── */

/*
 * The register has 79 categories and the chart has five fixed asset accounts, so a mapping is needed and
 * it is a judgement, not data. This one is a PROPOSAL for the accountant to correct.
 *
 * A category that is not on this list is NOT quietly placed somewhere. It is reported as unmapped, because
 * a silent default is how a van ends up under furniture.
 */
const CATEGORY_TO_ACCOUNT = {
  /* 2040 Computer equipment */
  'Computer & Laptop': '2040/000',
  'COMPUTER TOWER DESKTOP': '2040/000',
  'COMPUTER DESKTOP SMALL FACTOR': '2040/000',
  'COMPUTER MICRO DESKTOP': '2040/000',
  'COMPUTER MONITOR 15 INCH': '2040/000',
  'COMPUTER MONITOR 20 INCH': '2040/000',
  'COMPUTER MONITOR 22 INCH': '2040/000',
  'COMPUTER MONITOR 27 INCH': '2040/000',
  'COMPUTER KEYBOARD': '2040/000',
  'WIRELESS KEYBOARD': '2040/000',
  'COMPUTER MOUSE': '2040/000',
  'WIRELESS MOUSE': '2040/000',
  'Printer & Scanner': '2040/000',
  'LABEL PRINTER': '2040/000',
  'NETWORK POE SWITCH': '2040/000',
  'NETWORK WIFI RECORDER': '2040/000',
  'ANDROID PLAYER': '2040/000',
  'ICT EUIPMENT RACK': '2040/000',
  'AUTOMATIC VOLTAGE REGULATOR': '2040/000',
  'PROJECTOT': '2040/000',
  'HDMI TO VGA CONVERTER': '2040/000',
  'VGA MALE TO VGA FEMALE CABLE': '2040/000',

  /* 2050 Motor */
  'Vehicle': '2050/000',

  /* 2030 Plant and machinery */
  'Tools & Instruments': '2030/000',
  'CORDLESS CIRCULAR SAW': '2030/000',
  'CORDLESS KNIFE SAW': '2030/000',
  'CORDLESS ELECTRIC SCREWDRIVER': '2030/000',
  'WIRED IMPACT DRILL': '2030/000',
  'DRILL BIT SET': '2030/000',
  'LASER DISTANCE METER': '2030/000',
  'LASER LEVEL METER': '2030/000',
  'WALKING MEASURES': '2030/000',
  'METER ROLLER STAND REEL': '2030/000',
  'PORTABLE POWER STATION': '2030/000',
  'IBC TANK': '2030/000',
  'ENGINE WATER JET': '2030/000',
  'ENGINE BLOWER': '2030/000',
  'SAFETY HELMET': '2030/000',
  'MAINTENANCE WARNING BARICADE': '2030/000',
  'SPOT LIGHT TRIPOD STAND': '2030/000',
  'BATTERY': '2030/000',
  'SOLAR LAMP': '2030/000',
  'Power & Electrical': '2030/000',
  'CCTV & Security': '2030/000',
  'WIRELESS CCTV CAMERA': '2030/000',
  'ACTION CAMERA': '2030/000',
  'BODY CAMERA': '2030/000',
  'TIME LAPSE CAMERA': '2030/000',

  /* 2060 Furniture and fixtures */
  'Office Furniture': '2060/000',
  'FURNITURE': '2060/000',
  'OFFICE DESK': '2060/000',
  'SIDE TABLE': '2060/000',
  'BANQUET TABLE': '2060/000',
  'FILE CABINET': '2060/000',
  'SHOE AND STORAGE CABINETS': '2060/000',
  'HEAVY DUTY RACK': '2060/000',
  'VISITOR OFFICE CHAIR WITH ARMREST': '2060/000',
  'VISITOR OFFICE CHAIR-RED': '2060/000',
  'VISITOR OFFICE CHAIR-BLUE': '2060/000',
  'MEDIUM-BACK OFFICE CHAIR': '2060/000',
  'SOFA': '2060/000',
  'WHITE BOARD': '2060/000',
  'SPLIT UNIT AIRCONDITIONING': '2060/000',
  'AIR COOLER': '2060/000',
  'WALL FAN': '2060/000',
  'REFRIGERATOR': '2060/000',
  'WATER FITER HOT AND COLD': '2060/000',
  'TV': '2060/000',
  'Appliances': '2060/000',
  'STORAGE BOX -95 LITTER': '2060/000',
  'STORAGE BOX -30 LITTER': '2060/000',
  'STACKABLE BOX': '2060/000',
  'STACKABLE 3 LAYER OFFICE LETTER TRAY': '2060/000',
  'SHREDDER MACHINE': '2060/000',
  'COMB BINDING MACHINE': '2060/000',
  'LAMINATE MACHINE': '2060/000',
  'PAPER CUTTER': '2060/000',
  'HEAVY-DUTY LONG-REACH STAPLER': '2060/000',
  'TENDER BOX': '2060/000',
};

/** The accumulated depreciation account that pairs with each cost account. */
const DEPN_ACCOUNT = {
  '2020/000': '2520/000',
  '2030/000': '2530/000',
  '2040/000': '2540/000',
  '2050/000': '2550/000',
  '2060/000': '2560/000',
};

/* ── Helpers ────────────────────────────────────────────────────────────────── */

function loadEnv() {
  const env = {};
  for (const name of ['.env.local', '.env', '.env.production']) {
    const p = path.join(ROOT, name);
    if (!fs.existsSync(p)) continue;
    for (const line of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && !(m[1] in env)) env[m[1]] = m[2];
    }
    return { env, from: name };
  }
  return { env, from: null };
}

function arg(name, fallback) {
  const hit = process.argv.slice(2).find(a => a.startsWith('--' + name + '='));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const money = n => Number(n).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
const L = (s, n) => String(s).padEnd(n);
const R = (s, n) => String(s).padStart(n);
const rule = n => '-'.repeat(n);

/** Whole months from `YYYY-MM-DD` to the as-at date. Never negative. */
function monthsBetween(from, asAt) {
  const [fy, fm] = from.split('-').map(Number);
  const [ay, am] = asAt.split('-').map(Number);
  return Math.max(0, (ay - fy) * 12 + (am - fm));
}

/* ── Main ───────────────────────────────────────────────────────────────────── */

(async () => {
  const asAt = String(arg('as-at', DEFAULT_AS_AT));
  const threshold = Number(arg('threshold', DEFAULT_THRESHOLD));

  if (!/^\d{4}-\d{2}-\d{2}$/.test(asAt)) {
    console.error('--as-at must be YYYY-MM-DD, got: ' + asAt);
    process.exit(1);
  }
  if (!Number.isFinite(threshold) || threshold < 0) {
    console.error('--threshold must be a number, got: ' + arg('threshold', ''));
    process.exit(1);
  }

  const { env, from } = loadEnv();
  if (!from) {
    console.error('No environment file found: .env.local, .env or .env.production.');
    process.exit(1);
  }

  const db = await mysql.createConnection({
    host: env.DB_HOST || 'localhost',
    user: env.DB_USER || 'root',
    password: env.DB_PASSWORD || '',
    database: env.DB_NAME,
  });

  console.log('');
  console.log('OPENING BALANCE WORKSHEET');
  console.log(rule(100));
  console.log('  as at                  ' + asAt);
  console.log('  capitalisation floor   RM ' + money(threshold) + ' per unit');
  console.log('  credentials from       ' + from);
  console.log('  database               ' + (env.DB_NAME || '(default)'));
  console.log('  THIS SCRIPT ONLY READS. It posts nothing.');
  console.log('');

  /* ── The chart, so every code printed below is known to exist ── */
  const [coa] = await db.execute(
    'SELECT code, name, account_type, is_locked FROM chart_of_accounts',
  );
  const byCode = new Map(coa.map(a => [a.code, a]));

  /* ── Assets ── */
  const [assets] = await db.execute(
    `SELECT asset_no, name, COALESCE(category, '(none)') AS category, holder, status,
            purchase_cost AS cost, DATE_FORMAT(purchase_date, '%Y-%m-%d') AS pd,
            useful_life_years AS life
       FROM assets`,
  );

  const perAccount = new Map();   // code -> { units, cost, depn, noDepnUnits, noDepnCost }
  const expensed = [];            // below the floor
  const afterAsAt = [];           // bought later, not an opening figure
  const disposed = [];
  const unmapped = new Map();     // category -> { units, cost }
  const noDate = [];
  const noCost = [];
  const noLife = [];

  for (const a of assets) {
    if (String(a.status) === 'disposed') { disposed.push(a); continue; }

    const cost = Number(a.cost || 0);
    if (a.pd && a.pd > asAt) { afterAsAt.push(a); continue; }

    if (!cost) { noCost.push(a); }
    if (!a.pd) { noDate.push(a); }
    if (!a.life) { noLife.push(a); }

    /* Below the floor: an expense of an earlier year, not an opening asset. */
    if (cost < threshold) { expensed.push(a); continue; }

    const code = CATEGORY_TO_ACCOUNT[a.category];
    if (!code) {
      const u = unmapped.get(a.category) || { units: 0, cost: 0 };
      u.units += 1; u.cost += cost;
      unmapped.set(a.category, u);
      continue;
    }

    if (!perAccount.has(code)) {
      perAccount.set(code, { units: 0, cost: 0, depn: 0, noDepnUnits: 0, noDepnCost: 0 });
    }
    const b = perAccount.get(code);
    b.units += 1;
    b.cost += cost;

    if (!a.pd || !a.life) {
      b.noDepnUnits += 1;
      b.noDepnCost += cost;
      continue;
    }
    const months = monthsBetween(a.pd, asAt);
    b.depn += Math.min(cost, cost * (months / (Number(a.life) * 12)));
  }

  /* ── 1. Fixed assets ── */
  console.log('1. FIXED ASSETS, at or above the floor, mapped to the chart');
  console.log(rule(100));
  console.log('  ' + L('ACCOUNT', 10) + L('NAME', 30) + R('UNITS', 7)
    + R('COST', 16) + R('ACC DEPN', 16) + R('NBV', 16));
  console.log('  ' + rule(95));

  let totCost = 0, totDepn = 0, totUnits = 0;
  for (const [code, b] of [...perAccount.entries()].sort((x, y) => y[1].cost - x[1].cost)) {
    const acc = byCode.get(code);
    totCost += b.cost; totDepn += b.depn; totUnits += b.units;
    console.log('  ' + L(code, 10) + L(acc ? acc.name.slice(0, 29) : 'NOT ON THE CHART', 30)
      + R(b.units, 7) + R(money(b.cost), 16) + R(money(b.depn), 16)
      + R(money(b.cost - b.depn), 16));
    if (b.noDepnUnits) {
      console.log('  ' + L('', 10) + '  ' + b.noDepnUnits + ' unit(s) RM ' + money(b.noDepnCost)
        + ' carry no depreciation: purchase_date or useful_life_years is missing');
    }
  }
  console.log('  ' + rule(95));
  console.log('  ' + L('', 10) + L('TOTAL', 30) + R(totUnits, 7) + R(money(totCost), 16)
    + R(money(totDepn), 16) + R(money(totCost - totDepn), 16));
  console.log('');

  /* ── 2. What the floor removed ── */
  let expCost = 0;
  for (const a of expensed) expCost += Number(a.cost || 0);
  console.log('2. BELOW THE FLOOR, so NOT in the opening balance');
  console.log(rule(100));
  console.log('  ' + expensed.length + ' unit(s), RM ' + money(expCost));
  console.log('  These were expensed in the year they were bought. Raise the floor and more drop out;');
  console.log('  lower it and each one needs a home on the chart.');
  console.log('');

  /* ── 3. Unmapped ── */
  console.log('3. AT OR ABOVE THE FLOOR BUT NOT MAPPED - these are MISSING from section 1');
  console.log(rule(100));
  if (!unmapped.size) {
    console.log('  none');
  } else {
    let um = 0;
    for (const [cat, u] of [...unmapped.entries()].sort((x, y) => y[1].cost - x[1].cost)) {
      um += u.cost;
      console.log('  ' + L(String(cat).slice(0, 44), 46) + R(u.units, 6) + R(money(u.cost), 16));
    }
    console.log('  ' + rule(66));
    console.log('  ' + L('TOTAL NOT COUNTED ANYWHERE', 46) + R('', 6) + R(money(um), 16));
    console.log('  Add each category to CATEGORY_TO_ACCOUNT in this file, or raise the floor.');
  }
  console.log('');

  /* ── 4. Excluded for other reasons ── */
  let afterCost = 0;
  for (const a of afterAsAt) afterCost += Number(a.cost || 0);
  console.log('4. EXCLUDED');
  console.log(rule(100));
  console.log('  bought after ' + asAt + ' : ' + afterAsAt.length + ' unit(s), RM ' + money(afterCost)
    + '  (a current year addition)');
  console.log('  already disposed       : ' + disposed.length + ' unit(s)');
  console.log('');

  /* ── 5. Data quality ── */
  console.log('5. DATA QUALITY IN THE REGISTER');
  console.log(rule(100));
  console.log('  no purchase_cost       : ' + noCost.length + ' unit(s)');
  console.log('  no purchase_date       : ' + noDate.length + ' unit(s)');
  console.log('  no useful_life_years   : ' + noLife.length + ' unit(s)');
  console.log('');
  console.log('  A unit with no purchase_date cannot be shown to be older than ' + asAt + '. Every one of');
  console.log('  them is treated as an opening asset above, which is an ASSUMPTION and not a fact. If any');
  console.log('  was bought after that date it does not belong here at all.');
  console.log('');

  /* ── 6. The worksheet ── */
  console.log('6. THE WORKSHEET');
  console.log(rule(100));
  console.log('  ' + L('ACCOUNT', 10) + L('LINE', 44) + R('DEBIT', 16) + R('CREDIT', 16));
  console.log('  ' + rule(95));

  let dr = 0, cr = 0;
  for (const d of FROM_DOCUMENTS) {
    if (d.side === 'debit') dr += d.amount; else cr += d.amount;
    console.log('  ' + L(d.code, 10) + L(d.label.slice(0, 43), 44)
      + R(d.side === 'debit' ? money(d.amount) : '', 16)
      + R(d.side === 'credit' ? money(d.amount) : '', 16));
  }
  for (const [code, b] of [...perAccount.entries()].sort()) {
    const acc = byCode.get(code);
    dr += b.cost;
    console.log('  ' + L(code, 10) + L((acc ? acc.name : code) + ' at cost', 44)
      + R(money(b.cost), 16) + R('', 16));
  }
  for (const [code, b] of [...perAccount.entries()].sort()) {
    const dep = DEPN_ACCOUNT[code];
    if (!dep || b.depn <= 0) continue;
    const acc = byCode.get(dep);
    cr += b.depn;
    console.log('  ' + L(dep, 10) + L((acc ? acc.name : dep).slice(0, 43), 44)
      + R('', 16) + R(money(b.depn), 16));
  }

  console.log('  ' + rule(95));
  console.log('  ' + L('', 10) + L('SUBTOTAL of what has a source', 44)
    + R(money(dr), 16) + R(money(cr), 16));
  console.log('  ' + L('', 10) + L('UNEXPLAINED DIFFERENCE', 44)
    + R('', 16) + R(money(dr - cr), 16));
  console.log('');
  console.log('  The difference is NOT retained earnings. It is what the lines in section 7 will absorb.');
  console.log('  Putting it on 1050/000 today would hide every liability that has not been entered.');
  console.log('');

  /* ── 7. The holes ── */
  console.log('7. LINES THAT STILL HAVE NO SOURCE - the worksheet cannot be posted until these are known');
  console.log(rule(100));
  console.log('  ' + L('ACCOUNT', 10) + L('LINE', 44) + L('SIDE', 8) + 'WHERE THE FIGURE COMES FROM');
  console.log('  ' + rule(95));
  for (const [code, label, side, src] of AWAITING_A_SOURCE) {
    console.log('  ' + L(code, 10) + L(label.slice(0, 43), 44) + L(side, 8) + src);
  }
  console.log('');

  /* ── 8. Sources behind section 6 ── */
  console.log('8. SOURCE OF EVERY DOCUMENTED FIGURE ABOVE');
  console.log(rule(100));
  for (const d of FROM_DOCUMENTS) {
    console.log('  ' + L(d.code, 10) + R(money(d.amount), 14) + '  ' + d.source);
  }
  console.log('');

  console.log('NEXT STEP');
  console.log(rule(100));
  console.log('  1. Fill in section 7 from the factoring statement, supplier invoices and SSM records.');
  console.log('  2. Have the accountant approve the mapping in section 1 and the floor.');
  console.log('  3. Type the approved figures into Accounting > General Ledger > Opening Balances.');
  console.log('  4. Save as a DRAFT. Print it. Compare it against the paper line by line.');
  console.log('  5. Only then Post. A posted opening balance is corrected by reversal, never by editing.');
  console.log('');

  await db.end();
})().catch(err => {
  console.error('FAILED: ' + (err && err.message ? err.message : String(err)));
  process.exit(1);
});
