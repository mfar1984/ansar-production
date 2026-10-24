-- ============================================================================================
-- WORK ORDER MODULE - permissions: SIX modules, 28 rows, granted to Super Admin
--
-- Design: .agents/pipeline/2026-10-24_00-59-07/02-design.md section 8.2
--
-- Run:  node scripts/run-sql.js database/work_order_permissions.sql
--
-- IDEMPOTENT. `INSERT IGNORE` against the unique index on `permissions`.`name`, and again on
-- `role_permissions`, so a second run adds nothing.
--
-- `category` is 'operations', LOWERCASE. The Roles matrix groups by `permissions`.`category` and
-- the rows living in this database are lowercase.
--
-- ── THE SUPER ADMIN GRANT IS NOT DECORATION ──
--
-- `leafVisible()` calls `has(leaf.perm)`, and `usePermissions` joins through `role_permissions`.
-- The SERVER has a Super Admin shortcut; the CLIENT does not. So an ungranted permission makes
-- the control INVISIBLE rather than refused - which reads as a broken screen, with no error
-- anywhere to explain it.
--
-- ── MUST SHIP WITH `src/lib/permission-modules.ts` IN THE SAME CHANGE ──
--
-- `tests/sql/roles-endpoints.sql.test.js` reads `MODULE_ORDER` out of that source file and
-- `SELECT DISTINCT module FROM permissions` out of this database, and it fails BOTH directions:
-- a module listed with no permissions, and a module holding permissions but absent from the
-- list. Seeding these 28 rows without the six `MODULE_ORDER` entries is red; adding the entries
-- without these rows is red.
--
-- ── SIX MODULES, AND EACH SPLIT IS JUSTIFIED BY A DIFFERENT AUDIENCE ──
--
--   work_orders               10  the register and the whole lifecycle
--   work_order_types           4  master data, shaped on `asset_repair_categories`
--   work_order_templates       4  master data, shaped on `project_templates`
--   work_order_settings        2  the Numbering tab. Nothing to create, nothing to delete
--   work_order_approval        4  shaped on `asset_disposal_approval`
--   work_order_notifications   4  shaped on `asset_disposal_notifications`
-- ============================================================================================

-- >>>
-- ── 1. The register, and TEN actions read off its toolbar rather than guessed ──
--
-- `issue`, `complete`, `close` and `cancel` are NOT folded into `_edit`, because each governs a
-- named button with a distinct consequence and merging any one of them would grant the others:
--
--   issue     commits a draft and raises the approval request. A clerk who DRAFTS work orders
--             is not automatically the person who commits the company to them.
--   complete  is the technician's sign-off, including ticking checklist steps. Without it,
--             anybody who may tick a step may also reassign the job and move its date.
--   close     writes a row into `asset_maintenance` - ANOTHER MODULE'S TABLE - and accepts the
--             cost. It additionally requires that module's own `_create`, checked server-side.
--   cancel    keeps the record as evidence; `delete` erases it. The same distinction
--             `assets_internal_dispose` already draws against `_delete`.
--
-- No `_export` action. Nothing exports in this release, and a checkbox granting nothing is
-- worse than its absence.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_orders', 'view',     'work_orders_view',     'View the work order register and a work order',          'operations'),
  ('work_orders', 'create',   'work_orders_create',   'Raise a work order',                                     'operations'),
  ('work_orders', 'edit',     'work_orders_edit',     'Update a work order, its schedule and its assignee',     'operations'),
  ('work_orders', 'delete',   'work_orders_delete',   'Delete a work order',                                    'operations'),
  ('work_orders', 'issue',    'work_orders_issue',    'Issue a draft work order for approval',                  'operations'),
  ('work_orders', 'approve',  'work_orders_approve',  'Approve a work order that is waiting to be issued',      'operations'),
  ('work_orders', 'reject',   'work_orders_reject',   'Reject a work order that is waiting to be issued',        'operations'),
  ('work_orders', 'complete', 'work_orders_complete', 'Tick checklist steps and sign the work off as completed','operations'),
  ('work_orders', 'close',    'work_orders_close',    'Close a completed work order and record its cost',       'operations'),
  ('work_orders', 'cancel',   'work_orders_cancel',   'Cancel a work order and keep it as a record',            'operations')

-- >>>
-- ── 2. Types ──
--
-- Master data: the kinds of work, with their icon, their default checklist and the repair
-- category a closed asset job defaults to. Shaped on `asset_repair_categories`, which is the
-- same kind of table edited by the same kind of person.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_types', 'view',   'work_order_types_view',   'View work order types',   'operations'),
  ('work_order_types', 'create', 'work_order_types_create', 'Add a work order type',   'operations'),
  ('work_order_types', 'edit',   'work_order_types_edit',   'Update a work order type','operations'),
  ('work_order_types', 'delete', 'work_order_types_delete', 'Delete a work order type','operations')

-- >>>
-- ── 3. Templates ──
--
-- Shaped on `project_templates`. Writing a checklist that every future job of that kind will
-- carry is a different job from raising one work order.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_templates', 'view',   'work_order_templates_view',   'View work order checklist templates',    'operations'),
  ('work_order_templates', 'create', 'work_order_templates_create', 'Add a work order checklist template',    'operations'),
  ('work_order_templates', 'edit',   'work_order_templates_edit',   'Update a work order checklist template', 'operations'),
  ('work_order_templates', 'delete', 'work_order_templates_delete', 'Delete a work order checklist template', 'operations')

