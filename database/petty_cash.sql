-- ============================================================================
-- PETTY CASH ADVANCES
--
-- Run with:  node scripts/run-sql.js database/petty_cash.sql
--
-- ── WHAT THIS MODULE IS, AND WHY IT IS NOT `expenses` OR `claims` ──
--
-- The three money-out paths that already existed all record money that has
-- ALREADY been spent:
--
--   claims     an employee spent their own money and is reimbursed
--   expenses   the company bought something from a vendor
--   advances   salary paid early, recovered from later payslips
--
-- None of them covers "give me RM500 now, I will tell you afterwards what I spent
-- it on". That is an IMPREST ADVANCE, and it is a different thing in the books:
-- when the cash is handed over the company has not incurred a cost, it holds a
-- RECEIVABLE FROM THE EMPLOYEE. The cost appears later, receipt by receipt, and
-- whatever is not spent comes back.
--
--     issue RM500     DR  Staff petty cash advance   500   (an ASSET)
--                         CR  Petty cash / Bank            500
--
--     receipts 400    DR  the category's expense account   400
--                         CR  Staff petty cash advance     400
--
--     return 100      DR  Petty cash / Bank           100
--                         CR  Staff petty cash advance     100
--                     ────────────────────────────────────────
--                     the advance account is now nil
--
-- The unreturned balance therefore SITS IN THE LEDGER as a debt the employee owes,
-- not as a note on a screen. That is the whole point: RM500 issued against RM400
-- of receipts leaves RM100 visible on the Balance Sheet until it is settled.
--
-- The same reasoning as `payroll_advance_account_id`, whose comment in
-- `payroll-posting.ts` reads: "An ASSET being reduced. A recovery is not income,
-- and posting it as one reports a profit on being repaid."
--
-- ── WHY `amount_spent` IS NOT A COLUMN ──
--
-- It is derived: `SUM(total_amount) FROM expenses WHERE petty_cash_id = ?`. Two
-- writers keeping a running total in step is how `leave_balances.pending_days`
-- reached -2.0 on live data. One authority for the figure, computed on read.
--
-- ── IDEMPOTENT ──
--
-- MySQL has no `ADD COLUMN IF NOT EXISTS`, so every ALTER is wrapped in a prepared
-- statement guarded on `information_schema`. Production is MariaDB and development
-- is MySQL 8.0.45; both understand this. One statement per `-- >>>` block and no
-- trailing semicolons — the runner sends each block as a single statement with
-- `multipleStatements` off.
--
-- Every column type below was READ from `information_schema`, not assumed. All the
-- primary keys this references (`employees.id`, `admins.id`,
-- `chart_of_accounts.id`, `expenses.id`) are plain signed `int`, so the foreign key
-- columns are `INT` and not `INT UNSIGNED` — a mismatch there fails the ALTER with
-- errno 150 and no explanation of which side was wrong.
-- ============================================================================

