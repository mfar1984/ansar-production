-- ============================================================================
-- ASSET DISPOSAL, IN THE LEDGER
--
-- Run with:  node scripts/run-sql.js database/asset_disposal_accounting.sql
--
-- ── WHAT THIS CLOSES ──
--
-- `database/asset_disposals.sql` recorded a deliberate gap in its own header:
--
--     "NO LEDGER POSTING, AND THAT IS A DECISION. A disposal of a fixed asset has an
--      accounting entry behind it: remove the cost and the accumulated depreciation,
--      recognise the gain or loss. Nothing here posts to the general ledger, because
--      the accounting module is still being built and a posting written against a
--      chart of accounts that is still moving would have to be unpicked."
--
-- The accounting module is finished. This migration supplies the four things the
-- posting engine needs and cannot invent.
--
-- ── THE ENTRY IT MAKES POSSIBLE ──
--
--     DR  the Cash and bank account the money arrived in      proceeds
--     DR  Accumulated depreciation - <family>                 cost less book value
--         CR  <family> at cost                                    cost
--         CR  Gain on disposal of fixed assets                    proceeds over book value
--     or
--     DR  Loss on disposal of fixed assets                    book value over proceeds
--
-- Note what it is NOT: a sale. Selling surplus equipment is not turnover, so nothing
-- here touches the Sales account. Posting it as revenue would overstate turnover and
-- leave the asset sitting in the Balance Sheet after it had gone - two errors in one
-- entry.
--
-- ── 1. TWO ACCOUNTS, NOT FIVE ──
--
-- Measured before writing: the live chart ALREADY carries all five asset families.
--
--     Buildings               cost 2020/000   acc depn 2520/000   depn expense 9320/000
--     Plant and machinery          2030/000            2530/000                9330/000
--     Computer equipment           2040/000            2540/000                9340/000
--     Motor                        2050/000            2550/000                9350/000
--     Furniture and fixtures       2060/000            2560/000                9360/000
--
-- So only the gain and the loss are missing. TWO accounts on OPPOSITE sides of the
-- statements rather than one net account, because that is the precedent this chart
-- already sets for the same shape: 8030/000 Realised Forex Gains against 9300/000
-- Realised Forex Loss, wired as `forex_gain_account_id` and `forex_loss_account_id`.
--
-- 8050/000 was free, and it sits directly after the two forex gain accounts.
--
-- 9430/000 was free, and it is NOT the natural slot. The natural slot is beside the
-- depreciation block at 9370, which is taken by Cleaning, with Donations and
-- Subscriptions behind it. 9430 is the only gap in Operating expenses - between Sundry
-- expense and Bad Debt - and Bad Debt is at least the same kind of thing: a write-off.
-- Recorded here so nobody re-derives it.
--
-- Both are CLONED from their forex sibling rather than INSERTed by column list, the
-- rule `payroll_accounting_link.sql` and `petty_cash.sql` both follow: this migration
-- does not own `chart_of_accounts`, which was created by the previous application and
-- has 13 columns. A hand-written INSERT breaks the day a NOT NULL column is added.
--
-- Checked before relying on it: both source rows carry NULL in `description`,
-- `classification`, `service_type_code`, `tariff_code` and `tariff_description`, so a
-- clone inherits nothing stale. Only `account_type`, `status` and `is_locked` carry
-- meaning, and those are exactly what is wanted.
--
-- ── 2. THE CATEGORY MUST NAME ITS CHART ACCOUNTS ──
--
-- The engine needs to know WHICH cost account and WHICH accumulated depreciation
-- account a given asset belongs to. There is no single default that could be right: one
-- preference field would post a van to Computer equipment.
--
-- `asset_categories.asset_class` looked like the bridge and is not. It is
-- `enum('movable','fixed','intangible')` - about mobility, not accounting - and 101 of
-- the 105 categories are `movable`, covering RM533,769.75 of RM535,059.75. It cannot
-- tell a laptop from a lorry.
--
-- So two nullable account columns go on `asset_categories`, at the grain an accountant
-- actually thinks in, and a leaf inherits from its parent exactly as
-- `useful_life_years` already does:
--
--     COALESCE(c.cost_account_id, p.cost_account_id)
--
-- ONE level is enough, and that is measured rather than assumed: the tree is 17 top
-- level categories and 88 children, with NOTHING at level three.
--
-- NULLABLE, and that is the important part. The engine REFUSES by name when a category
-- has no mapping. It does not guess, and it does not fall back to a default - a wrong
-- account in a fixed-asset entry is silent, because the journal still balances.
--
-- ── 3. WHAT IS SEEDED, AND WHAT IS DELIBERATELY LEFT EMPTY ──
--
-- Seeded, because the category and the chart account are the same noun and no
-- judgement is involved:
--
--     Computer & Laptop, Printer & Scanner, Network Equipment,
--     Server & Storage, Mobile Device    -> 2040/000 / 2540/000  Computer equipment
--     Vehicle                            -> 2050/000 / 2550/000  Motor
--     Office Furniture                   -> 2060/000 / 2560/000  Furniture and fixtures
--     BUILDING                           -> 2020/000 / 2520/000  Buildings
--
-- Measured after running it: 239 of the 324 ansar-owned assets reach an account through
-- this seed plus the parent inheritance, carrying RM510,902.63 of RM535,059.75 - 95.5%
-- of the register by value.
--
-- LEFT NULL, because each one is a real accounting decision and it is not a migration's
-- to take. The counts are given so the size of the remaining work is visible:
--
--     Appliances                       33 assets   RM9,864.88   Plant, or Furniture?
--     Tools & Instruments              24          RM6,220.20   Plant is likely, still a call
--     Safety & PPE                      8          RM2,168.00   arguably not capitalised at all
--     CCTV & Security                   7          RM2,855.98   Plant, or Computer?
--     MAINTENANCE WARNING BARICADE      4            RM400.00
--     Other                             4            RM104.00
--     Power & Electrical                3          RM1,344.06
--     IBC TANK                          2          RM1,200.00
--     Software Licence                  0              RM0.00   intangible; the chart has no home
--
-- 85 assets and RM24,157.12, which is 4.5% of the register. Set them on
-- `Operations > Asset Management > Settings > Categories`, where this migration adds
-- the two pickers. Until they are set, a disposal in one of those categories is refused
-- with the category named.
--
-- The seed is guarded on `IS NULL`, so a re-run can never overwrite a choice somebody
-- has since made on that screen.
--
-- ── 4. COST HAS TO BE FROZEN TOO, AND THAT IS A CORRECTION ──
--
-- `asset_disposals` froze `book_value_at_disposal` and its header explains why: the
-- inputs - `purchase_cost`, `purchase_date`, `useful_life_years` - can all be CORRECTED
-- afterwards, and recomputing later would silently restate a figure that may already be
-- in a signed report.
--
-- The same argument applies to COST, and it was missed. The journal needs cost and
-- accumulated depreciation SEPARATELY, because they post to different accounts, and
-- only their difference was stored. Taking cost from `assets.purchase_cost` at posting
-- time means a cost corrected after the disposal would be paired with a book value
-- frozen before it - and accumulated depreciation, derived as cost less book value,
-- would absorb the whole error. The journal would still balance.
--
-- So `cost_at_disposal` is frozen beside it. Existing rows are backfilled from
-- `assets.purchase_cost`, which is the only source they have; that is honest for a row
-- recorded before this column existed and is stated rather than hidden.
--
-- ── 5. AND THE PROCEEDS NEED AN ACCOUNT ──
--
-- `proceeds` was stored with no account beside it, so nothing recorded WHERE the money
-- landed. `proceeds_account_id` is that account, nullable and only required when
-- proceeds are above zero - a scrapped or donated asset has no bank line at all, and
-- `proceeds = 0.00` is a sale for nothing, which also has none.
--
-- ── IDEMPOTENT ──
--
-- MySQL has no `ADD COLUMN IF NOT EXISTS`, so every ALTER is wrapped in a prepared
-- statement guarded on `information_schema`. Production is MariaDB and development is
-- MySQL 8.0.45; both understand this.
--
-- Column types were READ from `information_schema`, not assumed. `chart_of_accounts.id`
-- is a plain signed `int` while `asset_categories.id` and `asset_disposals.id` are
-- `int unsigned`, so the three new foreign key columns are `INT` and not `INT UNSIGNED`
-- - a mismatch fails the ALTER with errno 150 and no explanation of which side was
-- wrong.
--
-- One statement per `-- >>>` block and no trailing semicolons: the runner sends each
-- block as a single statement with `multipleStatements` off.
-- ============================================================================

