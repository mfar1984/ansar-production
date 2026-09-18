-- ============================================================
-- Operations > Asset Management — the VEHICLE profile
--
-- A CHILD TABLE, NOT EIGHT MORE COLUMNS ON `assets`
--
-- A car is an asset with extra facts: a plate, a chassis, an engine, a fuel type. The obvious
-- change is eight columns on `assets`, and it is the wrong one for three measured reasons.
--
--   1. `assets/index.ts` carries a 34-column INSERT whose own comment says "Re-counted after every
--      edit here, because a miscount does not throw — it shifts every value after the gap by one
--      position and MySQL coerces most of them". The same list exists a second time in
--      `assets/bulk.ts`, and `asset-install-batch.test.js` compares them. Eight columns means
--      34 -> 42 in two places.
--   2. They would be NULL on roughly every row. The register holds laptops, furniture, cabling and
--      software licences; a chassis number is meaningless on all of them.
--   3. It does not stop. This is the FIRST of a class of requests — a software licence wants a key
--      and a seat count, a CCTV unit wants an IP address and a channel. Twelve categories times N
--      columns on one table.
--
-- So it is a child table, which is what this module already does for every other set of extra facts
-- about an asset: `asset_obligations`, `asset_documents`, `asset_movements`, `asset_maintenance`,
-- `asset_service_batches`. The next profile is a sibling table, not another eight columns.
--
-- `asset_id` IS the primary key, so the 1:1 is enforced by the schema rather than by the endpoint.
-- One asset cannot have two plate records, and no code has to check.
--
-- WHICH CATEGORIES GET A PROFILE IS DECIDED HERE, AND ONLY HERE
--
-- `asset_categories.detail_form` names the profile a category reveals. It is seeded by THIS FILE and
-- there is deliberately NO control for it on the Asset Categories screen.
--
-- A profile is CODE, not configuration: each one needs a table, a form section and a panel group.
-- A settings toggle would let somebody switch on `software_licence` before its form exists, and they
-- would get an empty section or an error — the same mistake as a clickable tab whose page is not
-- built yet.
--
-- WHY NOT A SECOND FIELD ON THE FORM ASKING "IS THIS A VEHICLE?"
--
-- Because `category` already answers "what kind of thing is this", in five places, and only one of
-- them is the form: the CSV import (`ASSET_IMPORT_COLUMNS` has a `category` column), the Install
-- Assets wizard, bulk edit, the register filter, and the reports. A separate field would be set by
-- the form alone — so forty vehicles imported from a spreadsheet would arrive with no profile and
-- their plate fields would be unreachable, with nothing on screen explaining why.
--
-- It would also permit two nonsense states the form should not be able to produce: Vehicle with no
-- profile, and Office Furniture with a chassis number.
--
-- WHY ROAD TAX IS A COLUMN AND NOT AN `asset_obligations` ROW
--
-- It looks like one. It expires, it is renewed annually, and `asset_obligations` already has the
-- dates, the rate and the "N days left" badge.
--
-- But `obligationCover()` takes the LATEST `ends_on` across every obligation and that figure answers
-- "is a fault on this unit still covered". Road tax has nothing to do with whether a repair is
-- chargeable, so a van taxed to December would read as COVERED and somebody would do a warranty job
-- for free. The fix is to exclude it from that function — and once excluded, the badge and the
-- Coverage screen no longer see it either, which was the entire reason for putting it there.
--
-- So: one DATE column, with the countdown computed by the `daysUntil` helper the register already
-- uses. Less machinery and no wrong answer.
--
-- THE BACKFILL, AND THE ONE THING IT DELIBERATELY DOES NOT DO
--
-- Vehicles already in the register carry the chassis and the engine number JAMMED INTO `serial_no`
-- separated by a slash — `PN1HS02PX04023608/2KDU996863` on a Toyota Hiace, where the right-hand part
-- is the 2KD-FTV engine number. That split is deterministic, so it is done here.
--
-- `serial_no` is LEFT EXACTLY AS IT IS. A migration that also cleared it could not be undone if the
-- split misread one row.
--
-- THE PLATE IS NOT BACKFILLED, on purpose. Some rows hold it in `tag_no` (`WXY 4471`) and some hold
-- an internal sticker there instead (`VEH1`). No pattern separates them: both are three letters
-- followed by digits. A guess would put `VEH1` into a UNIQUE plate column, so the plate is typed in
-- once per vehicle instead.
--
-- ROW_FORMAT=DYNAMIC IS NOT DECORATION
--
-- `sql-portability.test.js` runs SHOW CREATE TABLE over every table in the database and fails any
-- that does not STATE its row format, because `SHOW CREATE TABLE` prints it only when it was set
-- explicitly — so a dump of a table that merely inherited the default restores as whatever the
-- importing server prefers, and 24 tables here are wide enough to be refused under COMPACT.
--
-- NO NEW PERMISSIONS. The vehicle fields are part of the asset form, so they answer to
-- `assets_internal_create` / `_edit` and the external pair, exactly like the PIC fields.
--
-- Idempotent. Adding a column and its DDL are separate statements over a session variable.
-- Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_vehicles.sql
-- ============================================================

