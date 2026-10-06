-- OVERTIME: WHICH PROJECT THE WORK BELONGS TO
-- ============================================================================
--
-- Requested from the screen: "Project or Task ini boleh dropdown dari projek yang mana satu".
--
-- `database/overtime_submission.sql` named this exact gap and declined to close it in that change:
--
--     "It does not add a `project_id`. `overtime_applications.project_name` is free-text
--      varchar(255), where `claim_items` gained a real FK to `projects`. That inconsistency is REAL
--      and it means overtime cost cannot be attributed to a project the way a claim line now can —
--      but it is a separate change with its own migration, its own backfill question and its own
--      screen work."
--
-- This is that separate change.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE EVIDENCE THAT FREE TEXT WAS THE WRONG ANSWER
-- ══════════════════════════════════════════════════════════════════════════════
--
-- MEASURED on the live table. The only overtime row on this installation reads:
--
--     overtime_number = 'OT-202609-001',  project_name = 'Selangor'
--
-- "Selangor" is a STATE, not a project. The box next to it on the old form was the State dropdown,
-- and somebody typed the state into the project field anyway. A free-text field asked to carry a
-- reference will be filled with whatever the person had in mind, and nothing can read it back.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY THE COLUMN IS NULLABLE, AND WHY `project_name` STAYS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- The field is labelled "Project **or Task**", and the second half is real: somebody works late on
-- month-end closing, on a tender submission, on a server migration. None of those is a row in
-- `projects`, and forcing one would make people pick a wrong project rather than leave it empty.
--
-- So `project_id` is NULL when the overtime was not for a project, and `project_name` carries what
-- it was for. Three further reasons the text column is not replaced:
--
--   1. The existing row says 'Selangor'. There is no project it maps to, and inventing one to
--      satisfy a NOT NULL constraint would be fabricating a cost attribution.
--   2. ON DELETE SET NULL means a deleted project empties `project_id`. If the name went with it,
--      an approved overtime record would stop saying what the work was. The name is the record's own
--      account of itself, which is exactly what a historical row should keep.
--   3. `checkOvertime` requires a project or task to be stated, and every reader of `project_name`
--      — the review screen, the details endpoint, the audit entries — keeps working untouched.
--
-- When a project IS chosen the endpoint writes BOTH: the id, and the project's title copied into
-- `project_name`. The copy is deliberate denormalisation for the reason in (2), and the id is what
-- anything aggregating cost per project must join on.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `ON DELETE SET NULL`, BECAUSE THAT IS WHAT EVERY SIBLING DOES
-- ══════════════════════════════════════════════════════════════════════════════
--
-- MEASURED from `information_schema.REFERENTIAL_CONSTRAINTS`. Every table that records a cost and
-- mentions a project uses SET NULL:
--
--     assets.project_id           fk_asset_project    SET NULL
--     claim_items.project_id      fk_ci_project       SET NULL
--     expenses.project_id         fk_exp_project      SET NULL
--     mileage_trips.project_id    fk_mtrip_project    SET NULL
--     purchase_orders.project_id  fk_po_project       SET NULL
--     purchase_requests.project_id fk_preq_project    SET NULL
--     sales_invoices.project_id   fk_sinv_project     SET NULL
--
-- The CASCADE rules on `projects` belong to tables that are PART of a project — its milestones,
-- its tasks, its documents, its participants. Those die with it. An approved overtime application
-- is money owed to a person; deleting a project must never delete a wage record, so CASCADE would
-- be a data-loss bug wearing a foreign key.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- NO BACKFILL. DELIBERATELY.
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `projects` holds ZERO rows on this installation, so there is nothing to match against. And even
-- with projects present, matching `project_name` text to a title would be a GUESS — this column
-- drives cost attribution, and a guessed foreign key is worse than an honest NULL because it looks
-- like a fact. Existing rows keep their text and get `project_id = NULL`, which reads correctly as
-- "filed before this was asked for".
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MARIADB
-- ══════════════════════════════════════════════════════════════════════════════
--
-- No generated column and no arithmetic in any CHECK — `database/mileage_module.sql` shipped two
-- STORED GENERATED columns that MySQL 8.0.45 accepted here and MariaDB refused on the server with
-- error 1901, leaving a half-applied migration. Nothing here goes near either construct.
--
-- `ADD COLUMN`, `ADD INDEX` and `ADD CONSTRAINT ... FOREIGN KEY` are standard on both engines.
-- Both tables are InnoDB with `utf8mb4_unicode_ci` (measured), and `projects.id` is `int` with
-- `auto_increment`, so `INT NULL` matches it exactly — a mismatched width is the usual cause of
-- errno 150 when adding a foreign key.
--
-- IDEMPOTENT. MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so every ALTER sits behind an
-- information_schema guard and the no-op branch is `DO 0`. All three guards are already satisfied on
-- this machine, so a run here changes nothing and only prints the verification row.
--
-- `-- >>>` IS THE SEPARATOR AND EACH CHUNK IS ONE STATEMENT. `scripts/run-sql.js` splits on that
-- marker and opens the connection with `multipleStatements: false`, so SET, PREPARE, EXECUTE and
-- DEALLOCATE are four chunks.
--
-- Run:  node scripts/run-sql.js database/overtime_project.sql
-- ============================================================================
-- >>>
-- 1/3 the column, directly after the text it complements rather than replaces.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND COLUMN_NAME = 'project_id') = 0,
  'ALTER TABLE `overtime_applications`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL
       COMMENT ''The project this overtime belongs to. NULL when it was a task, not a project.''
       AFTER `project_name`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 2/3 the index. Added before the constraint ON PURPOSE: a foreign key needs an index on its own
