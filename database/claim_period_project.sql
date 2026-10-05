-- ============================================================================
-- CLAIMS: A PERIOD INSTEAD OF A SINGLE DATE, AND A PROJECT ON EVERY LINE
-- ============================================================================
--
-- Requested from the screen. An expense claim is raised for a MONTH, not for a day: pick the
-- period, add as many lines as the month produced, see one total, submit once.
--
-- WHAT THIS ADDS
--
--   claims.period_from   date NULL   the first day the claim covers
--   claims.period_to     date NULL   the last day
--   claim_items.project_id  int NULL  which project the line belongs to, FK to projects
--
-- WHY `claim_date` STAYS, AND STAYS NOT NULL
--
-- It is `date NOT NULL` today and it is READ in several places on the HR review screen - list
-- column, filters, sort order. Dropping it would be a rewrite of a 55 KB screen inside a
-- migration about two new columns. So it stays, and the save path writes it equal to
-- `period_from`. Every existing reader keeps working and gets the right answer: the day the
-- claim's period opens.
--
-- That is the same arrangement `valid_days` and `valid_until` already have on a quotation -
-- both stored, one computed by the save path and never accepted from a request.
--
-- WHY THE BACKFILL
--
-- Existing claims have one date and no period. Left NULL, every screen reading the period
-- would need a "no period" branch for rows that DO have a date - a second meaning for the
-- same fact. So `period_from` and `period_to` are both backfilled from `claim_date`: a claim
-- raised for one day is a period of one day, which is true and needs no branch.
--
-- Guarded by `WHERE period_from IS NULL`, so a second run changes nothing.
--
-- WHY `project_id` IS NULLABLE WITH ON DELETE SET NULL
--
-- Read off the schema, not chosen: every table that merely REFERENCES a project uses exactly
-- this shape - `assets.fk_asset_project`, `expenses.fk_exp_project`,
-- `sales_invoices.fk_sinv_project`, `purchase_requests.fk_preq_project`, all
-- `int NULL ... ON DELETE SET NULL`. Only the `project_*` tables OWNED by a project cascade.
--
-- A claim line is the first kind: the money is owed whether or not the project record
-- survives. CASCADE here would delete somebody's approved reimbursement because an
-- administrator tidied up a finished project.
--
-- `expenses.project_id` is the closest existing analogue and this matches it byte for byte.
--
-- WHAT THIS DELIBERATELY DOES **NOT** DO
--
-- It does not retire the `MLG` / Mileage Claim type. Mileage is moving to its own module with
-- an odometer trip log, and that is a later release. Retiring the type NOW would leave a window
-- in which nobody can claim mileage at all - the old way gone and the new way not yet built.
-- `MLG` is set `status = 'inactive'` in the SAME release that ships the Mileage module.
--
-- And it must never be DELETED. `claims_ibfk_2` on `claims.claim_type_id` is ON DELETE CASCADE,
-- so dropping the type would cascade-delete every mileage claim ever filed, silently.
--
-- IDEMPOTENT. MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so every ALTER is behind an
-- information_schema guard and the no-op branch is `DO 0`.
--
-- `-- >>>` IS THE SEPARATOR AND EACH CHUNK IS ONE STATEMENT. `scripts/run-sql.js` splits on that
-- marker and opens the connection with `multipleStatements: false`, so SET, PREPARE, EXECUTE and
-- DEALLOCATE are four chunks. A chunk holding all four comes back ER_PARSE_ERROR - measured.
--
-- Run:  node scripts/run-sql.js database/claim_period_project.sql
-- ============================================================================
-- >>>
-- 1/4 claims.period_from
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'period_from') = 0,
  'ALTER TABLE `claims`
     ADD COLUMN `period_from` DATE NULL DEFAULT NULL AFTER `claim_date`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 2/4 claims.period_to
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'period_to') = 0,
  'ALTER TABLE `claims`
     ADD COLUMN `period_to` DATE NULL DEFAULT NULL AFTER `period_from`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- Backfill. A claim raised for one day is a period of one day - true, and it saves every reader