-- >>>
CREATE TABLE IF NOT EXISTS `asset_vehicles` (
  -- PRIMARY KEY, not merely a foreign key. This is what makes the relationship 1:1 in the schema
  -- instead of in whichever endpoint happened to remember.
  `asset_id`       INT UNSIGNED NOT NULL,

  -- Unique nationally, so UNIQUE here. Two assets sharing a plate is a data-entry error every time,
  -- and the endpoint turns the duplicate-key error into a sentence naming the field.
  -- NULL is allowed and MySQL permits many NULLs in a unique index, so a vehicle whose plate is not
  -- known yet still saves.
  `plate_no`       VARCHAR(20)  DEFAULT NULL COMMENT 'Registration number, e.g. WYB 848',

  -- The VIN. Unique worldwide by construction, so UNIQUE for the same reason as the plate.
  `chassis_no`     VARCHAR(40)  DEFAULT NULL COMMENT 'Chassis / VIN',

  -- Indexed but NOT unique: an engine can legitimately be replaced and moved between vehicles, so a
  -- duplicate is a fact rather than a mistake.
  `engine_no`      VARCHAR(40)  DEFAULT NULL,

  `fuel_type`      ENUM('petrol','diesel','hybrid','electric','ngv') DEFAULT NULL,
  `colour`         VARCHAR(40)  DEFAULT NULL,

  -- First registration. Never changes, which is why it is here and not an obligation.
  `registered_on`  DATE         DEFAULT NULL,

  -- Renewed annually. Held as the CURRENT expiry — see the header for why this is not an obligation.
  `road_tax_until` DATE         DEFAULT NULL,

  `created_by`     VARCHAR(150) DEFAULT NULL,
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`asset_id`),
  UNIQUE KEY `uq_avehicle_plate` (`plate_no`),
  UNIQUE KEY `uq_avehicle_chassis` (`chassis_no`),
  KEY `idx_avehicle_engine` (`engine_no`),
  -- "Whose road tax runs out next" is the one question this table will be asked in bulk.
  KEY `idx_avehicle_road_tax` (`road_tax_until`),

  -- CASCADE, unlike the SET NULL foreign keys on `assets` itself. Those point AT other things that
  -- outlive the asset — an employee, a client, a project. This row is PART OF the asset: deleting
  -- the van must not leave its plate behind with nothing referencing it.
  CONSTRAINT `fk_avehicle_asset` FOREIGN KEY (`asset_id`)
    REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── The profile flag on the category master ──
SET @avehicle_flag := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_categories'
     AND COLUMN_NAME = 'detail_form'
)

-- >>>
SET @avehicle_flag_ddl := IF(
  @avehicle_flag = 0,
  'ALTER TABLE `asset_categories`
     ADD COLUMN `detail_form` ENUM(''none'',''vehicle'') NOT NULL DEFAULT ''none''
       COMMENT ''Which extra form section this category reveals. Seeded by migration, never by the UI''
       AFTER `asset_class`',
  'DO 0'
)

-- >>>
PREPARE avehicle_flag_stmt FROM @avehicle_flag_ddl

-- >>>
EXECUTE avehicle_flag_stmt

-- >>>
DEALLOCATE PREPARE avehicle_flag_stmt

-- >>>
-- Seeded by NAME because that is what `assets.category` holds. Renaming the category afterwards does
-- NOT lose the flag: it travels on the row, keyed by `id`. What a rename does break is the lookup
-- from an asset back to its category — which is why the form also reveals the section for any asset
-- that ALREADY has an `asset_vehicles` row, so an existing van stays editable either way.
UPDATE `asset_categories` SET `detail_form` = 'vehicle' WHERE `name` = 'Vehicle'

-- >>>
-- ── Backfill: split the chassis and engine out of `serial_no` ──
--
-- Only where there is EXACTLY one slash, so a serial that happens to contain two is left for a human
-- rather than cut in an arbitrary place. `INSERT IGNORE` covers both re-runs (the asset already has a
-- row, PK conflict) and the unlikely duplicate chassis (unique-key conflict) without failing the
-- migration.
--
-- `NULLIF(TRIM(...), '')` so a serial like `ABC/` contributes a NULL rather than an empty string:
-- an empty string in a UNIQUE column collides with the next empty string, a NULL does not.
INSERT IGNORE INTO `asset_vehicles` (`asset_id`, `chassis_no`, `engine_no`, `created_by`)
SELECT a.`id`,
       NULLIF(TRIM(SUBSTRING_INDEX(a.`serial_no`, '/', 1)), ''),
       NULLIF(TRIM(SUBSTRING_INDEX(a.`serial_no`, '/', -1)), ''),
       'migration: asset_vehicles.sql'
  FROM `assets` a
 WHERE a.`category` = 'Vehicle'
   AND a.`serial_no` IS NOT NULL
   AND LENGTH(a.`serial_no`) - LENGTH(REPLACE(a.`serial_no`, '/', '')) = 1

-- >>>
-- ── Verification, reported rather than assumed ──
--
-- `vehicle_categories` must be at least 1, or the seed above matched nothing and the form section
-- would never appear. `plates_to_type` is the count a human still has to fill in, which is expected
-- to be non-zero: the plate is deliberately not guessed.
SELECT
  (SELECT COUNT(*) FROM `asset_categories` WHERE `detail_form` = 'vehicle') AS vehicle_categories,
  (SELECT COUNT(*) FROM `assets` WHERE `category` = 'Vehicle')              AS vehicle_assets,
  (SELECT COUNT(*) FROM `asset_vehicles`)                                   AS detail_rows,
  (SELECT COUNT(*) FROM `asset_vehicles` WHERE `chassis_no` IS NOT NULL)    AS chassis_backfilled,
  (SELECT COUNT(*) FROM `asset_vehicles` WHERE `plate_no` IS NULL)          AS plates_to_type
