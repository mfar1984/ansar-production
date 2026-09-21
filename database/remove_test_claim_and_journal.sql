-- ============================================================================
-- REMOVE THE TEST CLAIM CLM-202609-001 AND ITS LEDGER ENTRY GJ0001
--
-- Run with:  node scripts/run-sql.js database/remove_test_claim_and_journal.sql
--
-- ── WHAT IS BEING REMOVED, AND WHY BOTH TOGETHER ──
--
-- The ledger holds exactly ONE transaction, and it is a test:
--
--     claims #1   CLM-202609-001   employee 1   RM30.00   status paid
--                 description 'test'   remarks 'test'
--                 approved 14/09/2026, paid 14/09/2026 by bank_transfer
--
--     GJ0001      14/09/2026   posted   source claims/1
--                 DR 9140/000 Travelling    30.00
--                 CR 3010/010 Petty cash             30.00
--
-- Three screens report that one row: Journal Entries lists it, Trial Balance shows
-- Petty cash at -30.00 against Travelling at 30.00, and Year End Close offers a
-- (30.00) loss to transfer into Retained earnings. Removing the row clears all three.
--
-- ── WHY THE JOURNAL ALONE IS NOT ENOUGH ──
--
-- `document-posting.ts` decides a document still needs posting with:
--
--     WHERE source_table = ? AND source_id = ? AND status = 'posted' AND reverses_id IS NULL
--
-- Take GJ0001 out and nothing matches, so the claim - still `paid` - reappears in
-- Document Posting as awaiting posting, and the next person to press Post recreates
-- the entry under a new number.
--
-- A REVERSAL has exactly the same effect. `journal-post.ts` sets the original to
-- `status = 'reversed'` and gives the mirror a `reverses_id`, so neither row satisfies
-- the guard either. That is correct for a real correction - reverse, fix, post again -
-- and it is precisely why reversing was NOT chosen here. There is nothing to fix.
--
-- So the claim and the journal go together or neither goes. @go below is the one gate
-- that enforces it.
--
-- ── WHY DELETE RATHER THAN REVERSE, WHICH IS THE NORMAL RULE ──
--
-- A posted journal is reversed, never deleted, and `journals.ts` refuses a non-draft
-- delete with exactly that sentence. That rule protects a LEDGER THAT HAS BEEN
-- REPORTED ON. This one has not:
--
--     no opening balance is posted        no year has been closed
--     no sales or purchase document       no receipt, payment or bank movement
--     no e-Invoice submission             every other transaction table is empty
--
-- The company is about to start real books at 1/7/2026. A reversal would leave two
-- entries inside the first audited year, both explaining a RM30 row that says 'test'
-- twice. A delete leaves nothing to explain. Once the opening balance is posted this
-- reasoning expires and the normal rule applies again.
--
-- ── WHAT IS DELIBERATELY LEFT ALONE ──
--
-- audit_logs, 4 rows: #37 CREATE, #95 and #98 APPROVE, #99 UPDATE payment. They are
-- the only record of where CLM-202609-001 went, and this file cannot write one of its
-- own - a SQL script has no `logAudit`. Deleting them would turn an explained gap into
-- an unexplained one.
--
-- The GJ counter. `accounting_document_numbers` #19 reads last_used GJ0019, next
-- GJ0020, because nineteen numbers were issued during testing and eighteen drafts were
-- deleted. Removing GJ0001 does NOT free the number - the first real journal will be
-- GJ0020. That row is `editable = 1`, so it belongs to the Document Numbers screen and
-- to a decision, not to this file.
--
-- The receipt image `/uploads/claims/1789046151747-t8c7jtc.jpg`. SQL cannot delete a
-- file, and `public/uploads/**` is runtime data the server owns. It has to be removed
-- there by hand, or left as an orphan, which harms nothing.
--
-- Everything outside accounting: 1 expense, 5 leave applications, 1 overtime
-- application, 2 asset loan requests, 4 asset checkouts, 2 stocktakes. None of them
-- touches the ledger and none was asked for. Leave especially is not a plain delete -
-- `leave_balances` has already been reduced for the approved days, so removing an
-- application without restoring the balance would lose an employee's entitlement.
--
-- ── ORDER, AND WHY THE JOURNAL GOES FIRST ──
--
-- `run-sql.js` runs each block on its own with autocommit, so there is no rollback. The
-- order is therefore chosen for which half-state would be least harmful if one
-- statement somehow failed:
--
--   journal first  -> worst case is a paid claim with no entry, which SHOWS UP in
--                     Document Posting and is fixed by running this file again
--   claim first    -> worst case is a ledger entry whose source document does not
--                     exist, invisible on every claims screen and breaking
--                     `documentJournal` lookups
--
-- The first is visible and recoverable, so that is the order. In practice neither can
-- happen: every foreign key into these two tables is CASCADE or SET NULL, and
-- `petty_cash_requests` - the only other table referencing `journal_entries` - is
-- empty, so no statement here has a failure path.
--
-- ── IDEMPOTENT ──
--
-- Both ids are resolved BEFORE anything is written, and @go is 1 only when both
-- resolved. After the first run neither resolves, @go is 0, and every DELETE matches
-- nothing. On a database that never held the rows the file does nothing at all.
--
-- Matched on `claim_number` and `journal_no`, not on `id`: auto-increment ids are not
-- stable across databases.
--
-- One statement per `-- >>>` block and no trailing semicolons - the runner sends each
-- block as a single statement with `multipleStatements` off.
-- ============================================================================

