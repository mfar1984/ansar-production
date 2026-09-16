-- ============================================================
-- ASSET CLASS — movable, fixed, or intangible
--
-- WHAT THIS IS FOR, AND IT IS NOT FILING
--
-- The register has no way to say that a thing cannot be picked up. `holder` says which register it
-- is in and `ownership` says whose it is, but a building and a laptop are recorded identically.
--
-- That is a live defect, not a theoretical one. `FREE_TO_ISSUE` in `assets/checkouts.ts` offers every
-- internal asset that is not written off and has no loan open, so the moment a building or a plot of
-- land is recorded it appears on the left panel of Checkout & Loans as "available to issue". You
-- cannot hand a building across a counter. The class is what closes that.
--
-- THREE VALUES, NOT FIVE
--
-- The classification this was asked for has five headings: aset alih, aset tak alih, aset tidak
-- ketara, aset biologi, and stok/barang guna habis. Two of those are deliberately absent.
--
--   BIOLOGICAL is dead vocabulary here. This is an IT company: no farm, no zoo, no aquaculture. An
--   ENUM value nothing ever branches on is vocabulary pretending to be data, and it would sit in
--   every dropdown on every screen forever. If it is ever needed, one ALTER adds it and the ENUM is
--   the only thing that changes.
--
--   CONSUMABLES cannot live in `assets` at all, and calling them a class would hide that. This
--   table's identity is `asset_no` UNIQUE plus a physical `tag_no` sticker: ONE ROW IS ONE ITEM.
--   There is no `quantity` column and no unit of measure. A ream of paper is a quantity that rises
--   and falls, so it breaks `asset_checkouts` (one open loan per asset — you cannot lend 3 of 500
--   sheets), `asset_stocktake_lines` (found / not_found per row, with no counted quantity),
--   depreciation (a pen is an expense, not a written-down asset) and `asset_movements` (from-whom
--   to-whom, not in-how-many out-how-many). Stock needs its own tables, and that is a separate
--   decision recorded in `AdminSidebar.tsx`.
--
-- SET ON THE CATEGORY, COPIED ONTO THE ASSET
--
-- The class is declared once per CATEGORY — "Vehicle" is always movable, "Building" is always fixed,
-- "Software Licence" is always intangible — rather than chosen per asset, because 400 laptops is 400
-- chances to pick the wrong one.
--
-- But `assets` carries its own copy, seeded at creation and owned by the asset from then on. This is
-- the rule `asset_categories.default_loanable` already follows and its comment already states: "Read
-- once, then the asset owns it". Two reasons it has to be that way here:
--
--   1. `assets.category` is a NAME, VARCHAR(80), with NO foreign key. Deriving behaviour through a
--      join on a name means an asset whose category is NULL, or was renamed by something that missed
--      the cascade, has no class at all. While the category only supplied a DEFAULT that was
--      harmless. Once it gates whether a thing can be issued, a miss is a bug.
--   2. Reclassifying a category must not silently move existing assets. The same reason its useful
--      life is not applied retroactively: that figure may already be in a report somebody signed.
--
-- NOT NULL DEFAULT 'movable' on both. Movable is the safe default because it is what every existing
-- row already is — everything in the register today is equipment — so the column changes nothing on
-- the day it lands. A nullable class would mean every query that gates on it needs to decide what
-- NULL means, and they would not all decide the same thing.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_class.sql
-- ============================================================

-- >>>
SET @cat_class := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_categories'
     AND COLUMN_NAME = 'asset_class'
)

-- >>>
SET @cat_ddl := IF(
  @cat_class = 0,
  'ALTER TABLE `asset_categories`
     ADD COLUMN `asset_class` ENUM(''movable'', ''fixed'', ''intangible'')
       NOT NULL DEFAULT ''movable''
       COMMENT ''Seeds assets.asset_class at registration. Read once, then the asset owns it''
       AFTER `name`',
  'DO 0'
)

-- >>>
PREPARE cat_stmt FROM @cat_ddl

-- >>>
EXECUTE cat_stmt

-- >>>
DEALLOCATE PREPARE cat_stmt

-- >>>
SET @asset_class := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets' AND COLUMN_NAME = 'asset_class'
)

