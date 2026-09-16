-- ============================================================
-- ASSET PIC — the named person at the client site, and their job title
--
-- WHY TWO PLAIN COLUMNS AND NOT A FOREIGN KEY
--
-- A delivery list for an installed base names a person per unit. A real one, measured: the KEMAS
-- Pahang list carries 115 units across 16 sites, each row naming a PIC and their Jawatan.
--
-- Those people are the CLIENT's staff. This system has no table for them, and building one means
-- maintaining another organisation's HR data — transfers, promotions, resignations — which we will
-- never be told about and therefore never keep current. Stale HR data is worse than none, because
-- people trust a name that is on a screen.
--
-- So it is recorded as a SNAPSHOT: who held this unit at the client site. Changes go where every
-- other change of holder already goes, `asset_movements`, which carries `from_holder` and
-- `to_holder` as VARCHAR(200) for exactly this reason.
--
-- The same pattern is already in this table twice over: `site_name` and `site_address` sit beside
-- `site_id`, snapshotting the strings next to the link. And `asset_stocktake_lines`
-- `expected_location` snapshots a location spelling on purpose.
--
-- WHY NOT THE THREE PLACES THAT LOOK LIKE THEY WOULD DO
--
--   `asset_sites.contact_person` — ONE per site. Measured against the real file: the KEMAS Pahang
--   HQ site alone has 26 units and 26 DIFFERENT people. A site contact is who you ring about the
--   site; it cannot say who is sitting at unit 14.
--
--   `assets.employee_id` — that is `employees.id`, OUR staff, under a real foreign key. A client
--   officer is not an employee of ours and putting them there would corrupt every internal report
--   that joins it, starting with Employee Holdings.
--
--   `assets.notes` — a free-text dump. It cannot be a column in an export, cannot be filtered as a
--   field, and cannot be corrected in bulk. Two facts that a delivery list states separately, in
--   separate columns, should not arrive as one sentence.
--
-- PLACED AFTER `installed_on`, WHICH IS THE POINT
--
-- These are INSTALLATION facts. They belong beside the site, the address and the date the unit was
-- put in — not up with the serial and the tag, which are identification. A reader scanning the
-- column list should find the whole installation story in one run.
--
-- THE WIDTHS ARE MEASURED, NOT GUESSED
--
-- `pic_name` VARCHAR(150) matches `asset_sites.contact_person` VARCHAR(150) exactly. It is the same
-- kind of fact about the same kind of person, so a value can be promoted from one to the other
-- without truncation, and neither column has to be widened when the other is.
--
-- `pic_position` VARCHAR(150): the longest Jawatan in the real 115-row file is 32 characters
-- (`PEM PEMBANGUNAN MASYARAKAT KANAN`). 150 is headroom for a title somebody spells out in full,
-- not a number picked because it looked safe.
--
-- NO INDEX, AND THIS TIME THE REASON IS MEASURED
--
-- The register's only search over a name is built by `likeTerm`, which returns `%value%`. A LEADING
-- wildcard cannot use a B-tree index — MySQL scans regardless. So an index here would be paid for
-- on every insert and update in the batch engine and used by nothing. The same conclusion as
-- `label_printed_at`, reached from a different direction.
--
-- NO CHECK CONSTRAINT, DELIBERATELY
--
-- These are external-only in MEANING, and it is tempting to add
-- `CHECK (holder <> 'internal' OR pic_name IS NULL)`.
--
-- It is not added, for consistency. Six columns on this table are ALREADY external-only and NONE of
-- them carries such a constraint: `client_id`, `site_id`, `project_id`, `site_name`, `site_address`
-- and `installed_on` are all enforced in the endpoints, which write NULL for an internal asset.
-- Guarding PIC alone in the database would imply the other six are guaranteed there too, and they
-- are not — which is a worse state than guarding none of them, because the next reader would trust
-- it.
--
-- NULL MEANS NOT RECORDED
--
-- Both nullable, and `str()` in `operations.ts` turns an empty form field into NULL rather than an
-- empty string, so a blank stays a blank. That matters on the real file: 2 of the 115 rows name no
-- person at all and 7 name no Jawatan, several already highlighted by whoever prepared it. A row
-- with no PIC is a fact about the delivery, not a defect to paper over with a placeholder.
--
-- Idempotent, in TWO independently guarded steps. A single guard covering both columns would report
-- the second as done while it was missing, which is the failure `asset_stocktake_plan.sql` records
-- from its own four-guard split. MySQL has no `ADD COLUMN IF NOT EXISTS`, so each existence test and
-- its DDL are separate statements over a session variable.
-- Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_pic.sql
-- ============================================================

-- >>>
SET @asset_pic_name := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
     AND COLUMN_NAME = 'pic_name'
)

-- >>>
SET @asset_pic_name_ddl := IF(
  @asset_pic_name = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `pic_name` VARCHAR(150) DEFAULT NULL
       COMMENT ''The person holding this unit at the client site. A snapshot, not a link''
       AFTER `installed_on`',
  'DO 0'
)

-- >>>
PREPARE asset_pic_name_stmt FROM @asset_pic_name_ddl

-- >>>
EXECUTE asset_pic_name_stmt

-- >>>
DEALLOCATE PREPARE asset_pic_name_stmt

-- >>>
SET @asset_pic_pos := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
     AND COLUMN_NAME = 'pic_position'
)

-- >>>
-- `AFTER pic_name` and not `AFTER installed_on`, so the pair reads in the order a delivery list
-- prints them even when this half is applied on its own.
SET @asset_pic_pos_ddl := IF(
  @asset_pic_pos = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `pic_position` VARCHAR(150) DEFAULT NULL
       COMMENT ''The job title recorded for that person, as the delivery list stated it''
       AFTER `pic_name`',
  'DO 0'
)

-- >>>
PREPARE asset_pic_pos_stmt FROM @asset_pic_pos_ddl

-- >>>
EXECUTE asset_pic_pos_stmt

-- >>>
DEALLOCATE PREPARE asset_pic_pos_stmt

-- >>>
-- ── Verification ──
--
-- Both columns, their order relative to `installed_on`, and how many units currently name a person.
-- On a register that predates this change every count reads 0, which is the honest starting point
-- rather than an error. `no_index_on_pic` must stay 0: an index here would be written on every
-- batch insert and used by nothing, because the search that reads these columns uses a leading
-- wildcard.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME = 'pic_name')                              AS pic_name_present,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME = 'pic_position')                          AS pic_position_present,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME IN ('pic_name', 'pic_position'))           AS no_index_on_pic,
  (SELECT COUNT(*) FROM `assets`
    WHERE `holder` = 'external' AND `pic_name` IS NOT NULL AND `pic_name` <> '') AS external_with_pic,
  (SELECT COUNT(*) FROM `assets`
    WHERE `holder` = 'internal'
      AND ((`pic_name` IS NOT NULL AND `pic_name` <> '')
        OR (`pic_position` IS NOT NULL AND `pic_position` <> ''))) AS internal_leak_must_be_zero
