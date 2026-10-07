-- ============================================================================
-- THE 47 CHECK CONSTRAINTS OUTSIDE ACCOUNTING THAT WERE WRITTEN AND NEVER EXISTED
--
-- Run with:  node scripts/run-sql.js database/schema_repair_checks.sql
--
-- ── THIS IS THE SECOND HALF OF A JOB THAT WAS HALF DONE ──
--
-- `database/accounting_check_constraints.sql` repaired 26 constraints and its own header
-- recorded the rest of the problem in one line:
--
--     "only 20 CHECKs were live and every one of them sits on a `project_*` table.
--      Accounting had zero. Assets had zero."
--
-- It then fixed accounting and left assets. This file is the other half, and it also
-- supersedes the "20 live on project_*" reading, because that measurement was taken on a
-- DEVELOPMENT database. On the development machine those tables were created fresh, so
-- their inline rules arrived with them. The production database is older: the tables were
-- already there, `CREATE TABLE IF NOT EXISTS` skipped, and not one of the twenty exists.
--
-- MEASURED on a local database restored from the production dump of 2026-10-07:
--
--     69 CHECK constraints are declared across database/*.sql
--     22 are live
--     47 are missing
--
-- The cause is the one already diagnosed: a constraint declared INSIDE
-- `CREATE TABLE IF NOT EXISTS` can never reach a database where the table already exists.
-- The guard that makes a migration safe to re-run is the guard that makes it inert.
--
-- ── WHAT THIS FILE DOES NOT DO, AND THE TWO IT REFUSES TO ADD ──
--
-- `ck_acheck_holder` and `ck_asdoc_one_source` are NOT here, and must never be added.
-- Both appear in `database/*.sql` only inside COMMENTS, which exist to record that MySQL
-- rejects them outright:
--
--     ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN
--     Column 'employee_id' cannot be used in a check constraint 'ck_acheck_holder':
--     needed in a foreign key constraint 'fk_acheck_employee' referential action
--
-- Both rules are enforced by TRIGGERS instead. An extraction that scans for
-- `CONSTRAINT ... CHECK` without stripping comments first finds them and adds two
-- constraints that fail on every database — Rule 15, a check that reads a comment is not a
-- check. `tests/sql/schema-repair.test.js` asserts their ABSENCE from this file.
--
-- ── WHY ONE FILE, WHEN THE DATA IS NO LONGER EMPTY ──
--
-- The accounting repair argued for one bundle on the grounds that "every affected table
-- holds ZERO rows - all eleven of them, counted". That argument does NOT hold here and is
-- not being reused. These tables carry live production data: `lhdn_codes` 3854 rows,
-- `asset_obligations` 122, `project_documents` 51, `project_phase_requests` 13,
-- `sales_quotations` 11, `project_numbering` 5, `asset_checkouts` 4.
--
-- So every rule was evaluated against the rows that exist, as `COUNT(*) ... WHERE NOT
-- (body)` — a CHECK refuses a row only when its expression is FALSE, never when NULL.
-- All 47 refuse ZERO existing rows. That measurement, not emptiness, is why they can be
-- added in one pass. Each `CALL` below carries the row count it was measured against.
--
-- If a future database holds a row that violates one of these, the `ALTER` for that
-- constraint fails and the file stops there. That is the correct behaviour: the row is
-- telling you something the rule says cannot happen.
--
-- ── EVERY BODY IS VERBATIM FROM THE MIGRATION THAT DECLARES IT ──
--
-- Nothing is decided here. Each body was extracted mechanically and emitted mechanically,
-- because 47 rules transcribed by hand is 47 chances to change a rule while claiming to
-- copy it, and a changed rule inside a bug fix is a new rule nobody reviewed.
-- `tests/sql/schema-repair.test.js` re-derives all 69 declarations from database/*.sql and
-- fails if any body here differs by a character.
--
-- Six bodies come from a declaration inside a PREPARED STATEMENT (`ck_alr_extend_date`,
-- `ck_astake_plan`, `ck_bkr_status`, `ck_bkp_status`, `ck_bkr_returned`, `ck_bkp_returned`,
-- `chk_ppr_forward`, `ck_sq_valid_days`, `ck_tender_dlp`), where `''` is one quote. Those
-- migrations CAN converge on their own — they ALTER rather than relying on a CREATE that no
-- longer runs. They are included because they were never executed on this database, and one
-- file for production to run beats nine.
--
-- ── IDEMPOTENT, VIA THE SAME PROCEDURE ──
--
-- MySQL has no `ADD CONSTRAINT IF NOT EXISTS`. The procedure is copied from
-- `accounting_check_constraints.sql` unchanged: it checks the TABLE exists as well as the
-- constraint, so a database missing a module skips it instead of failing.
--
-- `BEGIN ... END` needs no `DELIMITER`: `scripts/run-sql.js` sends each `-- >>>` block to
-- the driver as ONE statement. The `mysql` CLI would need `DELIMITER` and is NOT the way to
-- run this file.
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
-- ── ap_refunds ──
-- Money BACK to us from a supplier. The mirror of ar_refunds, whose three constraints the
-- accounting repair did add - these were missed because that file worked from a list of seven
-- migrations and ap_refunds.sql was not on it.

-- ap_refunds.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ap_refund_allocations', 'ck_apfa_amount',
  '`amount` > 0')

-- >>>

-- ap_refunds.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ap_refund_allocations', 'ck_apfa_target',
  '`target_table` IN (''supplier_invoices'', ''supplier_debit_notes'')')

-- >>>

-- ap_refunds.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ap_refunds', 'ck_apf_amount',
  '`amount` > 0')

-- >>>

-- ap_refunds.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ap_refunds', 'ck_apf_reason',
  'CHAR_LENGTH(TRIM(`reason`)) > 0')

-- >>>

-- ap_refunds.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ap_refunds', 'ck_apf_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'')')

-- >>>
-- ── ar_refund_allocations ──
-- The allocation half of ar_refunds. The header rows got their constraints; the lines did not,
-- because they are declared in a different file.

-- ar_refund_allocations.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ar_refund_allocations', 'ck_arfa_amount',
  '`amount` > 0')

-- >>>

-- ar_refund_allocations.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('ar_refund_allocations', 'ck_arfa_target',
  '`target_table` IN (''sales_invoices'', ''sales_debit_notes'')')

-- >>>
-- ── assets ──
-- Dates that cannot run backwards, and a rate that cannot exist without its period.
-- `asset_obligations` holds 122 live rows and every one of them already satisfies both rules.

-- asset_checkout_stocktake.sql  (4 existing row(s), 0 refused)
CALL `add_missing_check`('asset_checkouts', 'ck_acheck_dates',
  '`due_on` >= `issued_on`')

-- >>>

-- asset_checkout_stocktake.sql  (4 existing row(s), 0 refused)
CALL `add_missing_check`('asset_checkouts', 'ck_acheck_return',
  '`returned_on` IS NULL OR `returned_on` >= `issued_on`')

-- >>>

-- asset_loan_requests.sql  (2 existing row(s), 0 refused)
CALL `add_missing_check`('asset_loan_requests', 'ck_alr_dates',
  '`wanted_to` >= `wanted_from`')

-- >>>

-- asset_loan_actions.sql  (2 existing row(s), 0 refused)
CALL `add_missing_check`('asset_loan_requests', 'ck_alr_extend_date',
  '`kind` <> ''extend'' OR `new_due_on` IS NOT NULL')

-- >>>

-- asset_obligations.sql  (122 existing row(s), 0 refused)
CALL `add_missing_check`('asset_obligations', 'ck_aobl_dates',
  '`starts_on` IS NULL OR `ends_on` >= `starts_on`')

-- >>>

-- asset_obligations.sql  (122 existing row(s), 0 refused)
CALL `add_missing_check`('asset_obligations', 'ck_aobl_rate',
  '(`rate` IS NULL AND `rate_period` IS NULL) OR (`rate` IS NOT NULL AND `rate_period` IS NOT NULL)')

-- >>>

-- asset_stocktake_plan.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('asset_stocktakes', 'ck_astake_plan',
  '`due_on` >= `starts_on`')

-- >>>
-- ── bank vouchers ──
-- Cash vouchers. `returned` is the fourth status added by bank_voucher_fields.sql, and the two
-- `_status` rules below are that file's WIDENED versions - the ones that include it.

-- bank_voucher_fields.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('bank_payments', 'ck_bkp_returned',
  '`status` <> ''returned'' OR `returned_date` IS NOT NULL')

-- >>>

-- bank_voucher_fields.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('bank_payments', 'ck_bkp_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'', ''returned'')')

-- >>>

-- bank_vouchers.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('bank_payments', 'ck_bkp_to',
  'CHAR_LENGTH(TRIM(`paid_to`)) > 0')

-- >>>

-- bank_vouchers.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('bank_payments', 'ck_bkp_total',
  '`total_amount` > 0')

-- >>>

-- bank_vouchers.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('bank_receipts', 'ck_bkr_from',
  'CHAR_LENGTH(TRIM(`received_from`)) > 0')

-- >>>

-- bank_voucher_fields.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('bank_receipts', 'ck_bkr_returned',
  '`status` <> ''returned'' OR `returned_date` IS NOT NULL')

-- >>>

-- bank_voucher_fields.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('bank_receipts', 'ck_bkr_status',
  '`status` IN (''draft'', ''confirmed'', ''cancelled'', ''returned'')')

-- >>>

-- bank_vouchers.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('bank_receipts', 'ck_bkr_total',
  '`total_amount` > 0')

-- >>>
-- ── mileage ──
-- A journey that ends behind where it started is a typo, not a journey. chk_mtrip_odo is the
-- one database guard that survived the generated columns being dropped.

-- mileage_module.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('employee_vehicles', 'chk_evehicle_rate',
  '`rate_per_km` > 0')

-- >>>

-- mileage_module.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('mileage_claims', 'chk_mclaim_period',
  '`period_to` >= `period_from`')

-- >>>

-- mileage_module.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('mileage_trips', 'chk_mtrip_odo',
  '`odo_end` > `odo_start`')

-- >>>
-- ── lhdn_codes ──
-- 3854 live rows, every one of them already `active` or `withdrawn`.

-- lhdn_codes.sql  (3854 existing row(s), 0 refused)
CALL `add_missing_check`('lhdn_codes', 'ck_lhdn_status',
  '`status` IN (''active'', ''withdrawn'')')

-- >>>
-- ── project management ──
-- The twenty that `accounting_check_constraints.sql` reported as the only live CHECKs in the
-- schema. They were live on the DEVELOPMENT database, where the tables were created fresh with
-- the rules inline. On the production database the tables already existed, so not one arrived.

-- project_management_changes.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_changes', 'chk_pc_applied',
  '(`status` = ''approved'' AND `applied_at` IS NOT NULL AND `value_before` IS NOT NULL AND `value_after` IS NOT NULL) OR (`status` <> ''approved'' AND `applied_at` IS NULL AND `value_before` IS NULL AND `value_after` IS NULL)')

-- >>>

-- project_management_changes.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_changes', 'chk_pc_decided',
  '(`status` IN (''approved'',''rejected'',''withdrawn'') AND `decided_on` IS NOT NULL) OR (`status` IN (''draft'',''submitted'') AND `decided_on` IS NULL)')

-- >>>

-- project_management_approvals.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_client_approvals', 'chk_pca_decided',
  '(`status` = ''pending'' AND `decided_on` IS NULL) OR (`status` = ''approved'' AND `decided_on` IS NOT NULL) OR (`status` IN (''rejected'',''withdrawn'') AND `decided_on` IS NOT NULL AND `decision_note` IS NOT NULL)')

-- >>>

-- project_management_approvals.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_client_approvals', 'chk_pca_order',
  '(`decided_on` IS NULL OR `decided_on` >= `requested_on`) AND (`due_on` IS NULL OR `due_on` >= `requested_on`)')

-- >>>

-- project_management_documents.sql  (51 existing row(s), 0 refused)
CALL `add_missing_check`('project_documents', 'chk_pd_shared',
  '(`is_client_visible` = 1 AND `shared_at` IS NOT NULL) OR (`is_client_visible` = 0 AND `shared_at` IS NULL)')

-- >>>

-- project_management_quality.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_ncrs', 'chk_pq_lifecycle',
  '(`status` = ''open'' AND `corrected_on` IS NULL AND `verified_on` IS NULL) OR (`status` = ''corrected'' AND `corrected_on` IS NOT NULL AND `verified_on` IS NULL) OR (`status` = ''verified'' AND `corrected_on` IS NOT NULL AND `verified_on` IS NOT NULL) OR (`status` = ''void'' AND `corrected_on` IS NULL AND `verified_on` IS NULL AND `closed_note` IS NOT NULL)')

-- >>>

-- project_management_quality.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_ncrs', 'chk_pq_order',
  '(`corrected_on` IS NULL OR `corrected_on` >= `found_on`) AND (`verified_on` IS NULL OR `corrected_on` IS NULL OR `verified_on` >= `corrected_on`) AND (`due_on` IS NULL OR `due_on` >= `found_on`)')

-- >>>

-- project_management_settings.sql  (5 existing row(s), 0 refused)
CALL `add_missing_check`('project_numbering', 'chk_pnum_padding',
  '`padding` BETWEEN 2 AND 8')

-- >>>

-- project_management_settings.sql  (5 existing row(s), 0 refused)
CALL `add_missing_check`('project_numbering', 'chk_pnum_prefix',
  'CHAR_LENGTH(TRIM(`prefix`)) BETWEEN 2 AND 20')

-- >>>

-- project_phase_approval.sql  (13 existing row(s), 0 refused)
CALL `add_missing_check`('project_phase_requests', 'chk_ppr_forward',
  '(`action` = ''advance'' AND ( (`from_phase` = ''initiation'' AND `to_phase` = ''planning'') OR (`from_phase` = ''planning'' AND `to_phase` = ''executing'') OR (`from_phase` = ''executing'' AND `to_phase` = ''monitoring'') OR (`from_phase` = ''monitoring'' AND `to_phase` = ''closing'') )) OR (`action` = ''complete'' AND `from_phase` = ''closing'' AND `to_phase` = ''closing'')')

-- >>>

-- project_management_reports.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('project_reports', 'chk_prp_period',
  '`period_end` >= `period_start`')

-- >>>

-- project_management_reports.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('project_reports', 'chk_prp_published',
  '(`status` = ''published'' AND `published_at` IS NOT NULL AND `percent_snapshot` IS NOT NULL) OR (`status` = ''draft'' AND `published_at` IS NULL AND `percent_snapshot` IS NULL)')

-- >>>

-- project_management_risk.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_risks', 'chk_pr_closed',
  '(`status` IN (''realised'',''closed'') AND `closed_on` IS NOT NULL) OR (`status` IN (''open'',''monitoring'') AND `closed_on` IS NULL)')

-- >>>

-- project_management_risk.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_risks', 'chk_pr_scale',
  '`probability` BETWEEN 1 AND 5 AND `impact` BETWEEN 1 AND 5')

-- >>>

-- project_management_settings.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_template_items', 'chk_ptli_duration',
  '`duration_days` IS NULL OR `duration_days` > 0')

-- >>>

-- project_management_timesheets.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_timesheets', 'chk_pts_decided',
  '(`status` = ''submitted'' AND `decided_on` IS NULL AND `decided_by` IS NULL AND `decision_note` IS NULL) OR (`status` = ''approved'' AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL) OR (`status` = ''rejected'' AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL AND `decision_note` IS NOT NULL)')

-- >>>

-- project_management_timesheets.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_timesheets', 'chk_pts_hours',
  '`hours` > 0 AND `hours` <= 24')

-- >>>

-- project_management_timesheets.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('project_timesheets', 'chk_pts_order',
  '`decided_on` IS NULL OR `decided_on` >= `work_date`')

-- >>>
-- ── sales and settings ──
-- chk_single_row is the one that is not about a date or an amount: `system_settings` is a
-- singleton, and a second row would make every reader's `LIMIT 1` pick a winner by accident.

-- quotation_validity_days.sql  (11 existing row(s), 0 refused)
CALL `add_missing_check`('sales_quotations', 'ck_sq_valid_days',
  '`valid_days` IS NULL OR `valid_days` >= 1')

-- >>>

-- create_system_settings.sql  (1 existing row(s), 0 refused)
CALL `add_missing_check`('system_settings', 'chk_single_row',
  'id = 1')

-- >>>

-- asset_obligations.sql  (0 existing row(s), 0 refused)
CALL `add_missing_check`('tenders', 'ck_tender_dlp',
  '`dlp_months` IS NULL OR (`dlp_months` BETWEEN 1 AND 120)')

-- >>>
DROP PROCEDURE IF EXISTS `add_missing_check`

-- >>>
-- ── Report what is now enforced, per table ──
--
-- Expected: 47 rows across 22 tables, PLUS whatever accounting_check_constraints.sql already
-- added — the `IN` list below names only this file's tables, so the accounting ones do not
-- appear here and their absence is not a failure.
--
-- `constraints` counts what the storage engine holds, not what a file says it should, which is
-- the whole point of this migration.
SELECT `TABLE_NAME`                AS `table_name`,
       COUNT(*)                    AS `constraints`,
       GROUP_CONCAT(`CONSTRAINT_NAME` ORDER BY `CONSTRAINT_NAME` SEPARATOR ', ') AS `names`
  FROM information_schema.TABLE_CONSTRAINTS
 WHERE `CONSTRAINT_SCHEMA` = DATABASE()
   AND `CONSTRAINT_TYPE` = 'CHECK'
   AND `TABLE_NAME` IN (
     'ap_refunds', 'ap_refund_allocations', 'ar_refund_allocations',
     'asset_checkouts', 'asset_loan_requests', 'asset_obligations', 'asset_stocktakes',
     'bank_payments', 'bank_receipts',
     'employee_vehicles', 'mileage_claims', 'mileage_trips',
     'lhdn_codes',
     'project_changes', 'project_client_approvals', 'project_documents', 'project_ncrs',
     'project_numbering', 'project_phase_requests', 'project_reports', 'project_risks',
     'project_template_items', 'project_timesheets',
     'sales_quotations', 'system_settings', 'tenders'
   )
 GROUP BY `TABLE_NAME`
 ORDER BY `TABLE_NAME`
