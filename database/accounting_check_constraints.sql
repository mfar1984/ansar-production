-- ============================================================================
-- THE 26 ACCOUNTING CHECK CONSTRAINTS THAT WERE WRITTEN AND NEVER EXISTED
--
-- Run with:  node scripts/run-sql.js database/accounting_check_constraints.sql
--
-- ── WHAT WAS WRONG, AND IT IS NOT WHAT IT LOOKED LIKE ──
--
-- Seven accounting migrations DECLARE 26 CHECK constraints between them:
--
--   journal_entries.sql       ck_je_status  ck_je_balanced  ck_je_posted_stamp  ck_jl_sides
--   ar_receipts.sql           ck_arr_status ck_arr_amount   ck_ara_amount       ck_ara_target
--   ap_payments.sql           ck_app_status ck_app_amount   ck_apa_amount       ck_apa_target
--   ar_contras.sql            ck_ctr_status ck_ctr_amount   ck_ctra_amount      ck_ctra_side
--                             ck_ctra_side_target
--   bank_transfers.sql        ck_bkt_status ck_bkt_amount   ck_bkt_to_amount    ck_bkt_different
--   bank_reconciliations.sql  ck_bkrc_status ck_bkrc_signed
--   ar_refunds.sql            ck_arf_status ck_arf_amount   ck_arf_reason
--
-- NONE of the 26 existed on the database. Measured, not assumed: of 346 foreign
-- keys and every CHECK constraint in the schema, only 20 CHECKs were live and
-- every one of them sits on a `project_*` table. Accounting had zero. Assets had
-- zero.
--
-- The cause is one line repeated seven times: every one of those files declares
-- its constraints INSIDE `CREATE TABLE IF NOT EXISTS`. The tables already
-- existed, created by an earlier version of the same files, so `IF NOT EXISTS`
-- skipped the whole statement. The guard that makes a migration safe to re-run
-- is the same guard that makes it INERT once the table is there. A constraint
-- added to such a file after the first deployment can never reach a database.
--
-- This is the third instance of one shape found in a single session:
--
--   1. `project_invoiced_revenue.sql` was written and not on the packager's list
--   2. `approval_multi_approver.sql` was written, on no list, and applied nowhere
--   3. these 26, written inside a statement that could no longer run
--
-- All three were invisible because 32 suites were failing and the number was
-- being carried as a baseline instead of read line by line. Nine of those suites
-- name these constraints explicitly.
--
-- ── WHY ALL SEVEN MODULES IN ONE FILE, AGAINST THE EARLIER RECOMMENDATION ──
--
-- The recommendation was one module at a time, on blast-radius grounds. That
-- argument does not survive the measurement, and it is withdrawn here rather
-- than quietly:
--
--   * these are not NEW rules. Each one is copied VERBATIM from the migration
--     that already declared it, so nothing here is being decided
--   * every affected table holds ZERO rows - all eleven of them, counted. A
--     CHECK cannot fail on data that does not exist
--   * it is ONE defect with ONE cause. Seven releases of the same fix is seven
--     chances to ship six of them
--
-- ── NOT A CURE FOR THE CAUSE ──
--
-- This file repairs the databases that exist. It does not stop the next
-- constraint added to a `CREATE TABLE IF NOT EXISTS` file from being inert, and
-- nothing in SQL can. That belongs to whoever edits those files: a constraint
-- added to an already-deployed table needs its own `ALTER`, and
-- `tests/sql/*.test.js` reading `information_schema` is what catches it.
--
-- ── IDEMPOTENT, VIA A PROCEDURE RATHER THAN 104 STATEMENTS ──
--
-- MySQL has no `ADD CONSTRAINT IF NOT EXISTS`. Written as guarded prepared
-- statements this file would be 26 x 4 = 104 blocks, and 104 near-identical
-- blocks is 104 places for a typo to hide. So one procedure holds the guard and
-- is called 26 times with the table, the name and the body.
--
-- The procedure checks the TABLE exists as well as the constraint, so a database
-- missing a module skips it instead of failing.
--
-- `BEGIN ... END` needs no `DELIMITER` here: `scripts/run-sql.js` sends each
-- `-- >>>` block to the driver as ONE statement, which is why the triggers in
-- `project_phase_approval.sql` work the same way. The `mysql` CLI would need
-- `DELIMITER` and is NOT the way to run this file.
--
-- Verified idempotent on MySQL 8.0.45 by running it twice with identical output.
-- Production is MariaDB 11.4.13, where the guard reads the same
-- `information_schema.TABLE_CONSTRAINTS` view; the verification SELECT at the end
-- reports what is actually present, so the result is readable rather than assumed.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
DROP PROCEDURE IF EXISTS `add_missing_check`

