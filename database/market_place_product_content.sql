-- ============================================================================
-- MARKET PLACE: TWO MORE CONTENT BLOCKS ON A PRODUCT
--
-- Run with:  node scripts/run-sql.js database/market_place_product_content.sql
--
-- ── WHY ──
--
-- The approved product page carries a Support card and a Warranty card, side by
-- side under the specification table. Nothing in this database held either.
--
-- `market_place_products` already has three one-item-per-line TEXT columns —
-- `key_highlights`, `specifications` and `included_items` — and
-- `market_place_catalogue.sql` records why they are columns rather than three child
-- tables: nothing queries an individual line, nothing sorts them independently of
-- their order on the page, and nothing joins to them. A table per bullet list would
-- be three joins and three more places to keep in step, to store text that is only
-- ever read whole.
--
-- These two are the same kind of text read the same way, so they follow the same
-- pattern. Two more columns, not two more tables.
--
-- ── WHAT WAS REFUSED, AND WHY IT IS WRITTEN DOWN ──
--
-- The reference design also shows a FIVE STAR RATING and tabs called `Performance`
-- and `Features`. None of them is added here.
--
--   RATING      There is no reviews table, no rating column and no row anywhere
--               saying a customer scored this product. Rendering five gold stars
--               would be inventing a claim about customer satisfaction on the
--               company's own public site. A rating is a reviews feature — a table,
--               a submission path and moderation — not a column and not a
--               decoration. When that lands it brings its own migration.
--
--   PERFORMANCE Nothing measures it. A column added now would be a second place to
--               type the same specifications, and the two would disagree.
--
--   FEATURES    `key_highlights` IS the feature list. A second column for the same
--               content is how the two come to contradict each other, and the page
--               would have to pick a winner.
--
-- ── IDEMPOTENT ──
--
-- Each column is added behind a guard on `information_schema.COLUMNS`, through
-- PREPARE, because a bare `ALTER TABLE ... ADD COLUMN` fails on a second run and a
-- bare `IF()` naming the column does not help — MySQL resolves BOTH branches of
-- `IF()` when it prepares the statement, which is the trap
-- `market_place_catalogue.sql` records costing it a failed second run.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. Is the table even here ──
--
-- Checked rather than assumed. A server that pulls this release without having run
-- `market_place_catalogue.sql` first has no table to alter, and an unguarded ALTER
-- would stop the run with `ER_NO_SUCH_TABLE` — which reads as this migration being
-- broken rather than as an earlier one being missing. The report at the bottom says
-- which it was.
SET @mpc_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
)

-- >>>
-- ── 2. Support ──
SET @mpc_support := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
     AND COLUMN_NAME = 'support_text'
)

-- >>>
-- Placed AFTER `included_items` so the five content columns sit together in
-- `DESCRIBE` and in a `mysqldump`. Column order carries no meaning to a query, and
-- it carries a lot to the next person reading the table.
SET @sql := IF(@mpc_table = 1 AND @mpc_support = 0,
  'ALTER TABLE `market_place_products`
     ADD COLUMN `support_text` TEXT DEFAULT NULL
       COMMENT ''One per line. The Support card on the product page.''
       AFTER `included_items`',
  'SELECT ''support_text: nothing to do'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3. Warranty ──
SET @mpc_warranty := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
     AND COLUMN_NAME = 'warranty_text'
)

-- >>>
SET @sql := IF(@mpc_table = 1 AND @mpc_warranty = 0,
  'ALTER TABLE `market_place_products`
     ADD COLUMN `warranty_text` TEXT DEFAULT NULL
       COMMENT ''One per line. The Warranty card on the product page.''
       AFTER `support_text`',
  'SELECT ''warranty_text: nothing to do'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 4. Report ──
--
-- `table_found` is the one to read first. 0 means `market_place_catalogue.sql` has
-- not been applied on this database, both columns were skipped, and the fix is to
-- run that file rather than this one again.
--
-- Both `*_present` must read 1 once the table exists. A guard on column EXISTENCE
-- alone would be satisfied on the first run and never checked again, so the shape is
-- confirmed here instead of trusted.
SELECT
  @mpc_table                                                                  AS table_found,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
      AND COLUMN_NAME = 'support_text')                                       AS support_text_present,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
      AND COLUMN_NAME = 'warranty_text')                                      AS warranty_text_present,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products')  AS product_columns,
  -- Both must be TEXT and both must be NULLABLE. A blank card is a legitimate
  -- answer — most products will carry neither — so NOT NULL would force an
  -- operator to type something for a block that should simply not render.
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
      AND COLUMN_NAME IN ('support_text', 'warranty_text')
      AND DATA_TYPE = 'text' AND IS_NULLABLE = 'YES')                         AS both_text_and_nullable
