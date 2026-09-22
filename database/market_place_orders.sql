-- MARKET PLACE: ORDER, SHIPMENT AND TRACKING
--
-- Run with:  node scripts/run-sql.js database/market_place_orders.sql
--
-- ── RUN `market_place_catalogue.sql` FIRST ──
--
-- The order lines carry foreign keys to `market_place_products` and
-- `market_place_product_options`, which that file creates. The keys are added through a
-- guarded PREPARE, so running this first does no damage - the tables are created without
-- them and statement 14 reports `product_fk` as 0, so the skip is visible rather than
-- silent. Apply the catalogue migration and run this again.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT THIS IS FOR
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Operations > Market Place > Order, and Operations > Market Place > Tracking.
--
--   market_place_orders          one order: who bought, what it came to, where it goes
--   market_place_order_items     the lines, with the catalogue values FROZEN
--   market_place_shipments       one courier booking at EasyParcel
--   market_place_tracking_events the courier's own event log, appended on refresh
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY THIS IS NOT `sales_orders`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `sales_orders` and `sales_order_items` already exist, and reusing them was checked
-- rather than dismissed. Its 32 columns are `customer_id`, `payment_term_id`,
-- `exchange_rate`, `source_quotation_id`, `converted_to_pi_id`, `converted_to_do_id`,
-- `converted_to_invoice_id`, `conversion_status`, `tax_mode`, `salesperson`. That is the
-- ERP's DOCUMENT CHAIN: quotation to sales order to delivery order to invoice, against a
-- customer who has agreed payment terms and a currency.
--
-- A shop buyer is none of those things. There is no `customers` row for them, no payment
-- term, no exchange rate, and a shop order is not a step in a conversion chain - it is the
-- whole transaction. Forcing one into `sales_orders` would leave twenty columns permanently
-- NULL and put a shop order into the conversion queue the accounting screens read.
--
-- `sales_order_items.product_id` also points at the ERP item master, not at
-- `market_place_products`. Two different product tables cannot share one line table
-- without a discriminator column that every existing reader would have to learn.
--
-- Both ERP tables hold 0 rows today, so nothing was migrated and nothing was lost.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `fulfilment` IS COPIED ONTO THE ORDER, NOT JOINED FROM THE PRODUCT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- This is the column the whole Order screen forks on: `online` prices postage from
-- EasyParcel and books a courier, `offline` charges no postage and is confirmed as a
-- handover at a counter.
--
-- `market_place_products.fulfilment` can be EDITED after the order exists. An operator
-- switching a product from posted to collected would silently rewrite the history of every
-- order already placed against it - orders that really did go by courier would start
-- claiming they were collected, and their shipment rows would contradict them.
--
-- So it is frozen here at creation, the same discipline the line snapshots below follow.
-- An order is a record of what happened, and a record that changes when the catalogue
-- changes is not a record.
--
-- A MIXED order is refused by the endpoint, not by the schema: one order cannot hold both
-- an `online` and an `offline` product, because there is one address and one handover for
-- the whole order. MySQL cannot see across tables to enforce it, so the endpoint does, and
-- it says so in a sentence.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- FOUR ORDER STATES, AND WHY NOT MORE
-- ══════════════════════════════════════════════════════════════════════════════
--
--   pending    created; nothing has been sent and nobody has collected
--   shipped    ONLINE ONLY. A shipment exists at EasyParcel
--   completed  the buyer has it
--   cancelled  it is not happening
--
-- ── THERE IS NO SEPARATE `delivered` AND `collected` ──
--
-- Two terminal states, one per fulfilment route, was the first draft. It is wrong for the
-- reason this schema keeps rejecting elsewhere: `fulfilment` ALREADY says which way the
-- order reached the buyer, so encoding it a second time in `status` creates two authorities
-- that can disagree. A report that wants couriered deliveries filters
-- `fulfilment = 'online'`; one that wants completions filters `status = 'completed'` and
-- cannot half-miss by forgetting the other name.
--
-- ── THERE IS NO `processing` OR `packing` ──
--
-- Nothing would set it. An offline order goes pending to completed when somebody presses
-- Confirm Receipt; an online one goes pending to shipped when the courier is booked. A
-- state with no transition into it is a dead entry in a filter.
--
-- ── THE COURIER'S OWN STATUS IS NOT HERE ──
--
-- EasyParcel reports nine codes (0 Cancel, 2 To Be Collected, 3 Collected, 4 In Transit,
-- 5 Delivered, 6 Returned, 7 Schedule In Arrangement, 8 On Hold, 11 Drop Off). Those live
-- on `market_place_shipments.shipment_status_code`, because they describe the PARCEL and a
-- parcel is not an order - one order can be booked, cancelled and rebooked.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- PAYMENT: TWO COLUMNS, AND WHY THEY EARN THEIR PLACE
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `payment_status` and `paid_at`, and nothing else.
--
-- `market_place_settings.how_to_order` already exists and its own comment describes it as
-- "a paragraph with payment instructions in it" - so the approved design already assumes
-- the buyer pays by instruction, typically a transfer, and that SOMEBODY has to record that
-- the money arrived. Without these two columns an operator cannot tell a paid order from an
-- unpaid one, and Confirm Receipt and Book Courier would be pressed on orders nobody paid
-- for. A free-text note would carry the same fact in a form nothing can filter.
--
-- What is NOT here: no gateway reference, no payment method, no partial payments, no
-- invoice posting. CHIP is configured at Settings > Integration > Payments and has a probe
-- but no caller that creates a payment - checked, not assumed. Posting a shop sale to the
-- ledger is DR bank, CR revenue with `cost_per_item` to cost of sales, which is the
-- `sales_invoices` path and a separate piece of work. These two columns record a fact an
-- operator knows; they do not pretend to be an accounting integration.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE LINES ARE SNAPSHOTS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `name`, `option_name`, `sku`, `unit_price`, `weight_kg` and the three dimensions are
-- COPIED onto the line, not read back through `product_id`.
--
-- A price change must not rewrite what somebody was charged last month, and a weight change
-- must not contradict the parcel that was already booked and paid for at the old one. The
-- foreign keys are `ON DELETE SET NULL` for the same reason: a product can only be deleted
-- while it is a draft, but if one ever goes, the order still reads back completely.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE TRACKING EVENTS HAVE A UNIQUE KEY, AND IT IS LOAD-BEARING
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `POST /shipment/tracking_status` returns the ENTIRE `status_log` every time, not the
-- events since last call. Appending the response would duplicate every earlier event on
-- every refresh, and after a week of hourly refreshes a two-event parcel would have three
-- hundred rows.
--
-- `uq_mpte_event (shipment_id, event_date, tracking_status(190))` makes the refresh
-- idempotent through `INSERT IGNORE`: re-reading the same log inserts nothing. The prefix
-- length keeps the key inside the 3072-byte index limit for utf8mb4 - 4 + 5 + 760 bytes.
--
-- EasyParcel returns `event_date` in TWO formats in the same array:
-- `"2026-01-23 12:29:47"` and `"2026-01-23T04:28:52.494Z"`. Normalising them is
-- `src/lib/easyparcel.ts`'s job, because a DATETIME column cannot take the second form and
-- two spellings of one instant would defeat the unique key.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE PERMISSIONS: ACTION SETS READ OFF THE ENDPOINTS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `market_place_orders`    view, create, edit, delete, receive, ship
-- `market_place_tracking`  view, sync
--
-- `market-place-orders.ts` answers GET, POST, PUT, DELETE, plus two actions that CRUD
-- cannot name:
--
--   receive   confirm the buyer has it. A counter clerk who confirms handovers has no
--             business changing the price on an order, so this is not `_edit`.
--   ship      book a courier, which SPENDS REAL MONEY from the EasyParcel wallet, and
--             cancel one, which refunds it. Booking and un-booking are one authority and
--             the buttons sit beside each other. Emphatically not implied by `_edit`.
--
-- `market-place-tracking.ts` answers GET and POST(refresh). `sync` already exists in this
-- system's vocabulary - `holidays_sync` is the same act, pulling state from a third party.
--
-- Both new action names get a label in `PermissionMatrix.tsx`. Its own comment records what
-- happens otherwise: `dispose` had none, so the Roles matrix rendered a chip reading the
-- raw key beside one reading `Assign`.
--
-- `market_place_orders_view` and `market_place_tracking_view` ALREADY EXIST -
-- `market_place_permissions.sql` seeded them view-only so the greyed-out menu entries were
-- visible at all. `INSERT IGNORE` leaves them alone and adds the rest.
--
-- The category is `operations`, a CLOSED list in `src/lib/permission-modules.ts`
-- cross-checked both ways by `tests/sql/roles-endpoints.sql.test.js`. A permission whose
-- category names no sidebar section cannot be granted through the matrix at all.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `CREATE TABLE IF NOT EXISTS`, `INSERT IGNORE`, and guarded foreign keys through PREPARE.
-- Production runs this by hand and a hand runs things twice.
--
-- The guards go through PREPARE rather than a bare `IF()`, and that is not stylistic.
-- `market_place_catalogue.sql` records the trap that cost a failed second run: MySQL
-- RESOLVES BOTH BRANCHES of `IF()` at prepare time, so an `IF()` naming a table in the
-- branch that will NOT be taken still fails. An `ALTER` cannot appear in either branch of
-- an expression at all - it has to be a string handed to PREPARE.
--
-- NO CHECK CONSTRAINTS. Quantities, totals and the mixed-fulfilment rule are validated in
-- the endpoint, which is the only place that can put a sentence on the screen. MySQL 8
-- enforces a CHECK and MySQL 5.7 silently ignores one, so a CHECK would be a rule that
-- holds on one server and not another - and nothing else in this schema uses them.
--
-- ROW_FORMAT is DECLARED on every table. `sql-portability.test.js` asserts it, because
-- `mysqldump` writes only what a table declares and one that inherited the format takes
-- the IMPORTING server's default.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. The order ──
CREATE TABLE IF NOT EXISTS `market_place_orders` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,

  -- `MPO-2026-0001`. Allocated by `nextReference()` in `src/lib/operations-db.ts`, the same
  -- helper behind `VND-`, `TDR-`, `LED-`, `PRP-`, `CLT-` and `STK-`. It reads the highest
  -- number for the year and adds one, so two simultaneous requests can compute the same
  -- value - `uq_mpo_no` is what makes a duplicate impossible and the endpoint's five-attempt
  -- retry is what makes the collision invisible.
  `order_no`   VARCHAR(24) NOT NULL,
  `order_date` DATETIME    NOT NULL,

  -- FROZEN from the product at creation. See the header.
  `fulfilment` ENUM('online','offline') NOT NULL,

  `status` ENUM('pending','shipped','completed','cancelled') NOT NULL DEFAULT 'pending',

  -- ── Payment ──
  `payment_status` ENUM('unpaid','paid') NOT NULL DEFAULT 'unpaid',
  `paid_at`        DATETIME NULL DEFAULT NULL,

  -- ── The buyer ──
  --
  -- Not a foreign key to anything. There is no customer table a shop buyer belongs to, and
  -- inventing one would mean a registration step nobody asked for.
  `buyer_name`    VARCHAR(150) NOT NULL,
  `buyer_company` VARCHAR(150) NULL DEFAULT NULL,
  -- Required for both routes: a courier needs it to deliver and a counter needs it to call
  -- when somebody does not turn up. Stored as typed - EasyParcel wants the national number
  -- without the country code and a separate ISO country code, which
  -- `src/lib/easyparcel.ts` derives rather than storing a second time.
  `buyer_phone`   VARCHAR(30)  NOT NULL,
  `buyer_email`   VARCHAR(190) NULL DEFAULT NULL,
  -- OFFLINE ONLY, and it is not an invention: `FULFILMENT_HINT.offline` in
  -- `src/lib/market-place.ts` already states that a collected product means "the buyer is
  -- asked for an identity card, which is what the counter checks". This is where the
  -- counter records what it checked. NULL on an online order, where nobody checks one.
  `buyer_ic`      VARCHAR(20)  NULL DEFAULT NULL,

  -- ── Where it goes. ONLINE ONLY, every column NULL-able ──
  --
  -- An offline order has no delivery address, and a NOT NULL column would force the form to
  -- invent one. `country_code` is the exception: it has a default because EasyParcel
  -- requires it on every quotation and `MY` is the only origin this account ships from.
  `address_1`    VARCHAR(200) NULL DEFAULT NULL,
  `address_2`    VARCHAR(200) NULL DEFAULT NULL,
  `city`         VARCHAR(100) NULL DEFAULT NULL,
  `postcode`     VARCHAR(10)  NULL DEFAULT NULL,
  -- The LETTER code - `swk`, `png` - which is canonical across this database. `my-states.ts`
  -- records why: two code systems once coexisted and the numeric one printed a bare `14` in
  -- the holidays table. EasyParcel wants ISO 3166-2 (`MY-13`), and `subdivisionCode()`
  -- converts at the boundary rather than storing a third format here.
  `state_code`   VARCHAR(8)   NULL DEFAULT NULL,
  `country_code` CHAR(2)      NOT NULL DEFAULT 'MY',

  -- ── Money ──
  --
  -- `shipping_amount` is what the chosen courier rate came to, written when the booking
  -- succeeds. It stays 0.00 on an offline order, which is the whole point of that route.
  -- `total_amount` is stored rather than derived because it is what the buyer was told, and
  -- recomputing it from lines that have since been edited would produce a different figure.
  `subtotal`        DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `shipping_amount` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `total_amount`    DECIMAL(15,2) NOT NULL DEFAULT 0.00,

  -- ── The handover ──
  --
  -- Written by Confirm Receipt on an offline order, and by the tracking refresh when
  -- EasyParcel reports status code 5 on an online one. `received_by` is the ADMIN USERNAME
  -- who confirmed it, not the buyer - the buyer is already named above, and the question
  -- this column answers is who at the counter said so.
  `received_at`  DATETIME     NULL DEFAULT NULL,
  `received_by`  VARCHAR(150) NULL DEFAULT NULL,
  `receive_note` VARCHAR(300) NULL DEFAULT NULL,

  -- ── Cancellation ──
  `cancelled_at`  DATETIME     NULL DEFAULT NULL,
  `cancel_reason` VARCHAR(300) NULL DEFAULT NULL,

  `notes`      TEXT         NULL DEFAULT NULL,
  -- The USERNAME, matching `market_place_products.created_by`. Within Market Place one form
  -- of identity beats two, and the audit log carries the numeric id anyway.
  `created_by` VARCHAR(150) NULL DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mpo_no` (`order_no`),
  -- The list is filtered by status and by route, and sorted newest first. The composite
  -- covers the default screen; `idx_mpo_date` covers the date range filter on its own.
  KEY `idx_mpo_status` (`status`, `order_date`),
  KEY `idx_mpo_fulfilment` (`fulfilment`, `status`),
  KEY `idx_mpo_date` (`order_date`),
  KEY `idx_mpo_payment` (`payment_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 2. The lines ──
