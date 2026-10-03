-- ═══════════════════════════════════════════════════════════════════════════════
-- TRADE DOCUMENTS — AN OPTIONAL SUBJECT LINE
--
-- WHAT IT IS
--
-- A government department or an agency asks for a quotation whose heading names the work:
--
--   Subject: Supply, deliver, install and test a security surveillance system at the
--            Seri Kembangan office
--
-- There was nowhere to put that. The item lines describe each thing supplied and the remark is a
-- note to the reader at the foot of the sheet; neither is the heading of the deal. Operators were
-- putting it into the first item line, where it printed with a quantity and a price beside it.
--
-- WHAT IT IS NOT
--
--   * NOT the sheet's own name. "Sales Quotation" is the document TYPE and comes from the registry.
--   * NOT a remark. A remark is addressed to the reader of ONE document — "valid for 30 days" — and
--     `document-transfer.ts` deliberately does not carry it forward. A subject names the DEAL, so it
--     travels down the chain: quotation to order to delivery order to invoice, typed once.
--   * NOT required. NULL is the normal case and nothing prints. Most commercial quotations have no
--     subject line at all, which is why this is a column and not a form rule.
--
-- WHY ALL SIXTEEN TABLES
--
-- Fifteen trade documents print through ONE sheet — `DocumentPrint.tsx` — and are saved through one
-- handler. A column on some of them would mean a `hasSubject` flag on the registry, a conditional in
-- the SELECT, a conditional in the save, and a conditional in the transfer: four places to be wrong,
-- to save nine bytes a row. `hasSalesperson` exists because four tables genuinely have no such
-- column and nobody sells us anything; a purchase order to a supplier DOES have a subject.
--
-- `sales_pre_quotations` is the sixteenth. It has no screen of its own and nothing will ever set the
-- column — but it is a transfer SOURCE for two documents, and `document-import.ts` reads the source's
-- header with one statement built from the graph. Without the column that statement is
-- ER_BAD_FIELD_ERROR for the two targets a pre-quotation feeds, and the dropdown comes back empty.
-- That exact failure, from that exact table, cost a release already — see the note on `DocSpec.party`.
--
-- varchar(255), matching `business_proposals.title` and `helpdesk_tickets.subject`, the two columns in
-- this database that hold the same sort of thing. NOT TEXT: a subject is one line on paper, and the
-- print sheet measures its height to decide where the page breaks.
--
-- AFTER `location`, which all sixteen tables already have, so the column lands in the same position
-- everywhere rather than at the end of whichever table was widened last.
--
-- IDEMPOTENT. Every ALTER is behind an information_schema guard, so a second run changes nothing.
--
-- Run:  node scripts/run-sql.js database/document_subject.sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- >>>
-- ── 1/16 sales_pre_quotations ──
-- Operations keeps this one. It is a transfer SOURCE, so the column has to exist.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_pre_quotations' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_pre_quotations`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2/16 sales_quotations ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_quotations`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 3/16 sales_orders ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_orders' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_orders`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 4/16 delivery_orders ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `delivery_orders`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 5/16 proforma_invoices ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'proforma_invoices' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `proforma_invoices`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 6/16 sales_invoices ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_invoices' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_invoices`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 7/16 sales_credit_notes ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_credit_notes' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_credit_notes`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 8/16 sales_debit_notes ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_debit_notes' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `sales_debit_notes`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 9/16 cash_sales ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cash_sales' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `cash_sales`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 10/16 purchase_requests ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'purchase_requests' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `purchase_requests`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 11/16 purchase_orders ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'purchase_orders' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `purchase_orders`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 12/16 goods_received_notes ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'goods_received_notes' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `goods_received_notes`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 13/16 supplier_invoices ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'supplier_invoices' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `supplier_invoices`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 14/16 cash_purchases ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cash_purchases' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `cash_purchases`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 15/16 supplier_credit_notes ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'supplier_credit_notes' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `supplier_credit_notes`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 16/16 supplier_debit_notes ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'supplier_debit_notes' AND COLUMN_NAME = 'subject') = 0,
  'ALTER TABLE `supplier_debit_notes`
     ADD COLUMN `subject` VARCHAR(255) NULL DEFAULT NULL AFTER `location`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── Verification ──
--
-- Expect: subject_columns 16, widths '255', nullable 'YES'. A figure below 16 means a table was
-- missed, and the document that writes it would answer ER_BAD_FIELD_ERROR on its first save.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'subject'
      AND TABLE_NAME IN ('sales_pre_quotations', 'sales_quotations', 'sales_orders', 'delivery_orders', 'proforma_invoices', 'sales_invoices', 'sales_credit_notes', 'sales_debit_notes', 'cash_sales', 'purchase_requests', 'purchase_orders', 'goods_received_notes', 'supplier_invoices', 'cash_purchases', 'supplier_credit_notes', 'supplier_debit_notes')) AS subject_columns,
  (SELECT GROUP_CONCAT(DISTINCT CHARACTER_MAXIMUM_LENGTH) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'subject'
      AND TABLE_NAME IN ('sales_pre_quotations', 'sales_quotations', 'sales_orders', 'delivery_orders', 'proforma_invoices', 'sales_invoices', 'sales_credit_notes', 'sales_debit_notes', 'cash_sales', 'purchase_requests', 'purchase_orders', 'goods_received_notes', 'supplier_invoices', 'cash_purchases', 'supplier_credit_notes', 'supplier_debit_notes')) AS widths,
  (SELECT GROUP_CONCAT(DISTINCT IS_NULLABLE) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'subject'
      AND TABLE_NAME IN ('sales_pre_quotations', 'sales_quotations', 'sales_orders', 'delivery_orders', 'proforma_invoices', 'sales_invoices', 'sales_credit_notes', 'sales_debit_notes', 'cash_sales', 'purchase_requests', 'purchase_orders', 'goods_received_notes', 'supplier_invoices', 'cash_purchases', 'supplier_credit_notes', 'supplier_debit_notes')) AS nullable
