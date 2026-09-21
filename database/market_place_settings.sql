-- MARKET PLACE: SHOP SETTINGS, AND THE CATEGORY ICON
--
-- Run with:  node scripts/run-sql.js database/market_place_settings.sql
--
-- ── RUN `market_place_catalogue.sql` FIRST ──
--
-- This file ALTERs `market_place_categories`, which that one creates. The ALTER is
-- guarded on the table existing, so running this first does no damage - it simply
-- skips, and statement 11 reports `categories_table` as 0 so the skip is visible
-- rather than silent. Apply the catalogue migration and run this again.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT THIS IS FOR
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Operations > Market Place > Settings. Three tabs:
--
--   Storefront   whether the shop is open, and the wording at the top of it
--   Inventory    what happens when something runs low, and how much a visitor is told
--   Categories   how the shop is grouped, which is `market_place_categories`
--
-- ══════════════════════════════════════════════════════════════════════════════
-- SIX OF THE SEVEN SETTINGS ARE READ BY NOTHING TODAY, AND THAT IS SAID ON SCREEN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- There is no public Shop page. Checked rather than assumed: `src/app` holds
-- `about-us`, `business`, `career`, `client`, `news`, `resources` and the rest, and
-- no `shop`, `store`, `storefront` or `product` route; `src/pages` holds only `api`.
--
-- So `is_open`, `page_heading`, `intro_text`, `products_per_page`, `how_to_order`,
-- `hide_sold_out` and `show_stock_left` are stored and waiting for a consumer.
-- `default_low_stock` is the exception - the product form reads it when creating,
-- which is why it is the one the screen calls live.
--
-- That is deliberate and it is the pattern the Market Place group already follows:
-- the vocabulary and the permissions ship before the screen that consumes them. What
-- is NOT acceptable is a toggle that implies it published something, so the
-- Storefront tab carries a banner saying plainly that nothing outside the admin panel
-- reads these yet.
--
-- ── `is_open` DEFAULTS TO 0, WHICH IS CLOSED ──
--
-- A shop that opens itself the moment its settings row appears is a shop that went
-- public without anybody deciding to. The operator turns it on.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT IS DELIBERATELY NOT HERE
-- ══════════════════════════════════════════════════════════════════════════════
--
-- ── NO PAYMENT CREDENTIALS ──
--
-- CHIP is already configurable at Settings > Integration > Payments: the
-- `integrations` row carries `payments_provider` (whose enum includes `chip`),
-- `payments_api_key`, `payments_secret_key`, `payments_collection_id`,
-- `payments_callback_url` and `payments_sandbox_mode`, and `src/lib/integration-test.ts`
-- verifies them against `https://gate.chip-in.asia/api/v1`.
--
-- The sidebar tooltip for this page already drew that boundary - "Courier and payment
-- credentials stay in Integration" - and it is the right one: a gateway is an account
-- the company holds, not a property of one shop. Copying the keys here would be a
-- second place for them to drift and a second place for them to leak.
--
-- Nothing calls that gateway yet. A payment needs an order, and Market Place > Order
-- does not exist.
--
-- ── NO SHIPPING SETTINGS, AND THE REASON IS NOT "NO CHECKOUT" ──
--
-- There is NO courier integration in this application. Searched for `easyparcel`,
-- `easy.parcel`, `courier` and `shipping` across `src`, `database`, `tests`, `deploy`
-- and `public/assets`: nothing. So there is no rate source to configure, and a
-- postage band typed in by hand would be a number nothing could honour.
--
-- `market_place_products` already carries `weight_kg` and the three dimensions, which
-- is what a courier rate is banded on when there is one. The product form says so.
--
-- ── NO TAX CODE, AND IT IS WAITING ON ONE ANSWER ──
--
-- `market_place_catalogue.sql` recorded the reasoning and it has not changed: ANSAR's
-- registration W24-2104-32000006 is SERVICE tax; selling goods is not a service, and
-- sales tax is charged at the manufacturer or importer level, which ANSAR is not. So
-- the expected answer is NO TAX, on code `Sales Tax Exempted` / LHDN `E` - an
-- exemption on GOODS - and NOT `Service Tax Exempted` / LHDN `02`, which would
-- describe the supply as an exempt service.
--
-- "Expected" is not "decided". The company's tax agent has not answered, and a code
-- stored today would be a guess sitting in a field that looks authoritative. There is
-- also nothing to apply it to until an order exists. So the column is not created and
-- the Storefront tab says what it is waiting for.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE CATEGORY ICON
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `market_place_categories` was created with `name`, `slug`, `sort_order` and
-- `is_active`. The approved Categories tab shows an ICON column, so one is added.
--
-- It is ADMIN DATA rather than page content for the reason `tender_categories.sql`
-- already records: the PUBLIC listing shows one icon per category, so keeping it
-- beside the name is what stops the website holding a second, drifting copy of the
-- same list. `asset_categories` carries one on the same argument.
--
-- A Bootstrap Icons class name, e.g. `bi-award`. Not an uploaded image: a 16px glyph
-- that has to survive a colour change is a font, and an upload would need a size, a
-- type check and a delete path for something the design draws in one colour.
--
-- Default `bi-tag`, which `ADD COLUMN` also writes into the existing `Merchandise`
-- row - so no backfill statement is needed and none is written.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE PERMISSIONS: TWO MODULES, AND THE ACTION SETS ARE READ OFF THE ENDPOINTS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `market_place_settings`    view, edit          market-place-settings.ts answers
--                                               GET and PUT. There is nothing to
--                                               create or delete: it is one row that
--                                               `INSERT IGNORE` below guarantees.
--
-- `market_place_categories`  view, create,       market-place-categories.ts answers
--                            edit, delete        GET, POST, PUT and DELETE.
--
-- ── WHY CATEGORIES GETS ITS OWN MODULE RATHER THAN BORROWING `_settings_edit` ──
--
-- Every sibling categories screen has its own: `tender_categories`,
-- `asset_categories`, `asset_repair_categories`, `procurement_categories`,
-- `expense_categories`. The reason is recorded on the Checkout leaf in
-- `AdminSidebar.tsx`: one permission that opened eight screens meant a counter clerk
-- could not be given the checkout desk without also being given the stock take.
--
-- The same split applies here. Closing the shop and adding an aisle are not one
-- authority - `is_open` takes the whole storefront offline, while a category only
-- changes how it is grouped. A role can now hold one without the other, and the tab
-- ribbon hides the tab it cannot read.
--
-- `market_place_settings_view` ALREADY EXISTS - `market_place_permissions.sql` seeded
-- it for the menu entry, and `market_place_catalogue.sql` left it as view-only
-- because the page had no endpoint. It has one now, so `edit` joins it. `INSERT
-- IGNORE` against the unique key on `permissions.name`, so the existing row is
-- untouched.
--
-- The category is `operations`, which is a CLOSED list in
-- `src/lib/permission-modules.ts` cross-checked both ways by
-- `tests/sql/roles-endpoints.sql.test.js`. A permission whose category names no
-- sidebar section cannot be granted through the Roles matrix at all.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `CREATE TABLE IF NOT EXISTS`, `INSERT IGNORE`, and a guarded `ALTER`. Production
-- runs this by hand and a hand runs things twice.
--
-- The guard goes through a PREPARE rather than a bare `IF()`, and that is not
-- stylistic. `market_place_catalogue.sql` records the trap that cost a failed second
-- run: MySQL RESOLVES BOTH BRANCHES of `IF()` at prepare time, so an `IF()` naming a
-- column or table in the branch that will NOT be taken still fails. An `ALTER` is
-- worse than a `SELECT` here, because it cannot appear in either branch of an
-- expression at all - it has to be a string handed to `PREPARE`.
--
-- NO CHECK CONSTRAINTS. `products_per_page` between 4 and 48 and the two stock
-- numbers are validated in the endpoint, which is the only place that can put a
-- sentence on the screen. MySQL 8 enforces a CHECK and MySQL 5.7 silently ignores
-- one, so a CHECK would be a rule that holds on one server and not another - and
-- nothing else in this schema uses them.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. Is the categories table there, and does it already have the icon ──
SET @mpc_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_categories'
)