-- >>>
-- ── 1. The requests table ──
CREATE TABLE IF NOT EXISTS `petty_cash_requests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `request_no` VARCHAR(32) NOT NULL COMMENT 'PC-YYYYMM-nnn, issued in code like OT- and EXP-',
  `employee_id` INT NOT NULL COMMENT 'Who is accountable for the cash. Never a payee name.',
  `purpose` VARCHAR(500) NOT NULL COMMENT 'What the float is for. Required: cash with no stated purpose cannot be reviewed.',
  `needed_by` DATE NULL COMMENT 'When the staff member needs it. Advisory, not enforced.',
  `amount_requested` DECIMAL(15,2) NOT NULL,

  -- ── The approval chain, driven by the shared engine ──
  -- `pending | approved | rejected` are the words `applyApprovalAction` writes with
  -- the default StatusWords. `issued`, `closed` and `cancelled` are this module's
  -- own and are never written by the engine.
  `status` ENUM('pending','approved','rejected','issued','closed','cancelled')
    NOT NULL DEFAULT 'pending',
  `current_level` INT UNSIGNED NOT NULL DEFAULT 0
    COMMENT 'Levels signed. 0 = nobody yet, which is what the engine expects on submit.',
  `applied_date` DATE NOT NULL,
  `reviewed_by` INT NULL COMMENT 'admins.id of the last approver',
  `reviewed_date` DATETIME NULL,
  `review_remarks` VARCHAR(500) NULL,

  -- ── The issue: the only step at which money actually moves ──
  -- Approval is permission to pay; issuing is the payment. Kept apart for the same
  -- reason `expenses` separates approve from mark-paid — and the amount is separate
  -- from `amount_requested` because an approver may release less than was asked.
  `amount_issued` DECIMAL(15,2) NULL,
  `issued_by` INT NULL COMMENT 'admins.id',
  `issued_date` DATE NULL COMMENT 'The journal takes THIS date, never today',
  `issued_from_account_id` INT NULL COMMENT 'chart_of_accounts.id, Cash and bank, the tin or account the cash left',
  `issue_method` VARCHAR(32) NULL,
  `issue_reference` VARCHAR(100) NULL COMMENT 'Cheque or transfer reference, for the bank reconciliation',

  -- ── The return of whatever was not spent ──
  `amount_returned` DECIMAL(15,2) NULL,
  `returned_date` DATE NULL,
  `returned_to_account_id` INT NULL COMMENT 'chart_of_accounts.id, Cash and bank, where the balance went back',
  `return_reference` VARCHAR(100) NULL,

  -- ── Close: the advance is fully accounted for ──
  `closed_by` INT NULL COMMENT 'admins.id',
  `closed_date` DATETIME NULL,

  /*
   * ── WHY THE JOURNAL IDS ARE STORED, WHEN NO OTHER MODULE STORES THEM ──
   *
   * Every other posting engine guards against double-posting with
   * `WHERE source_table = ? AND source_id = ? AND status = 'posted' AND reverses_id IS NULL`,
   * and `documentJournal(table, id)` looks a journal up the same way. Both assume
   * ONE journal per document.
   *
   * A petty cash float writes TWO against this row — the issue and the return —
   * plus one per receipt against `expenses`. Under the shared guard the return
   * would find the issue's journal and be refused as a duplicate, and
   * `documentJournal` would return whichever of the two it happened to hit first.
   *
   * Inventing a second `source_table` value to tell them apart was rejected: it
   * would name a table that does not exist, and every reader of
   * `journal_entries.source_table` would be looking for it.
   *
   * So each movement records its own journal, which is also what lets the screen
   * link to both. `ON DELETE SET NULL` because a journal is never deleted once
   * posted — it is reversed — so this only fires if history is being rewritten
   * deliberately, and losing the pointer is better than blocking that.
   *
   * The guard becomes "is this column set AND is that journal still live", which
   * correctly allows a re-issue after the issue journal has been reversed — the
   * same behaviour `reverses_id IS NULL` gives every other module.
   */
  `issue_journal_id` INT NULL COMMENT 'journal_entries.id for DR advance / CR cash',
  `return_journal_id` INT NULL COMMENT 'journal_entries.id for DR cash / CR advance',

  `remarks` VARCHAR(500) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pcr_request_no` (`request_no`),
  KEY `idx_pcr_employee` (`employee_id`),
  KEY `idx_pcr_status` (`status`),
  KEY `idx_pcr_applied` (`applied_date`),
  /* `(employee_id, status)` serves the ESS list AND the guard that refuses a second
     open float for the same person, which is the query on the hot path. */
  KEY `idx_pcr_employee_status` (`employee_id`, `status`),
  CONSTRAINT `fk_pcr_employee` FOREIGN KEY (`employee_id`)
    REFERENCES `employees` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_pcr_issued_from` FOREIGN KEY (`issued_from_account_id`)
    REFERENCES `chart_of_accounts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_pcr_returned_to` FOREIGN KEY (`returned_to_account_id`)
    REFERENCES `chart_of_accounts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_pcr_issue_journal` FOREIGN KEY (`issue_journal_id`)
    REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_pcr_return_journal` FOREIGN KEY (`return_journal_id`)
    REFERENCES `journal_entries` (`id`) ON DELETE SET NULL