CREATE TABLE IF NOT EXISTS `market_place_order_items` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` INT UNSIGNED NOT NULL,

  -- NULL-able so a deleted draft product does not take the order's history with it.
  `product_id` INT UNSIGNED NULL DEFAULT NULL,
  `option_id`  INT UNSIGNED NULL DEFAULT NULL,

  -- ── The snapshot. See the header ──
  `name`        VARCHAR(200)  NOT NULL,
  `option_name` VARCHAR(120)  NULL DEFAULT NULL,
  `sku`         VARCHAR(64)   NULL DEFAULT NULL,
  `unit_price`  DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `quantity`    INT UNSIGNED  NOT NULL DEFAULT 1,
  `line_total`  DECIMAL(15,2) NOT NULL DEFAULT 0.00,

  -- What the courier prices on. Frozen too: a weight corrected in the catalogue next month
  -- must not contradict the parcel already booked at the old one. An option's own
  -- `weight_kg` wins over the product's when it has one, and that resolution happens once,
  -- here, rather than at every read.
  `weight_kg` DECIMAL(10,3) NULL DEFAULT NULL,
  `length_cm` DECIMAL(10,2) NULL DEFAULT NULL,
  `width_cm`  DECIMAL(10,2) NULL DEFAULT NULL,
  `height_cm` DECIMAL(10,2) NULL DEFAULT NULL,

  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_mpoi_order` (`order_id`),
  KEY `idx_mpoi_product` (`product_id`),
  KEY `idx_mpoi_option` (`option_id`),
  -- CASCADE on the order: a line without its order is unreadable, and the order is the
  -- thing an operator deletes. The product keys are added separately below, guarded on the
  -- catalogue tables existing.
  CONSTRAINT `fk_mpoi_order` FOREIGN KEY (`order_id`)
    REFERENCES `market_place_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 3. The courier booking ──
--
-- ONE ROW PER BOOKING, not one per order. A booking can be cancelled within seven days of
-- the collection date and the order then rebooked with a different courier, and both
-- attempts are history worth keeping - the first one was paid for and refunded.
-- `idx_mps_order` plus `cancelled_at IS NULL` is how the live one is found.
CREATE TABLE IF NOT EXISTS `market_place_shipments` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` INT UNSIGNED NOT NULL,

  -- ── What EasyParcel calls it ──
  --
  -- `EI-2602-4P2SK` for the order, `ES-2602-4VW9E` for the shipment. Both NULL-able because
  -- a booking row is written BEFORE the response is parsed, so a failed submit leaves a row
  -- that names the attempt rather than nothing at all.
  `ep_order_number`  VARCHAR(40)  NULL DEFAULT NULL,
  `shipment_number`  VARCHAR(40)  NULL DEFAULT NULL,
  -- The courier's own waybill. NULL until the courier assigns one, which the API documents
  -- as arriving later - sometimes on submit, sometimes only on the `shipment.awb.update`
  -- webhook. Tracking is keyed on this, so an order with no AWB yet cannot be tracked and
  -- the screen says so instead of showing an empty history.
  `awb_number`       VARCHAR(60)  NULL DEFAULT NULL,
  `awb_url`          VARCHAR(500) NULL DEFAULT NULL,
  `tracking_url`     VARCHAR(500) NULL DEFAULT NULL,

  -- ── Which service was bought ──
  `service_id`      VARCHAR(20)  NULL DEFAULT NULL,
  `courier_name`    VARCHAR(120) NULL DEFAULT NULL,
  `service_name`    VARCHAR(160) NULL DEFAULT NULL,
  `collection_date` DATE         NULL DEFAULT NULL,

  -- ── The parcel as booked ──
  --
  -- Summed from the lines at booking time and stored, because the quotation was priced on
  -- these exact figures. Recomputing them later from lines that have since been edited
  -- would produce a parcel that does not match the one the courier was paid for.
  `weight_kg` DECIMAL(10,3) NULL DEFAULT NULL,
  `length_cm` DECIMAL(10,2) NULL DEFAULT NULL,
  `width_cm`  DECIMAL(10,2) NULL DEFAULT NULL,
  `height_cm` DECIMAL(10,2) NULL DEFAULT NULL,

  -- ── What it cost ──
  `currency_code`  CHAR(3)       NOT NULL DEFAULT 'MYR',
  `shipment_price` DECIMAL(15,2) NULL DEFAULT NULL,
  `total_paid`     DECIMAL(15,2) NULL DEFAULT NULL,

  -- ── Where the parcel is, in EasyParcel's own terms ──
  --
  -- The numeric code is stored and the text is stored beside it. Both, deliberately: the
  -- code is what a filter uses and the text is what the courier actually said, and the API
  -- documentation warns that the wording "may vary by courier and region". Keeping only the
  -- code would lose the courier's own sentence; keeping only the text would make filtering
  -- a string comparison against wording that changes.
  `shipment_status_code` SMALLINT     NULL DEFAULT NULL,
  `shipment_status`      VARCHAR(160) NULL DEFAULT NULL,
  `last_synced_at`       DATETIME     NULL DEFAULT NULL,

  -- ── Cancellation ──
  --
  -- EasyParcel requires a remark on `/shipment/cancel` and refuses the call more than seven
  -- days after the collection date or once the driver has collected. Both refusals arrive as
  -- a per-item error inside a 200 response, so the endpoint reads `data[].status` rather
  -- than the HTTP code.
  `cancelled_at`   DATETIME     NULL DEFAULT NULL,
  `cancel_remark`  VARCHAR(300) NULL DEFAULT NULL,

  -- The raw submit response, for the one question a parsed row cannot answer: what exactly
  -- did EasyParcel say when this went wrong. LONGTEXT rather than JSON, matching how this
  -- codebase already stores third-party payloads - a JSON column would refuse to store a
  -- truncated or non-JSON error body, which is precisely the body worth keeping.
  `api_response` LONGTEXT NULL DEFAULT NULL,

  `created_by` VARCHAR(150) NULL DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_mps_order` (`order_id`),
  -- Tracking refresh looks a shipment up by AWB, because that is the only key the tracking
  -- response carries back. Not UNIQUE: a courier can reuse a waybill number across years,
  -- and a unique key would refuse the second booking rather than reporting the clash.
  KEY `idx_mps_awb` (`awb_number`),
  KEY `idx_mps_shipment_no` (`shipment_number`),
  KEY `idx_mps_status` (`shipment_status_code`),
  CONSTRAINT `fk_mps_order` FOREIGN KEY (`order_id`)
    REFERENCES `market_place_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 4. The courier's event log ──