-- a "no period" branch for rows that already carry a date.
UPDATE `claims` SET `period_from` = `claim_date` WHERE `period_from` IS NULL
-- >>>
UPDATE `claims` SET `period_to` = `claim_date` WHERE `period_to` IS NULL
-- >>>
-- 3/4 claim_items.project_id
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claim_items' AND COLUMN_NAME = 'project_id') = 0,
  'ALTER TABLE `claim_items`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL AFTER `category`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 4/4 the foreign key, named and ruled like every other reference to a project.
-- An index first: MySQL creates one implicitly for a new FK, but naming it keeps the
-- second run's guard simple and the EXPLAIN readable.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claim_items' AND INDEX_NAME = 'idx_ci_project') = 0,
  'ALTER TABLE `claim_items` ADD INDEX `idx_ci_project` (`project_id`)',
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
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'claim_items'
      AND CONSTRAINT_NAME = 'fk_ci_project' AND CONSTRAINT_TYPE = 'FOREIGN KEY') = 0,
  'ALTER TABLE `claim_items`
     ADD CONSTRAINT `fk_ci_project` FOREIGN KEY (`project_id`)
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
-- 5/6 claims.submission_ref
--
-- ONE SUBMISSION NOW PRODUCES SEVERAL CLAIMS, AND NOTHING SAID THEY WERE RELATED.
--
-- An employee submits one form covering a period, and each claim TYPE in it becomes its own row
-- in `claims` - which is what lets `max_amount`, `requires_receipt` and `expense_account_id` keep
-- working per type without a single new rule.
--
-- But MEASURED on the HR review screen: three rows from one submission render as three UNRELATED
-- rows. The pager counts rows, the pending-work badge counts rows, and the reviewer clicks Approve
-- three times. And no existing column can carry the relation: `claim_number` is UNIQUE and
-- generated per row, and `applied_date` is a separate NOW() per INSERT so it is not reliably equal.
--
-- So one column carries it. It holds the claim number of the FIRST claim in the group, which makes
-- it self-describing - all three read `CLM-202610-001`, and the first one's own number equals it.
-- A claim submitted alone gets it too, equal to its own number, so there is no NULL branch and no
-- second meaning for "not part of a group". Same reasoning as the period backfill above.
--
-- It is varchar(50) to match `claim_number` exactly, and INDEXED because the review screen will
-- look rows up by it.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'submission_ref') = 0,
  'ALTER TABLE `claims`
     ADD COLUMN `submission_ref` VARCHAR(50) NULL DEFAULT NULL AFTER `claim_number`',
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
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND INDEX_NAME = 'idx_claims_submission') = 0,
  'ALTER TABLE `claims` ADD INDEX `idx_claims_submission` (`submission_ref`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 6/6 Backfill: an existing claim is a submission of one, so it refers to itself.
UPDATE `claims` SET `submission_ref` = `claim_number` WHERE `submission_ref` IS NULL
-- >>>
-- The result, for whoever runs this and wants to see it worked.
SELECT 'claims.period_from' AS item,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'period_from') AS present
 UNION ALL
SELECT 'claims.period_to',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'period_to')
 UNION ALL
SELECT 'claim_items.project_id',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claim_items' AND COLUMN_NAME = 'project_id')
 UNION ALL
SELECT 'fk_ci_project',
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'claim_items'
           AND CONSTRAINT_NAME = 'fk_ci_project' AND CONSTRAINT_TYPE = 'FOREIGN KEY')
 UNION ALL
SELECT 'claims.submission_ref',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims' AND COLUMN_NAME = 'submission_ref')
 UNION ALL
SELECT 'idx_claims_submission',
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'claims'
           AND INDEX_NAME = 'idx_claims_submission')
 UNION ALL
SELECT 'claims with no period (must be 0)',
       (SELECT COUNT(*) FROM claims WHERE period_from IS NULL OR period_to IS NULL)
 UNION ALL
SELECT 'claims with no submission_ref (must be 0)',
       (SELECT COUNT(*) FROM claims WHERE submission_ref IS NULL)