-- >>>
-- `information_schema.COLUMNS` answers 0 for a table that does not exist, so this
-- needs no guard of its own.
SET @mpc_icon := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_categories'
     AND COLUMN_NAME = 'icon'
)

-- >>>
-- ── 2. Add it, once ──
--
-- `AFTER name` so it reads in the order the screen shows it. `NOT NULL DEFAULT` means
-- the existing `Merchandise` row is filled by this statement.
SET @sql := IF(@mpc_table = 1 AND @mpc_icon = 0,
  'ALTER TABLE `market_place_categories`
     ADD COLUMN `icon` VARCHAR(60) NOT NULL DEFAULT ''bi-tag'' AFTER `name`',
  'SELECT ''market_place_categories.icon: already present, or the table is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3. The shop settings ──
--
-- ONE ROW, AT id = 1. The same shape as `system_settings` and
-- `accounting_preferences`: one column per setting, not a key/value table.
--
-- There is no key/value settings table anywhere in this codebase, and the reason a
-- wide row wins here is types. `products_per_page` is a number the endpoint range
-- checks and `is_open` is a boolean; in a key/value table both would be VARCHAR and
-- every reader would parse them again, differently.
--
-- NOT added to `system_settings`. That row is the SITE - site name, company TIN,
-- timezone, branding, backup - and `getSettingsRow()` returns `SELECT *`, so a shop
-- setting living there is one careless reuse away from travelling with the company's
-- tax identity. Accounting made the same call with `accounting_preferences`.
CREATE TABLE IF NOT EXISTS `market_place_settings` (
  -- Always 1. `TINYINT` rather than `INT` because a second row is not a thing that
  -- should look possible, and the endpoint only ever writes `WHERE id = 1`.
  `id` TINYINT UNSIGNED NOT NULL DEFAULT 1,

  -- ── Storefront ──

  -- Off means the Shop page says the shop is not open yet instead of listing
  -- products. Default CLOSED: see the header.
  `is_open`           TINYINT(1)   NOT NULL DEFAULT 0,
  -- The large heading on the Shop page. NOT NULL, and the endpoint refuses a blank
  -- with a sentence rather than letting `coerce()` turn '' into NULL and hit this
  -- constraint as a 500.
  `page_heading`      VARCHAR(120) NOT NULL DEFAULT 'Shop',
  -- One or two lines under the heading. NULL is a real answer and means none.
  `intro_text`        VARCHAR(300)     NULL DEFAULT NULL,
  -- Between 4 and 48, enforced in the endpoint.
  `products_per_page` SMALLINT UNSIGNED NOT NULL DEFAULT 12,
  -- Shown on every product page while there is no checkout. TEXT rather than VARCHAR:
  -- it is a paragraph with payment instructions in it, not a label.
  `how_to_order`      TEXT             NULL DEFAULT NULL,

  -- ── Inventory ──

  -- On removes a sold-out product from the shop entirely. Off leaves it listed with a
  -- Sold Out badge, which keeps the page populated and tells a returning buyer the
  -- item is real. Default OFF, because removing a product is the answer that loses
  -- information.
  `hide_sold_out`     TINYINT(1)   NOT NULL DEFAULT 0,
  -- On shows "4 left" when stock is low. Off publishes no stock level at all.
  `show_stock_left`   TINYINT(1)   NOT NULL DEFAULT 1,
  -- Filled into a NEW product's low stock field. Changing it does not alter products
  -- that already exist - it is a default, not a rule, which is why it is read at the
  -- moment a product form opens and never afterwards.
  --
  -- THE ONE SETTING HERE THAT SOMETHING ALREADY READS. `market-place-products.ts`
  -- returns it as `defaults.low_stock_threshold` and the product form uses it instead
  -- of a hardcoded 5.
  `default_low_stock` SMALLINT UNSIGNED NOT NULL DEFAULT 5,

  -- ── Who last touched it ──
  --
  -- The USERNAME, matching `market_place_products.created_by`, rather than the numeric
  -- `admin_id` that `system_settings.updated_by` holds. Within Market Place one form
  -- of identity beats two, and the audit log carries the id anyway.
  `updated_by` VARCHAR(100) NULL DEFAULT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`)
-- ROW_FORMAT is DECLARED. `sql-portability.test.js` asserts every table states it,
-- because `mysqldump` writes only what a table declares and one that inherited the
-- format takes the IMPORTING server's default.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 4. The row itself ──
--
-- Created here rather than lazily by the endpoint. `getSettingsRow()` creates
-- `system_settings` on first read, which works but means the first GET of a fresh
-- install performs a write - and a GET that writes is a GET that fails behind a
-- read-only replica. Every default above is in the DDL, so this is the whole row.
INSERT IGNORE INTO `market_place_settings` (`id`) VALUES (1)

-- >>>
-- ── 5. The permissions ──
--
-- `market_place_settings_view` is already seeded; `INSERT IGNORE` leaves it alone and
-- adds `edit`. The four category actions are new.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_settings',   'view',   'market_place_settings_view',     'Read the Market Place shop settings',    'operations'),
  ('market_place_settings',   'edit',   'market_place_settings_edit',     'Change the Market Place shop settings',  'operations'),
  ('market_place_categories', 'view',   'market_place_categories_view',   'Read the Market Place shop categories',  'operations'),
  ('market_place_categories', 'create', 'market_place_categories_create', 'Create a Market Place shop category',    'operations'),
  ('market_place_categories', 'edit',   'market_place_categories_edit',   'Change a Market Place shop category',    'operations'),
  ('market_place_categories', 'delete', 'market_place_categories_delete', 'Delete a Market Place shop category',    'operations')

-- >>>
-- ── 5a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `usePermissions` joins
-- through `role_permissions`, so an ungranted permission makes the tab and every
-- button INVISIBLE rather than denied - which reads as a broken screen.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('market_place_settings', 'market_place_categories')

-- >>>
-- ── 6. Report what landed ──
--
-- `categories_table` is the one to read on a first run. 0 means this file ran before
-- `market_place_catalogue.sql` and the icon column was skipped - apply that one and
-- run this again. Everything else here is already correct in that case.
SELECT
  @mpc_table                                                                AS categories_table,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_categories'
      AND COLUMN_NAME = 'icon')                                             AS category_icon_column,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_settings') AS settings_table,
  (SELECT COUNT(*) FROM `market_place_settings`)                            AS settings_rows,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'market_place_settings')                               AS settings_permissions,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'market_place_categories')                             AS category_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` IN ('market_place_settings', 'market_place_categories')) AS granted_to_super_admin
