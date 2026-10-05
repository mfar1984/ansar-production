-- ============================================================================
-- CUSTOMER PO NUMBER ON THE REST OF THE SALES CHAIN
-- ============================================================================
--
-- Requested from the screen: the Customer PO No. exists on a sales order and nowhere else, and it is
-- needed on the proforma, the delivery order, the invoice and the notes raised from that order.
--
-- MEASURED before writing this. `po_no` is present on exactly ONE of the sixteen trade-document
-- header tables:
--
--     sales_orders          po_no varchar(100)        <- the only one
--     cash_sales            reference_no varchar(100) <- the PAYMENT reference, a different thing
--     supplier_invoices     delivery_order_no         <- our supplier's DO, not a customer PO
--     goods_received_notes  delivery_order_no         <- the same
--     purchase_orders       order_no varchar(50)      <- OUR number. We are the customer there
--
-- So six tables gain the column, and varchar(100) matches `sales_orders.po_no` exactly. The field is
-- declared once in `sales-document-kinds.ts` with `maxLength: 100`, and a narrower column would let
-- MySQL truncate a long government LO number silently.
--
-- AFTER `customer_address`, which all six already carry, so the column lands in the same position
-- everywhere rather than at the end of whichever table was widened last. It is also the right
-- neighbour: this is a fact about the CUSTOMER's paperwork, not about ours.
--
-- WHAT IS DELIBERATELY NOT IN THIS LIST
--
--   sales_quotations        a quotation comes BEFORE the customer raises a PO. That is the sequence:
--   sales_pre_quotations    we quote, they issue a PO against the quotation. A PO field on a
--                           quotation is a box empty by definition, and the field's own hint - "the
--                           number the CUSTOMER will quote when they pay" - describes something
--                           nobody does to a quotation. One entry in the registry turns it on if
--                           that turns out to be wrong
--
--   the seven purchase      "Customer PO" has no meaning on a document where WE are the customer.
--   documents               Our own purchase order number is `purchase_orders.order_no` and the
--                           supplier's delivery reference is `delivery_order_no`. Both already exist
--
-- IDEMPOTENT, because production runs this by hand and a hand runs things twice. MySQL 8 has no
-- `ADD COLUMN IF NOT EXISTS`, so every ALTER is behind an information_schema guard and the no-op
-- branch is `DO 0`.
--
-- `-- >>>` IS THE SEPARATOR AND EACH CHUNK IS ONE STATEMENT. `scripts/run-sql.js` splits on that
-- marker and opens the connection with `multipleStatements: false`, so `SET`, `PREPARE`, `EXECUTE`
-- and `DEALLOCATE` are four chunks and not one block. Measured the other way first: a chunk holding
-- all four came back ER_PARSE_ERROR. This is the shape `document_subject.sql` already uses.
--
-- Run:  node scripts/run-sql.js database/customer_po_no.sql
-- ============================================================================
-- >>>
-- 1/6 proforma_invoices
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'proforma_invoices' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `proforma_invoices`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 2/6 delivery_orders
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `delivery_orders`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 3/6 sales_invoices
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_invoices' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `sales_invoices`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 4/6 sales_credit_notes
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_credit_notes' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `sales_credit_notes`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 5/6 sales_debit_notes
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_debit_notes' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `sales_debit_notes`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- 6/6 cash_sales
-- Its `reference_no` is the PAYMENT reference - the cheque or transaction number, declared on the
-- kind as `Payment Ref.`. A counter sale to a government department still quotes an LO number, so
-- the two are separate fields answering separate questions and this one is added rather than reused.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cash_sales' AND COLUMN_NAME = 'po_no') = 0,
  'ALTER TABLE `cash_sales`
     ADD COLUMN `po_no` VARCHAR(100) NULL DEFAULT NULL AFTER `customer_address`',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- The result, for whoever runs this and wants to see that it worked. SEVEN rows, counting the
-- `sales_orders` column that was already there.
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'po_no'
 ORDER BY TABLE_NAME
