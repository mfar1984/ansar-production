-- ============================================================
-- INTERNAL LOCATIONS — a master list for where company equipment sits
--
-- WHAT THIS FIXES
--
-- `assets.location` is free text, VARCHAR(200), commented "room, floor, site, or vehicle plate".
-- The same store gets typed three ways — "Level 3 Store", "Level 3 store", "L3 Store" — and then
-- nothing can group on it, because grouping on free text groups on typing accidents.
--
-- This is not a hypothetical. `stocktakes.ts` builds the list of locations you can scope a count
-- by from `SELECT DISTINCT location FROM assets`, and scopes the session with
-- `AND a.location = ?`. Three spellings of one store means three entries in that dropdown and a
-- count that silently misses two thirds of the room.
--
-- `asset_sites_models.sql` already fixed exactly this problem for the EXTERNAL register, and
-- stated the division of labour: "`location` stays for the shelf or room within a site; `site_id`
-- is the site." Internal equipment has no client site, so `location` IS the place — and it never
-- got the same treatment. This is that treatment.
--
-- INTERNAL ONLY, AND WHY
--
-- `location_id` is set for `holder = 'internal'`. For an external asset, `location` means the room
-- inside the CLIENT's building, and a room in a client's hospital is not one of our locations.
-- That register already has `site_id` for the place and keeps `location` as free text for the room.
--
-- `assets.location` IS KEPT, AND IT IS NOT A DUPLICATE
--
-- `location_id` is the truth. `assets.location` stays as the LABEL, written from the chosen
-- location's name by the endpoint, for two reasons:
--
--   1. `asset_stocktake_lines.expected_location` and `.actual_location` are deliberate SNAPSHOTS
--      copied off `assets.location` when a session opens. A count is evidence about a moment, so
--      those must keep freezing a string rather than following a foreign key that can be renamed
--      afterwards.
--   2. Every existing query that reads `a.location` keeps working unchanged — the stock take scope,
--      the register search, the CSV export, the bulk transfer.
--
-- Renaming a location rewrites the label on the assets pointing at it, which is exactly what
-- `asset-categories.ts` already does for `assets.category`. The stock take snapshots stay frozen,
-- which is correct: they record what was expected on the day.
--
-- NO `code`, NO `kind`, NO hierarchy
--
-- `name` is UNIQUE and that alone is what stops the drift this file exists to stop. A second
-- identifier is a second thing to keep in step, and a `kind` column nothing branches on is
-- vocabulary pretending to be data. Add them when something needs them.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_locations.sql
-- ============================================================