-- `ROW_FORMAT=DYNAMIC` is DECLARED, not left to the server.
--
-- 172 of the 173 tables here state it, and `sql-portability.test.js` asserts that every one does.
-- The reason is a dump: `mysqldump` writes only what the table DECLARES, so a table that inherited
-- the format from `innodb_default_row_format` exports without it and takes the IMPORTING server's
-- default instead. Dynamic is what the long `varchar(500)` columns on this table need to store
-- off-page; Compact would make a wide row fail to fit.
--
-- This table was created without it and was the one exception the suite found.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 1a. The row format, for a table an earlier run already created ──
--
-- Same reason as 1b below: `CREATE TABLE IF NOT EXISTS` is skipped where the table exists, so the
-- clause above never reaches it. `CREATE_OPTIONS` is what records the DECLARATION — `ROW_FORMAT`
-- reports `Dynamic` either way, so reading that column would say the work was already done.
SET @declared := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petty_cash_requests'
     AND CREATE_OPTIONS LIKE '%row_format%'
)

-- >>>
SET @sql := IF(@declared = 0,
  'ALTER TABLE `petty_cash_requests` ROW_FORMAT=DYNAMIC',
  'SELECT ''petty_cash_requests already declares its row format'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 1b. The two journal pointers, for a table an earlier run already created ──
--
-- `CREATE TABLE IF NOT EXISTS` above is SKIPPED on any database where the table
-- already exists, so a column added to it later never lands there. Both paths have
-- to be written or the migration is correct only on a clean install — which is the
-- one place nobody tests it.
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petty_cash_requests'
     AND COLUMN_NAME = 'issue_journal_id'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `petty_cash_requests`
     ADD COLUMN `issue_journal_id` INT NULL
       COMMENT ''journal_entries.id for DR advance / CR cash'' AFTER `closed_date`,
     ADD COLUMN `return_journal_id` INT NULL
       COMMENT ''journal_entries.id for DR cash / CR advance'' AFTER `issue_journal_id`,
     ADD CONSTRAINT `fk_pcr_issue_journal` FOREIGN KEY (`issue_journal_id`)
       REFERENCES `journal_entries` (`id`) ON DELETE SET NULL,
     ADD CONSTRAINT `fk_pcr_return_journal` FOREIGN KEY (`return_journal_id`)
       REFERENCES `journal_entries` (`id`) ON DELETE SET NULL',
  'SELECT ''petty_cash_requests journal pointers already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2. The link from an expense back to the float that funded it ──
--
-- This column is what makes the module honest. Without it an expense recorded
-- against petty cash is indistinguishable from one the company paid directly, and
-- the RM100 that was never returned would be invisible.
--
-- `ON DELETE RESTRICT`, not SET NULL: an expense already posted against the advance
-- account must keep pointing at the float it cleared. Losing that link would leave
-- a journal against the advance with nothing explaining which advance it cleared.
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
     AND COLUMN_NAME = 'petty_cash_id'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `expenses`
     ADD COLUMN `petty_cash_id` INT NULL
       COMMENT ''petty_cash_requests.id this expense was paid out of. NULL = paid by the company directly.'',
     ADD KEY `idx_expenses_petty_cash` (`petty_cash_id`),
     ADD CONSTRAINT `fk_expenses_petty_cash` FOREIGN KEY (`petty_cash_id`)
       REFERENCES `petty_cash_requests` (`id`) ON DELETE RESTRICT',
  'SELECT ''expenses.petty_cash_id already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3. The advance account itself ──
--
-- Copied from a sibling rather than written out, for the reason recorded in
-- `payroll_accounting_link.sql`: `chart_of_accounts` was created by the previous
-- application and this migration does not own its column list. A hand-written
-- INSERT breaks the day a NOT NULL column is added to it.
SET @cols := (
  SELECT GROUP_CONCAT(CONCAT('`', `COLUMN_NAME`, '`') ORDER BY `ORDINAL_POSITION`)
    FROM information_schema.COLUMNS
   WHERE `TABLE_SCHEMA` = DATABASE()
     AND `TABLE_NAME` = 'chart_of_accounts'
     AND `COLUMN_NAME` NOT IN ('id', 'code', 'name', 'created_at', 'updated_at')
     AND `EXTRA` NOT LIKE '%GENERATED%'
)

-- >>>
-- ── 3070/000 Staff petty cash advance, copied from 3060/000 Staff loans and advances ──
--
-- Its OWN account rather than reusing 3060/000, and the reason is the requirement:
-- an imprest float has to be aged and cleared independently. Sharing one balance
-- with salary advances means neither can be reconciled — a RM100 unreturned float
-- and a RM100 salary advance would be one RM200 figure that agrees with nothing.
--
-- A sub-code family of 3060 was considered and rejected: 3060/000 is `Current
-- assets` and so is this, but the two are settled by completely different
-- mechanisms (payroll deduction against cash returned), so they are not one family.
SET @sql := IF(
  (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '3070/000') = 0
  AND (SELECT COUNT(*) FROM `chart_of_accounts` WHERE `code` = '3060/000') = 1,
  CONCAT('INSERT INTO `chart_of_accounts` (`code`, `name`, ', @cols, ') ',
         'SELECT ''3070/000'', ''Staff petty cash advance'', ', @cols,
         ' FROM `chart_of_accounts` WHERE `code` = ''3060/000'''),
  'SELECT ''3070/000 already present, or 3060/000 is missing to copy from'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- A copied row inherits the source's flags, so assert rather than assume. An
-- inactive or locked advance account would refuse every issue with a message about
-- the chart, which sends the reader to the wrong screen.
UPDATE `chart_of_accounts`
   SET `status` = 'active', `is_locked` = 0
 WHERE `code` = '3070/000' AND (`status` <> 'active' OR `is_locked` <> 0)

-- >>>
-- ── 4. The preference that names it ──
--
-- On `accounting_preferences` and offered by the Accounting Preferences screen,
-- NOT a module-local constant. The ten payroll accounts are seeded by migration and
-- unreachable from any UI, which means a company that wants a different account has
-- no way to say so. Adding the field to `PREFERENCE_ACCOUNT_FIELDS` in
-- `src/lib/accounting.ts` wires the picker, the type validation and the audit
-- snapshot from that one array.
SET @has := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'accounting_preferences'
     AND COLUMN_NAME = 'petty_cash_advance_account_id'
)

-- >>>
SET @sql := IF(@has = 0,
  'ALTER TABLE `accounting_preferences`
     ADD COLUMN `petty_cash_advance_account_id` int NULL
       COMMENT ''Cash issued to staff and not yet accounted for. An ASSET, not an expense.''',
  'SELECT ''accounting_preferences.petty_cash_advance_account_id already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- Matched by CODE and wrapped in COALESCE, so a re-run never overwrites a choice
-- the company has since made on the Preferences screen.
UPDATE `accounting_preferences` p
   SET p.`petty_cash_advance_account_id` = COALESCE(p.`petty_cash_advance_account_id`,
         (SELECT `id` FROM `chart_of_accounts`
           WHERE `code` = '3070/000' AND `status` = 'active'))
 WHERE p.`id` = 1

-- >>>
-- ── 5. Permissions ──
--
-- `category` is `human_resources`, matching every other HR module. A permission
-- with no category falls outside every section of the roles matrix and cannot be
-- granted through the screen.
--
-- `approve` and `reject` are separate, as they are for expenses and claims: the
-- authority to release company cash and the authority to refuse a request are not
-- the same job.
--
-- `issue` and `close` are NOT separate permissions. Issuing is gated on `edit` for
-- the same reason recording a payment against an expense is — the comment there
-- reads "Recording a payment is an edit of the record, not a second approval" — and
-- inventing two more actions would put four buttons behind four permissions on a
-- screen that has one workflow.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('petty_cash', 'view',    'petty_cash_view',    'View petty cash requests',                        'human_resources'),
  ('petty_cash', 'create',  'petty_cash_create',  'Raise a petty cash request',                      'human_resources'),
  ('petty_cash', 'edit',    'petty_cash_edit',    'Issue cash against an approved request, record the return and close it', 'human_resources'),
  ('petty_cash', 'delete',  'petty_cash_delete',  'Delete a pending petty cash request',             'human_resources'),
  ('petty_cash', 'approve', 'petty_cash_approve', 'Approve a petty cash request',                    'human_resources'),
  ('petty_cash', 'reject',  'petty_cash_reject',  'Reject a petty cash request',                     'human_resources')

-- >>>
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('petty_cash_approval', 'view',   'petty_cash_approval_view',   'View the petty cash approval workflow',    'human_resources'),
  ('petty_cash_approval', 'create', 'petty_cash_approval_create', 'Add an approval level for petty cash',     'human_resources'),
  ('petty_cash_approval', 'edit',   'petty_cash_approval_edit',   'Change an approval level for petty cash',  'human_resources'),
  ('petty_cash_approval', 'delete', 'petty_cash_approval_delete', 'Remove an approval level for petty cash',  'human_resources'),
  ('petty_cash_notifications', 'view', 'petty_cash_notifications_view', 'View petty cash notification settings',   'human_resources'),
  ('petty_cash_notifications', 'edit', 'petty_cash_notifications_edit', 'Change petty cash notification settings', 'human_resources')

-- >>>
-- ── 6. Grant them to Super Admin ──
--
-- MANDATORY, not a convenience. The SERVER has a Super Admin bypass
-- (`api-guard.ts` `can()` returns true for it), but the CLIENT does not:
-- `usePermissions` reads `/api/admin/user-permissions`, which joins through
-- `role_permissions` and returns nothing else. So without this grant the sidebar
-- entry and the settings tabs are INVISIBLE to Super Admin while the endpoints
-- behind them would have answered — which reads as a broken menu, not as a
-- permission problem.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.id, p.id
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(REPLACE(r.name, ' ', '-')) = 'super-admin'
   AND p.module IN ('petty_cash', 'petty_cash_approval', 'petty_cash_notifications')

-- >>>
-- ── 7. Notification defaults ──
--
-- Without these rows `getModuleSettings('petty_cash')` returns an empty map and the
-- module silently sends nothing: `notify_approver !== '1'` is the first guard in
-- `notifyApprover`. That is exactly the fault that left seven modules never
-- emailing an approver.
INSERT IGNORE INTO `hr_module_settings` (`module`, `setting_key`, `value`) VALUES
  ('petty_cash', 'email_profile',      'hr'),
  ('petty_cash', 'notify_employee',    '1'),
  ('petty_cash', 'notify_approver',    '1'),
  ('petty_cash', 'notify_every_level', '0'),
  ('petty_cash', 'cc_email',           '')

-- >>>
-- ── 8. Report what landed ──
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petty_cash_requests')      AS requests_table,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'
      AND COLUMN_NAME = 'petty_cash_id')                                          AS expenses_link,
  (SELECT `id` FROM `chart_of_accounts` WHERE `code` = '3070/000')                AS advance_account_id,
  (SELECT `petty_cash_advance_account_id` FROM `accounting_preferences` WHERE `id` = 1)
                                                                                  AS preference_points_at,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` IN ('petty_cash', 'petty_cash_approval', 'petty_cash_notifications'))
                                                                                  AS permissions_seeded,
  (SELECT COUNT(*) FROM `hr_module_settings` WHERE `module` = 'petty_cash')       AS settings_seeded,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petty_cash_requests'
      AND COLUMN_NAME IN ('issue_journal_id', 'return_journal_id'))               AS journal_pointers
