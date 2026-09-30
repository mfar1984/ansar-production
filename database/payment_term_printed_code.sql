-- ============================================================================
-- THE PAYMENT TERM A DOCUMENT PRINTS IS ITS CODE, NOT THE REGISTER'S SENTENCE
-- ============================================================================
--
-- Reported from a printed Sales Quotation. The reference block read
--
--     Payment Terms : Cash in Advance - Payment required before delivery
--
-- wrapped over three lines, beside rows that are a document number and a date. A commercial document states its
-- term the way every quotation and invoice outside this application states it: CIA, Net 30 days, Net 60 days.
--
-- The sentence is `accounting_payment_terms.description`, and it is the register's own explanation of what the term
-- MEANS, written for whoever picks it from a dropdown. It is not what the customer receiving the document needs.
--
-- ── WHAT WAS WRONG, EXACTLY ──
--
-- `sales-document-handler.ts` resolved the snapshot as
--
--     COALESCE(NULLIF(TRIM(description), ''), code)
--
-- preferring the sentence and falling back to the code. It now reads `code` alone. Note which way round that
-- COALESCE was: it existed BECAUSE the column it preferred can be empty. Measured on the live register, `code` is
-- NOT NULL on all seven active terms while `description` is NULL on #4, `Net 30 days` - the DEFAULT. So reading the
-- code removes the fallback rather than inverting it.
--
-- ── WHY A MIGRATION AND NOT A JOIN AT READ TIME ──
--
-- A join would have corrected every existing document at once and cost nothing, and it is still the wrong answer.
-- `payment_term_description` is a SNAPSHOT: it exists so a document shows the terms it was raised under even after
-- somebody rewords the register, the same reason `customer_name` and `customer_address` sit beside `customer_id`.
-- Reading it live would silently restate a quotation that has already been sent to a customer.
--
-- So the code path stops writing the sentence, and this corrects what is already stored.
--
-- ── WHAT THIS TOUCHES, AND WHAT IT DELIBERATELY DOES NOT ──
--
-- Fourteen document tables carry both `payment_term_id` and `payment_term_description`. All fourteen are updated,
-- because one handler writes all of them and a sheet that prints a code on a quotation and a sentence on an invoice
-- is the same defect with a smaller audience.
--
-- `customers` and `suppliers` are NOT touched: they carry `payment_term_id` only, with no snapshot column. Their
-- registers go on showing the description, which is correct there - it explains the term to whoever is setting it.
--
-- Rows whose `payment_term_id` no longer resolves to a term are LEFT ALONE. An inner join does that by
-- construction. A document naming a term somebody deleted keeps the words it was issued with, which is the whole
-- point of a snapshot; blanking it to satisfy a format would destroy the only remaining record of its terms.
--
-- `status` is not filtered. A document raised under a term that has since been retired still states that term -
-- the status controls what may be CHOSEN, not what has already been printed.
--
-- ── IDEMPOTENT ──
--
-- Every statement assigns from the join and is guarded by `<>`, so a second run updates 0 rows rather than
-- rewriting every row to the value it already holds. Production applies this by hand and a hand runs things twice.
--
--     node scripts/run-sql.js database/payment_term_printed_code.sql
--
-- ============================================================================


-- ── 1. BEFORE ──
--
-- How many documents state a term, and how many of those state the sentence rather than the code. Read it again
-- after: `to_fix` falls to 0 and `already_code` rises by the same number.

SELECT 'sales_quotations' AS document_table,
       COUNT(*) AS carries_term,
       SUM(d.payment_term_description <> pt.code) AS to_fix,
       SUM(d.payment_term_description = pt.code) AS already_code
  FROM sales_quotations d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
 WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
UNION ALL
SELECT 'sales_orders', COUNT(*), SUM(d.payment_term_description <> pt.code),
       SUM(d.payment_term_description = pt.code)
  FROM sales_orders d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
 WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
UNION ALL
SELECT 'sales_invoices', COUNT(*), SUM(d.payment_term_description <> pt.code),
       SUM(d.payment_term_description = pt.code)
  FROM sales_invoices d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
 WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
UNION ALL
SELECT 'purchase_orders', COUNT(*), SUM(d.payment_term_description <> pt.code),
       SUM(d.payment_term_description = pt.code)
  FROM purchase_orders d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
 WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
UNION ALL
SELECT 'supplier_invoices', COUNT(*), SUM(d.payment_term_description <> pt.code),
       SUM(d.payment_term_description = pt.code)
  FROM supplier_invoices d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
 WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> '';

-- >>>

-- ── 2. THE CORRECTION, one statement per document table ──
--
-- Written out rather than looped. A prepared statement over `information_schema` would be shorter and would put an
-- UPDATE with an interpolated table name one typo away from a table nobody meant to touch. Fourteen named tables
-- are fourteen things a reader can check.

UPDATE sales_quotations d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE sales_pre_quotations d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE sales_orders d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE delivery_orders d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE proforma_invoices d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE sales_invoices d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE sales_credit_notes d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE sales_debit_notes d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE purchase_requests d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE purchase_orders d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE goods_received_notes d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE supplier_invoices d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE supplier_credit_notes d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

UPDATE supplier_debit_notes d
  JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   SET d.payment_term_description = pt.code
 WHERE d.payment_term_description IS NULL OR d.payment_term_description <> pt.code;

-- >>>

-- ── 3. AFTER ──
--
-- `still_wrong` must be 0 across all fourteen tables.

SELECT COALESCE(SUM(bad), 0) AS still_wrong FROM (
  SELECT SUM(d.payment_term_description <> pt.code) AS bad
    FROM sales_quotations d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM sales_pre_quotations d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM sales_orders d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM delivery_orders d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM proforma_invoices d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM sales_invoices d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM sales_credit_notes d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM sales_debit_notes d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM purchase_requests d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM purchase_orders d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM goods_received_notes d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM supplier_invoices d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM supplier_credit_notes d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
  UNION ALL SELECT SUM(d.payment_term_description <> pt.code)
    FROM supplier_debit_notes d JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
) x;

-- >>>

-- Documents whose term no longer exists. Left as they were on purpose; reported so the number is known rather
-- than a surprise the next time somebody reads a sheet with a sentence on it.

SELECT COUNT(*) AS orphans FROM (
  SELECT d.payment_term_id FROM sales_quotations d
    LEFT JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
     AND pt.id IS NULL
  UNION ALL
  SELECT d.payment_term_id FROM sales_invoices d
    LEFT JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
     AND pt.id IS NULL
  UNION ALL
  SELECT d.payment_term_id FROM purchase_orders d
    LEFT JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
     AND pt.id IS NULL
  UNION ALL
  SELECT d.payment_term_id FROM supplier_invoices d
    LEFT JOIN accounting_payment_terms pt ON pt.id = d.payment_term_id
   WHERE d.payment_term_description IS NOT NULL AND TRIM(d.payment_term_description) <> ''
     AND pt.id IS NULL
) y;
