-- ============================================================================
-- A QUOTATION'S VALIDITY IS A NUMBER OF DAYS
--
-- Run with:  node scripts/run-sql.js database/quotation_validity_days.sql
--
-- ── WHAT THIS IS, AND WHAT IT REPLACES ──
--
-- `Valid Until` was a date picker. Then it was a number of MONTHS, for one
-- release. It is DAYS now, and this file removes the months column on its way.
--
-- Enter 30 on a quotation dated 2026-08-25 and it expires 2026-09-24.
--
-- ── WHY DAYS AND NOT MONTHS ──
--
-- Two reasons, and the second is the one that matters.
--
-- 1. It is this module's own vocabulary. `accounting_payment_terms.due_in_days`
--    is an INT and has always been. The `_months` columns in this schema —
--    `projects.dlp_months`, `tenders.dlp_months`,
--    `asset_models.default_warranty_months` — belong to Project Management and
--    Asset Management. An accounting document counting in days matches the
--    accounting table that already counts.
--
-- 2. A DAY HAS ONE LENGTH AND A MONTH DOES NOT. "One month from 31 January" has
--    no answer the arithmetic can give without inventing a rule: MySQL clamps to
--    28 February, so a validity entered as one month is 28 days in February and
--    31 in July. The previous version had to document that clamp on both sides
--    and hope nobody reported it as a fault. Days have no such case — the
--    endpoint adds n days and there is nothing to explain.
--
-- ── BOTH COLUMNS ARE STILL STORED, AND IT IS STILL NOT TWO SOURCES OF TRUTH ──
--
--   `valid_days`   what the operator typed. NEW.
--   `valid_until`  the date it comes to. KEPT.
--
-- Deriving the DAYS from two dates would be exact, unlike months — `DATEDIFF` has
-- no truncation to lose. So why keep both?
--
-- Because `valid_until` is PRINTED on the sheet the customer receives, and a
-- printed value must be frozen at the moment it was issued. If the date were
-- computed at read time from the quotation date, editing that date would silently
-- change what an already-issued quotation says about its own expiry, and a
-- reprint would not match the copy the customer holds.
--
-- They cannot drift, because ONE place computes the date: the save path, from the
-- days. `valid_until` is never accepted from a request. That is the arrangement
-- `subtotal`, `tax_amount` and `total_amount` already have on these documents.
--
-- ── WHAT HAPPENS TO `valid_months` ──
--
-- Dropped, with its CHECK. It shipped in one release and this file removes it
-- whether or not that release reached a given database, so both states converge:
--
--   never applied     nothing to drop, `valid_days` is added
--   already applied   `valid_months` and `ck_sq_valid_months` go, `valid_days` is added
--
-- Nothing is converted from one to the other, and that is measured rather than
-- assumed: `sales_quotations` holds ZERO rows. There is nothing to convert.
--
-- `database/quotation_validity_months.sql` is deleted and off the packager's
-- list. Keeping it there would mean a fresh server adds a column this file then
-- drops.
--
-- ── `SMALLINT UNSIGNED`, WHICH IS ENOUGH AND NOT MORE ──
--
-- Max 65535 days, about 179 years. `accounting_payment_terms.due_in_days` is a
-- full INT, which is four bytes to express a number that cannot exceed a few
-- hundred. UNSIGNED is the part that matters: a negative validity is impossible
-- at the storage level rather than only in the endpoint, and a quotation that
-- expires before it was raised is the one state the old `notBefore` check existed
-- to refuse.
--
-- NULL means the quotation does not expire, which is what a blank date meant.
--
-- Idempotent. One statement per "-- >>>" block, no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. The months CHECK goes first, because it constrains the column below it ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
       WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND CONSTRAINT_NAME = 'ck_sq_valid_months' AND CONSTRAINT_TYPE = 'CHECK'
    ),
    'ALTER TABLE `sales_quotations` DROP CHECK `ck_sq_valid_months`',
    'SELECT ''ck_sq_valid_months is not there'' AS note'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 2. And the months column ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND COLUMN_NAME = 'valid_months'
    ),
    'ALTER TABLE `sales_quotations` DROP COLUMN `valid_months`',
    'SELECT ''valid_months is not there'' AS note'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 3. The period the operator enters ──
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND COLUMN_NAME = 'valid_days'
    ),
    'SELECT ''sales_quotations.valid_days already exists'' AS note',
    'ALTER TABLE `sales_quotations`
       ADD COLUMN `valid_days` SMALLINT UNSIGNED NULL DEFAULT NULL AFTER `valid_until`'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 4. A validity of zero days is not a validity ──
--
-- `0` computes an expiry of the quotation date itself: an offer that expires the
-- day it is made. The endpoint refuses it, and so does the storage engine — a rule
-- only the endpoint knows is a rule the next endpoint will not.
--
-- NULL passes, because NULL means "does not expire".
SET @sql := (
  SELECT IF(
    EXISTS (
      SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
       WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
         AND CONSTRAINT_NAME = 'ck_sq_valid_days' AND CONSTRAINT_TYPE = 'CHECK'
    ),
    'SELECT ''ck_sq_valid_days already exists'' AS note',
    'ALTER TABLE `sales_quotations`
       ADD CONSTRAINT `ck_sq_valid_days` CHECK (`valid_days` IS NULL OR `valid_days` >= 1)'
  )
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 5. Report what is now there ──
--
-- Expected: `days_col 1  days_chk 1  months_col 0  months_chk 0  rows_now 0
--            with_days 0  with_date 0`
--
-- `months_col` and `months_chk` are reported at ZERO deliberately. A migration
-- that removes something should prove the removal, not assume it — the whole
-- reason this file exists is that the previous one shipped a column that turned
-- out to be the wrong unit.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND COLUMN_NAME = 'valid_days')                                        AS `days_col`,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND CONSTRAINT_NAME = 'ck_sq_valid_days')                              AS `days_chk`,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND COLUMN_NAME = 'valid_months')                                      AS `months_col`,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations'
      AND CONSTRAINT_NAME = 'ck_sq_valid_months')                            AS `months_chk`,
  (SELECT COUNT(*) FROM `sales_quotations`)                                  AS `rows_now`,
  (SELECT COUNT(*) FROM `sales_quotations` WHERE `valid_days` IS NOT NULL)    AS `with_days`,
  (SELECT COUNT(*) FROM `sales_quotations` WHERE `valid_until` IS NOT NULL)   AS `with_date`
