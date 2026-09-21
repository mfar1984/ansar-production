-- ============================================================================
-- MARKET PLACE: THE PRODUCT CATALOGUE
--
-- Run with:  node scripts/run-sql.js database/market_place_catalogue.sql
--
-- ── THIS REPLACES `market_place_products.sql`, AND THE MODEL IS DIFFERENT ──
--
-- That migration built a listing that WRAPPED SPECIFIC ASSETS: one row per
-- physical unit in `market_place_product_units`, each pointing at an `assets` row,
-- so the disposal journal could name the exact item that left.
--
-- The approved design is a RETAIL CATALOGUE. It counts stock with an integer,
-- carries a SKU and a barcode, has options with their own price and stock, and
-- sells things like medals and shirts. `Stock Quantity` cannot say WHICH unit
-- shipped, so a table linking a listing to particular assets has nothing to hold.
--
-- So `market_place_product_units` is DROPPED, and the drop is GUARDED on the table
-- being empty. It holds 0 rows today, which is the only reason this is safe; if a
-- row ever appears the migration leaves both tables alone and the report says so,
-- rather than destroying data to make a schema tidy.
--
-- ── WHAT THIS COSTS, STATED RATHER THAN HIDDEN ──
--
-- The shop no longer feeds the disposal engine. Selling a surplus asset through it
-- would leave the asset still on the register, and it would have to be written off
-- separately on Operations > Asset Management > Disposal.
--
-- `asset_disposal_accounting.sql` is NOT wasted by this. It closes a gap that
-- exists whether or not the shop sells assets: 324 assets carrying RM243,324 of
-- accumulated depreciation, and before it there was no account anywhere to record
-- one leaving. It stays.
--
-- But it is NOT the engine for this shop. A merchandise sale is a real SALE - DR
-- bank, CR revenue, with `cost_per_item` going to cost of sales - which is the
-- `sales_invoices` path, not the disposal path. That is the Order step's decision
-- and is recorded here so it is not rediscovered.
--
-- ── NO PER-PRODUCT TAX CODE, AND WHY THE REASONING IS KEPT ──
--
-- The approved form has no tax field. `market_place_products.sql` had one, with
-- this reasoning, which the e-Invoice step will need:
--
--   ANSAR's registration W24-2104-32000006 is SERVICE tax. Selling goods is not a
--   service, and sales tax is charged at the manufacturer or importer level, which
--   ANSAR is not. So the expected answer is NO TAX, and the right code is
--   `Sales Tax Exempted`, LHDN `E` - an exemption on GOODS. NOT
--   `Service Tax Exempted`, which carries LHDN `02` and would describe the supply
--   as an exempt service, which it is not.
--
-- One shop-wide code belongs on Market Place > Settings when that page lands.
-- Whether a given item is taxable at all remains the company's tax agent's answer.
--
-- ── FIVE TABLES ──
--
--   market_place_products              the item
--   market_place_product_options       Size M, Size L - each with its own price,
--                                      weight, SKU and stock
--   market_place_product_images        up to 8 per product, ordered
--   market_place_categories            the shop filter
--   market_place_product_categories    many to many, because the form says "A
--                                      product can sit in more than one"
--
-- ── COLLECTION POINT: THE EVENT OPTION IS DISABLED IN THE UI, AND HERE IS WHY ──
--
-- `collection_source` accepts `event` and `manual`. Nothing in this database holds
-- an event: there is no `events`, `calendar`, `booking` or `venue` table and no
-- `event_date` column anywhere - checked, not assumed. So the form renders that
-- radio DISABLED with a tooltip, which is the rule for a control whose backing does
-- not exist. A clickable dead option is how Activity Logs came to look broken.
--
-- The column keeps both values so the day an events module lands, the change is a
-- picker in the form rather than a migration.
--
-- ── ONE-PER-LINE TEXT, NOT A CHILD TABLE ──
--
-- `key_highlights`, `specifications` and `included_items` are TEXT holding one item
-- per line, which is what the form collects and what the product page renders.
--
-- Three child tables were considered and refused: nothing queries an individual
-- highlight, nothing sorts them independently of their order in the box, and
-- nothing joins to them. A table per bullet list would be three joins and three
-- more places to keep in step, to store text that is only ever read whole.
--
-- ── IDEMPOTENT ──
--
-- `CREATE TABLE IF NOT EXISTS` for the four new tables. The products table is
-- REBUILT, so it is dropped and recreated under the same emptiness guard - a second
-- run finds the new shape already there and the guard skips it.
--
-- Column types were READ from `information_schema`. `accounting_tax.id` is a signed
-- `int` and `assets.id` is `int unsigned`; nothing here references either, so the
-- errno 150 trap those caused does not apply.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. IS THERE ANYTHING TO REBUILD, AND IS IT SAFE ──
--
-- ── A TRAP THAT COST A FAILED SECOND RUN, WRITTEN DOWN SO IT IS NOT REPEATED ──
--
-- The obvious way to read a row count from a table that may not exist is:
--
--     SET @n := IF((SELECT COUNT(*) FROM information_schema.TABLES
--                    WHERE TABLE_NAME = 'maybe_gone') = 0,
--                  0,
--                  (SELECT COUNT(*) FROM `maybe_gone`))
--
-- That does not work. MySQL RESOLVES BOTH BRANCHES of `IF()` when it prepares the
-- statement, so the table named in the branch that will not be taken still has to
-- exist. Once this migration drops the units table, that statement fails on the next
-- run with `ER_NO_SUCH_TABLE` - which is exactly what happened.
--
-- Nothing was destroyed, and only by luck: the failure left the variable NULL, and
-- `NULL = 0` is NULL rather than true, so the guard below fell to 0 and skipped the
-- drops. Accidental safety is not safety.
--
-- So a count over a possibly-absent table goes through a PREPARE, the same way every
-- guarded ALTER in this codebase does. `SELECT ... INTO @var` is allowed inside a
-- prepared statement on both MySQL 8 and MariaDB.
--
-- ── AND THE REBUILD ONLY HAPPENS ONCE ──
--
-- `@mp_new_shape` tests for the `slug` column, which only the NEW table has. Without
-- it every run would drop and recreate the products table, which is wasteful on an
-- empty database and would FAIL on a populated one - the options, images and
-- category-link tables all carry a foreign key to it.
SET @mp_products_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
)

