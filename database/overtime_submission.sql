-- OVERTIME: ONE SUBMISSION, SEVERAL ENTRIES
-- ============================================================================
--
-- Requested from the screen, in the same words the claim rebuild was: an employee works overtime on
-- six days in a month and should file them ONCE, not open the form six times.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY THIS IS ONE COLUMN AND NOT A CHILD TABLE
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `claims` needed `claim_items` because a claim HEADER and a receipt LINE are different things: the
-- header carries the type, the cap and the approval, and the line carries one purchase.
--
-- `overtime_applications` is not shaped like that, and it does not need to be. MEASURED off the
-- table: `overtime_date`, `start_time`, `end_time`, `total_hours`, `work_state`, `project_name`,
-- `reason`, `hourly_rate` and `overtime_rate_id` are ALL on the application row. One row already IS
-- one overtime entry — one date, one window, one rate.
--
-- And every one of those is decided PER ENTRY, not per submission. A technician works Monday in
-- Selangor and Saturday on a Kuching site: different `work_state`, and therefore a different day
-- type, a different multiplier and a different `overtime_rate_id`. A header could not hold any of it.
--
-- So a submission of six days is SIX rows, exactly as a claim submission covering three types is
-- three `claims` rows. What was missing is the same thing that was missing there: nothing said the
-- six were related.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY NO EXISTING COLUMN CAN CARRY THE RELATION
-- ══════════════════════════════════════════════════════════════════════════════
--
--   `overtime_number`  UNIQUE, and generated per row. It cannot be shared by definition.
--   `applied_date`     a separate `NOW()` per INSERT, so it is not reliably equal across a group —
--                      the same reason it was rejected for claims.
--   `overtime_date`    the entries have DIFFERENT dates. That is the whole point of the feature.
--
-- So one new column. It holds the overtime number of the FIRST entry in the group, which makes it
-- self-describing: all six read `OT-202610-001`, and the first one's own number equals it. An entry
-- submitted alone gets it too, equal to its own number, so there is no NULL branch and no second
-- meaning for "not part of a group".
--
-- `varchar(50)` to match `overtime_number` exactly, and INDEXED because the review screen looks rows
-- up by it.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT THIS MIGRATION DELIBERATELY DOES **NOT** DO
-- ══════════════════════════════════════════════════════════════════════════════
--
-- It does not touch `total_amount`. That column is written `0.00` at submission ON PURPOSE —
-- `overtime-create.ts` records why: an application awaiting approval must not already carry a
-- payable figure, because the APPROVER confirms the rate. A multi-entry submission changes nothing
-- about that, and making the figure appear earlier would be a different decision wearing this one's
-- clothes.
--
-- It does not add a `project_id`. `overtime_applications.project_name` is free-text `varchar(255)`,
-- where `claim_items` gained a real FK to `projects`. That inconsistency is REAL and it means
-- overtime cost cannot be attributed to a project the way a claim line now can — but it is a
-- separate change with its own migration, its own backfill question and its own screen work, and it
-- was not what was asked for. Named here so it is a known gap rather than an oversight.
--
-- It does not add a cap column. The 104-hour monthly limit is statutory — Employment (Limitation of
-- Overtime Work) Regulations 1980, regulation 2 — and lives as `MONTHLY_OVERTIME_CAP` in
-- `src/lib/overtime-validate.ts`. A company cannot configure its way past a regulation, so there is
-- nothing to store.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MARIADB
-- ══════════════════════════════════════════════════════════════════════════════
--
-- No generated column and no arithmetic in any CHECK. `database/mileage_module.sql` shipped two
-- STORED GENERATED columns that MySQL 8.0.45 accepted here and MariaDB refused on the server with
-- error 1901, leaving a half-applied migration. Error 1901 covers CHECK clauses too. Nothing in this
-- file goes near either construct.
--
-- IDEMPOTENT. MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so every ALTER sits behind an
-- information_schema guard and the no-op branch is `DO 0`. The backfill is narrowed by the value it
-- sets, so a second run changes nothing.
--
-- `-- >>>` IS THE SEPARATOR AND EACH CHUNK IS ONE STATEMENT. `scripts/run-sql.js` splits on that
-- marker and opens the connection with `multipleStatements: false`, so SET, PREPARE, EXECUTE and
-- DEALLOCATE are four chunks.
--
-- Run:  node scripts/run-sql.js database/overtime_submission.sql
-- ============================================================================
-- >>>
-- 1/3 the column.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND COLUMN_NAME = 'submission_ref') = 0,
  'ALTER TABLE `overtime_applications`
     ADD COLUMN `submission_ref` VARCHAR(50) NULL DEFAULT NULL
       COMMENT ''The overtime_number of the FIRST entry in the submission. Equals own number when filed alone.''
       AFTER `overtime_number`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 2/3 the index. The review screen groups by this column, so it is read far more than it is written.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND INDEX_NAME = 'idx_overtime_submission') = 0,
  'ALTER TABLE `overtime_applications`
     ADD INDEX `idx_overtime_submission` (`submission_ref`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 3/3 Backfill. An entry filed alone is a group of one, which is true and saves every reader a
-- "not part of a group" branch for rows that already have a number.
UPDATE `overtime_applications`
   SET `submission_ref` = `overtime_number`
 WHERE `submission_ref` IS NULL
-- >>>
-- VERIFICATION. `scripts/run-sql.js` prints a row set, so this is what the operator reads back.
--
-- `db_version` is printed because the previous release failed on exactly that difference: the
-- generated columns in `database/mileage_module.sql` were measured on MySQL 8.0.45 here and refused
-- by MariaDB on the server. Nothing in THIS file depends on an engine extension, and the figure is
-- here so the reader can see which engine answered.
--
-- `EXTRA LIKE '%STORED GENERATED%'`, not `'%GENERATED%'`: `created_at` and `updated_at` carry
-- `DEFAULT_GENERATED`, and that string contains the word. The looser pattern made the mileage
-- diagnostic report 2 generated columns on a correctly plain table, and a diagnostic that reads
-- wrong is worse than none because it is believed.
SELECT VERSION() AS db_version,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND COLUMN_NAME = 'submission_ref') AS col_1,
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND INDEX_NAME = 'idx_overtime_submission') AS idx_1,
       (SELECT COUNT(*) FROM `overtime_applications`
         WHERE `submission_ref` IS NULL) AS unset_0,
       (SELECT COUNT(*) FROM `overtime_applications`) AS rows_total,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND EXTRA LIKE '%STORED GENERATED%') AS stored_gen_0
-- >>>
