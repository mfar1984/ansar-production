-- ============================================================================
-- MARKET PLACE: PRODUCT LISTINGS
--
-- Run with:  node scripts/run-sql.js database/market_place_products.sql
--
-- ── WHAT THIS IS FOR ──
--
-- The company holds surplus and second-hand equipment it wants to sell. The sidebar
-- entry has existed as `soon` since the group was built, with this description:
--
--     "Product listings. Planned: one listing over many identical held-for-sale
--      assets, so 87 identical cables are sold as one product rather than 87 of them."
--
-- That sentence is the whole design. ONE listing, MANY units, and each unit is a
-- specific asset - because when it eventually sells, the disposal entry built in
-- `asset_disposal_accounting.sql` has to name the exact unit that left.
--
-- ── TWO TABLES, AND WHY NOT ONE ──
--
-- A single table with a `quantity` column would be simpler and wrong. The asset
-- register holds 324 individually identified units: each has its own `asset_no`, its
-- own purchase cost, its own book value and its own accumulated depreciation. Selling
-- "3 of them" does not say WHICH three, and the disposal journal needs to know: three
-- identical laptops bought in different years remove three different amounts from the
-- Balance Sheet.
--
-- So `market_place_products` is what the buyer reads, and
-- `market_place_product_units` is what the ledger needs.
--
-- ── QUANTITY IS DERIVED, NEVER STORED ──
--
-- `COUNT(*)` over the unit rows. A stored count is a second authority that has to be
-- kept in step with the first, and `petty_cash.sql` already records what that costs
-- here: "Two writers keeping a running total in step is how `leave_balances.pending_days`
-- reached -2.0 on live data."
--
-- Availability is derived too, and for a reason that is not hypothetical: somebody can
-- write an asset off on the Disposal screen while it is sitting on a listing. The
-- available count excludes any unit whose asset has since been disposed of, so the
-- listing stops offering something that is gone without anybody having to remember to
-- edit it.
--
-- ── `asset_id` IS NOT NULL, AND THAT IS A CHANGE OF MIND WORTH RECORDING ──
--
-- The plan was to make it nullable from the start so non-asset stock - surplus bought
-- for a project and expensed rather than capitalised - could arrive without a data
-- migration. That argument is weaker than it looks.
--
-- A unit row with no asset AND no cost is meaningless, and nullable permits it at the
-- schema level. Everything that can be listed TODAY is an asset, so NOT NULL is a real
-- guard that holds right now. And relaxing it later is `MODIFY COLUMN ... NULL`, which
-- is additive and touches no row.
--
-- When non-asset stock does arrive it needs TWO things: that MODIFY, and a `unit_cost`
-- column, because the accounting differs - selling a capitalised asset is a disposal,
-- while selling something already expensed is other income. Adding an unused
-- `unit_cost` now would be a column nothing writes.
--
-- ── `UNIQUE (asset_id)`: ONE ASSET, ONE LISTING ──
--
-- The same constraint `asset_disposals` uses, for the same reason: without it the same
-- laptop could sit on two listings and be sold twice. The database enforces it rather
-- than the endpoint.
--
-- A unit can be REMOVED from a listing, which frees the asset to be listed again. That
-- is correct while nothing has sold. It stops being correct the moment orders exist,
-- and the Order step has to refuse removing a unit that a buyer has paid for.
--
-- ── THE TAX CODE IS A CODE, NOT A BOOLEAN ──
--
-- `tax_id` names a row on `accounting_tax`, restricted to `tax_type = 'Supply'` and
-- `status = 'active'`. A boolean `taxable` would have been shorter and could not carry
-- what an e-Invoice needs: LHDN requires a tax TYPE code on every line, and
-- `accounting_tax.tax_type_code` is where it lives.
--
-- THE DEFAULT IS `Sales Tax Exempted`, LHDN code `E`, and the reasoning matters because
-- it is easy to get backwards:
--
--   ANSAR's registration W24-2104-32000006 is SERVICE tax. Selling a used laptop is a
--   supply of GOODS, not a service, so service tax does not apply to it. Sales tax is
--   charged at the MANUFACTURER or IMPORTER level and ANSAR is neither. So the expected
--   answer is no tax at all.
--
--   `Service Tax Exempted` carries LHDN `02` - service tax, at a zero rate. That would
--   describe this supply as a service that happens to be exempt, which it is not.
--   `Sales Tax Exempted` carries LHDN `E`, an exemption on goods, which is what this is.
--
-- The DEFAULT is a default. Whether a given item is taxable is the company's tax
-- agent's answer, not this migration's, and the screen lets any active Supply code be
-- chosen.
--
-- ── `item_condition`, NOT `condition` ──
--
-- `CONDITION` is a reserved word in MySQL. A column called `condition` works only while
-- every statement remembers to quote it, and the one that forgets fails with a syntax
-- error that points at the wrong place.
--
-- ── NO DOCUMENT NUMBER ──
--
-- A product listing is MASTER DATA, not a document. `accounting_document_numbers`
-- issues numbers to things that are posted, printed or sent - invoices, receipts,
-- vouchers - and a listing is none of those. The title is what a reader recognises it
-- by. An order, when that step lands, IS a document and will take a number.
--
-- ── PERMISSIONS: THREE ADDED, ONE ALREADY THERE ──
--
-- `market_place_permissions.sql` seeded `market_place_products_view` and deliberately
-- nothing else, recording why: "Market Place has no endpoints. Seeding
-- `market_place_orders_delete` today would be a guess, and a wrong guess is worse than
-- a missing one: it puts a checkbox in the Roles matrix that grants nothing."
--
-- The endpoint exists now, and it answers GET, POST, PUT and DELETE. So `create`,
-- `edit` and `delete` are added and the action set is READ OFF THE ENDPOINT rather than
-- guessed - the rule `asset_page_permissions.sql` states.
--
-- No `approve` and no `reject`. Listing something for sale is not an application and
-- has no chain; the other Market Place pages are still `soon` and will add their own
-- actions when their endpoints exist.
--
-- ── IDEMPOTENT ──
--
-- `CREATE TABLE IF NOT EXISTS`, `INSERT IGNORE` against the unique key on
-- `permissions.name`, and `INSERT IGNORE` against `role_permissions`'s primary key.
--
-- Column types were READ from `information_schema`. `assets.id` is `int unsigned` and
-- `accounting_tax.id` is a plain signed `int`, so `asset_id` is UNSIGNED and `tax_id`
-- is not - a mismatch fails the foreign key with errno 150 and no explanation of which
-- side was wrong.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. The listing: what a buyer reads ──
CREATE TABLE IF NOT EXISTS `market_place_products` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title`       VARCHAR(200) NOT NULL
                COMMENT 'What it is called on the listing. Not unique: a closed listing and a new one may share a name.',
  `summary`     VARCHAR(500) DEFAULT NULL
                COMMENT 'One line for the listing card.',
  `description` TEXT         DEFAULT NULL
                COMMENT 'The long copy.',

  -- `item_condition`, because CONDITION is reserved in MySQL. See the header.
  --
  -- Three values and they are the two things the company actually sells plus the one in
  -- between: `new` is surplus that was never used, `used` is second-hand, `refurbished`
  -- is second-hand that was repaired first and is worth more than plain used.
  `item_condition` ENUM('new', 'used', 'refurbished') NOT NULL DEFAULT 'used',

  `unit_price`  DECIMAL(15,2) NOT NULL DEFAULT 0.00
                COMMENT 'Per unit, in MYR. Every unit under one listing is the same price - that is what makes it one listing.',

  -- `accounting_tax.id`, Supply and active. Signed INT to match that table's key.
  `tax_id`      INT          DEFAULT NULL
                COMMENT 'accounting_tax.id. NULL is refused by the endpoint on a listed product; the e-Invoice needs a tax type code.',

  -- `draft` while it is being prepared, `listed` when it is public, `closed` when it is
  -- finished. Withdrawing something goes back to `draft`.
  --
  -- There is deliberately NO `sold_out`: that is derived from the available unit count,
  -- and a stored flag would be a second authority to keep in step.
  `status`      ENUM('draft', 'listed', 'closed') NOT NULL DEFAULT 'draft',

  `created_by`  VARCHAR(150) DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_mpp_status` (`status`),
  KEY `idx_mpp_title` (`title`),
  CONSTRAINT `fk_mpp_tax` FOREIGN KEY (`tax_id`)
    REFERENCES `accounting_tax` (`id`) ON DELETE RESTRICT
