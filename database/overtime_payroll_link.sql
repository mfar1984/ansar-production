-- ============================================================================
-- OVERTIME: RECORD WHICH PAYROLL RUN PAID IT
-- ============================================================================
--
-- THE DEFECT THIS CLOSES, AND WHY IT BLOCKS THREE OTHER FEATURES
--
-- `src/pages/api/admin/payroll/process.ts` sweeps overtime into a payslip with:
--
--     WHERE oa.status = 'approved' AND oa.overtime_date BETWEEN ? AND ?
--
-- and then marks NOTHING. After the run, the application still reads `approved` — indistinguishable
-- from overtime that has never been paid at all. Two consequences, both measured against the code:
--
--   1. DOUBLE PAYMENT. Running the same period twice, or two periods whose dates overlap, pays the
--      same hours again. `api/admin/overtime/[id].ts` can ALSO record a direct payment against the
--      same still-`approved` row, posting a second journal for money already inside a payslip's
--      gross pay. The rule against it is written in a comment at that endpoint and enforced by
--      nothing.
--
--   2. IT MAKES CANCEL UNSAFE. Withdrawing an approval has to refuse any application already inside
--      an issued payslip, and today there is no way to ask. Cancel would silently contradict a
--      payslip that has been printed and paid.
--
-- So this column is the prerequisite. Cancel, Reopen and Un-pay are all built on being able to ask
-- "has payroll already paid this".
--
-- ----------------------------------------------------------------------------
-- WHY A LINK COLUMN AND NOT `status = 'paid'`
-- ----------------------------------------------------------------------------
--
-- Marking payroll-paid overtime as `status = 'paid'` was the obvious alternative and it is REFUSED.
--
-- `api/admin/overtime/[id].ts` deliberately excludes `payroll` from its `PAYMENT_METHODS`, and its
-- comment says why: "Overtime paid through the payroll run is paid BY that run, and recording it as
-- paid here as well would put the same money in the ledger twice — once from this journal and once
-- inside the payroll journal's gross pay." Setting `paid` from the payroll run would make the row
-- look like it had been through that endpoint, with a `payment_date`, a `paid_from_account_id` and a
-- journal of its own — none of which exist. The two payment routes would become indistinguishable.
--
-- A LINK says exactly what happened and no more: this overtime is inside that payroll period. The
-- status still reads `approved`, which is true — it was approved, and it was never separately paid.
--
-- And it carries information the status cannot. `payroll_period_id` names the period, so a screen can
-- say "already in September 2026 payroll" rather than just refusing.
--
-- ----------------------------------------------------------------------------
-- ON DELETE SET NULL, AND THAT IS THE DELIBERATE DIRECTION
-- ----------------------------------------------------------------------------
--
-- Deleting a payroll period must not delete the overtime — the hours were worked. SET NULL releases
-- the link, and the overtime becomes payable again, which is correct: a deleted period paid nobody.
--
-- CASCADE would destroy a wage record. RESTRICT would make a draft period that was created by
-- mistake impossible to remove once it had touched any overtime. SET NULL is also the shape every
-- sibling cost reference already uses — `assets`, `claim_items`, `expenses`, `mileage_trips`,
-- `purchase_orders`, `purchase_requests` and `sales_invoices` all point at `projects` that way.
--
-- NO BACKFILL. `payroll_records` holds 0 rows on this database, so there is no historical run to
-- attribute. On a database that does have runs, a backfill would have to guess which of several
-- overlapping periods paid a given application, and guessing at that is how the double payment this
-- column exists to prevent would be created by the fix itself. A production operator who needs it
-- can match on dates by hand, with the ambiguity in front of them.
--
-- IDEMPOTENT. Production applies this by hand and a hand runs things twice. Every step is guarded on
-- information_schema.
-- ============================================================================

-- >>>
-- 1/4 the column.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND COLUMN_NAME = 'payroll_period_id') = 0,
  'ALTER TABLE `overtime_applications`
     ADD COLUMN `payroll_period_id` INT NULL DEFAULT NULL
       COMMENT ''The payroll run that paid this overtime inside gross pay. NULL means payroll has not paid it.''
       AFTER `payment_reference`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 2/4 the index. The payroll run filters on it for EVERY employee on the run, and the screen asks
-- "what is already paid" to decide which buttons to draw.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND INDEX_NAME = 'idx_ot_payroll_period') = 0,
  'ALTER TABLE `overtime_applications`
     ADD INDEX `idx_ot_payroll_period` (`payroll_period_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 3/4 the foreign key. SET NULL — see the header.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
      AND CONSTRAINT_NAME = 'fk_ot_payroll_period'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY') = 0,
  'ALTER TABLE `overtime_applications`
     ADD CONSTRAINT `fk_ot_payroll_period`
     FOREIGN KEY (`payroll_period_id`) REFERENCES `payroll_periods` (`id`)
       ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 4/4 VERIFICATION. `scripts/run-sql.js` prints a row set, so this is what the operator reads back.
-- Every figure on the left must equal the number in its own name.
SELECT 'payroll_period_id exists (want 1)' AS check_name,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND COLUMN_NAME = 'payroll_period_id') AS value
 UNION ALL
SELECT 'idx_ot_payroll_period exists (want 1)',
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND INDEX_NAME = 'idx_ot_payroll_period')
 UNION ALL
SELECT 'fk_ot_payroll_period exists (want 1)',
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'overtime_applications'
           AND CONSTRAINT_NAME = 'fk_ot_payroll_period' AND CONSTRAINT_TYPE = 'FOREIGN KEY')
 UNION ALL
SELECT 'the FK is ON DELETE SET NULL (want 1)',
       (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_ot_payroll_period'
           AND DELETE_RULE = 'SET NULL')
 UNION ALL
SELECT 'overtime linked to a payroll run (0 until a run marks one)',
       (SELECT COUNT(*) FROM `overtime_applications` WHERE `payroll_period_id` IS NOT NULL)
 UNION ALL
SELECT 'orphan links, must be 0',
       (SELECT COUNT(*) FROM `overtime_applications` oa
         WHERE oa.`payroll_period_id` IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM `payroll_periods` p WHERE p.id = oa.`payroll_period_id`))
