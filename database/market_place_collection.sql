-- ═══════════════════════════════════════════════════════════════════════════════
-- MARKET PLACE — COUNTER COLLECTION, AND PUTTING A PRODUCT DRAFT BEHIND APPROVAL
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Two features that arrived in one conversation and share one migration because
-- neither is big enough to be worth its own, and both are guarded ALTERs on tables
-- that already exist.
--
--   1. A COLLECTION CODE on an offline order. The buyer is emailed a QR code; the
--      counter scans it and the order closes. Until now the counter had to find the
--      order by name in a list.
--   2. A product cannot go live on its own. `draft` gains a `pending` stage, and the
--      shared approval chain decides whether it reaches `active`.
--
-- ── WHAT THIS FILE DOES *NOT* CREATE ──
--
-- No table. Every column here is added to `market_place_orders` or
-- `market_place_products`, and every permission row is an `INSERT IGNORE`.
--
-- It also deliberately seeds NO `hr_module_settings` rows for `market_place`.
-- `getModuleSettings()` in `src/lib/hr-module-settings.ts` fills every declared key
-- from `NOTIFICATION_KEYS` when it is unset, so five seeded rows holding exactly the
-- defaults would be five rows that mean nothing. This note exists so the absence
-- reads as a decision rather than as something forgotten.
--
-- ── IT NEEDS BOTH EARLIER MIGRATIONS, AND SURVIVES THE WRONG ORDER ──
--
--   market_place_catalogue.sql   creates `market_place_products`
--   market_place_orders.sql      creates `market_place_orders`
--
-- Every ALTER is guarded on its table AND its column, through a PREPARE. A bare
-- `IF()` is not enough and `market_place_settings.sql` records why: MySQL RESOLVES
-- BOTH BRANCHES of `IF()` at prepare time, so an `IF()` naming a column on a table
-- that does not exist fails with ER_NO_SUCH_TABLE before the guard is read. Run this
-- first and it reports 0 for the columns it skipped; apply the earlier file and run
-- it again.
--
-- IDEMPOTENT. Production applies it by hand, and a hand runs things twice.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. Do the two tables exist? ──
SET @mpo_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
)
-- >>>
SET @mpp_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
)
-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. THE COLLECTION CODE
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- ── WHY A STORED CODE AND NOT A SIGNED TOKEN ──
--
-- `src/lib/public-token.ts` already mints HMAC tokens for anonymous callers and it was
-- the obvious reuse. It is the wrong tool here for one reason: those tokens EXPIRE, by
-- design, in minutes to a day. A buyer who collects three weeks after ordering would
-- present a QR the counter refuses, and the refusal would be indistinguishable from a
-- forgery. A collection code has no natural lifetime — it is valid until the goods are
-- handed over — so it is a stored value, not a signature.
--
-- Stored also buys three things a token cannot: it is revocable before it is used, it
-- can be re-sent without minting a second secret, and it is short enough for a person
-- to TYPE when their phone is flat. That last one is not a nicety. A counter that can
-- only accept a scan stops working when a battery does.
--
-- ── TWELVE CHARACTERS, AND THE SAME ALPHABET AS AN ASSET ID ──
--
-- `ASSET_UID_ALPHABET` is 34 characters — the digits and the letters minus `I` and `O`,
-- which are the two a person transcribes wrongly. 34^12 is about 2.4e18, so guessing one
-- is not an attack anybody mounts, and at 12 characters the QR stays a version-1 symbol,
-- the smallest and easiest to scan off a phone screen held at a counter.
--
-- The alphabet is SHARED rather than reinvented so a clerk retyping either a collection
-- code or an asset number follows one rule. The GENERATOR is separate — see
-- `newCollectCode()` in `src/lib/operations-db.ts` — because an asset id and a collection
-- code are different namespaces and one function returning both would invite a comparison
-- between them.
--
-- ── NULL FOR AN ONLINE ORDER, AND THE UNIQUE INDEX PERMITS THAT ──
--
-- A posted order has no counter to walk to; its proof of delivery is the courier's own
-- scan. So `collect_code` is NULL for every `fulfilment = 'online'` row, and MySQL allows
-- any number of NULLs in a UNIQUE index — the same property `market_place_products.sku`
-- already depends on so that many products may have no SKU while no two share one.
SET @mpo_code := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND COLUMN_NAME = 'collect_code'
)
-- >>>
SET @sql := IF(@mpo_table = 1 AND @mpo_code = 0,
  'ALTER TABLE `market_place_orders`
     ADD COLUMN `collect_code` VARCHAR(12) NULL DEFAULT NULL AFTER `buyer_ic`,
     ADD COLUMN `collect_code_sent_at` DATETIME NULL DEFAULT NULL AFTER `collect_code`',
  'SELECT ''collect_code: already present, or market_place_orders is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>

-- The unique index, guarded separately: the columns may have landed on an earlier run
-- while the index did not, and re-adding an existing index is an error rather than a no-op.
SET @mpo_code_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
     AND INDEX_NAME = 'uq_mpo_collect_code'
)
-- >>>
SET @sql := IF(@mpo_table = 1 AND @mpo_code_uq = 0,
  'ALTER TABLE `market_place_orders`
     ADD UNIQUE KEY `uq_mpo_collect_code` (`collect_code`)',
  'SELECT ''uq_mpo_collect_code: already present, or the table is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. THE PRODUCT STATUS GAINS `pending`
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- ── WHY A FOURTH VALUE RATHER THAN A SEPARATE FLAG ──
--
-- The shared approval engine writes the application's own `status` column — see
-- `applyApprovalAction` in `src/lib/approval-flow.ts` — and it needs somewhere to put
-- "submitted, nobody has signed yet". A boolean `is_pending` beside `status` would be a
-- second authority on one question, and the first screen to read only one of them would
-- show a live product as a draft or a draft as live.
--
-- ── WHERE `pending` SITS, AND WHY IT IS NOT LAST ──
--
-- `draft, pending, active, archived` is the lifecycle order, and an ENUM's declaration
-- order is what `ORDER BY status` uses. Appending `pending` after `archived` would sort a
-- product awaiting approval below one the shop has retired. The list query spells its
-- ordering out with `FIELD()` rather than relying on this, but the column should still
-- read correctly to somebody querying it by hand.
--
-- ── WHAT A REJECTION WRITES ──
--
-- `draft`, not a fifth value. A refused product has to be EDITABLE again, which is what
-- `draft` means, and the reason lives in `hr_approval_records.remarks` where the whole
-- trail already is. A `rejected` status would be a state whose only exit is back to draft
-- anyway, plus a second place to store a reason.
--
-- The mapping is `{ pending: 'pending', approved: 'active', rejected: 'draft' }`, passed
-- to the engine as `statusWords` at the call site. `applicants` is the precedent: its
-- column is a recruitment pipeline and it maps the same three outcomes onto its own words.
SET @mpp_pending := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
     AND COLUMN_NAME = 'status' AND COLUMN_TYPE LIKE '%pending%'
)
-- >>>
SET @sql := IF(@mpp_table = 1 AND @mpp_pending = 0,
  'ALTER TABLE `market_place_products`
     MODIFY COLUMN `status` ENUM(''draft'',''pending'',''active'',''archived'')
       NOT NULL DEFAULT ''draft''',
  'SELECT ''products.status: pending already declared, or the table is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. THE APPROVAL COLUMNS ON A PRODUCT
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `current_level` is REQUIRED by the engine, not optional bookkeeping: `applyApprovalAction`
-- writes it in the same statement as the status, and `checkApproverTurn` reads it to refuse
-- level 2 before level 1 has signed. 0 means nobody has signed.
--
-- ── WHY THE SUBMITTER IS STORED TWICE, AS AN ID *AND* A NAME ──
--
-- `notifyDecision` needs an email address, which means resolving the account — so the id.
-- But an account can be deleted, and the record of who submitted a product should survive
-- that, so the name is snapshotted alongside.
--
-- There is deliberately NO foreign key to `admins`. `hr_approval_records` stores
-- `actor_admin_id` + `actor_name` with no key for exactly this reason, and it is the right
-- precedent: `ON DELETE SET NULL` would leave a readable name with a dangling id, and
-- `RESTRICT` would refuse to delete a staff account because they once published a product.
SET @mpp_level := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
     AND COLUMN_NAME = 'current_level'
)
-- >>>
SET @sql := IF(@mpp_table = 1 AND @mpp_level = 0,
  'ALTER TABLE `market_place_products`
     ADD COLUMN `current_level` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `status`,
     ADD COLUMN `submitted_at` DATETIME NULL DEFAULT NULL AFTER `current_level`,
     ADD COLUMN `submitted_by` VARCHAR(150) NULL DEFAULT NULL AFTER `submitted_at`,
     ADD COLUMN `submitted_by_admin_id` INT UNSIGNED NULL DEFAULT NULL AFTER `submitted_by`,
     ADD KEY `idx_mpp_pending` (`status`, `current_level`)',
  'SELECT ''products approval columns: already present, or the table is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. THE PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Ten rows: two new MODULES with four actions each for the two settings tabs, plus two new
-- ACTIONS on the existing `market_place_products` module.
--
-- ── WHY THE TABS GET THEIR OWN MODULES ──
--
-- Because that is what the shared components consume. `ApprovalWorkflow` derives
-- `<permModule>_create`, `_edit` and `_delete` from its prop, and `ModuleNotifications`
-- derives `_edit`; both endpoints look the module up in their own PERM map. Equipment Loan
-- has exactly this pair — `asset_loan_approval` and `asset_loan_notifications` — and
-- borrowing `market_place_settings_edit` instead would mean somebody who may open the shop
-- can also rewrite who approves a product.
--
-- `create` and `delete` on the notifications module are seeded for matrix symmetry and are
-- read by nothing, which is what Equipment Loan does and is recorded there too.
--
-- ── WHY `submit` AND `approve` ARE SEPARATE FROM `edit` ──
--
-- `edit` changes a price. `submit` asks for a decision. `approve` makes a product visible
-- to the public. Folding submit into edit would mean anybody who can fix a typo can push a
-- product into the approval queue; folding approve into edit would mean the person who
-- wrote it can publish it, which is the one thing an approval chain exists to prevent.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_approval',      'view',    'market_place_approval_view',      'Read the Market Place approval chain',            'operations'),
  ('market_place_approval',      'create',  'market_place_approval_create',    'Add a Market Place approval level',               'operations'),
  ('market_place_approval',      'edit',    'market_place_approval_edit',      'Change a Market Place approval level',             'operations'),
  ('market_place_approval',      'delete',  'market_place_approval_delete',    'Remove a Market Place approval level',             'operations'),
  ('market_place_notifications', 'view',    'market_place_notifications_view', 'Read Market Place notification settings',          'operations'),
  ('market_place_notifications', 'create',  'market_place_notifications_create','Add Market Place notification settings',          'operations'),
  ('market_place_notifications', 'edit',    'market_place_notifications_edit', 'Change Market Place notification settings',        'operations'),
  ('market_place_notifications', 'delete',  'market_place_notifications_delete','Remove Market Place notification settings',       'operations'),
  ('market_place_products',      'submit',  'market_place_products_submit',    'Submit a Market Place product for approval',       'operations'),
  ('market_place_products',      'approve', 'market_place_products_approve',   'Approve or reject a submitted Market Place product','operations')
-- >>>
-- ── 5a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `usePermissions` joins through
-- `role_permissions`, so an ungranted permission makes the button INVISIBLE rather than
-- denied — which reads as a broken screen.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND (p.`module` IN ('market_place_approval', 'market_place_notifications')
        OR (p.`module` = 'market_place_products' AND p.`action` IN ('submit', 'approve')))
-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. REPORT WHAT LANDED
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `collect_code` and `product_pending` are the two to read on a first run. 0 for either
-- means this file ran before the migration that creates the table it alters — apply that
-- one and run this again. Nothing here is damaged in the meantime.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND COLUMN_NAME = 'collect_code')                                          AS collect_code,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_orders'
      AND INDEX_NAME = 'uq_mpo_collect_code')                                    AS collect_code_unique,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
      AND COLUMN_NAME = 'status' AND COLUMN_TYPE LIKE '%pending%')               AS product_pending,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'market_place_products'
      AND COLUMN_NAME IN ('current_level', 'submitted_at', 'submitted_by',
                          'submitted_by_admin_id'))                              AS product_approval_columns,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'market_place_approval')  AS approval_permissions,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'market_place_notifications')                               AS notification_permissions,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'market_place_products'
      AND `action` IN ('submit', 'approve'))                                     AS product_actions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND (p.`module` IN ('market_place_approval', 'market_place_notifications')
           OR (p.`module` = 'market_place_products'
               AND p.`action` IN ('submit', 'approve'))))                        AS granted_to_super_admin