-- >>>
-- ── 4. Settings: TWO actions, and that is the whole of it ──
--
-- The Numbering tab edits a row this migration already INSERTed, so there is nothing to create
-- and nothing to delete. `project_settings` ships with the same two for the same reason, and
-- the label in `MODULE_LABEL` reads 'Work Order Settings: Numbering' so one concept keeps one
-- spelling. There is no `work_order_numbering` PERMISSION - only the table of that name.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_settings', 'view', 'work_order_settings_view', 'View work order numbering settings',   'operations'),
  ('work_order_settings', 'edit', 'work_order_settings_edit', 'Change work order numbering settings', 'operations')

-- >>>
-- ── 5. Approval ──
--
-- FOUR actions, and the two beyond view/edit are load bearing here: `ApprovalWorkflow.tsx`
-- derives its Add and Remove buttons from `${permModule}_create` and `${permModule}_delete`,
-- and `/api/admin/hr/approval` demands `create` on POST and `delete` on DELETE. Without them
-- the Approval tab renders with no way to add a level - a screen that looks broken rather than
-- a permission to be asked for. `project_approval` shipped with two and had to be corrected.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_approval', 'view',   'work_order_approval_view',   'View the work order approval chain',       'operations'),
  ('work_order_approval', 'create', 'work_order_approval_create', 'Add a work order approval level',          'operations'),
  ('work_order_approval', 'edit',   'work_order_approval_edit',   'Update a work order approval level',       'operations'),
  ('work_order_approval', 'delete', 'work_order_approval_delete', 'Remove a work order approval level',       'operations')

-- >>>
-- ── 6. Notifications - FOUR actions, and TWO OF THEM GATE NOTHING TODAY ──
--
-- Measured, and stated plainly rather than implied: `ModuleNotifications.tsx` reads only
-- `${permModule}_edit`, and `src/pages/api/admin/hr/module-settings.ts` demands only `view` and
-- `edit`. So `work_order_notifications_create` and `_delete` control no button and no endpoint
-- in this release.
--
-- They ship anyway, and the reason is consistency of the Roles screen rather than capability:
-- `asset_disposal_notifications` and `project_notifications` both carry four, so a Work Order
-- row showing two would read as an omission next to its two siblings. Dropping them would also
-- change the count, the matrix, the seed and the suite for no gain.
--
-- This is NOT the same thing as inventing an `_export` checkbox: that would name a capability
-- that exists nowhere. These two match a shape that exists in two shipped modules. The
-- dishonest part would be claiming they gate something - so they do not claim it.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_notifications', 'view',   'work_order_notifications_view',
   'View work order notification settings', 'operations'),
  ('work_order_notifications', 'create', 'work_order_notifications_create',
   'Add a work order notification setting. Matches the sibling modules; gates no control today.', 'operations'),
  ('work_order_notifications', 'edit',   'work_order_notifications_edit',
   'Change work order notification settings', 'operations'),
  ('work_order_notifications', 'delete', 'work_order_notifications_delete',
   'Remove a work order notification setting. Matches the sibling modules; gates no control today.', 'operations')

-- >>>
-- ── 7. Grant all 28 to Super Admin, and to no other role ──
--
-- `LOWER(TRIM(r.name)) = 'super admin'` - the live role is named exactly "Super Admin",
-- verified before this file was written. `project_phase_approval.sql` uses the same predicate.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('work_orders', 'work_order_types', 'work_order_templates',
                      'work_order_settings', 'work_order_approval', 'work_order_notifications')

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
--
-- EXPECTED - six rows, and `actions` must equal `grants` on every one of them:
--
--   operations  work_orders               actions 10  grants 10
--   operations  work_order_types          actions  4  grants  4
--   operations  work_order_templates      actions  4  grants  4
--   operations  work_order_settings       actions  2  grants  2
--   operations  work_order_approval       actions  4  grants  4
--   operations  work_order_notifications  actions  4  grants  4
--
-- 28 rows in total. `permissions` held 750 before this file; it holds 778 after.
--
-- A module reading `grants 0` means the Super Admin role was not found, and the Work Order
-- section of the sidebar will be INVISIBLE even though every permission exists.
-- ════════════════════════════════════════════════════════════════════════════════════════════
SELECT p.`category`, p.`module`, COUNT(*) AS actions,
       SUM((SELECT COUNT(*) FROM `role_permissions` rp
             JOIN `roles` r ON r.`id` = rp.`role_id`
            WHERE rp.`permission_id` = p.`id`
              AND LOWER(TRIM(r.`name`)) = 'super admin')) AS grants,
       (SELECT COUNT(*) FROM `permissions`)               AS permissions_total
  FROM `permissions` p
 WHERE p.`module` IN ('work_orders', 'work_order_types', 'work_order_templates',
                      'work_order_settings', 'work_order_approval', 'work_order_notifications')
 GROUP BY p.`category`, p.`module`
 ORDER BY FIELD(p.`module`, 'work_orders', 'work_order_types', 'work_order_templates',
                'work_order_settings', 'work_order_approval', 'work_order_notifications')
