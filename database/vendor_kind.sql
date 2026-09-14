-- ============================================================================
--
-- VENDORS: A COMPANY OR A MARKETPLACE
--
-- Run with:  node scripts/run-sql.js database/vendor_kind.sql
--
-- ── THE PROBLEM THIS SOLVES ──
--
-- `Bought From` on the asset form is a picker over this table, and it always has
-- been -- `assets.vendor_id` has a foreign key to `vendors.id`. What it could not
-- record was a laptop bought from Shopee, because every field on a vendor row
-- describes a CONTRACTOR: an SSM number, a CIDB grade, a bumiputera flag, a rating,
-- a comma-separated list of procurement categories. None of those mean anything for
-- a marketplace, and "Shopee" sitting in the procurement register beside companies
-- that went through the supplier application process reads as a mistake.
--
-- ── WHY TWO COLUMNS HERE AND NOT A FOURTH TABLE ──
--
-- A separate `asset_suppliers` table was the first idea and it was refused. This
-- schema already carries THREE tables for sellers, and `operations_vendors.sql`
-- opens by drawing the line between them:
--
--   procurement_applications  a company ASKING to be a supplier
--   vendors                   a company we have ACCEPTED and buy from
--   suppliers                 the accounting record, invoices and credit notes
--
-- A fourth would be a fourth answer to "who did we buy this from". And it does not
-- stop at one table: `assets.vendor_id` and `asset_maintenance.vendor_id` BOTH have
-- a foreign key to `vendors`, so a new table means either a second nullable column
-- on each -- two columns answering one question, with no rule for which wins -- or
-- repointing the keys, which breaks the link to the register that already exists.
--
-- A marketplace IS somewhere we buy from. It belongs in the same table; what it
-- needed was a way to say it is not a contractor.
--
-- ── WHAT EACH COLUMN IS FOR ──
--
-- `kind`     what this row IS. Placed beside `source`, which records how the row was
--            CREATED (typed in, or imported from an application). Two different
--            questions, so two columns rather than widening one ENUM.
--
-- `platform` which marketplace, and ONLY for a marketplace row.
--
--            `name` is left free on purpose, so both shapes work:
--              name 'Shopee'     platform 'Shopee'    -- bought from the platform
--              name 'Kedai ABC'  platform 'Shopee'    -- bought from a seller on it
--            The second is the honest record when three different sellers on one
--            platform have supplied three different units, and a single `name`
--            column could not tell them apart.
--
-- ── NOTHING IS BACKFILLED, AND THAT IS CORRECT ──
--
-- `kind` defaults to 'company', so every existing vendor keeps the meaning it
-- already had. There is no marketplace row to migrate, because until now there was
-- no way to enter one.
--
-- ── IDEMPOTENT ──
--
-- MySQL has no `ADD COLUMN IF NOT EXISTS`, so each ALTER is wrapped in a prepared
-- statement guarded by information_schema. Re-running is a no-op that says so.
--
-- `ROW_FORMAT` is NOT set here: `vendors` already declares it, from
-- `set_row_format_dynamic.sql`. Declaring it again would be a second place for the
-- same fact.
-- ============================================================================

-- >>>
-- ── 1. `kind` -- a contractor, or a marketplace ──
SET @has_kind := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
     AND COLUMN_NAME = 'kind'
)

-- >>>
SET @sql := IF(@has_kind = 0,
  'ALTER TABLE `vendors`
     ADD COLUMN `kind` ENUM(''company'',''marketplace'') NOT NULL DEFAULT ''company''
       COMMENT ''company = a contractor or supplier; marketplace = an online platform''
       AFTER `source`',
  'SELECT ''vendors.kind already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2. `platform` -- which marketplace ──
--
-- 60 characters. The longest name worth storing is a platform plus a country suffix
-- ("TikTok Shop Malaysia" is 20), and a column wide enough to hold a paragraph
-- invites one to be typed.
SET @has_platform := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
     AND COLUMN_NAME = 'platform'
)

-- >>>
SET @sql := IF(@has_platform = 0,
  'ALTER TABLE `vendors`
     ADD COLUMN `platform` VARCHAR(60) DEFAULT NULL
       COMMENT ''Shopee, Lazada, TikTok Shop, ... only meaningful when kind = marketplace''
       AFTER `kind`',
  'SELECT ''vendors.platform already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3. The index the filter reads ──
--
-- The register filters by `kind` so the procurement view can exclude marketplaces,
-- and the asset form's service picker asks for companies only. Both are
-- `WHERE kind = ?` on a table read on every asset form open.
SET @has_idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
     AND INDEX_NAME = 'idx_vendor_kind'
)

-- >>>
SET @sql := IF(@has_idx = 0,
  'ALTER TABLE `vendors` ADD KEY `idx_vendor_kind` (`kind`)',
  'SELECT ''idx_vendor_kind already present'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 4. Report what landed ──
--
-- No new permissions. A marketplace is a vendor, so `vendors_view / create / edit /
-- delete / export` already govern it. Inventing `vendor_marketplace_*` would be a
-- second name for the same authority on the same screen.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
      AND COLUMN_NAME = 'kind')                                    AS col_kind,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
      AND COLUMN_NAME = 'platform')                                AS col_platform,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors'
      AND INDEX_NAME = 'idx_vendor_kind')                          AS idx_kind,
  (SELECT COUNT(*) FROM `vendors`)                                 AS vendors_total,
  (SELECT COUNT(*) FROM `vendors` WHERE `kind` = 'marketplace')     AS marketplaces
