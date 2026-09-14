/**
 * Pelaksana skrip SQL untuk ansarlatest.
 *
 * Fail SQL dipisahkan dengan baris penanda `-- >>>` (bukan `;`) supaya
 * pernyataan yang mengandungi titik bertindih dalaman — seperti
 * CREATE PROCEDURE — boleh dihantar sebagai satu blok.
 *
 * Guna:
 *   node scripts/run-sql.js database/create_settings_expansion.sql
 *   node scripts/run-sql.js database/create_settings_expansion.sql database/seed_settings_permissions.sql
 */
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

const ROOT = path.join(__dirname, '..');

/**
 * Credentials, from the first environment file that exists.
 *
 * ── `.env.production` IS ON THIS LIST, AND WHY ──
 *
 * This tool ships with the production package, because production needs a way to apply a migration and
 * `git pull` is the only channel it has. There, the file is `.env.production` — `.env.local` is the DEVELOPMENT
 * database and is deliberately never shipped.
 *
 * Without this the tool ran on the server, found neither file, and fell back to `root@localhost` with an empty
 * password against a database called `ansar`. That fails with an access-denied error that says nothing about a
 * missing file, which is the same trap `session-verify.js` records for its own defaults.
 *
 * ORDER MATTERS: `.env.local` first, so a developer's machine keeps using the development database even when a
 * `.env.production` is sitting beside it.
 */
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

function splitStatements(sql) {
  return sql
    .split(/^[ \t]*--[ \t]*>>>[ \t]*$/m)
    .map(chunk =>
      chunk
        .split(/\r?\n/)
        .filter(line => !/^\s*--/.test(line))
        .join('\n')
        .trim()
    )
    .filter(stmt => stmt.length > 0);
}

(async () => {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    console.error('Guna: node scripts/run-sql.js <fail.sql> [fail2.sql ...]');
    process.exit(1);
  }

  const { env, from } = loadEnv();
  if (!from) {
    console.error('TIADA fail persekitaran: .env.local, .env atau .env.production.');
    console.error('Cipta satu di akar folder dengan DB_HOST, DB_USER, DB_PASSWORD dan DB_NAME.');
    process.exit(1);
  }

  const conn = await mysql.createConnection({
    host: env.DB_HOST || 'localhost',
    port: Number(env.DB_PORT || 3306),
    user: env.DB_USER || 'root',
    password: env.DB_PASSWORD || '',
    database: env.DB_NAME || 'ansar',
    multipleStatements: false,
  });

  /* WHICH file the credentials came from is printed. On a server with two of them, that is the one fact worth
     seeing before a migration writes anything. */
  console.log(`Bersambung ke ${env.DB_NAME}@${env.DB_HOST}:${env.DB_PORT || 3306} (dari ${from})\n`);

  let totalOk = 0;
  let totalFail = 0;

  for (const file of files) {
    const full = path.isAbsolute(file) ? file : path.join(ROOT, file);
    if (!fs.existsSync(full)) {
      console.error(`TIADA: ${file}`);
      totalFail++;
      continue;
    }
    const statements = splitStatements(fs.readFileSync(full, 'utf8'));
    /*
     * ASCII `-`, not an em dash.
     *
     * This output is read through a pipe more often than not (`| Select-Object -Last 10`), and a piped Node
     * process writes raw UTF-8 bytes rather than going through the console's Unicode API. PowerShell then decodes
     * those bytes with `[Console]::OutputEncoding`, which on this machine is IBM437 — so `—` (U+2014, bytes
     * `E2 80 94`) arrives as `ΓÇö`. Every run of this tool showed that.
     *
     * The console can be switched to UTF-8, but a tool whose output is only legible after the reader configures
     * their terminal is a tool with a trap in it. ASCII costs nothing here.
     */
    console.log(`=== ${path.basename(file)} - ${statements.length} pernyataan ===`);

    let ok = 0;
    const failures = [];
    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      try {
        await conn.query(stmt);
        ok++;
      } catch (err) {
        failures.push({ index: i + 1, code: err.code, message: err.message, preview: stmt.slice(0, 110).replace(/\s+/g, ' ') });
      }
    }
    totalOk += ok;
    totalFail += failures.length;
    console.log(`  berjaya: ${ok}   gagal: ${failures.length}`);
    for (const f of failures) {
      console.log(`  [#${f.index}] ${f.code}: ${f.message}`);
      console.log(`         > ${f.preview}`);
    }
    console.log('');
  }

  console.log(`JUMLAH - berjaya: ${totalOk}   gagal: ${totalFail}`);
  await conn.end();
  process.exit(totalFail > 0 ? 1 : 0);
})().catch(err => {
  console.error('RALAT MAUT:', err.message);
  process.exit(1);
});
