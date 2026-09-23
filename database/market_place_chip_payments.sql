-- ============================================================================
-- MARKET PLACE: PAYING FOR AN ORDER THROUGH CHIP COLLECT
--
-- Run with:  node scripts/run-sql.js database/market_place_chip_payments.sql
--
-- ── WHAT THIS ANSWERS, AND WHOSE ARGUMENT IT OVERTURNS ──
--
-- `market_place_orders.sql` deliberately gave payment TWO columns and wrote down
-- why:
--
--     "What is NOT here: no gateway reference, no payment method, no partial
--      payments, no invoice posting. CHIP is configured at Settings > Integration
--      > Payments and has a probe but no caller that creates a payment - checked,
--      not assumed."
--
-- And `src/lib/market-place.ts` said of `PAYMENT_STATUSES`:
--
--     "No `refunded`, no `partial`, no `failed`. Each of those describes something
--      a gateway does, and none of them can be reached from anything this
--      application currently performs."
--
-- Both were CORRECT WHEN WRITTEN. The premise has changed: a caller now exists.
-- `src/lib/chip.ts` creates a purchase, `api/public/shop/checkout.ts` sends the
-- buyer to CHIP's hosted page, and `api/public/shop/chip-callback.ts` is told the
-- outcome. So `failed` is reachable, and the gap between "an order exists" and
-- "the money arrived" is now a real state a buyer sits in for two minutes.
--
-- The old reasoning is not deleted from those files. It is answered in place, so
-- the next reader sees that the decision was revisited rather than forgotten.
--
-- ── FOUR COLUMNS FOR THE GATEWAY, AND EACH EARNS ITS PLACE ──
--
--   payment_ref       CHIP's purchase id. UNIQUE, because the webhook arrives
--                     carrying only this and must resolve to exactly ONE order -
--                     and because the same purchase must never be attachable to
--                     two orders.
--   payment_method    what CHIP reported it was paid with (fpx, card, ewallet).
--                     Recorded because "paid" without it cannot answer the only
--                     question a reconciliation asks.
--   paid_amount       what CHIP ACTUALLY captured. NOT assumed equal to
--                     `total_amount`: if they differ, that is a fault worth
--                     seeing rather than a row silently marked paid.
--   payment_event_at  when the gateway last said something, which is not the same
--                     instant as `paid_at`.
--
-- Plus `payment_payload LONGTEXT` - the raw webhook body. LONGTEXT rather than
-- JSON, matching `market_place_shipments.api_response` and for the same recorded
-- reason: a JSON column refuses to store a truncated or non-JSON error body, and
-- that is precisely the body worth keeping.
--
-- ── `public_token`, BECAUSE `order_no` MUST NOT BE THE LOOKUP KEY ──
--
-- A guest coming back from CHIP has nothing to identify their order by. `order_no`
-- is `MPO-2026-0001` - sequential, so anybody could walk the whole shop's order
-- book by counting. So a random token addresses the return page.
--
-- It is NOT `collect_code`. That code is the COUNTER's authority and
-- `market-place-qr.ts` argues explicitly that it must never become a URL: it is
-- emailed as a QR for somebody to present, and a code that is also a web address
-- is a code that leaks into browser history, referrer headers and shared links.
--
-- It is NOT an HMAC from `public-token.ts` either, and `market_place_collection.sql`
-- already recorded the reason for the neighbouring case: those tokens EXPIRE. A
-- buyer opening their order confirmation a week later would be refused, and the
-- refusal is indistinguishable from a forgery.
--
-- ── THE ENUM GAINS TWO VALUES, IN THE MIDDLE AND AT THE END ──
--
--   unpaid    no payment attempt. The default, and what every admin-created order
--             still is.
--   awaiting  a CHIP purchase exists and the buyer is on the hosted page. THIS IS
--             THE STATE THAT DID NOT EXIST, and without it an abandoned checkout
--             is indistinguishable from an order nobody has paid for.
--   paid      CHIP confirmed it.
--   failed    CHIP said it failed or the buyer cancelled.
--
-- `unpaid` stays FIRST and `paid` keeps its place ahead of the new terminal value.
-- MySQL stores an ENUM by its name in an ALTER, so no existing row changes meaning
-- - but declaration order is what `ORDER BY payment_status` uses, so the sequence
-- is the lifecycle rather than alphabetical.
--
-- ── `payments_public_key` IS A THIRD CREDENTIAL, AND IT NEEDS TEXT ──
--
-- CHIP signs every webhook and the signature is verified with RSA PKCS#1 v1.5 over
-- SHA-256 using a PUBLIC key from the merchant portal - a different value from the
-- API key, and issued separately for test and live.
--
-- It cannot go in any existing column: `payments_api_key` and
-- `payments_secret_key` are both `VARCHAR(255)` and a 2048-bit RSA public key in
-- PEM form is over 400 characters. Measured, not guessed - that is why this is
-- TEXT.
--
-- ── IDEMPOTENT ──
--
-- Every ALTER is guarded through a PREPARE, on the COLUMN or the INDEX or the
-- COLUMN_TYPE. A bare `IF()` naming a column does not work: MySQL resolves BOTH
-- branches when it prepares the statement, which is the trap
-- `market_place_catalogue.sql` records costing it a failed second run.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 0. Are the tables even here ──
--
-- Checked rather than assumed. A server that pulls this release without having run
-- `market_place_orders.sql` has nothing to alter, and an unguarded ALTER would stop
-- the run with `ER_NO_SUCH_TABLE` - an error that names THIS file rather than the
-- missing one.
SET @mpo_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
)