-- column, and without one InnoDB silently creates a differently-named one, which the guard below
-- would then not recognise on a second run.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND INDEX_NAME = 'idx_overtime_project') = 0,
  'ALTER TABLE `overtime_applications`
     ADD INDEX `idx_overtime_project` (`project_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 3/3 the constraint. SET NULL, for the reason given in the header: deleting a project must not
-- delete a wage record.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND CONSTRAINT_NAME = 'fk_ot_project') = 0,
  'ALTER TABLE `overtime_applications`
     ADD CONSTRAINT `fk_ot_project` FOREIGN KEY (`project_id`)
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
-- VERIFICATION. `scripts/run-sql.js` prints a row set, so this is what the operator reads back.
--
-- `db_version` is printed because a previous release failed on exactly that difference: the
-- generated columns in `database/mileage_module.sql` were measured on MySQL 8.0.45 here and refused
-- by MariaDB on the server.
--
-- `delete_rule_setnull` must read SET NULL. If it ever reads CASCADE, deleting a project deletes
-- approved overtime, and that is the one outcome this file exists to prevent.
--
-- `EXTRA LIKE '%STORED GENERATED%'`, not `'%GENERATED%'`: `created_at` and `updated_at` carry
-- `DEFAULT_GENERATED`, and the looser pattern reports a correctly plain table as generated.
SELECT VERSION() AS db_version,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND COLUMN_NAME = 'project_id') AS col_1,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND COLUMN_NAME = 'project_name') AS text_col_kept_1,
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND INDEX_NAME = 'idx_overtime_project') AS idx_1,
       (SELECT COALESCE(MAX(r.DELETE_RULE), 'MISSING')
          FROM information_schema.REFERENTIAL_CONSTRAINTS r
         WHERE r.CONSTRAINT_SCHEMA = DATABASE()
           AND r.CONSTRAINT_NAME = 'fk_ot_project') AS delete_rule_setnull,
       (SELECT COUNT(*) FROM `overtime_applications`
         WHERE `project_id` IS NOT NULL
           AND `project_id` NOT IN (SELECT `id` FROM `projects`)) AS orphans_0,
       (SELECT COUNT(*) FROM `overtime_applications`) AS rows_total,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND EXTRA LIKE '%STORED GENERATED%') AS stored_gen_0
-- >>>
