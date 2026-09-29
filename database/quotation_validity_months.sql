-- ============================================================================
-- A QUOTATION'S VALIDITY IS A PERIOD, NOT A DATE SOMEBODY TYPES
--
-- Run with:  node scripts/run-sql.js database/quotation_validity_months.sql
--
-- ── WHAT CHANGES ON THE SCREEN ──
--
-- `Valid Until` was a date picker. It becomes a NUMBER OF MONTHS, and the expiry
-- date is worked out from the quotation date: enter 2 and a quotation dated
-- 2026-08-25 expires 2026-10-25.
--
-- Typing a date was the wrong shape for the thing being recorded. Nobody decides
-- "this offer expires on the 25th of October"; they decide "this offer is good
-- for two months". The date is a CONSEQUENCE, and asking for the consequence
-- means the operator does the arithmetic and the form checks it afterwards -
-- which is what `notBefore: 'quotation_date'` was for.
--
-- ── BOTH ARE STORED, AND THAT IS NOT TWO SOURCES OF TRUTH ──
--
--   `valid_months`  what the operator typed. NEW.
--   `valid_until`   the date it works out to. KEPT.
--
-- Neither alone is enough:
--
--   Deriving the MONTHS from the two dates fails for any gap that is not a whole
--   month. `TIMESTAMPDIFF(MONTH, ...)` truncates, so a quotation valid to the
--   31st would read back as a month less and the form would show a figure nobody
--   entered.
--
--   Deriving the DATE at read time is worse. `valid_until` is PRINTED on the
--   sheet the customer receives - `print: 'Valid Until'` in the registry. If it
--   were computed on every read, editing the quotation date would silently change
--   what an already-issued quotation says about its own expiry. A reprint would
--   not match the copy the customer holds.
--
-- They cannot drift because ONE place computes the date: the save path, from the
-- months. `valid_until` is never accepted from a request. That is exactly the
-- pattern `subtotal`, `tax_amount` and `total_amount` already follow on these
-- same documents - stored, and recomputed from their inputs on every write.
--
-- ── `smallint unsigned`, AND THE PRECEDENT IS ALREADY HERE ──
--
-- Not invented for this. Measured across the schema:
--
--     projects.dlp_months              smallint unsigned
--     tenders.dlp_months               smallint unsigned
--     asset_models.default_warranty_months  smallint unsigned
--
-- Three columns already express "a number of months" that way. A fourth spelling
-- would be a fourth thing to remember.
--
-- NULL means the quotation does not expire, which is what a blank date meant.
-- Unsigned, so a negative period is impossible at the storage level rather than
-- only in the endpoint - a quotation that expires before it was raised is the one
-- state `notBeforeReason` existed to refuse.
--
-- ── NO BACKFILL, AND THAT IS MEASURED RATHER THAN ASSUMED ──
--
-- `sales_quotations` holds ZERO rows, and `valid_until` is NULL on all of them.
-- There is nothing to convert and no round-trip to preserve. Counted before this
-- file was written; if that ever stops being true, a backfill would have to
-- decide what a 47-day validity becomes, and there is no correct answer to that.
--
-- `business_proposals.valid_until` is a separate date column on a separate module
-- and is NOT touched. One concept in two places is worth knowing about; changing
-- both in a migration about quotations is not.
--
-- ── WHAT `DATE_ADD(..., INTERVAL n MONTH)` DOES AT A MONTH END ──
--
-- 31 January plus one month is 28 February, or 29 in a leap year. MySQL clamps to
-- the last valid day rather than overflowing into March. That is the correct
-- reading of "one month" and it is recorded here so it is not reported as a fault.
--
-- Idempotent. One statement per "-- >>>" block, no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. The period the operator enters ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND COLUMN_NAME = 'valid_months'
    ),
    'SELECT ''sales_quotations.valid_months already exists'' AS note',
    'ALTER TABLE `sales_quotations`
       ADD COLUMN `valid_months` SMALLINT UNSIGNED NULL DEFAULT NULL AFTER `valid_until`'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 2. A period of zero is not a period ──
--
-- `0` would compute an expiry of the quotation date itself: an offer that expires
-- the day it is made. The endpoint refuses it, and so does the storage engine, for
-- the reason every guard in `accounting_check_constraints.sql` exists - a rule only
-- the endpoint knows is a rule the next endpoint will not.
--
-- NULL passes, because NULL means "does not expire".
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
       WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND CONSTRAINT_NAME = 'ck_sq_valid_months' AND CONSTRAINT_TYPE = 'CHECK'
    ),
    'SELECT ''ck_sq_valid_months already exists'' AS note',
    'ALTER TABLE `sales_quotations`
       ADD CONSTRAINT `ck_sq_valid_months` CHECK (`valid_months` IS NULL OR `valid_months` >= 1)'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 3. Report what is now there ──
--
-- Expected: `col 1  chk 1  rows 0  with_months 0  with_date 0`.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND COLUMN_NAME = 'valid_months')                                    AS `col`,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND CONSTRAINT_NAME = 'ck_sq_valid_months')                          AS `chk`,
  (SELECT COUNT(*) FROM `sales_quotations`)                                AS `rows_now`,
  (SELECT COUNT(*) FROM `sales_quotations` WHERE `valid_months` IS NOT NULL) AS `with_months`,
  (SELECT COUNT(*) FROM `sales_quotations` WHERE `valid_until` IS NOT NULL)  AS `with_date`