-- >>>
SET @int_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'integrations'
)

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 1. THE GATEWAY COLUMNS
-- ══════════════════════════════════════════════════════════════════════════════
SET @mpo_ref := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND COLUMN_NAME = 'payment_ref'
)

-- >>>
-- All five in ONE ALTER. They are one decision and they arrive together; five
-- separate guarded ALTERs would let a half-applied run leave an order with a
-- reference and nowhere to record what it was paid with.
--
-- Placed AFTER `paid_at`, so the payment columns sit together in `DESCRIBE` and in
-- a `mysqldump`. Column order means nothing to a query and a lot to the next
-- person reading the table.
SET @sql := IF(@mpo_table = 1 AND @mpo_ref = 0,
  'ALTER TABLE `market_place_orders`
     ADD COLUMN `payment_ref` VARCHAR(64) NULL DEFAULT NULL
       COMMENT ''CHIP purchase id. NULL on an order that never went through the gateway.''
       AFTER `paid_at`,
     ADD COLUMN `payment_method` VARCHAR(40) NULL DEFAULT NULL
       COMMENT ''What CHIP reported it was paid with: fpx, card, ewallet.''
       AFTER `payment_ref`,
     ADD COLUMN `paid_amount` DECIMAL(15,2) NULL DEFAULT NULL
       COMMENT ''What CHIP actually captured. Compared against total_amount, never assumed equal.''
       AFTER `payment_method`,
     ADD COLUMN `payment_event_at` DATETIME NULL DEFAULT NULL
       COMMENT ''When the gateway last reported on this order.''
       AFTER `paid_amount`,
     ADD COLUMN `payment_payload` LONGTEXT NULL DEFAULT NULL
       COMMENT ''The raw webhook body, for the question a parsed row cannot answer.''
       AFTER `payment_event_at`',
  'SELECT ''gateway columns: already present, or market_place_orders is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 1a. The unique index on the reference, guarded SEPARATELY ──
--
-- Separate because the column may have landed on an earlier run while the index did
-- not, and re-adding an existing index is an error rather than a no-op.
--
-- UNIQUE and NULL-able together: MySQL permits any number of NULLs in a unique
-- index, which is the property that lets every admin-created order carry no
-- reference while no two gateway orders can share one. The same property
-- `uq_mpo_collect_code` already depends on.
SET @mpo_ref_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND INDEX_NAME = 'uq_mpo_payment_ref'
)

-- >>>
SET @sql := IF(@mpo_table = 1 AND @mpo_ref_uq = 0,
  'ALTER TABLE `market_place_orders`
     ADD UNIQUE KEY `uq_mpo_payment_ref` (`payment_ref`)',
  'SELECT ''uq_mpo_payment_ref: already present, or the table is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 2. THE PUBLIC TOKEN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- 32 characters from the same 34-character alphabet as a collection code, so one
-- transcription rule covers every code in this product. 34^32 is far past guessing;
-- the length is chosen for a URL rather than for a person to type, which is exactly
-- why it is NOT the collection code.
SET @mpo_token := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND COLUMN_NAME = 'public_token'
)