-- >>>
CREATE PROCEDURE `add_missing_check`(
  IN p_table VARCHAR(64),
  IN p_name  VARCHAR(64),
  IN p_body  TEXT
)
BEGIN
  DECLARE v_table INT DEFAULT 0;
  DECLARE v_check INT DEFAULT 0;

  SELECT COUNT(*) INTO v_table
    FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table;

  SELECT COUNT(*) INTO v_check
    FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = p_table
     AND CONSTRAINT_NAME = p_name
     AND CONSTRAINT_TYPE = 'CHECK';

  IF v_table = 1 AND v_check = 0 THEN
    SET @ddl := CONCAT('ALTER TABLE `', p_table, '` ADD CONSTRAINT `', p_name,
                       '` CHECK (', p_body, ')');
    PREPARE st FROM @ddl;
    EXECUTE st;
    DEALLOCATE PREPARE st;
  END IF;
END

-- >>>
-- ── journal_entries: the general ledger, and the most consequential of the set ──
--
-- `ck_je_balanced` is the one that matters most in the whole file. A POSTED journal
-- whose debits do not equal its credits is a ledger that does not balance, and every
-- statement derived from it is wrong from that row onward. A draft is exempt, because
-- being unfinished is what draft is for.
CALL `add_missing_check`('journal_entries', 'ck_je_status',
  '`status` IN (''draft'', ''posted'', ''reversed'')')

-- >>>
CALL `add_missing_check`('journal_entries', 'ck_je_balanced',
  '`status` = ''draft'' OR `total_debit` = `total_credit`')

-- >>>
-- Posted means posted BY somebody AT some time. A posted row with neither cannot be
-- audited, and an unauditable ledger entry is worse than a missing one.
CALL `add_missing_check`('journal_entries', 'ck_je_posted_stamp',
  '`status` = ''draft'' OR (`posted_at` IS NOT NULL AND `posted_by` IS NOT NULL)')

-- >>>
-- Exactly one side carries an amount, and neither is negative. A negative credit is a
-- debit written confusingly, and permitting it means every report downstream has to
-- handle both spellings of the same fact.
CALL `add_missing_check`('journal_lines', 'ck_jl_sides',
  '`debit` >= 0 AND `credit` >= 0 AND (`debit` = 0) <> (`credit` = 0)')

