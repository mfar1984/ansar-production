-- ============================================================
-- ESS attachment size limit — Settings > Configuration > General
-- Date: 2026-10-20
--
-- Adds `system_settings.ess_attachment_mb`: the per-file cap for the three ESS
-- screens that carry an attachment — Claims, Expenses and Leave.
--
-- ── WHY A NEW COLUMN RATHER THAN REUSING `max_upload_mb` ──
--
-- `max_upload_mb` already exists, already has a field on this very screen, and is
-- read by NOTHING. Measured: 9 references in `src`, all of them the form field, its
-- validation and the save. No upload endpoint reads it. So reusing it would have
-- been tempting.
--
-- It cannot be reused, because its DEFAULT IS 50 and the ESS limit was 5. Pointing
-- the ESS endpoints at that column would multiply the attachment limit by ten on
-- every existing install the moment this deploys — a behaviour change nobody asked
-- for, and a wider upload surface granted silently.
--
-- So this column DEFAULTS TO 5, which is exactly the value that was hardcoded in
-- `claims/submit.ts`, `expenses/submit.ts` and `leave/apply.ts`. Applying this
-- migration changes no behaviour at all. The setting only does something once an
-- operator deliberately changes it.
--
-- `max_upload_mb` is left exactly as it is. It is a separate defect — a field that
-- saves and governs nothing, whose hint names Downloads and tender documents while
-- Downloads enforces a hardcoded 5 GB and tender documents enforce 15 MB. Fixing it
-- means deciding what should happen to a 5 GB channel, which is not this change.
--
-- Idempotent. Statement separator: a line reading "-- >>>"
-- ============================================================
-- >>>
DROP PROCEDURE IF EXISTS ansar_add_column
-- >>>
CREATE PROCEDURE ansar_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_ddl TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND COLUMN_NAME = p_column
  ) THEN
    SET @ddl_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_ddl);
    PREPARE stmt FROM @ddl_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END
-- >>>
CALL ansar_add_column('system_settings', 'ess_attachment_mb', 'INT NOT NULL DEFAULT 5')
-- >>>
DROP PROCEDURE IF EXISTS ansar_add_column
-- >>>
-- A row written before this column existed gets the documented default rather than
-- MySQL's zero, because `INT NOT NULL` with no value is 0 and a limit of 0 MB would
-- refuse every attachment while looking like a deliberate setting.
UPDATE `system_settings`
   SET `ess_attachment_mb` = 5
 WHERE `ess_attachment_mb` IS NULL OR `ess_attachment_mb` < 1