-- >>>
CREATE TABLE IF NOT EXISTS `asset_locations` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- VARCHAR(200) to match `assets.location` exactly. A shorter column would truncate on the
  -- backfill below and the truncated row would then never match the asset it came from.
  `name`        VARCHAR(200) NOT NULL,
  `description` VARCHAR(400) DEFAULT NULL,
  -- Inactive rather than deleted: a store that closes must stop being offered on new assets and
  -- stay readable on the forty already recorded there, and in every stock take that counted it.
  `is_active`   TINYINT(1)   NOT NULL DEFAULT 1,
  `sort_order`  INT          NOT NULL DEFAULT 0,
  `created_by`  VARCHAR(150) DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_loc_name` (`name`),
  KEY `idx_asset_loc_active` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- >>>
-- ── Seed the master FROM the data that is already there ──
--
-- Not a hand-written starter list. Inventing "Level 1 Office" for somebody else's building is a
-- guess, and it would sit in the dropdown beside the real places competing with them. Every
-- spelling already in use becomes a row, so nothing recorded is lost and the register keeps
-- resolving. Tidying the three spellings of one store into one is then a deliberate act on the
-- screen, done by somebody who knows which is right.
--
-- INSERT IGNORE, so a re-run adds only what is new.
INSERT IGNORE INTO `asset_locations` (`name`, `description`, `created_by`)
SELECT DISTINCT a.`location`, 'Carried over from free-text asset records', 'asset_locations.sql'
  FROM `assets` a
 WHERE a.`holder` = 'internal'
   AND a.`location` IS NOT NULL
   AND a.`location` <> ''

-- >>>
SET @loc_col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets' AND COLUMN_NAME = 'location_id'
)

-- >>>
SET @loc_ddl := IF(
  @loc_col = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `location_id` INT UNSIGNED DEFAULT NULL
       COMMENT ''asset_locations.id — internal only. `location` is the label kept in step with it''
       AFTER `location`,
     ADD KEY `idx_asset_location` (`location_id`)',
  'DO 0'
)

-- >>>
PREPARE loc_stmt FROM @loc_ddl

-- >>>
EXECUTE loc_stmt

-- >>>
DEALLOCATE PREPARE loc_stmt

-- >>>
-- The foreign key is added separately, so a re-run that already has the column does not try to
-- add the constraint a second time.
SET @loc_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
     AND CONSTRAINT_NAME = 'fk_asset_location'
)

-- >>>
-- SET NULL, never CASCADE. Removing a location must not delete the assets that were in it — the
-- equipment still physically exists, which is the same rule every other FK on this table follows.
SET @loc_fk_ddl := IF(
  @loc_fk = 0,
  'ALTER TABLE `assets`
     ADD CONSTRAINT `fk_asset_location` FOREIGN KEY (`location_id`)
       REFERENCES `asset_locations` (`id`) ON DELETE SET NULL',
  'DO 0'
)

-- >>>
PREPARE loc_fk_stmt FROM @loc_fk_ddl

-- >>>
EXECUTE loc_fk_stmt

-- >>>
DEALLOCATE PREPARE loc_fk_stmt

-- >>>
-- ── Backfill ──
-- Match on the exact string, because that string is what the seed above inserted. Only rows whose
-- `location_id` is still NULL, so a re-run cannot overwrite a correction made on the screen.
UPDATE `assets` a
  JOIN `asset_locations` l ON l.`name` = a.`location`
   SET a.`location_id` = l.`id`
 WHERE a.`holder` = 'internal'
   AND a.`location_id` IS NULL

-- >>>
-- ── Normalise the LABEL to its master's exact spelling ──
--
-- The collation on these columns is `utf8mb4_unicode_ci`, and the "ci" does real work here: the
-- seed's `DISTINCT` treats "Level 3 Store" and "Level 3 store" as the SAME value, the UNIQUE index
-- refuses the second, and the backfill's `l.name = a.location` matches both spellings to the one
-- row. So case-only variants collapse by themselves, which is exactly the drift this file exists to
-- remove. Only genuinely different strings — "L3 Store" — survive as separate rows, and deciding
-- those are the same place is a judgement for the screen, not for a migration.
--
-- What that leaves behind is an asset still LABELLED "Level 3 store" while the row it points at is
-- named "Level 3 Store". `location_id` is the truth, so the label is rewritten from it.
--
-- `BINARY` is required. Without it, `a.location <> l.name` is FALSE for a case-only difference —
-- the comparison uses the same case-insensitive collation — so the statement would match nothing
-- and quietly do nothing, which is the worst outcome available: a migration that reports success
-- and leaves the inconsistency in place.
UPDATE `assets` a
  JOIN `asset_locations` l ON l.`id` = a.`location_id`
   SET a.`location` = l.`name`
 WHERE a.`holder` = 'internal'
   AND BINARY a.`location` <> BINARY l.`name`

-- >>>
-- ── Permissions ──
--
-- Its own module, for the same reason `asset_categories` is its own module: a role can maintain the
-- register without being able to redefine the places every asset is counted in. A stock take is
-- scoped by location, so whoever controls this list controls what a count covers.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('asset_locations', 'view',   'asset_locations_view',   'View internal asset locations',   'operations'),
  ('asset_locations', 'create', 'asset_locations_create', 'Add an internal asset location',   'operations'),
  ('asset_locations', 'edit',   'asset_locations_edit',   'Change an internal asset location', 'operations'),
  ('asset_locations', 'delete', 'asset_locations_delete', 'Remove an internal asset location', 'operations')

-- >>>
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'asset_locations'

-- >>>
SELECT
  (SELECT COUNT(*) FROM `asset_locations`)                                     AS locations,
  (SELECT COUNT(*) FROM `assets`
    WHERE `holder` = 'internal' AND `location_id` IS NOT NULL)                  AS assets_linked,
  (SELECT COUNT(*) FROM `assets`
    WHERE `holder` = 'internal'
      AND `location` IS NOT NULL AND `location` <> ''
      AND `location_id` IS NULL)                                               AS assets_unmatched,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'asset_locations')       AS permissions