-- >>>
SET @mp_new_shape := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
     AND COLUMN_NAME = 'slug'
)

-- >>>
SET @mp_units_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_product_units'
)

-- >>>
-- Row counts, each through a PREPARE so no absent table is ever named.
SET @sql := IF(@mp_products_table = 1,
  'SELECT COUNT(*) INTO @mp_rows FROM `market_place_products`',
  'SELECT 0 INTO @mp_rows')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
SET @sql := IF(@mp_units_table = 1,
  'SELECT COUNT(*) INTO @mp_units_rows FROM `market_place_product_units`',
  'SELECT 0 INTO @mp_units_rows')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 1a. The verdict ──
--
-- Rebuild only when the OLD shape is present and BOTH old tables are empty. A
-- database that already has the new shape is left alone, and one holding real rows is
-- left alone and reported.
SET @mp_rebuild := IF(@mp_new_shape = 0 AND @mp_rows = 0 AND @mp_units_rows = 0, 1, 0)

-- >>>
-- ── 2. Drop the asset-unit table. It has nothing to hold under the new model. ──
SET @sql := IF(@mp_rebuild = 1,
  'DROP TABLE IF EXISTS `market_place_product_units`',
  'SELECT ''nothing to rebuild: already the new shape, or a table holds rows'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3. Drop the old products table, under the same guard ──
--
-- Dropped rather than ALTERed: the new shape shares only `id`, `status` and a
-- price column with the old one, and a chain of twenty ADD COLUMNs plus three
-- DROP COLUMNs over an empty table is harder to read and no safer.
SET @sql := IF(@mp_rebuild = 1,
  'DROP TABLE IF EXISTS `market_place_products`',
  'SELECT ''market_place_products left as it is'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 4. The product ──
CREATE TABLE IF NOT EXISTS `market_place_products` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,

  -- ── Basic information ──
  `name` VARCHAR(200) NOT NULL
         COMMENT 'Shown as the card title in the shop.',
  -- Built from the name when left blank. UNIQUE because it is the public URL: two
  -- products sharing one would make one of them unreachable.
  `slug` VARCHAR(220) NOT NULL
         COMMENT 'The public URL. Derived from the name when not given.',
  `short_description` VARCHAR(500) DEFAULT NULL
         COMMENT 'One or two lines on the listing card.',
  `full_description`  TEXT         DEFAULT NULL
         COMMENT 'The detail on the product page. PLAIN TEXT: line breaks are kept, markup is shown rather than rendered.',

  -- ── Pricing ──
  `price` DECIMAL(15,2) NOT NULL DEFAULT 0.00
         COMMENT 'What a buyer pays. 0.00 means it is given away, which is allowed and deliberate.',
  -- The old price, shown struck through beside the current one. It has to be HIGHER
  -- than `price` or there is no saving to show, and the endpoint refuses otherwise.
  `compare_at_price` DECIMAL(15,2) DEFAULT NULL
         COMMENT 'Struck-through was-price. Must exceed price. NULL = not on offer.',
  `cost_per_item`    DECIMAL(15,2) DEFAULT NULL
         COMMENT 'What it costs the company, for margin. ADMIN ONLY - never sent to a storefront response.',

  -- ── Inventory ──
  -- UNIQUE but NULLABLE: MySQL allows many NULLs in a unique index, so a product
  -- without a SKU is fine and two products sharing one is not.
  `sku`     VARCHAR(64) DEFAULT NULL COMMENT 'The company''s own code. Unique across products.',
  `barcode` VARCHAR(64) DEFAULT NULL COMMENT 'EAN, UPC or similar.',
  -- Off means this product NEVER sells out, which is what anything made to order
  -- needs. `stock_quantity` is then ignored rather than decremented.
  `track_stock`         TINYINT(1) NOT NULL DEFAULT 1,
  `stock_quantity`      INT        NOT NULL DEFAULT 0
         COMMENT 'Ignored once the product has options, because each option carries its own.',
  `low_stock_threshold` INT        NOT NULL DEFAULT 5
         COMMENT 'The point at which the shop says how few are left and the admin list flags it.',

  -- ── Options ──
  -- The HEADING a buyer chooses under, e.g. `Size`, so the shop reads "Choose a
  -- Size" rather than "Choose an option". Required once an option row exists, which
  -- the endpoint enforces because the database cannot see across tables.
  `option_label` VARCHAR(60) DEFAULT NULL,

  -- ── What to say about it ──
  -- One item per line. See the header for why these are not three child tables.
  `key_highlights` TEXT DEFAULT NULL COMMENT 'One per line. Becomes the bullets on the product page.',
  `specifications` TEXT DEFAULT NULL COMMENT 'One `label: value` per line. Rendered as a table.',
  `included_items` TEXT DEFAULT NULL COMMENT 'One per line. What comes in the box.',

  -- ── How it reaches the buyer ──
  -- `online` posts it and charges postage from the courier rates. `offline` is
  -- collected in person: no postage, no courier, and the shipping fields below do
  -- not apply. The buyer is asked for an identity card, which is what the counter
  -- checks.
  `fulfilment` ENUM('online', 'offline') NOT NULL DEFAULT 'online',
  -- Only meaningful when `fulfilment = 'offline'`. `event` is accepted by the column
  -- and DISABLED in the form, because no events table exists - see the header.
  `collection_source`   ENUM('event', 'manual') NOT NULL DEFAULT 'manual',
  `collection_location` VARCHAR(300) DEFAULT NULL
         COMMENT 'Where the buyer turns up. Specific enough to find a hall, not just a city.',
  -- BOTH halves are needed: a date on its own is not something anybody can turn up
  -- for, so this is a DATETIME rather than a DATE plus a nullable time.
  `collection_at`       DATETIME     DEFAULT NULL,

  -- ── Shipping ──
  -- Stored to the gram, because postage brackets are decided on small differences.
  `weight_kg`  DECIMAL(10,3) DEFAULT NULL,
  -- All three or none: two out of three describes nothing a courier can price.
  `length_cm`  DECIMAL(10,2) DEFAULT NULL,
  `width_cm`   DECIMAL(10,2) DEFAULT NULL,
  `height_cm`  DECIMAL(10,2) DEFAULT NULL,

  -- ── Organisation ──
  -- Free text rather than references. A vendor here is a note to the buyer about who
  -- supplies the item, not a row in `vendors` - that register is for procurement and
  -- carries SSM numbers and CIDB grades, which a shop supplier need not have.
  `vendor` VARCHAR(150) DEFAULT NULL COMMENT 'Who supplies it. Admin only.',
  `brand`  VARCHAR(150) DEFAULT NULL COMMENT 'Shown on the product page when set.',

  -- ── Publishing ──
  -- `draft` keeps it out of the shop, `active` puts it in, `archived` takes it out
  -- again while keeping its history. Archived is NOT the same as deleted and not the
  -- same as draft: it says this was once sold and no longer is.
  `status`     ENUM('draft', 'active', 'archived') NOT NULL DEFAULT 'draft',
  `featured`   TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Featured products lead the shop.',
  `sort_order` INT        NOT NULL DEFAULT 0
         COMMENT 'Lower first, WITHIN the featured and unfeatured groups.',

  -- ── Search engines ──
  -- 70 and 180 are where Google cuts the title and the description. Both fall back
  -- to the name and the short description when empty, so leaving them blank is a
  -- valid answer rather than a gap.
  `seo_title`       VARCHAR(70)  DEFAULT NULL,
  `seo_description` VARCHAR(180) DEFAULT NULL,
  `seo_keywords`    VARCHAR(255) DEFAULT NULL
         COMMENT 'Comma separated. Search engines largely ignore these.',

  `created_by` VARCHAR(150) DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mpp_slug` (`slug`),
  UNIQUE KEY `uq_mpp_sku` (`sku`),
  -- `(status, featured, sort_order)` is the shop's own ordering, which is the hot
  -- path once a storefront exists.
  KEY `idx_mpp_shop` (`status`, `featured`, `sort_order`),
  KEY `idx_mpp_name` (`name`)
-- ROW_FORMAT is DECLARED. `sql-portability.test.js` asserts every table states it,
-- because `mysqldump` writes only what a table declares and one that inherited the
-- format takes the IMPORTING server's default - under COMPACT the long columns here
-- stop fitting InnoDB's 8126-byte row.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 5. The options ──
--
-- NULL price, weight and stock each mean "use the product's". That is why all three
-- are nullable rather than defaulted: 0.00 is a real price and 0 is a real stock
-- level, so neither could stand for "not set".
CREATE TABLE IF NOT EXISTS `market_place_product_options` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` INT UNSIGNED NOT NULL,
  `name`       VARCHAR(120) NOT NULL COMMENT 'What the buyer picks, e.g. Size M.',
  `sku`        VARCHAR(64)  DEFAULT NULL COMMENT 'Its own code. Not unique: a variant may share one.',
  `price`      DECIMAL(15,2) DEFAULT NULL COMMENT 'NULL = the product''s price.',
  `weight_kg`  DECIMAL(10,3) DEFAULT NULL COMMENT 'NULL = the product''s weight.',
  `stock_quantity` INT       DEFAULT NULL COMMENT 'NULL = unlimited, which is what the form shows.',
  `sort_order` INT          NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- One name per product, so two rows cannot both be `Size M`.
  UNIQUE KEY `uq_mppo_name` (`product_id`, `name`),
  KEY `idx_mppo_product` (`product_id`, `sort_order`),
  CONSTRAINT `fk_mppo_product` FOREIGN KEY (`product_id`)
    REFERENCES `market_place_products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 6. The pictures ──
--
-- The PATH only. Files live under `public/uploads/` and are written by the shared
-- upload handler in `src/lib/operations-upload.ts`, never by an endpoint reaching
-- into `public/` itself - the helpdesk doors record why: an unchecked `.html` or
-- `.svg` in a directory Next serves from our own origin is cross-site scripting
-- with our own domain behind it.
CREATE TABLE IF NOT EXISTS `market_place_product_images` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` INT UNSIGNED NOT NULL,
  `path`       VARCHAR(500) NOT NULL COMMENT 'As stored, e.g. /uploads/market-place/abc123.jpg',
  `original_name` VARCHAR(255) DEFAULT NULL,
  -- Lowest first. The FIRST picture is the one on the card, which is why the order
  -- matters and is not left to insertion time.
  `sort_order` INT          NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_mppi_product` (`product_id`, `sort_order`),
  CONSTRAINT `fk_mppi_product` FOREIGN KEY (`product_id`)
    REFERENCES `market_place_products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 7. The categories ──
CREATE TABLE IF NOT EXISTS `market_place_categories` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(120) NOT NULL,
  `slug`       VARCHAR(140) NOT NULL,
  `sort_order` INT        NOT NULL DEFAULT 0,
  `is_active`  TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mpc_name` (`name`),
  UNIQUE KEY `uq_mpc_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 8. Which categories a product sits in ──
--
-- A composite primary key rather than a surrogate `id`: the pair IS the identity,
-- and a surrogate would permit the same pair twice.
CREATE TABLE IF NOT EXISTS `market_place_product_categories` (
  `product_id`  INT UNSIGNED NOT NULL,
  `category_id` INT UNSIGNED NOT NULL,

  PRIMARY KEY (`product_id`, `category_id`),
  KEY `idx_mppc_category` (`category_id`),
  CONSTRAINT `fk_mppc_product` FOREIGN KEY (`product_id`)
    REFERENCES `market_place_products` (`id`) ON DELETE CASCADE,
  -- CASCADE both ways: removing a category removes the grouping, not the products.
  CONSTRAINT `fk_mppc_category` FOREIGN KEY (`category_id`)
    REFERENCES `market_place_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 9. One category to start with ──
--
-- The form shows a category list, and an empty list reads as a broken control
-- rather than as an empty one. `Merchandise` is the group the first products belong
-- to, and more are added from the Settings page when it lands.
INSERT IGNORE INTO `market_place_categories` (`name`, `slug`, `sort_order`, `is_active`) VALUES
  ('Merchandise', 'merchandise', 10, 1)

-- >>>
-- ── 10. The permissions, SEEDED HERE RATHER THAN CHECKED ──
--
-- `market_place_products.sql` seeded these, and this file now supersedes it. Carrying
-- only a CHECK would leave a real hole: a server that pulls this release WITHOUT
-- having run that migration first would get the tables and no permissions, and that
-- fails SILENTLY. The client's `hasPermission` is a plain `includes` with no Super
-- Admin shortcut, so a permission with no row evaluates false for everybody and every
-- button is simply absent, with nothing on screen explaining why.
--
-- `INSERT IGNORE` against the unique key on `permissions.name`, so running this after
-- the older migration changes nothing. That is what lets
-- `market_place_products.sql` leave the shipping list: one file now does the whole
-- job and the order no longer matters.
--
-- Still exactly FOUR actions, because the endpoint still answers exactly GET, POST,
-- PUT and DELETE. The action set is READ OFF THE ENDPOINT, not guessed - and
-- `market_place_orders`, `_tracking` and `_settings` keep `view` alone until they have
-- endpoints of their own.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_products', 'view',   'market_place_products_view',   'Read the Market Place product listings',  'operations'),
  ('market_place_products', 'create', 'market_place_products_create', 'Create a Market Place product',          'operations'),
  ('market_place_products', 'edit',   'market_place_products_edit',   'Change a Market Place product',          'operations'),
  ('market_place_products', 'delete', 'market_place_products_delete', 'Delete a Market Place product',          'operations')

-- >>>
-- ── 10a. Grant them to Super Admin ──
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'market_place_products'

-- >>>
-- ── 11. Report what landed ──
--
-- `rebuilt` is the one to read, and BOTH of its zero cases are fine:
--
--   1  the old shape was found empty and replaced
--   0  and `already_new_shape` is 1  -> a second run, nothing to do
--   0  and `already_new_shape` is 0  -> A TABLE HELD ROWS. Nothing destructive ran.
--      That needs a human, not a re-run.
SELECT
  @mp_rebuild                                                                    AS rebuilt,
  @mp_new_shape                                                                  AS already_new_shape,
  @mp_rows                                                                       AS product_rows_found,
  @mp_units_rows                                                                 AS units_rows_found,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN ('market_place_products', 'market_place_product_options',
                         'market_place_product_images', 'market_place_categories',
                         'market_place_product_categories'))                     AS tables_present,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_product_units')
                                                                                 AS units_table_gone_if_zero,
  (SELECT COUNT(*) FROM `market_place_categories`)                               AS categories,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products')    AS product_columns,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'market_place_products')   AS product_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE p.`module` = 'market_place_products'
      AND LOWER(TRIM(r.`name`)) = 'super admin')                                 AS granted_to_super
