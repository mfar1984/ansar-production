-- FOUR CHART ACCOUNTS: INVOICE FACTORING, AND SHARE CAPITAL FOR A SDN BHD
--
-- Idempotent. Safe to run twice.
--
-- ── WHY THIS IS A MIGRATION AND THE OPENING BALANCE IS NOT ──
--
-- `scripts/opening-balance-worksheet.js` refuses to post an opening balance by SQL, and the reasons are
-- written out at the top of it: a journal is posted once, it has no natural unique key to make a second
-- run harmless, and a journal that appears by SQL has no `posted_by` for an audit to ask about.
--
-- None of that applies to a chart account. It is MASTER DATA: additive, reversible by setting
-- `status = 'inactive'`, carrying no audit weight of its own, and `code` has a UNIQUE index so
-- `INSERT IGNORE` makes a replay a genuine no-op rather than a duplicate.
--
-- ── THE THREE FACTORING ACCOUNTS ──
--
-- ANSAR factors the KEMAS Pahang rental contract through Planworth Global. Measured from two months of
-- bank statements, the monthly cycle against an invoice of RM13,144.50 is:
--
--   advance received        10,218.96   arrives mid-month
--   released on collection    2,576.32   Planworth, "refund"
--   released on collection      202.38   Planworth, "advance"
--                          ----------
--   received by ANSAR       12,997.66
--   retained as the fee        146.84   = 1.117%
--
-- All three amounts are identical in both months, which is what a fixed rental factored on fixed terms
-- looks like. The fee is inferred from the difference and is to be confirmed against a Planworth
-- statement, not taken as established.
--
-- `Factoring clearing` MUST be `Cash and bank` and this is not a matter of taste.
-- `src/pages/api/admin/accounting/ar-receipts.ts` refuses any other account type outright:
--
--   'Choose the account the money was banked into. It has to be an active Cash and bank account -
--    a receipt that lands anywhere else would show cash the company does not have.'
--
-- And the receipt has to go somewhere that is not a real bank, because Planworth collects RM13,144.50
-- from KEMAS while only RM2,778.70 reaches the bank. The customer's debt must be cleared for the full
-- amount, through the AR module, because `3000/000 Debtors Control Account` carries `is_locked = 1` and
-- `accountPostingError()` refuses a manual journal to it. A clearing account is the only shape that
-- satisfies both, and it nets to zero every month - a balance left on it means a month Planworth has
-- collected and not yet released.
--
-- This is the same pattern the CHIP payment gateway will need for the same reason: when a third party
-- collects on your behalf, the amount collected is not the amount that reaches the bank.
--
-- ── WHY SHARE CAPITAL, AND WHAT IS DELIBERATELY NOT DONE TO `Capital` ──
--
-- The chart carries `1000/000 Capital` and `1100/000 Drawings`. Those are SOLE PROPRIETOR accounts: a
-- proprietor introduces capital and takes drawings. A company issues SHARES, and a director takes a
-- salary or a dividend - there is no such thing as a director's drawings.
--
-- That the taxpayer is a company is now established rather than assumed: the TIN is `C23976830020`, a
-- `C` prefix is non-individual, and LHDN confirmed it matches BRN `201101012342` on a live connection
-- test.
--
-- `Capital` and `Drawings` are NOT renamed, deactivated or deleted here. Both are unused - `journal_lines`
-- holds two rows in total and neither touches them - so retiring them is safe, and it is still not this
-- file's decision. Renaming an equity account is the accountant's, and a migration that quietly renamed
-- one would be discovered by someone reading a balance sheet that no longer says what they expected.
--
-- Deactivate them from Chart of Accounts once the accountant confirms. Until then two similar equity
-- accounts sit side by side, which is a reason to ask rather than a defect.
-- ============================================================================

-- >>>
-- ============================================================
-- The four accounts.
--
-- `INSERT IGNORE` against the UNIQUE index on `code`, so a second run inserts nothing. A code that
-- already exists is left exactly as it is, including its name - if one of these codes is already in use
-- for something else, this file must not overwrite it, and the verification below reports the mismatch.
--
-- Codes chosen to sort into the right neighbourhood, because a chart is read in code order:
--
--   3010/060  after Credit card account, last of the five Cash and bank accounts
--   4090/000  after Employment Insurance System payable, last of the current liabilities
--   9265/000  BETWEEN Bank interest paid (9260) and Loan interest paid (9270). A factoring fee is a
--             finance cost, and putting it among the sundry expenses would hide what it is
--   1010/000  immediately after Capital, so the equity block reads in one place
-- ============================================================
INSERT IGNORE INTO `chart_of_accounts` (`code`, `name`, `account_type`, `description`, `status`, `is_locked`) VALUES
  ('3010/060', 'Factoring clearing', 'Cash and bank',
   'Money a factoring company has collected from a customer and not yet remitted. An AR receipt is banked here for the full invoice, then this account is cleared by the advance, the fee and the net remittance. It nets to zero each cycle; a balance means a collection has not been released.',
   'active', 0),

  ('4090/000', 'Factoring liability', 'Current liabilities',
   'Advances drawn against invoices not yet collected by the factoring company. This is borrowing, not revenue and not a customer receipt: the customer still owes the invoice until the factor collects it.',
   'active', 0),

  ('9265/000', 'Factoring charges', 'Operating expenses',
   'The factoring company fee, being the difference between the invoice and what it remits. A finance cost, which is why it sits between bank interest and loan interest.',
   'active', 0),

  ('1010/000', 'Share Capital', 'Equity',
   'Issued and paid up share capital. A company issues shares; 1000/000 Capital and 1100/000 Drawings are sole proprietor accounts and are unused.',
   'active', 0)

-- >>>
-- ============================================================
-- Verification, to be read by a person.
--
-- `scripts/run-sql.js` does not print result sets, so running this file proves only that the statements
-- parse. Run this in a client to see it: four rows, each with the type the code depends on.
--
-- `expected_type` is checked rather than assumed because `Factoring clearing` being `Cash and bank` is
-- load bearing - AR Receipt rejects anything else, and the failure would arrive at the moment somebody
-- is trying to record a collection.
-- ============================================================
SELECT c.`code`, c.`name`, c.`account_type`, c.`status`, c.`is_locked`,
       e.`expected_type`,
       CASE WHEN c.`account_type` = e.`expected_type` THEN 'ok'
            ELSE 'WRONG TYPE - this code was already in use for something else'
       END AS `verdict`
  FROM (
              SELECT '3010/060' AS `code`, 'Cash and bank'       AS `expected_type`
    UNION ALL SELECT '4090/000',           'Current liabilities'
    UNION ALL SELECT '9265/000',           'Operating expenses'
    UNION ALL SELECT '1010/000',           'Equity'
  ) e
  LEFT JOIN `chart_of_accounts` c ON c.`code` = e.`code`
 ORDER BY e.`code`