CREATE TABLE IF NOT EXISTS `market_place_tracking_events` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `shipment_id` INT UNSIGNED NOT NULL,

  `event_date`      DATETIME     NOT NULL,
  `status_code`     SMALLINT     NULL DEFAULT NULL,
  `tracking_status` VARCHAR(255) NOT NULL,
  -- `"Kuala Lumpur Hub, Kuala Lumpur, MY"`, or NULL - the API returns null for most events
  -- and that is a real answer meaning the courier did not say where.
  `location`        VARCHAR(255) NULL DEFAULT NULL,

  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_mpte_shipment` (`shipment_id`, `event_date`),
  -- THE KEY THAT MAKES REFRESH IDEMPOTENT. See the header.
  UNIQUE KEY `uq_mpte_event` (`shipment_id`, `event_date`, `tracking_status`(190)),
  CONSTRAINT `fk_mpte_shipment` FOREIGN KEY (`shipment_id`)
    REFERENCES `market_place_shipments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 5. Are the catalogue tables there, and are the keys already added ──
SET @mpp_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
)

-- >>>
SET @mppo_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_product_options'
)

-- >>>
SET @fk_product := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_order_items'
     AND CONSTRAINT_NAME = 'fk_mpoi_product'
)

-- >>>
SET @fk_option := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_order_items'
     AND CONSTRAINT_NAME = 'fk_mpoi_option'
)

