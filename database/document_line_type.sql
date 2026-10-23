-- ═══════════════════════════════════════════════════════════════════════════════
-- TRADE DOCUMENT LINES — A ROW TYPE, SO A BILL OF QUANTITIES CAN BE WRITTEN
--
-- WHAT IT IS
--
--   line_type ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'
--
-- A Bill of Quantities is written as lettered sections: a heading row naming the section, the item
-- rows under it numbered from 1, and a subtotal row carrying the sum of those items.
--
--   D   EARTHWORKS                                 <- heading, carries a code and a title
--   1   Excavate to reduced level     120  m3      <- item
--   2   Cart away surplus             120  m3      <- item
--       Jumlah(RM) - D                    4,320.00 <- subtotal, derived and never stored
--
-- Operators were typing the heading into the first item line, where it printed with a quantity and a
-- price beside it, and there was nowhere at all for the section subtotal.
--
-- WHAT IT IS NOT
--
--   * NOT a charge. A heading and a subtotal carry TEXT and nothing else: `buildCommonLine` in
--     `src/lib/document-lines.ts` zeroes every figure column on a non-item row as its FIRST statement,
--     and `figuresOfLines` re-enforces it on the read side so a hand-edited row cannot poison a total.
--   * NOT a stored total. The subtotal row's figure is DERIVED at render by `sectionView` in
--     `src/lib/document-sections.ts`. There is no second summation anywhere — the header totals stay
--     the sum of the lines.
--   * NOT optional per table. Fifteen trade documents save through one handler and print through one
--     sheet, so a column on some of them would mean a flag on the registry and a conditional in the
--     SELECT, the save and the transfer.
--
-- ENUM rather than VARCHAR: the value set is closed, three members, and the driver refuses a fourth
-- with ER_DATA_TRUNCATED instead of storing it. The server decides the value before it is written —
-- `isLineType` falling back to 'item' — so the column's strictness is a net and never a user-facing
-- failure.
--
-- WHY ALL SIXTEEN TABLES
--
-- `sales_pre_quotation_items` is the sixteenth. It has no screen of its own and nothing will ever set
-- the column — but it is a live transfer SOURCE, and seven statements that this change filters
-- interpolate its name, three of them in `src/pages/api/admin/accounting/document-flow.ts`. Without
-- the column those statements are ER_BAD_FIELD_ERROR for the documents a pre-quotation feeds. That
-- exact omission, from that exact table, cost a release already — see `database/document_subject.sql`.
--
-- NO BACKFILL. `DEFAULT 'item'` is what MySQL writes into every existing row as it adds the column,
-- and 'item' is what every existing row is. An UPDATE would be sixteen full table scans that change
-- nothing.
--
-- IDEMPOTENT by `ansar_add_column`'s information_schema guard, so a second run changes nothing.
-- The DDL argument is DOUBLE-QUOTED because `ENUM('item',...)` contains single quotes — the same
-- reason 18 of the calls in `database/create_settings_expansion.sql` are written that way.
--
-- Run:  node scripts/run-sql.js database/document_line_type.sql
-- Statement separator: a line reading "-- >>>"
-- ═══════════════════════════════════════════════════════════════════════════════
-- >>>
DROP PROCEDURE IF EXISTS ansar_add_column
-- >>>
CREATE PROCEDURE ansar_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_ddl TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND COLUMN_NAME = p_column
  ) THEN
    SET @ddl_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_ddl);
    PREPARE stmt FROM @ddl_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END
-- >>>
-- 1/16 sales_quotation_items
CALL ansar_add_column('sales_quotation_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 2/16 sales_order_items
CALL ansar_add_column('sales_order_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 3/16 delivery_order_items
CALL ansar_add_column('delivery_order_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 4/16 proforma_invoice_items
CALL ansar_add_column('proforma_invoice_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 5/16 sales_invoice_items
CALL ansar_add_column('sales_invoice_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 6/16 cash_sales_items
CALL ansar_add_column('cash_sales_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 7/16 sales_credit_note_items
CALL ansar_add_column('sales_credit_note_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 8/16 sales_debit_note_items
CALL ansar_add_column('sales_debit_note_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 9/16 purchase_request_items
CALL ansar_add_column('purchase_request_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 10/16 purchase_order_items
CALL ansar_add_column('purchase_order_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 11/16 goods_received_note_items
CALL ansar_add_column('goods_received_note_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 12/16 supplier_invoice_items
CALL ansar_add_column('supplier_invoice_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 13/16 cash_purchase_items
CALL ansar_add_column('cash_purchase_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 14/16 supplier_credit_note_items
CALL ansar_add_column('supplier_credit_note_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 15/16 supplier_debit_note_items
CALL ansar_add_column('supplier_debit_note_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
-- 16/16 sales_pre_quotation_items
-- Operations keeps this one. It is a transfer SOURCE, so the column has to exist.
CALL ansar_add_column('sales_pre_quotation_items', 'line_type',
  "ENUM('item','heading','subtotal') NOT NULL DEFAULT 'item'")
-- >>>
DROP PROCEDURE IF EXISTS ansar_add_column
-- >>>
-- Verification
--
-- Expect: line_type_columns 16, types 'enum(''item'',''heading'',''subtotal'')', nullable_default
-- 'NO/item'. A figure below 16 means a table was missed, and the document that reads it would answer
-- ER_BAD_FIELD_ERROR on its first load — the handler SELECTs `i.line_type`, so the register 500s
-- before it draws a row. More than one distinct type or default means a table was widened by hand.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'line_type'
      AND TABLE_NAME IN ('sales_quotation_items', 'sales_order_items', 'delivery_order_items', 'proforma_invoice_items', 'sales_invoice_items', 'cash_sales_items', 'sales_credit_note_items', 'sales_debit_note_items', 'purchase_request_items', 'purchase_order_items', 'goods_received_note_items', 'supplier_invoice_items', 'cash_purchase_items', 'supplier_credit_note_items', 'supplier_debit_note_items', 'sales_pre_quotation_items')) AS line_type_columns,
  (SELECT GROUP_CONCAT(DISTINCT COLUMN_TYPE) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'line_type'
      AND TABLE_NAME IN ('sales_quotation_items', 'sales_order_items', 'delivery_order_items', 'proforma_invoice_items', 'sales_invoice_items', 'cash_sales_items', 'sales_credit_note_items', 'sales_debit_note_items', 'purchase_request_items', 'purchase_order_items', 'goods_received_note_items', 'supplier_invoice_items', 'cash_purchase_items', 'supplier_credit_note_items', 'supplier_debit_note_items', 'sales_pre_quotation_items')) AS types,
  (SELECT GROUP_CONCAT(DISTINCT CONCAT(IS_NULLABLE, '/', COLUMN_DEFAULT)) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'line_type'
      AND TABLE_NAME IN ('sales_quotation_items', 'sales_order_items', 'delivery_order_items', 'proforma_invoice_items', 'sales_invoice_items', 'cash_sales_items', 'sales_credit_note_items', 'sales_debit_note_items', 'purchase_request_items', 'purchase_order_items', 'goods_received_note_items', 'supplier_invoice_items', 'cash_purchase_items', 'supplier_credit_note_items', 'supplier_debit_note_items', 'sales_pre_quotation_items')) AS nullable_default
