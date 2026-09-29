-- ============================================================================
-- MANY APPROVER ACCOUNTS PER APPROVAL LEVEL
--
-- Run with:  node scripts/run-sql.js database/approval_multi_approver.sql
--
-- ── THE PROBLEM THIS REMOVES ──
--
-- `hr_approval_workflow` carried `uq_module_level` UNIQUE (`module`, `level`).
-- That is one approver per level, enforced by the storage engine, and it is the
-- wrong shape for how approval actually works here: an HR team has ten people
-- who may sign at level 1, and a board has three who may sign at level 2. Under
-- the old index, naming a second HR clerk at level 1 meant either overwriting the
-- first or inventing a level 2 that is not really a second stage — which then
-- makes the real second stage level 3 and reorders the whole chain.
--
-- After this migration a level is a STAGE, and a stage may hold any number of
-- accounts. Any ONE of them signing advances the application to the next stage.
--
-- ── WHY THE REPLACEMENT INDEX STILL EXISTS ──
--
-- `uq_module_level_approver` (`module`, `level`, `approver_admin_id`) keeps the
-- one thing that genuinely is a duplicate: the SAME account listed twice at the
-- SAME level. Two identical rows would make that person count twice towards the
-- level and show up twice in the settings table, and there is no reading of the
-- data where that is intended.
--
-- Its leftmost prefix is (`module`, `level`), which is what `getChain()` filters
-- and orders on, so dropping the old index costs nothing at read time.
--
-- `approver_admin_id` is NULLABLE and MySQL permits repeated NULLs in a UNIQUE
-- index. That is not a hole worth closing here: the API refuses to insert a row
-- without an account (`approver_admin_id` must be an integer >= 1), and a chain
-- row naming nobody has no meaning to the engine either way.
--
-- ── IDEMPOTENT, AND WHY IT HAS TO BE ──
--
-- MySQL has no `DROP INDEX IF EXISTS` and no `CREATE INDEX IF NOT EXISTS`, so a
-- bare DDL statement is an error on the second run. Production is MariaDB and
-- development is MySQL 8.0.45; both understand `information_schema.STATISTICS`
-- and prepared statements, so the same file runs on both.
--
-- One statement per `-- >>>` block and no trailing semicolons: the runner sends
-- each block to the driver as a single statement with `multipleStatements` off.
-- Same shape as `opening_balances.sql`.
--
-- ── SAFETY ──
--
-- No existing row can violate the new index. The old UNIQUE on (`module`,
-- `level`) already made a duplicate (`module`, `level`, `approver_admin_id`)
-- impossible, so the CREATE cannot fail on legacy data. The verification block at
-- the end reports the duplicate count anyway rather than assuming it.
-- ============================================================================

-- >>>
-- ── 1. Drop the one-approver-per-level constraint ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_approval_workflow'
         AND INDEX_NAME = 'uq_module_level'
    ),
    'ALTER TABLE `hr_approval_workflow` DROP INDEX `uq_module_level`',
    'SELECT ''uq_module_level already dropped'' AS note'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 2. Add the constraint that only forbids the SAME account twice at one level ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hr_approval_workflow'
         AND INDEX_NAME = 'uq_module_level_approver'
    ),
    'SELECT ''uq_module_level_approver already exists'' AS note',
    'ALTER TABLE `hr_approval_workflow`
       ADD UNIQUE KEY `uq_module_level_approver` (`module`, `level`, `approver_admin_id`)'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 3. Report the result ──
--
-- `levels` is COUNT(DISTINCT level), not COUNT(*), because that is now the number
-- of STAGES an application must pass through. `chain.length` used to be the same
-- number and no longer is — which is exactly the arithmetic the application code
-- had to be changed for.
SELECT `module`,
       COUNT(*)                       AS approver_rows,
       COUNT(DISTINCT `level`)         AS levels,
       MAX(`level`)                    AS highest_level,
       COUNT(*) - COUNT(DISTINCT CONCAT(`level`, ':', COALESCE(`approver_admin_id`, 0)))
                                       AS duplicate_rows
  FROM `hr_approval_workflow`
 WHERE `status` = 'active'
 GROUP BY `module`
 ORDER BY `module`