-- >>>
-- ── 6. The product key ──
--
-- `SET NULL`, not `CASCADE` and not `RESTRICT`. CASCADE would delete order lines when a
-- product went, which destroys the record of a completed sale. RESTRICT would refuse to
-- delete a draft product that had somehow been ordered, reporting a foreign key name to
-- somebody who typed nothing wrong. SET NULL keeps the line, with its frozen name and
-- price, and loses only the link.
SET @sql := IF(@mpp_table = 1 AND @fk_product = 0,
  'ALTER TABLE `market_place_order_items`
     ADD CONSTRAINT `fk_mpoi_product` FOREIGN KEY (`product_id`)
     REFERENCES `market_place_products` (`id`) ON DELETE SET NULL',
  'SELECT ''fk_mpoi_product: already present, or market_place_products is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 7. The option key ──
SET @sql := IF(@mppo_table = 1 AND @fk_option = 0,
  'ALTER TABLE `market_place_order_items`
     ADD CONSTRAINT `fk_mpoi_option` FOREIGN KEY (`option_id`)
     REFERENCES `market_place_product_options` (`id`) ON DELETE SET NULL',
  'SELECT ''fk_mpoi_option: already present, or the options table is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 8. The permissions ──
--
-- `market_place_orders_view` and `market_place_tracking_view` already exist; `INSERT IGNORE`
-- leaves them alone.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_orders',   'view',    'market_place_orders_view',    'Read Market Place orders',                          'operations'),
  ('market_place_orders',   'create',  'market_place_orders_create',  'Create a Market Place order',                       'operations'),
  ('market_place_orders',   'edit',    'market_place_orders_edit',    'Change a Market Place order',                        'operations'),
  ('market_place_orders',   'delete',  'market_place_orders_delete',  'Delete a Market Place order',                        'operations'),
  ('market_place_orders',   'receive', 'market_place_orders_receive', 'Confirm the buyer has received a Market Place order', 'operations'),
  ('market_place_orders',   'ship',    'market_place_orders_ship',    'Book or cancel a courier for a Market Place order',  'operations'),
  ('market_place_tracking', 'view',    'market_place_tracking_view',  'Read the Market Place fulfilment queue',             'operations'),
  ('market_place_tracking', 'sync',    'market_place_tracking_sync',  'Refresh Market Place tracking from the courier',     'operations')

-- >>>
-- ── 8a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `usePermissions` joins through
-- `role_permissions`, so an ungranted permission makes the button INVISIBLE rather than
-- denied - which reads as a broken screen.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('market_place_orders', 'market_place_tracking')

-- >>>
-- ── 9. Report what landed ──
--
-- `product_fk` and `option_fk` are the two to read on a first run. 0 means this file ran
-- before `market_place_catalogue.sql` and the keys were skipped - apply that one and run
-- this again. Everything else here is already correct in that case.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders')          AS orders_table,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_order_items')     AS items_table,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_shipments')       AS shipments_table,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_tracking_events') AS events_table,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_order_items'
      AND CONSTRAINT_NAME = 'fk_mpoi_product')                                       AS product_fk,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_order_items'
      AND CONSTRAINT_NAME = 'fk_mpoi_option')                                        AS option_fk,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_tracking_events'
      AND INDEX_NAME = 'uq_mpte_event')                                              AS event_unique_parts,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'market_place_orders')        AS order_permissions,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'market_place_tracking')      AS tracking_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` IN ('market_place_orders', 'market_place_tracking'))             AS granted_to_super_admin
