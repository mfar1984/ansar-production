-- EXPENSES: ONE SUBMISSION, SEVERAL EXPENSES — AND A LINE THAT CAN STAND ON ITS OWN
-- ============================================================================
--
-- Requested from the screen, in the same words the claim and overtime rebuilds were: an employee
-- comes back from a week of work with a handful of receipts and should file them ONCE.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT ALREADY WORKED, SO THAT NOBODY REBUILDS IT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `expense_items` ALREADY EXISTS and is ALREADY WRITTEN. `src/lib/expense-create.ts` opens a
-- transaction, inserts one `expenses` row, then loops the lines into `expense_items`. Both the ESS
-- and the admin path go through it. There is no data loss and there never was.
--
-- So this migration does NOT add multi-line capability. It adds the two things that capability is
-- missing: a way to say that several EXPENSES were filed together, and enough columns on a LINE for
-- a line to describe its own receipt.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY ONE SUBMISSION MUST BECOME SEVERAL `expenses` ROWS, GROUPED BY CATEGORY
-- ══════════════════════════════════════════════════════════════════════════════
--
-- This is the same decision `claims` made for `claim_type_id`, and expenses has a LIVE conflict
-- rather than a theoretical one. MEASURED: all twelve rows of `expense_categories` carry a
-- DIFFERENT `expense_account_id` — 98, 77, 82, 100, 99, 69, 74, 63, 58, 61, 71, 64.
--
-- `hrPaymentPlan` reads that account from the CATEGORY of the `expenses` row it is paying. So a
-- single row holding lines of three categories has no answer to the only question the payment asks:
-- which account does this debit. `budget_limit`, `requires_approval`, `approval_threshold` and
-- `status` are per category too.
--
-- Pushing `category_id` down to `expense_items` was considered and rejected: five of those six
-- behaviours would then have no row to belong to, and the approval chain — one `current_level` per
-- `expenses` row — would have to become per item, which is the sibling-row pattern wearing a child
-- table's clothes.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY NO EXISTING `expenses` COLUMN CAN CARRY THE GROUPING
-- ══════════════════════════════════════════════════════════════════════════════
--
--   `expense_number`  UNIQUE, one per row. It cannot be shared by definition.
--   `applied_date`    a separate `NOW()` per INSERT, so it is not reliably equal across a group —
--                     the same reason it was rejected for claims and for overtime.
--   `created_at`      DOES NOT EXIST on this table. Checked, not assumed.
--
-- So one new column, holding the `expense_number` of the FIRST expense in the group. Every row in
-- the group reads the same value and the first one's own number equals it, so an expense filed alone
-- refers to itself: no NULL branch, and no second meaning for "not part of a group".
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE LINE COLUMNS, AND THE LIMITATION EACH ONE REMOVES
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `receipt_path` — THE REAL ONE. `expenses.receipt_url` is a single `varchar(255)` on the HEADER, so
-- a submission of ten receipts could store at most ONE file per expense row. `claim_items.receipt_path`
-- has been per line since the claim rebuild; this brings expenses level. The header column is KEPT
-- and still written with the first line's file, so every existing reader of `receipt_url` keeps
-- working.
--
-- `project_id` — AND IT FIXES A LIVE BUG. A grep for `project_id` across every file whose path
-- matches `expense` returns ZERO: `expenses.project_id` has existed, with a foreign key, and NOTHING
-- HAS EVER WRITTEN IT. Meanwhile two Project Cost readers SUM against it, so the "claimed" figure on
-- every Project Cost screen is permanently RM 0.00. Putting the project on the LINE is the correct
-- level — one shopping trip can buy materials for two jobs — and the readers move with it.
--
-- `vendor_name`, `invoice_number` — on the header today, which forces every line of one expense to
-- share one vendor. Ten receipts from a week of work are ten vendors. The header columns are KEPT
-- and still written from the first line, for the same backward-compatibility reason as `receipt_url`.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MARIADB
-- ══════════════════════════════════════════════════════════════════════════════
--
-- No generated column and no arithmetic in any CHECK. `database/mileage_module.sql` shipped two
-- STORED GENERATED columns that MySQL 8.0.45 accepted here and MariaDB refused on the server with
-- error 1901, leaving a half-applied migration. Error 1901 covers CHECK clauses too.
--
-- `expense_items.total_price` therefore stays a PLAIN column that the writer computes, exactly as
-- `mileage_trips.distance_km` had to become.
--
-- IDEMPOTENT. MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so every ALTER sits behind an
-- information_schema guard and the no-op branch is `DO 0`. The backfill is narrowed by the value it
-- sets, so a second run changes nothing.
--
-- `-- >>>` IS THE SEPARATOR AND EACH CHUNK IS ONE STATEMENT. `scripts/run-sql.js` splits on that
-- marker and opens the connection with `multipleStatements: false`, so SET, PREPARE, EXECUTE and
-- DEALLOCATE are four chunks.
--
-- Run:  node scripts/run-sql.js database/expenses_submission.sql
-- ============================================================================
-- >>>
-- 1/6 the grouping column.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
      AND COLUMN_NAME = 'submission_ref') = 0,
  'ALTER TABLE `expenses`
     ADD COLUMN `submission_ref` VARCHAR(50) NULL DEFAULT NULL
       COMMENT ''The expense_number of the FIRST expense in the submission. Equals own number when filed alone.''
       AFTER `expense_number`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 2/6 its index. The review screen groups by this column, so it is read far more than written.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
      AND INDEX_NAME = 'idx_expenses_submission') = 0,
  'ALTER TABLE `expenses` ADD INDEX `idx_expenses_submission` (`submission_ref`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 3/6 Backfill. An expense filed alone is a group of one, which is true and saves every reader a