-- >>>
-- ── 1a. The column list to clone, minus the identity and the timestamps ──
SET @cols := (
  SELECT GROUP_CONCAT(CONCAT('`', `COLUMN_NAME`, '`') ORDER BY `ORDINAL_POSITION`)
    FROM information_schema.COLUMNS
   WHERE `TABLE_SCHEMA` = DATABASE()
     AND `TABLE_NAME` = 'chart_of_accounts'
     AND `COLUMN_NAME` NOT IN ('id', 'code', 'name', 'created_at', 'updated_at')
     AND `EXTRA` NOT LIKE '%GENERATED%'
)

-- >>>
-- ── 1b. 8050/000 Gain on disposal of fixed assets, from 8030/000 Realised Forex Gains ──
--
-- Other income. A gain on disposal is not turnover and must not sit in Revenues, or a
-- Profit and Loss would report selling a desk as trading.
SET @sql := IF(
  (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '8050/000') = 0
  AND (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '8030/000') = 1,
  CONCAT('INSERT INTO `chart_of_accounts` (`code`, `name`, ', @cols, ') ',
         'SELECT ''8050/000'', ''Gain on disposal of fixed assets'', ', @cols,
         ' FROM `chart_of_accounts` WHERE `code` = ''8030/000'''),
  'SELECT ''8050/000 already present, or 8030/000 is missing to clone from'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 1c. 9430/000 Loss on disposal of fixed assets, from 9300/000 Realised Forex Loss ──
SET @sql := IF(
  (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '9430/000') = 0
  AND (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '9300/000') = 1,
  CONCAT('INSERT INTO `chart_of_accounts` (`code`, `name`, ', @cols, ') ',
         'SELECT ''9430/000'', ''Loss on disposal of fixed assets'', ', @cols,
         ' FROM `chart_of_accounts` WHERE `code` = ''9300/000'''),
  'SELECT ''9430/000 already present, or 9300/000 is missing to clone from'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 1d. Assert rather than assume ──
--
-- A cloned row inherits the source's flags. An inactive or locked account would refuse
-- every disposal with a message about the chart, which sends the reader to the wrong
-- screen. Same guard `petty_cash.sql` puts on 3070/000.
UPDATE `chart_of_accounts`
   SET `status` = 'active', `is_locked` = 0
 WHERE `code` IN ('8050/000', '9430/000')
   AND (`status` <> 'active' OR `is_locked` <> 0)

-- >>>
-- ── 2a. The two preference fields ──
--
-- On `accounting_preferences` and offered by the Accounting Preferences screen, NOT
-- module-local constants. The ten payroll accounts are seeded by migration and
-- reachable from no UI, which means a company wanting a different account has no way to
-- say so; `petty_cash.sql` records that as a gap and not a precedent. Adding these to
-- `PREFERENCE_ACCOUNT_FIELDS` in `src/lib/accounting.ts` wires the picker, the type
-- validation, the hint and the audit snapshot from that one array.
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'accounting_preferences'
     AND COLUMN_NAME = 'disposal_gain_account_id'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `accounting_preferences`
     ADD COLUMN `disposal_gain_account_id` int NULL
       COMMENT ''Proceeds above book value on a fixed asset disposal. Other income, not turnover.'',
     ADD COLUMN `disposal_loss_account_id` int NULL
       COMMENT ''Book value above proceeds on a fixed asset disposal.''',
  'SELECT ''accounting_preferences disposal accounts already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2b. Point them at the new codes, without overwriting a later choice ──
UPDATE `accounting_preferences` p
   SET p.`disposal_gain_account_id` = COALESCE(p.`disposal_gain_account_id`,
         (SELECT `id` FROM `chart_of_accounts` WHERE `code` = '8050/000' AND `status` = 'active')),
       p.`disposal_loss_account_id` = COALESCE(p.`disposal_loss_account_id`,
         (SELECT `id` FROM `chart_of_accounts` WHERE `code` = '9430/000' AND `status` = 'active'))
 WHERE p.`id` = 1

-- >>>
-- ── 3a. The category to chart mapping ──
--
-- `INT` signed, matching `chart_of_accounts.id`. RESTRICT rather than SET NULL: an
-- account a category depends on must not be deletable out from under it, and accounts
-- are retired with `status = 'inactive'` rather than deleted, so this fires only if
-- somebody is rewriting the chart by hand.
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_categories'
     AND COLUMN_NAME = 'cost_account_id'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `asset_categories`
     ADD COLUMN `cost_account_id` INT NULL
       COMMENT ''chart_of_accounts.id, Fixed assets, where this family sits at cost. Inherited from the parent when NULL.'',
     ADD COLUMN `depreciation_account_id` INT NULL
       COMMENT ''chart_of_accounts.id, the matching Accumulated depreciation account. Inherited from the parent when NULL.'',
     ADD CONSTRAINT `fk_asset_cat_cost_account` FOREIGN KEY (`cost_account_id`)
       REFERENCES `chart_of_accounts` (`id`) ON DELETE RESTRICT,
     ADD CONSTRAINT `fk_asset_cat_depn_account` FOREIGN KEY (`depreciation_account_id`)
       REFERENCES `chart_of_accounts` (`id`) ON DELETE RESTRICT',
  'SELECT ''asset_categories account columns already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 4a. The frozen cost, and the account the proceeds landed in ──
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
     AND COLUMN_NAME = 'cost_at_disposal'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `asset_disposals`
     ADD COLUMN `cost_at_disposal` DECIMAL(15,2) NULL
       COMMENT ''purchase_cost as at disposed_on, frozen. The journal needs cost and accumulated depreciation separately.''
       AFTER `book_value_at_disposal`,
     ADD COLUMN `proceeds_account_id` INT NULL
       COMMENT ''chart_of_accounts.id, Cash and bank, where the proceeds landed. Required only when proceeds > 0.''
       AFTER `cost_at_disposal`,
     ADD CONSTRAINT `fk_disposal_proceeds_account` FOREIGN KEY (`proceeds_account_id`)
       REFERENCES `chart_of_accounts` (`id`) ON DELETE RESTRICT',
  'SELECT ''asset_disposals cost and proceeds account already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 4b. Backfill the frozen cost for rows recorded before the column existed ──
--
-- From `assets.purchase_cost`, which is the only source such a row has. Stated in the
-- header rather than hidden: for a disposal recorded earlier, this is the cost as it
-- stands TODAY, not necessarily as it stood on `disposed_on`. Only rows where the
-- column is still NULL, so a re-run cannot restate a frozen figure.
UPDATE `asset_disposals` d
   JOIN `assets` a ON a.`id` = d.`asset_id`
    SET d.`cost_at_disposal` = a.`purchase_cost`
  WHERE d.`cost_at_disposal` IS NULL
    AND a.`purchase_cost` IS NOT NULL

-- >>>
-- ── 3b. Seed the mappings that involve no judgement ──
--
-- One list, joined twice, rather than two CASE expressions that would have to be kept
-- in step. A category name not in the list does not join, so it is not touched.
--
-- Guarded on both columns being NULL, so a re-run never overwrites a choice made on the
-- Categories screen. See the header for what is deliberately absent and why.
UPDATE `asset_categories` c
  JOIN (
              SELECT 'Computer & Laptop' AS cat, '2040/000' AS cost_code, '2540/000' AS depn_code
    UNION ALL SELECT 'Printer & Scanner',        '2040/000',              '2540/000'
    UNION ALL SELECT 'Network Equipment',        '2040/000',              '2540/000'
    UNION ALL SELECT 'Server & Storage',         '2040/000',              '2540/000'
    UNION ALL SELECT 'Mobile Device',            '2040/000',              '2540/000'
    UNION ALL SELECT 'Vehicle',                  '2050/000',              '2550/000'
    UNION ALL SELECT 'Office Furniture',         '2060/000',              '2560/000'
    UNION ALL SELECT 'BUILDING',                 '2020/000',              '2520/000'
  ) m ON m.cat = c.`name`
  JOIN `chart_of_accounts` cost ON cost.`code` = m.cost_code AND cost.`status` = 'active'
  JOIN `chart_of_accounts` depn ON depn.`code` = m.depn_code AND depn.`status` = 'active'
   SET c.`cost_account_id`         = cost.`id`,
       c.`depreciation_account_id` = depn.`id`
 WHERE c.`cost_account_id` IS NULL
   AND c.`depreciation_account_id` IS NULL

-- >>>
-- ── 5. Report what landed ──
SELECT
  (SELECT COUNT(*) FROM `chart_of_accounts`
    WHERE `code` = '8050/000' AND `account_type` = 'Other income'
      AND `status` = 'active' AND `is_locked` = 0)                    AS gain_account_ok,
  (SELECT COUNT(*) FROM `chart_of_accounts`
    WHERE `code` = '9430/000' AND `account_type` = 'Operating expenses'
      AND `status` = 'active' AND `is_locked` = 0)                    AS loss_account_ok,
  (SELECT `disposal_gain_account_id` FROM `accounting_preferences` WHERE `id` = 1)
                                                                      AS gain_preference,
  (SELECT `disposal_loss_account_id` FROM `accounting_preferences` WHERE `id` = 1)
                                                                      AS loss_preference,
  (SELECT COUNT(*) FROM `asset_categories` WHERE `cost_account_id` IS NOT NULL)
                                                                      AS categories_mapped,
  (SELECT COUNT(*) FROM `asset_categories`)                           AS categories_total,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
      AND COLUMN_NAME IN ('cost_at_disposal', 'proceeds_account_id')) AS disposal_columns,
  (SELECT COUNT(*) FROM `assets` a
     JOIN `asset_categories` c ON c.`name` = a.`category`
     LEFT JOIN `asset_categories` p ON p.`id` = c.`parent_id`
    WHERE a.`ownership` = 'ansar'
      AND COALESCE(c.`cost_account_id`, p.`cost_account_id`) IS NOT NULL)
                                                                      AS assets_postable
