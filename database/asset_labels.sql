-- ============================================================
-- ASSET LABELS — `label_printed_at`, and the rule it lets us relax
--
-- WHAT THIS COLUMN IS ACTUALLY FOR
--
-- `installAssetBatch` refused a unit that had neither a serial number nor an asset tag. The reason
-- was recorded in `asset_batch_install.sql` and in the code itself, and it was correct at the time:
-- during a stock take somebody reads a label off the side of the box, and two units that carry no
-- label cannot be told apart by the person holding the count sheet. Three unmarked keyboards produce
-- three lines that cannot be matched to three objects, and the session cannot be reconciled.
--
-- Note what that argument is about. It is about the PHYSICAL discriminator, not the database one.
-- The database one has never been missing: `asset_no` is allocated by the engine itself under
-- `uq_asset_no`. Serial-or-tag was pressed into service as the physical discriminator for one reason
-- only — nothing else was printed on the object.
--
-- A printed QR label carries `asset_no`. So once labels exist, requiring a serial is requiring a
-- SECOND identifier to do a job the first one now does, and a second identifier is a second thing to
-- keep in step. The same argument that kept a `code` column off `asset_locations`.
--
-- WHY THE RULE COULD NOT SIMPLY BE DELETED
--
-- The failure it prevented is real. Relaxing the rule without a replacement means three unmarked
-- keyboards, labels never printed, and a count that cannot be reconciled — discovered during the
-- count, which is the worst moment to discover it.
--
-- So the hard refusal becomes a VISIBLE STATE. An asset with no serial, no tag and no label is
-- "needs a label", counted on the register and on the stock take screen. The protection survives as
-- information, delivered before the count instead of during it.
--
-- WITHOUT THIS COLUMN THE WARNING WOULD BE PERMANENT NOISE
--
-- The alternative was to derive it from `serial_no` and `tag_no` alone. But that stays true forever:
-- an asset deliberately identified by its QR label has no serial and no tag by design, so it would
-- be flagged for the rest of its life. A warning that never clears is a warning everybody learns to
-- skip, and then the one unit that genuinely has no identifier is skipped with it. The column is
-- what lets the flag CLEAR.
--
-- IT SAYS "GENERATED", NOT "LABELLED", AND THAT IS DELIBERATE
--
-- This system cannot know whether anybody peeled the sticker off and put it on the box. Claiming it
-- does would be a column that lies. It records the one fact available: a label for this unit was
-- rendered for printing at this moment. `tag_no` is deliberately NOT auto-filled with the asset
-- number for the same reason — the form calls that field "the sticker physically on the item", and
-- writing a value there before anybody prints one makes the register state something untrue, sending
-- a stock taker to look for a sticker that was never made.
--
-- NO INDEX, DELIBERATELY
--
-- The only query is a COUNT for the metric strip, over the same table the register already scans
-- several times for its other metrics. An index on a column that is NULL for most rows on the day it
-- lands would not be used, and the register's existing summary sets the precedent for the cost.
--
-- Idempotent: re-running finds the column present and does nothing. MySQL has no
-- `ADD COLUMN IF NOT EXISTS`, so the existence test and the DDL are separate statements over a
-- session variable. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_labels.sql
-- ============================================================

-- >>>
SET @asset_label := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
     AND COLUMN_NAME = 'label_printed_at'
)

-- >>>
SET @asset_label_ddl := IF(
  @asset_label = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `label_printed_at` DATETIME DEFAULT NULL
       COMMENT ''When a QR label was last GENERATED for this unit. Not proof it was stuck on''
       AFTER `tag_no`',
  'DO 0'
)

-- >>>
PREPARE asset_label_stmt FROM @asset_label_ddl

-- >>>
EXECUTE asset_label_stmt

-- >>>
DEALLOCATE PREPARE asset_label_stmt

-- >>>
-- ── Verification ──
--
-- Reports the column and how many units currently have no physical identifier at all. On a register
-- that predates this change every row reads 0 printed labels, and the "needs a label" figure is the
-- honest size of the backlog rather than an error.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME = 'label_printed_at')                      AS column_present,
  (SELECT COUNT(*) FROM `assets`
    WHERE `holder` = 'internal'
      AND (`serial_no` IS NULL OR `serial_no` = '')
      AND (`tag_no` IS NULL OR `tag_no` = '')
      AND `label_printed_at` IS NULL)                            AS internal_needs_a_label,
  (SELECT COUNT(*) FROM `assets` WHERE `label_printed_at` IS NOT NULL) AS labels_generated