-- >>>
-- ── 1. The claim, with every guard applied at once ──
--
-- `description = 'test'` is included on purpose. It is the field that makes this a test
-- rather than a transaction, and a real RM30 accommodation claim that happened to reach
-- the same number must not be caught by this file.
SET @claim_id := (
  SELECT c.`id`
    FROM `claims` c
   WHERE c.`claim_number` = 'CLM-202609-001'
     AND c.`total_amount` = 30.00
     AND c.`status` = 'paid'
     AND c.`description` = 'test'
   LIMIT 1
)

-- >>>
-- ── 2. Its journal, and only if the claim resolved ──
--
-- `source_id = @claim_id` is what ties the two deletes to the same document. Guarded on
-- both reversal columns as well: a journal that has already been reversed is a
-- correction somebody made, and this file must not touch a decision.
SET @jrnl_id := (
  SELECT j.`id`
    FROM `journal_entries` j
   WHERE @claim_id IS NOT NULL
     AND j.`journal_no` = 'GJ0001'
     AND j.`source_table` = 'claims'
     AND j.`source_id` = @claim_id
     AND j.`status` = 'posted'
     AND j.`reverses_id` IS NULL
     AND j.`reversed_by_id` IS NULL
     AND j.`total_debit` = 30.00
     AND j.`total_credit` = 30.00
   LIMIT 1
)

-- >>>
-- ── 3. One gate for both ──
--
-- Resolved before any write, so a claim can never be removed without its journal and a
-- journal can never be removed without its claim. Every DELETE below tests it.
SET @go := IF(@claim_id IS NOT NULL AND @jrnl_id IS NOT NULL, 1, 0)

-- >>>
-- ── 4. The journal lines ──
--
-- `fk_jl_journal` is ON DELETE CASCADE so step 5 would take these anyway. Written out
-- because a reader of this file should not have to look up a constraint to know what it
-- removes, and because a cascade that is silently relied on is a cascade nobody checks.
DELETE FROM `journal_lines`
 WHERE @go = 1
   AND `journal_id` = @jrnl_id

-- >>>
-- ── 5. The journal header ──
DELETE FROM `journal_entries`
 WHERE @go = 1
   AND `id` = @jrnl_id

-- >>>
-- ── 6. The approval trail ──
--
-- `hr_approval_records` is the shared table keyed by (module, application_id) and has
-- no foreign key to `claims`, so nothing would stop the claim going first and orphaning
-- these two rows against an application_id that no longer exists. Module is `claim`,
-- singular - read from the table, not guessed.
DELETE FROM `hr_approval_records`
 WHERE @go = 1
   AND `module` = 'claim'
   AND `application_id` = @claim_id

-- >>>
-- ── 7. The claim line ──
--
-- `claim_items_ibfk_1` is ON DELETE CASCADE, so step 8 would take this too. Explicit
-- for the same reason as step 4.
DELETE FROM `claim_items`
 WHERE @go = 1
   AND `claim_id` = @claim_id

-- >>>
-- ── 8. The claim ──
DELETE FROM `claims`
 WHERE @go = 1
   AND `id` = @claim_id

-- >>>
-- ── 9. Report ──
--
-- `scripts/run-sql.js` prints statement counts and not result sets, so through the
-- runner the verification is the screen: General Ledger > Journal Entries shows no
-- journals, Financial Reports > Trial Balance shows no accounts with a balance, and
-- Year End Close offers nothing to transfer.
SELECT
  (SELECT COUNT(*) FROM `claims` WHERE `claim_number` = 'CLM-202609-001') AS test_claim_left,
  (SELECT COUNT(*) FROM `journal_entries`)                                AS journals_total,
  (SELECT COUNT(*) FROM `journal_lines`)                                  AS journal_lines_total,
  (SELECT COUNT(*) FROM `claims`)                                         AS claims_total,
  (SELECT COUNT(*) FROM `claim_items`)                                    AS claim_items_total,
  (SELECT COUNT(*) FROM `hr_approval_records` WHERE `module` = 'claim')    AS claim_trail_left