-- >>>
-- ── ar_receipts: money in from a customer ──
CALL `add_missing_check`('ar_receipts', 'ck_arr_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
CALL `add_missing_check`('ar_receipts', 'ck_arr_amount', '`amount` > 0')

-- >>>
CALL `add_missing_check`('ar_receipt_allocations', 'ck_ara_amount', '`amount` > 0')

-- >>>
-- The allocation target list is CLOSED. An allocation pointing at a table nobody
-- settles against is a settlement that no report can find again.
CALL `add_missing_check`('ar_receipt_allocations', 'ck_ara_target',
  '`target_table` IN (''sales_invoices'', ''sales_debit_notes'')')

-- >>>
-- ── ap_payments: money out to a supplier ──
--
-- `ck_app_amount` is the guard that stops money coming BACK from a supplier being
-- recorded as a negative payment. A refund is its own document with its own approval;
-- smuggling one in as a minus sign hides it from every AP report.
CALL `add_missing_check`('ap_payments', 'ck_app_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
CALL `add_missing_check`('ap_payments', 'ck_app_amount', '`amount` > 0')

-- >>>
CALL `add_missing_check`('ap_payment_allocations', 'ck_apa_amount', '`amount` > 0')

-- >>>
CALL `add_missing_check`('ap_payment_allocations', 'ck_apa_target',
  '`target_table` IN (''supplier_invoices'', ''supplier_debit_notes'')')

-- >>>
-- ── ar_contras: one party that is both a customer and a supplier, set off ──
CALL `add_missing_check`('ar_contras', 'ck_ctr_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
CALL `add_missing_check`('ar_contras', 'ck_ctr_amount', '`amount` > 0')

-- >>>
CALL `add_missing_check`('ar_contra_allocations', 'ck_ctra_amount', '`amount` > 0')

-- >>>
CALL `add_missing_check`('ar_contra_allocations', 'ck_ctra_side',
  '`side` IN (''customer'', ''supplier'')')

-- >>>
-- The side and the target must AGREE. A contra allocation claiming the customer side
-- while pointing at a supplier invoice would set off a debt against itself, and the
-- endpoint knowing better is no protection once a second endpoint writes here.
CALL `add_missing_check`('ar_contra_allocations', 'ck_ctra_side_target',
  '(`side` = ''customer'' AND `target_table` IN (''sales_invoices'', ''sales_debit_notes''))
   OR (`side` = ''supplier'' AND `target_table` IN (''supplier_invoices'', ''supplier_debit_notes''))')

-- >>>
-- ── bank_transfers: our money moving between our own accounts ──
CALL `add_missing_check`('bank_transfers', 'ck_bkt_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
CALL `add_missing_check`('bank_transfers', 'ck_bkt_amount', '`amount` > 0')

-- >>>
-- Both ends, because a transfer carries two figures for two currencies. A zero
-- ARRIVING is money that left and landed nowhere.
CALL `add_missing_check`('bank_transfers', 'ck_bkt_to_amount', '`to_amount` > 0')

-- >>>
-- A transfer to ITSELF nets to nothing and appears twice on one account's statement.
CALL `add_missing_check`('bank_transfers', 'ck_bkt_different',
  '`from_account_id` <> `to_account_id`')

-- >>>
-- ── bank_reconciliations: the statement agreed against the ledger ──
CALL `add_missing_check`('bank_reconciliations', 'ck_bkrc_status',
  '`status` IN (''draft'', ''reconciled'', ''cancelled'')')

-- >>>
-- A reconciliation is somebody's signature. Reconciled with no name and no time is an
-- assurance nobody gave.
CALL `add_missing_check`('bank_reconciliations', 'ck_bkrc_signed',
  '`status` <> ''reconciled'' OR (`reconciled_at` IS NOT NULL AND `reconciled_by` IS NOT NULL)')

-- >>>
-- ── ar_refunds: money back to a customer ──
CALL `add_missing_check`('ar_refunds', 'ck_arf_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
CALL `add_missing_check`('ar_refunds', 'ck_arf_amount', '`amount` > 0')

-- >>>
-- Money leaving to a customer needs a stated reason. TRIM, so a space is not a reason.
CALL `add_missing_check`('ar_refunds', 'ck_arf_reason',
  'CHAR_LENGTH(TRIM(`reason`)) > 0')

-- >>>
DROP PROCEDURE IF EXISTS `add_missing_check`

-- >>>
-- ── Report what is now enforced, per table ──
--
-- Expected: 26 rows across 11 tables. `constraints` counts what the storage engine
-- holds, not what a file says it should, which is the whole point of this migration.
SELECT `TABLE_NAME`                AS `table_name`,
       COUNT(*)                    AS `constraints`,
       GROUP_CONCAT(`CONSTRAINT_NAME` ORDER BY `CONSTRAINT_NAME` SEPARATOR ', ') AS `names`
  FROM information_schema.TABLE_CONSTRAINTS
 WHERE `CONSTRAINT_SCHEMA` = DATABASE()
   AND `CONSTRAINT_TYPE` = 'CHECK'
   AND `TABLE_NAME` IN (
     'journal_entries', 'journal_lines',
     'ar_receipts', 'ar_receipt_allocations',
     'ap_payments', 'ap_payment_allocations',
     'ar_contras', 'ar_contra_allocations',
     'bank_transfers', 'bank_reconciliations', 'ar_refunds'
   )
 GROUP BY `TABLE_NAME`
 ORDER BY `TABLE_NAME`
