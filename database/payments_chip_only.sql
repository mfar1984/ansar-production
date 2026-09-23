-- ============================================================================
-- PAYMENTS: ONE GATEWAY, AND IT IS CHIP COLLECT
--
-- Run with:  node scripts/run-sql.js database/payments_chip_only.sql
--
-- ── WHY A MIGRATION AT ALL, WHEN NO COLUMN CHANGES ──
--
-- It changes ONE VALUE on ONE ROW. `integrations.payments_provider` is a
-- `varchar(40)` and the endpoint's accepted list has been narrowed from
-- `['billplz', 'toyyibpay', 'chip', 'stripe', 'ipay88']` to `['chip']`.
--
-- The validation is on INPUT, so a row already holding `billplz` is not rejected
-- on read - it is simply a value nothing can produce any more. And the Test
-- Connection reads the STORED value, so until somebody saves the Payments page the
-- test would answer:
--
--     The saved provider is "billplz", and CHIP is the only gateway this system
--     supports.
--
-- which reads as this change being broken rather than as a row being stale. Saving
-- the form once fixes it, but an operator has no way to know that is what is
-- needed. So the row is corrected here.
--
-- ── NO SCHEMA CHANGE, AND THAT IS DELIBERATE ──
--
-- `payments_collection_id` now carries CHIP's Brand ID and KEEPS ITS NAME. Renaming
-- it would have meant a migration on a live table, an endpoint field rename, a
-- form rename and an edit to the column list `settings-endpoints.sql.test.js`
-- asserts - for no behaviour. The form labels the field "Brand ID" and the
-- `PaymentsConfig.brandId` argument is named for the value, which is where the
-- naming needed to be honest.
--
-- `payments_secret_key` is LEFT IN PLACE and left alone. CHIP issues one
-- credential, so nothing reads it any more, but a column is not dropped to tidy a
-- form: the value may be a real credential somebody pasted, and destroying it wins
-- nothing. `testPayments` now takes the API key explicitly, so a stale secret can
-- no longer outrank the key on screen.
--
-- ── IDEMPOTENT ──
--
-- A plain UPDATE with a WHERE that stops matching once it has run. Running it twice
-- reports `rows_changed: 0` the second time, which is the correct answer rather
-- than an error.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. Is there anything to correct ──
--
-- Read BEFORE the update, so the report can tell "it was already chip" from "it was
-- something else and has been fixed". A count taken afterwards cannot distinguish
-- those two, and they mean different things to whoever is reading the output.
SET @pay_before := (
  SELECT `payments_provider` FROM `integrations` WHERE `id` = 1
)

-- >>>
-- ── 2. Correct it ──
--
-- `<> 'chip'` rather than an unconditional SET, so a second run touches no row and
-- `updated_at` on this table is not bumped for a change that did not happen.
--
-- `<=>` is not needed here but NULL is handled: a NULL provider is also not 'chip',
-- and `NULL <> 'chip'` is NULL rather than TRUE - so the IS NULL arm is spelled out.
-- A NULL column would otherwise be left behind by a condition that looks like it
-- covers everything.
UPDATE `integrations`
   SET `payments_provider` = 'chip'
 WHERE `id` = 1
   AND (`payments_provider` IS NULL OR `payments_provider` <> 'chip')

-- >>>
-- ── 3. Report ──
--
-- `was` is the interesting column:
--
--   'chip'     already correct, nothing ran, nothing to do
--   'billplz'  or another name - it has just been corrected
--   NULL       the row had no provider at all and now has one
--
-- `is_now` must read `chip` in every case. If it does not, the row with id = 1 does
-- not exist, and that is a different problem - `integrations` is a single-row
-- settings table and every reader in the application selects `WHERE id = 1`.
SELECT
  @pay_before                                                              AS was,
  (SELECT `payments_provider` FROM `integrations` WHERE `id` = 1)          AS is_now,
  (SELECT COUNT(*) FROM `integrations` WHERE `id` = 1)                     AS settings_row_present,
  -- Both columns must still be here. The change deliberately removes NEITHER, and a
  -- guard that only checked the value would not notice if one had been dropped by
  -- something else.
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'integrations'
      AND COLUMN_NAME IN ('payments_secret_key', 'payments_collection_id')) AS kept_columns