-- "not part of a group" branch for rows that already have a number.
UPDATE `expenses`
   SET `submission_ref` = `expense_number`
 WHERE `submission_ref` IS NULL
-- >>>
-- 4/6 the line's own receipt. See the header note: this is the limitation that actually bites.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_items'
      AND COLUMN_NAME = 'receipt_path') = 0,
  'ALTER TABLE `expense_items`
     ADD COLUMN `receipt_path` VARCHAR(255) NULL DEFAULT NULL
       COMMENT ''This line''''s own receipt. expenses.receipt_url held one file for the whole expense.''
       AFTER `remarks`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 5/6 the line's vendor and invoice. On the header today, which forces ten receipts to share one
-- vendor. The header columns are kept and still written from the first line.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_items'
      AND COLUMN_NAME = 'vendor_name') = 0,
  'ALTER TABLE `expense_items`
     ADD COLUMN `vendor_name` VARCHAR(200) NULL DEFAULT NULL AFTER `description`,
     ADD COLUMN `invoice_number` VARCHAR(100) NULL DEFAULT NULL AFTER `vendor_name`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 6/6 the line's project, and the foreign key.
--
-- SET NULL, because every sibling cost table uses it: assets, claim_items, expenses, mileage_trips,
-- purchase_orders, purchase_requests, sales_invoices and overtime_applications. The CASCADE rules on
-- `projects` belong to tables that are PART of a project. A receipt somebody is owed money for is
-- not part of a project, so CASCADE would delete a reimbursement because a finished job was tidied
-- up. The index is added FIRST: a foreign key needs one on its own column, and without a named one
-- InnoDB creates a differently-named index that the guard would not recognise on a second run.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_items'
      AND COLUMN_NAME = 'project_id') = 0,
  'ALTER TABLE `expense_items`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL
       COMMENT ''The project this line was bought for. NULL when it belongs to none.''
       AFTER `invoice_number`,
     ADD INDEX `idx_expense_items_project` (`project_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_items'
      AND CONSTRAINT_NAME = 'fk_ei_project') = 0,
  'ALTER TABLE `expense_items`
     ADD CONSTRAINT `fk_ei_project` FOREIGN KEY (`project_id`)
       REFERENCES `projects` (`id`) ON DELETE SET NULL',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 7/7 `expense_categories.requires_receipt`.
--
-- MEASURED: `claim_types` has `requires_receipt tinyint(1)` and `expense_categories` does NOT. So the
-- per-line receipt rule the rebuilt form needs had nothing to read, and a rule that is coded but
-- inert is worse than an absent one — it reads as enforced.
--
-- DEFAULT 1, and that is the whole point: the old endpoint ended with
-- `if (!receipt) return fail(400, 'Attach the receipt or invoice.')`, so a receipt was ALWAYS
-- required. Defaulting to 1 preserves that exactly, for every one of the twelve existing categories,
-- while making it relaxable per category the way claim types already are. Defaulting to 0 would
-- silently drop a control that has been in force since the module was built.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_categories'
      AND COLUMN_NAME = 'requires_receipt') = 0,
  'ALTER TABLE `expense_categories`
     ADD COLUMN `requires_receipt` TINYINT(1) NOT NULL DEFAULT 1
       COMMENT ''Whether a line in this category must carry a receipt. 1 preserves the old always-required rule.''
       AFTER `requires_approval`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- VERIFICATION. `scripts/run-sql.js` prints a row set, so this is what the operator reads back.
--
-- `db_version` is printed because a previous release failed on exactly that difference: the
-- generated columns in `database/mileage_module.sql` were measured on MySQL 8.0.45 here and refused
-- by MariaDB on the server.
--
-- `delete_rule_setnull` must read SET NULL. If it ever reads CASCADE, deleting a project deletes
-- reimbursements somebody is owed, and that is the one outcome this file exists to prevent.
--
-- `EXTRA LIKE '%STORED GENERATED%'`, not `'%GENERATED%'`: `created_at` carries `DEFAULT_GENERATED`
-- and the looser pattern reports a correctly plain table as generated.
SELECT VERSION() AS db_version,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
           AND COLUMN_NAME = 'submission_ref') AS sub_col_1,
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
           AND INDEX_NAME = 'idx_expenses_submission') AS sub_idx_1,
       (SELECT COUNT(*) FROM `expenses` WHERE `submission_ref` IS NULL) AS unset_0,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_items'
           AND COLUMN_NAME IN ('receipt_path', 'vendor_name', 'invoice_number', 'project_id')) AS line_cols_4,
       -- Must be 1, and every existing category must read 1: the old rule was always-required.
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expense_categories'
           AND COLUMN_NAME = 'requires_receipt') AS receipt_col_1,
       (SELECT COUNT(*) FROM `expense_categories` WHERE `requires_receipt` = 0) AS relaxed_cats,
       (SELECT COALESCE(MAX(r.DELETE_RULE), 'MISSING')
          FROM information_schema.REFERENTIAL_CONSTRAINTS r
         WHERE r.CONSTRAINT_SCHEMA = DATABASE()
           AND r.CONSTRAINT_NAME = 'fk_ei_project') AS delete_rule_setnull,
       (SELECT COUNT(*) FROM `expense_items`
         WHERE `project_id` IS NOT NULL
           AND `project_id` NOT IN (SELECT `id` FROM `projects`)) AS orphans_0,
       (SELECT COUNT(*) FROM `expenses`) AS expenses_total,
       (SELECT COUNT(*) FROM `expense_items`) AS items_total,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME IN ('expenses', 'expense_items')
           AND EXTRA LIKE '%STORED GENERATED%') AS stored_gen_0
-- >>>
