-- ============================================================
-- LEASE TO OWN — a fifth obligation kind, and the date a handover happened
--
-- WHAT WAS MISSING
--
-- External Assets exists to monitor PROJECT equipment: win a tender, deploy N units at client sites,
-- and each unit carries a dated term. The four obligation kinds already recorded what the term IS —
-- `warranty`, `rental`, `service_contract`, `dlp` — but only one thing ever happened when one ENDED:
-- `coverState` returned 'expired' and a badge changed colour.
--
-- For a lease-to-own that is not enough, because the ending is not "cover stops". The ending is a
-- TRANSFER OF OWNERSHIP: the client finishes paying and the equipment becomes theirs. There was no
-- way to record that arrangement at all, so the deal could not be entered into the system.
--
-- THE ENDING IS DERIVED FROM THE KIND, NOT STORED BESIDE IT
--
-- It is tempting to add an `on_expiry` column. It is not added, and this is the reason:
--
--   `lease_to_own`     ends -> the asset becomes the CLIENT's
--   `rental`           ends -> the asset comes BACK to us
--   everything else    ends -> cover stops, the asset does not move
--
-- The ending varies only for the two rented kinds, and for each of them it is fixed. A second column
-- could therefore hold a value that DISAGREED with the kind — `kind = 'warranty'` with
-- `on_expiry = 'transfer_to_client'` — and nothing in the schema could say which was true. Derived
-- from the kind it cannot disagree, which is the same reason `needs_label` and `is_overdue` are
-- derived rather than stored.
--
-- WHY THE VALUE IS APPENDED AT THE END OF THE ENUM, AND WHY THAT IS NOT COSMETIC
--
-- Three measured reasons:
--
--   1. MySQL stores an ENUM BY ORDINAL, not by text. Inserting `lease_to_own` between `rental` and
--      `service_contract` would shift every later value down one, and every existing row storing
--      ordinal 3 would silently start reading as `lease_to_own` instead of `service_contract`. That
--      is data corruption with no error.
--   2. Appending at the end of an enum is an IN-PLACE metadata change. Inserting or reordering forces
--      a full table copy, which on a production register is downtime for no gain.
--   3. Nothing in this application orders `asset_obligations` by `kind`, so the ordinal is invisible
--      to every reader. Checked, not assumed: the only `ORDER BY kind` in the source is on
--      `partner_categories`, a different table.
--
-- On THIS database `asset_obligations` is empty, so nothing could have been remapped here. That is
-- luck, not a reason — production has rows.
--
-- THE MODIFY RESTATES THE WHOLE DEFINITION, DELIBERATELY
--
-- `MODIFY COLUMN` replaces a column definition rather than amending it. Anything left out is lost, so
-- `NOT NULL` and `COLLATE utf8mb4_unicode_ci` are both written out — read from `SHOW CREATE TABLE`,
-- not guessed. Omitting `NOT NULL` would quietly make the column nullable and let an obligation exist
-- with no kind at all. `kind` is also the second part of `idx_aobl_asset (asset_id, kind)`, which
-- MySQL maintains across the change.
--
-- `handed_over_on` — A DATE, AND DELIBERATELY NOT A MONEY FIGURE
--
-- When a lease-to-own term ends and the unit becomes the client's, it leaves ANSAR's books. The
-- figure an accountant wants is its NET BOOK VALUE ON THAT DAY, and it is tempting to store it.
--
-- It is not stored. The date is enough: `bookValue()` already computes a straight-line figure from
-- `purchase_cost`, `purchase_date` and `useful_life_years`, and given the handover date it computes
-- the value AT that date for ever afterwards. A stored money column would be a second answer that can
-- disagree with the formula the whole register uses everywhere else — and it would disagree the first
-- time somebody corrected a purchase cost.
--
-- It also does a second job: it is the evidence that the transition HAPPENED, and when. The audit log
-- records that too, but a column on the asset is what a report can join to and what a list can filter
-- on cheaply.
--
-- THERE IS NO `recovered_on`, AND THE ASYMMETRY IS THE POINT
--
-- A rental ending is the opposite transition: the unit comes back and `holder` flips to `internal`.
-- At that moment the asset LEAVES the external register entirely, so there is no external row left to
-- stamp — the asset is now an internal one, and internal assets have no handover. The `recovered`
-- movement row carries the date, which is where every other change of holder is already recorded.
--
-- Adding `recovered_on` for symmetry would create a column that is meaningful on one register and
-- dead on the other, which is the shape `warranty_until` had before it became an obligation.
--
-- NO INDEX ON `handed_over_on`
--
-- The Handover & Recovery worklist selects by the OBLIGATION's `ends_on`, not by this column; this one
-- records what already happened. The only reads are a per-asset display and an occasional report over
-- the whole register, and both scan regardless. Same conclusion as `label_printed_at` and the PIC
-- columns, reached the same way.
--
-- Idempotent, in TWO independently guarded steps — the enum and the column. A single guard would
-- report the second as done while it was missing, which is the failure `asset_stocktake_plan.sql`
-- records from its own four-guard split.
-- Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_lease_to_own.sql
-- ============================================================

