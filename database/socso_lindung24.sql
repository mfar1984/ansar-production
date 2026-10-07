-- ============================================================================
-- LINDUNG 24 JAM — the Non-Employment Injury Scheme (SKBBK), employee-borne
-- ============================================================================
--
-- WHY THIS EXISTS, AND IT WAS PROVEN FROM THE EMPLOYER'S OWN MASTER SHEET
--
-- The SEPTEMBER 2026 salary sheet carries a column headed "Employee's Lindung 24 jam".
-- One of three employees has a figure in it: 15.35, against a contributory wage of
-- RM2,100. That is EXACTLY band 25 of the Non-Employment Injury column of the Third
-- Schedule of Act 4 — the array already shipped in
-- src/lib/statutory-schedules.ts as SOCSO_NON_EMPLOYMENT_INJURY_SEN.
--
-- MEASURED after the statutory schedules replaced the flat percentages: the engine now
-- reproduces that sheet to the sen for both employees below RM5,000. For the one with the
-- Lindung line, the net pay differs by 15.35 and by nothing else. So the whole remaining
-- gap on that payslip IS this deduction, and the figure to deduct is already computed and
-- already tested — it simply had nowhere to be recorded.
--
-- MEASURED before this migration: a search of every column in the database for
-- '%eis%', '%sip%', '%lindung%', '%nei%' and '%skbbk%' returned ZERO matches. There was no
-- field on the employee, no column on the payslip, and no row on the ledger.
--
-- ----------------------------------------------------------------------------
-- WHY A PER-EMPLOYEE ELECTION AND NOT A GLOBAL SETTING
-- ----------------------------------------------------------------------------
--
-- The scheme is MANDATORY for foreign employees and OPTIONAL for Malaysians. The master
-- sheet proves the employer treats it that way: one employee enrolled, two not, in the same
-- month, on the same payroll. A global switch could not express that, and inferring it from
-- the free-text employees.nationality column would be guessing at law from a VARCHAR that
-- holds whatever was typed.
--
-- So it is an explicit flag, DEFAULT 0. Nobody is enrolled by this migration. Enrolling
-- somebody is a decision a person takes on the Employee Management screen, which is the
-- correct shape for an election the employee themselves has to make.
--
-- The screen warns when a non-Malaysian is NOT enrolled, because for them it is an
-- obligation rather than a choice. A warning, not an automatic enrolment: the system says
-- what the employer has to decide, and does not decide it from a text field.
--
-- ----------------------------------------------------------------------------
-- WHY ITS OWN COLUMN AND NOT `other_deductions`
-- ----------------------------------------------------------------------------
--
-- `payroll_records.other_deductions` exists, is already inside the generated
-- `total_deductions`, and is hardcoded to 0 by the payroll run. Putting Lindung there would
-- have needed no migration at all, and it was rejected:
--
--   A payslip would print it as "Potongan Lain-lain / Other Deductions". That is a STATUTORY
--   deduction under Act 4 appearing on a wage statement with no name, indistinguishable from
--   any other adjustment. It is the same fault as the missing PCB line, and the employer's
--   own sheet gives it a named column.
--
--   And it would collide. The moment anything else legitimately needs `other_deductions`,
--   the two figures are summed into one cell with no way to separate them again.
--
-- There is no employer side. Lindung 24 Jam is borne entirely by the employee, so there is
-- no `socso_nei_employer` column and the employer-cost total is untouched.
--
-- ----------------------------------------------------------------------------
-- THE TWO GENERATED COLUMNS HAVE TO BE REWRITTEN, AND THAT IS THE RISK HERE
-- ----------------------------------------------------------------------------
--
-- `total_deductions` and `net_salary` are STORED GENERATED. Their expressions were read out
-- of information_schema, not guessed:
--
--   total_deductions := epf_employee + socso_employee + eis_employee + tax_deduction
--                       + loan_deduction + advance_deduction + other_deductions
--
--   net_salary       := (the eight earnings) - (those seven deductions)
--
-- A new deduction column that is not inside BOTH of them is a number that is recorded and
-- never subtracted — visible on the payslip and absent from the net. So both are modified,
-- and they are modified TOGETHER: adding it to `total_deductions` alone would make
-- `net_salary` disagree with `gross_salary - total_deductions`, and
-- `src/lib/payroll-posting.ts` REFUSES to pay a period whose payslip does not reconcile.
-- Half this migration is worse than none of it.
--
-- MODIFY on a stored generated column REWRITES THE TABLE. With the new column defaulting to
-- 0.00, every existing row recomputes to the value it already held, so no historical payslip
-- changes. MEASURED locally: payroll_records holds 0 rows. On production the count is
-- whatever it is, and the arithmetic above is what makes the rewrite safe either way.
--
-- IDEMPOTENT. Production applies this by hand and a hand runs things twice. Every step is
-- guarded on information_schema, and the two MODIFY statements only fire when the expression
-- does not already name the new column — so a second run does not rewrite the table again.
-- ============================================================================

