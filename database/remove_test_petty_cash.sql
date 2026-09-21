-- ============================================================================
-- REMOVE THE TEST PETTY CASH REQUEST PC-202609-001
--
-- Run with:  node scripts/run-sql.js database/remove_test_petty_cash.sql
--
-- ── WHY THIS IS A SQL FILE AND NOT A BUTTON ──
--
-- `src/lib/petty-cash-status.ts` declares:
--
--     PETTY_CASH_CANCELLABLE = ['pending']
--     PETTY_CASH_DELETABLE   = ['pending', 'cancelled']
--
-- PC-202609-001 is `approved`, so it is in neither list. The admin screen renders no
-- delete and no cancel action for it, and `DELETE /api/admin/petty-cash/[id]` answers
-- 409: "A decided request is history."
--
-- That guard is CORRECT and was deliberately NOT relaxed to make this deletion
-- possible. Adding `approved` to PETTY_CASH_DELETABLE would let any genuinely
-- approved request be erased along with the approver's decision, for every company
-- and for ever, to clean up one RM10 test row. The cost is wildly out of proportion.
--
-- ── WHY THE ROW SHOULD GO AT ALL ──
--
-- It is a test raised while the module was being checked, on 2026-09-14. That date
-- falls INSIDE the first audited financial year, 1/7/2026 - 30/6/2027. Left in place
-- it is a RM10 approved-but-never-issued advance with no explanation, sitting in the
-- books an auditor will read. A test artefact removed before the ledger is opened
-- leaves nothing to explain. "A decided request is history" is a rule about real
-- decisions, and no decision was made here.
--
-- ── WHAT IT TOUCHES, MEASURED NOT ASSUMED ──
--
-- Read from the database before this file was written:
--
--     petty_cash_requests   1 row   #1 PC-202609-001 approved RM10.00
--                                   amount_issued NULL, amount_returned NULL
--                                   issue_journal_id NULL, return_journal_id NULL
--     hr_approval_records   1 row   #13 level 1, approved
--     expenses -> float     0 rows  so fk_expenses_petty_cash RESTRICT cannot block
--     journal_entries       1 row   GJ0001, source claims/1 - a CLAIM, not this
--
-- So NOTHING in the ledger refers to this request. There is no journal to reverse,
-- which is the only reason a delete is defensible instead of a reversal.
--
-- GJ0001 is left ALONE by this file. It is a posted journal and a posted journal is
-- reversed, never deleted. It belongs to claim CLM-202609-001 and is a separate
-- decision.
--
-- ── IDEMPOTENT, AND FENCED SO IT CANNOT REACH ANYTHING ELSE ──
--
-- Every guard below has to hold before a single row is removed:
--
--     request_no = 'PC-202609-001'    the UNIQUE key, so exactly one row at most
--     status     = 'approved'         a real approval that later got issued is skipped
--     amount_requested = 10.00        the test amount
--     issue_journal_id   IS NULL      nothing posted against it
--     return_journal_id  IS NULL      nothing posted against it
--     no expenses row points at it    no receipts were ever charged to the float
--
-- Miss any one and @pc_id is NULL and both deletes match nothing. On a second run the
-- row is already gone, so @pc_id is NULL again and the file is a true no-op. On a
-- database that never had the row it does nothing at all.
--
-- `request_no`, not `id`: auto-increment ids are not stable across databases and
-- `uq_pcr_request_no` is what makes the target unambiguous.
--
-- ── ONE-OFF, AND KEPT ON THE MIGRATIONS LIST ANYWAY ──
--
-- This is a repair, not a schema change, and `deploy/package-production.js` warns in
-- its own comment that one-off repairs are what got `database/` banned from the
-- package. It is named there regardless, because the guards above make a replay
-- harmless and because the alternative is asking the operator to paste SQL by hand
-- into the live database - which is the more dangerous of the two.
--
-- One statement per `-- >>>` block, no trailing semicolons: the runner sends each
-- block as a single statement with `multipleStatements` off.
-- ============================================================================

-- >>>
-- ── 1. Resolve the row, with every guard applied at once ──
--
-- A single SELECT rather than a chain of IFs, so there is no window in which some
-- guards have been checked and others have not.
SET @pc_id := (
  SELECT r.`id`
    FROM `petty_cash_requests` r
   WHERE r.`request_no` = 'PC-202609-001'
     AND r.`status` = 'approved'
     AND r.`amount_requested` = 10.00
     AND r.`issue_journal_id` IS NULL
     AND r.`return_journal_id` IS NULL
     AND NOT EXISTS (SELECT 1 FROM `expenses` x WHERE x.`petty_cash_id` = r.`id`)
   LIMIT 1
)

-- >>>
-- ── 2. The approval trail first ──
--
-- Child before parent. `hr_approval_records` carries no foreign key to
-- `petty_cash_requests` - it is a shared table keyed by (module, application_id) - so
-- nothing would stop the parent going first and orphaning row #13 against an
-- application_id that no longer exists. The same order, and for the same reason, as
-- the DELETE branch of `src/pages/api/admin/petty-cash/[id].ts`.
--
-- `= @pc_id` is already never true when @pc_id is NULL. The explicit IS NOT NULL is
-- there so the statement says so to the next reader.
DELETE FROM `hr_approval_records`
 WHERE `module` = 'petty_cash'
   AND @pc_id IS NOT NULL
   AND `application_id` = @pc_id

-- >>>
-- ── 3. The request ──
DELETE FROM `petty_cash_requests`
 WHERE @pc_id IS NOT NULL
   AND `id` = @pc_id

-- >>>
-- ── 4. Report what is left ──
--
-- `scripts/run-sql.js` prints statement counts and not result sets, so this is for a
-- reader running the file through a SQL client. Through the runner, the verification
-- is the screen: reload Human Resources > Petty Cash and the row is gone.
SELECT
  (SELECT COUNT(*) FROM `petty_cash_requests` WHERE `request_no` = 'PC-202609-001')
                                                                    AS pc_202609_001_left,
  (SELECT COUNT(*) FROM `petty_cash_requests`)                      AS petty_cash_rows_total,
  (SELECT COUNT(*) FROM `hr_approval_records` WHERE `module` = 'petty_cash')
                                                                    AS approval_rows_left