-- >>>
-- The guard reads the enum's TEXT rather than counting values, so re-running is safe even if some
-- other change has added a sixth kind in the meantime.
SET @has_lto := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_obligations'
     AND COLUMN_NAME = 'kind' AND COLUMN_TYPE LIKE '%lease\\_to\\_own%'
)

-- >>>
SET @lto_ddl := IF(
  @has_lto = 0,
  'ALTER TABLE `asset_obligations`
     MODIFY COLUMN `kind`
       ENUM(''warranty'', ''rental'', ''service_contract'', ''dlp'', ''lease_to_own'')
       COLLATE utf8mb4_unicode_ci NOT NULL',
  'DO 0'
)

-- >>>
PREPARE lto_stmt FROM @lto_ddl

-- >>>
EXECUTE lto_stmt

-- >>>
DEALLOCATE PREPARE lto_stmt

-- >>>
SET @has_handover := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
     AND COLUMN_NAME = 'handed_over_on'
)

-- >>>
SET @handover_ddl := IF(
  @has_handover = 0,
  'ALTER TABLE `assets`
     ADD COLUMN `handed_over_on` DATE DEFAULT NULL
       COMMENT ''The day this unit became the client property, when a lease-to-own term completed''
       AFTER `pic_position`',
  'DO 0'
)

-- >>>
PREPARE handover_stmt FROM @handover_ddl

-- >>>
EXECUTE handover_stmt

-- >>>
DEALLOCATE PREPARE handover_stmt

-- >>>
-- ── Verification ──
--
-- The enum carries five kinds and still refuses NULL; the column exists, is a DATE, and sits after
-- the PIC pair so the whole external lifecycle reads as one run. `handed_over_count` is 0 on a
-- register that predates this change, which is the honest starting point rather than an error.
--
-- `enum_order_unchanged` matters more than it looks: it confirms the four original values are still
-- in their original positions. If a future edit ever inserts rather than appends, every stored
-- ordinal shifts and the rows quietly change meaning.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_obligations'
      AND COLUMN_NAME = 'kind' AND COLUMN_TYPE LIKE '%lease\\_to\\_own%')      AS lease_to_own_present,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_obligations'
      AND COLUMN_NAME = 'kind' AND IS_NULLABLE = 'NO')                        AS kind_still_not_null,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_obligations'
      AND COLUMN_NAME = 'kind'
      AND COLUMN_TYPE = "enum('warranty','rental','service_contract','dlp','lease_to_own')")
                                                                              AS enum_order_unchanged,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME = 'handed_over_on' AND DATA_TYPE = 'date')              AS handover_column_is_date,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets'
      AND COLUMN_NAME = 'handed_over_on')                                     AS no_index_expected_zero,
  (SELECT COUNT(*) FROM `assets` WHERE `handed_over_on` IS NOT NULL)          AS handed_over_count,
  (SELECT COUNT(*) FROM `asset_obligations` WHERE `kind` = 'lease_to_own')    AS lease_to_own_rows