-- >>>
-- Indexed with `holder` and `status`, because that is the shape of the query it exists to serve:
-- Checkout asks for internal assets that are movable and not written off.
SET @asset_ddl := IF(
  @asset_class = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `asset_class` ENUM(''movable'', ''fixed'', ''intangible'')
       NOT NULL DEFAULT ''movable''
       COMMENT ''Physical nature. Seeded from the category, then owned by this asset''
       AFTER `category`,
     ADD KEY `idx_asset_class` (`asset_class`, `holder`, `status`)',
  'DO 0'
)

-- >>>
PREPARE asset_stmt FROM @asset_ddl

-- >>>
EXECUTE asset_stmt

-- >>>
DEALLOCATE PREPARE asset_stmt

-- >>>
-- ── Classify the categories that ship with the product ──
--
-- Only `Software Licence` is not movable. Everything else in the seeded list is equipment that can
-- be carried, wheeled or driven, which is why `movable` is the column default and why this statement
-- names one row rather than twelve.
--
-- No `fixed` category is seeded. Land and buildings are not in this register yet, and inventing
-- "Building" for an organisation that has not asked to record one would put an empty category in
-- every dropdown. It is one row on the Categories screen when it is needed.
--
-- ── WHY THIS IS GUARDED ON THE COLUMN HAVING JUST BEEN CREATED ──
--
-- The obvious guard is `AND asset_class = 'movable'`, and it is WRONG. `movable` is the DEFAULT, so
-- that condition cannot tell "never classified" from "deliberately corrected to movable" — and a
-- second run would silently undo the correction. Found by running the migration twice and checking,
-- not by reading it.
--
-- These two data steps belong to the CREATION of the columns, so they are tied to it. Run once, the
-- column is new and they fill it in. Run again, `@cat_class` and `@asset_class` are 1 and both are
-- no-ops. A hand runs things twice; that must cost nothing.
SET @cat_seed := IF(
  @cat_class = 0,
  'UPDATE `asset_categories` SET `asset_class` = ''intangible''
    WHERE `name` = ''Software Licence''',
  'DO 0'
)

-- >>>
PREPARE cat_seed_stmt FROM @cat_seed

-- >>>
EXECUTE cat_seed_stmt

-- >>>
DEALLOCATE PREPARE cat_seed_stmt

-- >>>
-- ── Backfill the assets from their category ──
--
-- Joined on the NAME, because that is what `assets.category` holds.
--
-- Guarded on `@asset_class = 0` for the reason written above the category seed: `movable` is the
-- default, so a value-based guard cannot protect a per-asset correction, and only "the column was
-- just created" can. A portable cabin recorded under a fixed category and corrected by hand stays
-- corrected.
--
-- An asset whose category is NULL, or names a category that no longer exists, keeps `movable`. That
-- is the honest outcome: nothing known about it says otherwise, and it is what it was before this
-- column existed.
SET @asset_seed := IF(
  @asset_class = 0,
  'UPDATE `assets` a
     JOIN `asset_categories` c ON c.`name` = a.`category`
      SET a.`asset_class` = c.`asset_class`
    WHERE c.`asset_class` <> ''movable''',
  'DO 0'
)

-- >>>
PREPARE asset_seed_stmt FROM @asset_seed

-- >>>
EXECUTE asset_seed_stmt

-- >>>
DEALLOCATE PREPARE asset_seed_stmt

-- >>>
SELECT
  (SELECT COUNT(*) FROM `asset_categories` WHERE `asset_class` = 'movable')    AS cat_movable,
  (SELECT COUNT(*) FROM `asset_categories` WHERE `asset_class` = 'fixed')      AS cat_fixed,
  (SELECT COUNT(*) FROM `asset_categories` WHERE `asset_class` = 'intangible') AS cat_intangible,
  (SELECT COUNT(*) FROM `assets` WHERE `asset_class` = 'movable')              AS asset_movable,
  (SELECT COUNT(*) FROM `assets` WHERE `asset_class` = 'fixed')                AS asset_fixed,
  (SELECT COUNT(*) FROM `assets` WHERE `asset_class` = 'intangible')           AS asset_intangible