-- ROW_FORMAT is DECLARED, not left to the server. `sql-portability.test.js` asserts every
-- table states it: `mysqldump` writes only what a table DECLARES, so one that inherited the
-- format from `innodb_default_row_format` exports without it and takes the IMPORTING
-- server's default instead. The `text` and `varchar(500)` columns here need Dynamic to
-- store off-page.
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 2. The units: what the ledger needs ──
CREATE TABLE IF NOT EXISTS `market_place_product_units` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` INT UNSIGNED NOT NULL,

  -- The exact unit on offer. NOT NULL today - see the header for what changes when
  -- non-asset stock arrives, and why nullable was rejected for now.
  `asset_id`   INT UNSIGNED NOT NULL
               COMMENT 'assets.id. The disposal journal needs the exact unit, because identical items bought in different years carry different book values.',

  `added_by`   VARCHAR(150) DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- ONE ASSET, ONE LISTING, enforced by the database. Without it the same laptop could
  -- sit on two listings and be sold twice. The same constraint `asset_disposals` uses.
  UNIQUE KEY `uq_mppu_asset` (`asset_id`),
  KEY `idx_mppu_product` (`product_id`),
  -- CASCADE: the link is part of the listing and means nothing without it. The ASSET is
  -- untouched - deleting a listing must never disturb the register.
  CONSTRAINT `fk_mppu_product` FOREIGN KEY (`product_id`)
    REFERENCES `market_place_products` (`id`) ON DELETE CASCADE,
  -- RESTRICT: an asset on a listing must not be deletable out from under it.
  CONSTRAINT `fk_mppu_asset` FOREIGN KEY (`asset_id`)
    REFERENCES `assets` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 3. The three actions the endpoint answers ──
--
-- `category` is `operations`, matching the sidebar section the group lives in.
-- `market_place_permissions.sql` records why: a new `market_place` category would name a
-- matrix heading that no sidebar section carries.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_products', 'create', 'market_place_products_create', 'Create a Market Place product listing',       'operations'),
  ('market_place_products', 'edit',   'market_place_products_edit',   'Change a listing, and add or remove its units', 'operations'),
  ('market_place_products', 'delete', 'market_place_products_delete', 'Delete a Market Place product listing',        'operations')

-- >>>
-- ── 4. Grant them to Super Admin ──
--
-- MANDATORY, not a convenience. The SERVER has a Super Admin bypass in `api-guard.ts`,
-- but the CLIENT does not: `usePermissions` reads `/api/admin/user-permissions`, which
-- joins through `role_permissions` and returns nothing else. Without this grant the
-- buttons are INVISIBLE to Super Admin while the endpoints behind them would have
-- answered - which reads as a broken screen, not as a permission problem.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'market_place_products'

-- >>>
-- ── 5. Report what landed ──
--
-- `listable_now` is the figure that says whether the screen has anything to work with.
-- Measured before this ran: 102 assets are `in_store`, 217 are `in_use` and 4 are
-- `under_repair`, with NONE `retired`. Only the first group can be listed, because
-- `in_use` is deployed and `under_repair` is away - neither is in the company's hands to
-- ship. Recovering an asset changes its status and makes it listable.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products')        AS products_table,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_product_units')   AS units_table,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'market_place_products')       AS product_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE p.`module` = 'market_place_products'
      AND LOWER(TRIM(r.`name`)) = 'super admin')                                     AS granted_to_super,
  (SELECT COUNT(*) FROM `accounting_tax`
    WHERE `tax_code` = 'Sales Tax Exempted' AND `tax_type` = 'Supply' AND `status` = 'active')
                                                                                     AS default_tax_code,
  (SELECT COUNT(*) FROM `assets` a
    WHERE a.`ownership` = 'ansar'
      AND a.`status` IN ('in_store', 'retired')
      AND NOT EXISTS (SELECT 1 FROM `asset_disposals` d WHERE d.`asset_id` = a.`id`)) AS listable_now