-- >>>
SET @sql := IF(@mpo_table = 1 AND @mpo_token = 0,
  'ALTER TABLE `market_place_orders`
     ADD COLUMN `public_token` VARCHAR(32) NULL DEFAULT NULL
       COMMENT ''Addresses /shop/order/<token>. NULL on an admin-created order, which needs no public page.''
       AFTER `collect_code_sent_at`',
  'SELECT ''public_token: already present, or market_place_orders is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
SET @mpo_token_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND INDEX_NAME = 'uq_mpo_public_token'
)

-- >>>
-- UNIQUE because it is the lookup key for the return page: a duplicate would show
-- one buyer another buyer's order, which is the worst failure available here.
SET @sql := IF(@mpo_table = 1 AND @mpo_token_uq = 0,
  'ALTER TABLE `market_place_orders`
     ADD UNIQUE KEY `uq_mpo_public_token` (`public_token`)',
  'SELECT ''uq_mpo_public_token: already present, or the table is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 3. `payment_status` GAINS `awaiting` AND `failed`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Guarded on the COLUMN_TYPE rather than on the column existing, which is the
-- pattern `market_place_collection.sql` used to add `pending` to a product status.
-- A guard on existence is satisfied on run 1 and would never widen anything.
SET @mpo_pay_enum := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND COLUMN_NAME = 'payment_status' AND COLUMN_TYPE LIKE '%awaiting%'
)

-- >>>
-- The whole definition is restated, because MODIFY COLUMN REPLACES rather than
-- amends: anything left out - the NOT NULL, the DEFAULT - would be silently
-- dropped. Both are spelled out for that reason.
SET @sql := IF(@mpo_table = 1 AND @mpo_pay_enum = 0,
  'ALTER TABLE `market_place_orders`
     MODIFY COLUMN `payment_status`
       ENUM(''unpaid'', ''awaiting'', ''paid'', ''failed'')
       NOT NULL DEFAULT ''unpaid''',
  'SELECT ''payment_status: awaiting already declared, or the table is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 4. CHIP'S PUBLIC KEY, FOR VERIFYING A WEBHOOK
-- ══════════════════════════════════════════════════════════════════════════════
--
-- TEXT, because a PEM does not fit `VARCHAR(255)` - measured against the existing
-- credential columns rather than assumed.
--
-- A webhook that is not verified is an open door: the body says "this order is
-- paid", and anybody who learns the URL could post one. So this column is what
-- stands between a public endpoint and a stranger marking orders paid, and the
-- callback refuses to act at all when it is empty.
SET @int_pub := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'integrations'
     AND COLUMN_NAME = 'payments_public_key'
)

-- >>>
SET @sql := IF(@int_table = 1 AND @int_pub = 0,
  'ALTER TABLE `integrations`
     ADD COLUMN `payments_public_key` TEXT NULL DEFAULT NULL
       COMMENT ''CHIP webhook public key, PEM. Verifies X-Signature. Separate for test and live.''
       AFTER `payments_secret_key`',
  'SELECT ''payments_public_key: already present, or integrations is not there yet'' AS note')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 5. REPORT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Read `orders_table_found` and `integrations_table_found` first. A 0 on either
-- means an earlier migration has not been applied on this database and everything
-- below it was skipped - the fix is that file, not a second run of this one.
--
-- Every other figure must read what its name says. `gateway_columns` is checked as
-- a COUNT of five rather than as "payment_ref exists", because the guard above is
-- keyed on one column and a half-applied ALTER would otherwise pass unnoticed.
SELECT
  @mpo_table                                                                  AS orders_table_found,
  @int_table                                                                  AS integrations_table_found,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND COLUMN_NAME IN ('payment_ref', 'payment_method', 'paid_amount',
                          'payment_event_at', 'payment_payload'))             AS gateway_columns_of_5,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND COLUMN_NAME = 'public_token')                                       AS public_token_of_1,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND INDEX_NAME IN ('uq_mpo_payment_ref', 'uq_mpo_public_token'))        AS unique_indexes_of_2,
  (SELECT COLUMN_TYPE FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND COLUMN_NAME = 'payment_status')                                     AS payment_status_now,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'integrations'
      AND COLUMN_NAME = 'payments_public_key' AND DATA_TYPE = 'text')         AS public_key_is_text_of_1,
  -- Nothing here may change a stored row. If this is not 0 on a database that had
  -- orders, a MODIFY has rewritten data rather than a definition.
  (SELECT COUNT(*) FROM `market_place_orders`
    WHERE `payment_status` NOT IN ('unpaid', 'awaiting', 'paid', 'failed'))    AS rows_with_a_bad_status
