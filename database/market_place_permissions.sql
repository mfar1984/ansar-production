-- MARKET PLACE: ONE PERMISSION MODULE PER PAGE
--
-- Idempotent. Safe to run twice.
--
-- ── WHAT THIS SEEDS, AND WHY IT MUST RUN BEFORE THE MENU APPEARS ──
--
-- Four `_view` permissions, one per planned Market Place page. The sidebar entries are DISABLED
-- until their screens land, but they still name a permission, and that is not decoration: the
-- client-side `hasPermission` in `src/app/(auth)/auth/[hash]/page.tsx` is a plain
--
--     userPermissions.includes(permission)
--
-- with NO Super Admin shortcut. A permission name with no row therefore evaluates false for every
-- role including Super Admin, `leafVisible()` hides the leaf, and once all four are hidden
-- `visibleNav()` drops the whole group. The result is not a greyed-out roadmap — it is a Market
-- Place that does not exist in the menu at all, for anybody, with nothing on screen saying why.
--
-- `tests/sql/sidebar.test.js` enforces both halves: every permission the sidebar names must have a
-- row here, and every planned entry must name a permission rather than being visible to all roles.
--
-- ── WHY ONLY `view`, AND NOT create/edit/delete ──
--
-- Because there is nothing to read them off yet.
--
-- `asset_page_permissions.sql` states the rule it followed: "ACTION SETS ARE READ OFF THE ENDPOINT,
-- not guessed", and it then lists each module beside the HTTP verbs its endpoint actually answers.
-- Market Place has no endpoints. Seeding `market_place_orders_delete` today would be a guess, and a
-- wrong guess is worse than a missing one: it puts a checkbox in the Roles matrix that grants
-- nothing, and a role administrator cannot tell a dead permission from a live one by looking at it.
-- That is the same clutter `database/payroll_approval_cleanup.sql` was written to remove.
--
-- `_view` is the exception because it is the one action whose meaning is already fixed: it is what
-- opens the page, it is what the sidebar checks, and it is decided by the menu rather than by an
-- endpoint. The write actions arrive in the migration that ships each screen, alongside the routes
-- whose verbs define them.
--
-- ── NO BACKFILL, AND THAT IS DELIBERATE ──
--
-- `asset_page_permissions.sql` needed one because it SPLIT two existing modules, so every role had
-- to keep the authority it already held. Nothing is being split here. These four modules are new
-- ground: no role held anything that used to govern these pages, because these pages have never
-- existed. Granting them to existing roles would be inventing authority, not preserving it.
--
-- Super Admin is the single exception below, for the same reason it is in every other migration:
-- the role is meant to see the whole product, and without a grant it would be the one role unable
-- to see the roadmap it is supposed to be planning.
--
-- ── CATEGORY ──
--
-- `operations`. `CATEGORY_ORDER` in `src/lib/permission-modules.ts` is a closed list cross-checked
-- against `SELECT DISTINCT category FROM permissions` in both directions by
-- `tests/sql/roles-endpoints.sql.test.js`, and the Market Place group lives inside the sidebar's
-- OPERATIONS section beside Tender Management, Procurement and Business Development. A new
-- `market_place` category would name a matrix heading that no sidebar section carries.
-- ============================================================================

-- >>>
-- ============================================================
-- 1. Four modules, one per page, in sidebar order.
--
--   market_place_products   Product    the sellable listings, grouped over held-for-sale assets
--   market_place_orders     Order      what a customer bought and paid for
--   market_place_tracking   Tracking   the fulfilment queue: to send, in transit, delivered
--   market_place_settings   Settings   storefront configuration
-- ============================================================
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('market_place_products', 'view', 'market_place_products_view', 'Read the Market Place product listings',        'operations'),
  ('market_place_orders',   'view', 'market_place_orders_view',   'Read Market Place customer orders',             'operations'),
  ('market_place_tracking', 'view', 'market_place_tracking_view', 'Read the Market Place fulfilment queue',        'operations'),
  ('market_place_settings', 'view', 'market_place_settings_view', 'Read the Market Place storefront settings',     'operations')

-- >>>
-- ============================================================
-- 2. Super Admin holds all four.
--
-- `LOWER(TRIM(r.name))` because the role name is typed by hand and has arrived as 'Super Admin',
-- 'super admin' and with a trailing space on different installations.
-- ============================================================
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('market_place_products', 'market_place_orders',
                      'market_place_tracking', 'market_place_settings')

-- >>>
-- ============================================================
-- 3. Verification, to be read by a person.
--
-- `scripts/run-sql.js` does not print result sets, so running this file proves only that the
-- statement parses. Run it in a client to see the numbers: 4 permissions, and 4 grants for as
-- many roles as are named 'super admin'.
-- ============================================================
SELECT
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` LIKE 'market\_place\_%') AS market_place_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r ON r.`id` = rp.`role_id`
    WHERE p.`module` LIKE 'market\_place\_%'
      AND LOWER(TRIM(r.`name`)) = 'super admin') AS super_admin_grants