-- >>>
-- 1/6 employees.lindung24_enrolled — the election.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees'
      AND COLUMN_NAME = 'lindung24_enrolled') = 0,
  'ALTER TABLE `employees`
     ADD COLUMN `lindung24_enrolled` TINYINT(1) NOT NULL DEFAULT 0
       COMMENT ''Enrolled in Lindung 24 Jam (SKBBK). Employee-borne. Mandatory for foreign employees, optional for Malaysians.''
       AFTER `socso_number`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 2/6 payroll_records.socso_nei_employee — what was actually deducted, per payslip.
--
-- Placed AFTER eis_employee so the three PERKESO lines sit together. MySQL does not require
-- a base column to precede a generated column that references it, so the position is for
-- whoever reads the table, not for the engine.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
      AND COLUMN_NAME = 'socso_nei_employee') = 0,
  'ALTER TABLE `payroll_records`
     ADD COLUMN `socso_nei_employee` DECIMAL(12,2) NOT NULL DEFAULT 0.00
       COMMENT ''Lindung 24 Jam (Non-Employment Injury, Act 4). Employee-borne; no employer share.''
       AFTER `eis_employee`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 3/6 total_deductions — add the new column to the generated expression.
--
-- The expression is written out in full rather than patched, because there is no way to
-- append to a generated expression. It is the expression read from information_schema with
-- one term added, and the guard means a re-run does not rewrite the table.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
      AND COLUMN_NAME = 'total_deductions'
      AND GENERATION_EXPRESSION LIKE '%socso_nei_employee%') = 0,
  'ALTER TABLE `payroll_records`
     MODIFY COLUMN `total_deductions` DECIMAL(12,2)
       GENERATED ALWAYS AS (
         `epf_employee` + `socso_employee` + `eis_employee` + `socso_nei_employee`
         + `tax_deduction` + `loan_deduction` + `advance_deduction` + `other_deductions`
       ) STORED',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 4/6 net_salary — the same term, subtracted.
--
-- This is the half that must not be forgotten. `payroll-posting.ts` re-derives gross from
-- its eight components and net from gross less its deductions, and refuses the payment if
-- either disagrees. A `total_deductions` that includes Lindung while `net_salary` does not
-- would block every payroll payment with "Payslip N does not add up".
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
      AND COLUMN_NAME = 'net_salary'
      AND GENERATION_EXPRESSION LIKE '%socso_nei_employee%') = 0,
  'ALTER TABLE `payroll_records`
     MODIFY COLUMN `net_salary` DECIMAL(12,2)
       GENERATED ALWAYS AS (
         (`basic_salary` + `housing_allowance` + `transport_allowance` + `meal_allowance`
          + `other_allowances` + `overtime_amount` + `bonus_amount` + `commission_amount`)
         - (`epf_employee` + `socso_employee` + `eis_employee` + `socso_nei_employee`
            + `tax_deduction` + `loan_deduction` + `advance_deduction` + `other_deductions`)
       ) STORED',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 5/6 An index on the election, so the payroll run's employee SELECT does not change shape.
--
-- Not for filtering: the run reads every active employee and the flag comes along in the row.
-- It is here because reporting "who is enrolled" is the first question an HR clerk asks after
-- this ships, and a four-row table today is not a reason to make that a full scan later.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees'
      AND INDEX_NAME = 'idx_employees_lindung24') = 0,
  'ALTER TABLE `employees` ADD INDEX `idx_employees_lindung24` (`lindung24_enrolled`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- 6/6 VERIFICATION. `scripts/run-sql.js` prints a row set, so this is what the operator reads
-- back. Every figure on the left must equal the number in its own name.
SELECT 'employees.lindung24_enrolled exists (want 1)' AS check_name,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees'
           AND COLUMN_NAME = 'lindung24_enrolled') AS value
 UNION ALL
SELECT 'idx_employees_lindung24 exists (want 1)',
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees'
           AND INDEX_NAME = 'idx_employees_lindung24')
 UNION ALL
SELECT 'payroll_records.socso_nei_employee exists (want 1)',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
           AND COLUMN_NAME = 'socso_nei_employee')
 UNION ALL
SELECT 'total_deductions now names it (want 1)',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
           AND COLUMN_NAME = 'total_deductions'
           AND GENERATION_EXPRESSION LIKE '%socso_nei_employee%')
 UNION ALL
SELECT 'net_salary now names it (want 1)',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
           AND COLUMN_NAME = 'net_salary'
           AND GENERATION_EXPRESSION LIKE '%socso_nei_employee%')
 UNION ALL
SELECT 'both generated columns still STORED (want 2)',
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll_records'
           AND COLUMN_NAME IN ('total_deductions','net_salary')
           AND EXTRA LIKE '%STORED GENERATED%')
 UNION ALL
SELECT 'payslips where net <> gross - deductions (want 0)',
       (SELECT COUNT(*) FROM `payroll_records`
         WHERE ABS(`net_salary` - (`gross_salary` - `total_deductions`)) > 0.001)
 UNION ALL
SELECT 'employees enrolled by this migration (want 0)',
       (SELECT COUNT(*) FROM `employees` WHERE `lindung24_enrolled` = 1)
