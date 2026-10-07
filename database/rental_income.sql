-- ============================================================================
-- RENTAL INCOME: ONE REVENUE ACCOUNT AND ONE ITEM CODE FOR THE EQUIPMENT RENTAL CONTRACTS
--
-- Run with:  node scripts/run-sql.js database/rental_income.sql
--
-- ── WHAT THIS IS FOR ──
--
-- PRJ-2026-0002 is "...KOMPUTER AUTOMASI PEJABAT SECARA SEWAAN BAGI TEMPOH 36 BULAN DI KEMAS NEGERI PAHANG",
-- RM473,202.00, billed monthly at RM13,144.50. PRJ-2026-0046 rents a dot matrix printer for three years,
-- RM14,400.00. Together RM487,602.00 of RM4,873,738.00 across the 46 projects: ten per cent of the order book,
-- tendered and won. That is a line of business, so its income belongs in turnover.
--
-- ── WHY 5030/000 IN REVENUES, AND NOT 8020/000 ──
--
-- `8020/000 Rent and hire received` already exists, but it is `Other income`, beside Interest received, Forex
-- gains, Gain on disposal and Bad debt recovered. Every one of those is non-operating. Posting the rental
-- contracts there would take RM487,602 out of turnover, which is the figure tender pre-qualification, bank
-- facilities and the service tax registration threshold all read.
--
-- `5000/000 Sales` would keep it in turnover but mix it with supply-and-install work, which hides the rental
-- line. So a new account inside Revenues: `5030/000` is free (only 5000, 5010 and 5020 exist).
--
-- Columns mirror what Chart of Accounts > Add Account writes (`chart-of-accounts.ts`): code, name,
-- account_type, description, status, is_locked. Nothing else is set there, so nothing else is set here.
--
-- ── WHY AN ITEM CODE, AND WHY ONE AND NOT ONE PER CONTRACT ──
--
-- A document line reaches a revenue account other than the Accounting Preferences default ONLY through its
-- product: `trade-document-posting.ts` joins `products p ON p.id = it.product_id` and uses
-- `p.revenue_account_id`, then falls back to `sales_account_id` (5000/000). `products` holds zero rows and no
-- screen writes to it, so without this row the item-code dropdown is empty and every line posts to 5000/000.
--
-- One general code rather than one per contract: both rental contracts are ICT equipment, and the monthly
-- amount and the wording differ per invoice, so the price is left at 0 and the line description is typed per
-- month. The code's job is to route the money to 5030/000.
--
--   code          RENT-ICT
--   unit          month (accounting_uom id 15), so the line reads 1 month
--   classification 022 "Others" on the LHDN list. There is no ICT rental code (028 is motor vehicles only), and
--                 an e-Invoice line needs one. Set here because no screen can set it later
--   tax           NONE. Whether a rental is a taxable service is the company's SST position, not a default an
--                 item code should carry. Pick the tax code on the invoice line
--
-- ── IDEMPOTENT ──
--
-- Every INSERT is guarded on the code it writes. A second run inserts nothing and changes nothing, including
-- after the account or the item has been edited by hand. Production runs this by hand, and a hand runs things
-- twice.
--
-- Plain INSERT ... SELECT ... WHERE NOT EXISTS, no procedure, so it needs no CREATE ROUTINE privilege and reads
-- the same on MySQL 8 and MariaDB 11.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
INSERT INTO `chart_of_accounts` (`code`, `name`, `account_type`, `description`, `status`, `is_locked`)
SELECT '5030/000', 'Rental income', 'Revenues',
       'Income from equipment rental contracts, for example the 36-month KEMAS Pahang contract (PRJ-2026-0002).',
       'active', 0
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM `chart_of_accounts` WHERE `code` = '5030/000')

-- >>>
-- The item, pointed at the account by its CODE rather than an id, because the id differs between this
-- database and production. If 5030/000 does not exist the SELECT returns no row and nothing is inserted,
-- rather than an item with no revenue account that would silently post to 5000/000.
INSERT INTO `products`
  (`code`, `name`, `description`, `classification_code`, `base_uom_id`, `uom_name`,
   `unit_price`, `selling_price`, `revenue_account_id`, `is_active`)
SELECT 'RENT-ICT', 'ICT equipment rental', NULL, '022',
       (SELECT `id` FROM `accounting_uom` WHERE `name` = 'month' LIMIT 1), 'month',
       0.00, 0.00, a.`id`, 1
  FROM `chart_of_accounts` a
 WHERE a.`code` = '5030/000'
   AND NOT EXISTS (SELECT 1 FROM `products` WHERE `code` = 'RENT-ICT')

-- >>>
-- ── Verification ──
--
-- Expected:  account_type Revenues   account_status active   item_active 1   item_points_at 5030/000
--
-- `item_points_at` is the one that matters. Anything other than 5030/000 means a rental line will post
-- somewhere else.
SELECT a.`code`            AS `account`,
       a.`account_type`    AS `account_type`,
       a.`status`          AS `account_status`,
       p.`code`            AS `item_code`,
       p.`is_active`       AS `item_active`,
       p.`uom_name`        AS `item_unit`,
       r.`code`            AS `item_points_at`
  FROM `chart_of_accounts` a
  LEFT JOIN `products` p ON p.`code` = 'RENT-ICT'
  LEFT JOIN `chart_of_accounts` r ON r.`id` = p.`revenue_account_id`
 WHERE a.`code` = '5030/000'
