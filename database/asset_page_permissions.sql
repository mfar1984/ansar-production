-- ============================================================================
-- ONE PERMISSION MODULE PER ASSET MANAGEMENT PAGE
--
-- Idempotent. Safe to run twice.
--
-- ── THE PROBLEM THIS FIXES ──
--
-- `assets_internal_view` gated EIGHT screens and `assets_external_view` gated FIVE. Roles
-- Management therefore offered two checkboxes for thirteen pages: granting somebody the
-- Checkout counter also granted them the stock take, the disposal register, the loan approval
-- queue and every report. There was no way to express "this clerk issues equipment" without
-- also expressing "this clerk writes equipment off".
--
-- Asset Settings was already granular — `asset_categories`, `asset_repair_categories`,
-- `asset_models`, `asset_locations`, `asset_sites` are five modules for five lists — so this
-- brings the working screens up to the shape the settings screens already had.
--
-- ── WHAT `assets_internal` AND `assets_external` MEAN AFTERWARDS ──
--
-- The REGISTER, and nothing else: the `assets` table itself. Asset Register and Installed Base.
-- Their seven actions already describe exactly that screen's toolbar — view, create, edit,
-- delete, assign, dispose, export — and every one of them still governs a real button, so
-- neither module is reduced to a dead checkbox.
--
-- ── THE TWO ACTIONS THAT ARE RETIRED, AND WHY THEY CANNOT SIMPLY STAY ──
--
--   `assets_internal_stocktake`  became `asset_stocktake_approve`
--   `assets_internal_approve`    became `asset_loan_requests_approve` + `_reject`
--
-- Both were bolted onto `assets_internal` because there was no module for the page that owned
-- them. Now there is. Leaving them behind would put two checkboxes in the matrix that grant
-- nothing, which is the exact clutter `database/payroll_approval_cleanup.sql` was written to
-- remove, and a reader cannot tell a dead permission from a live one by looking at it.
--
-- `asset_checkout_stocktake.sql` and `asset_loan_requests.sql` seeded those two rows. Both files
-- have had that seeding removed, so this deletion is not undone by replaying them on a machine
-- that has never run them. Neither file is in the production MIGRATIONS list, so production has
-- never run either one.
--
-- ── THE BACKFILL IS THE HALF THAT MATTERS ON A LIVE DATABASE ──
--
-- A new permission that nobody holds is a screen that has DISAPPEARED. Worse than that: the
-- client-side `hasPermission` is a plain `includes` with no Super Admin shortcut, so an ungranted
-- permission hides the menu entry and the page from the Super Admin too, while the API would
-- still have allowed it. So every new permission is granted to every role that already held the
-- permission which used to govern that act. Nobody's authority changes on the day this runs;
-- what changes is that it can now be taken away one page at a time.
-- ============================================================================

-- >>>
-- ============================================================
-- 1. The 32 new permissions, 10 modules, in sidebar order.
--
-- `category = 'operations'` on every row: they sit in the Operations section of the matrix
-- beside the two register modules they were split out of.
--
-- ACTION SETS ARE READ OFF THE ENDPOINT, not guessed:
--
--   asset_checkout      GET / POST issue / PUT return / DELETE   -> view create edit delete
--   asset_loan_requests GET / POST decide / PUT issue+PATCH recv -> view approve reject edit
--   asset_maintenance   GET / history POST / PUT / DELETE        -> view create edit delete
--   asset_disposal      GET / POST record / DELETE reverse       -> view create delete
--                       no `edit`: disposals.ts has no PUT, because a disposal record is
--                       evidence and is reversed rather than rewritten
--   asset_stocktake     GET / POST open / PUT / reconcile / DEL  -> view create edit approve delete
--   asset_reports       GET / GET export=1                       -> view export
--   asset_obligations   GET only                                 -> view
--                       coverage.ts is read-only; the screen links to the register to change
--                       anything, so there is no create/edit/delete to grant
--   asset_transitions   GET / POST handover / POST recovery       -> view create edit
--   asset_external_maintenance                                   -> view create edit delete
--   asset_external_reports                                       -> view export
-- ============================================================
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('asset_checkout', 'view',   'asset_checkout_view',   'Read the equipment checkout and loan lists',   'operations'),
  ('asset_checkout', 'create', 'asset_checkout_create', 'Issue equipment at the counter',               'operations'),
  ('asset_checkout', 'edit',   'asset_checkout_edit',   'Record equipment coming back',                 'operations'),
  ('asset_checkout', 'delete', 'asset_checkout_delete', 'Delete a checkout record',                     'operations'),

  ('asset_loan_requests', 'view',    'asset_loan_requests_view',    'Read the staff loan request queue',            'operations'),
  ('asset_loan_requests', 'approve', 'asset_loan_requests_approve', 'Approve a staff request to borrow equipment',  'operations'),
  ('asset_loan_requests', 'reject',  'asset_loan_requests_reject',  'Refuse a staff request to borrow equipment',   'operations'),
  ('asset_loan_requests', 'edit',    'asset_loan_requests_edit',    'Hand approved equipment over and receive it back', 'operations'),

  ('asset_maintenance', 'view',   'asset_maintenance_view',   'Read internal maintenance and repair rounds', 'operations'),
  ('asset_maintenance', 'create', 'asset_maintenance_create', 'Record a service against internal equipment', 'operations'),
  ('asset_maintenance', 'edit',   'asset_maintenance_edit',   'Amend an internal service round',             'operations'),
  ('asset_maintenance', 'delete', 'asset_maintenance_delete', 'Delete an internal service record or round',  'operations'),

  ('asset_disposal', 'view',   'asset_disposal_view',   'Read the internal disposal and write-off register', 'operations'),
  ('asset_disposal', 'create', 'asset_disposal_create', 'Record a disposal or write-off',                    'operations'),
  ('asset_disposal', 'delete', 'asset_disposal_delete', 'Reverse a recorded disposal',                       'operations'),

  ('asset_stocktake', 'view',    'asset_stocktake_view',    'Read a stock take session and its counts',      'operations'),
  ('asset_stocktake', 'create',  'asset_stocktake_create',  'Open a stock take session',                     'operations'),
  ('asset_stocktake', 'edit',    'asset_stocktake_edit',    'Enter counts and change a session state',       'operations'),
  ('asset_stocktake', 'approve', 'asset_stocktake_approve', 'Reconcile a stock take, writing lost onto missing equipment', 'operations'),
  ('asset_stocktake', 'delete',  'asset_stocktake_delete',  'Delete a stock take session',                   'operations'),

  ('asset_reports', 'view',   'asset_reports_view',   'Read the internal asset reports',   'operations'),
  ('asset_reports', 'export', 'asset_reports_export', 'Export an internal asset report',   'operations'),

  ('asset_obligations', 'view', 'asset_obligations_view', 'Read client coverage and obligations', 'operations'),

  ('asset_transitions', 'view',   'asset_transitions_view',   'Read the handover and recovery worklist', 'operations'),
  ('asset_transitions', 'create', 'asset_transitions_create', 'Hand ownership of equipment to a client',  'operations'),
  ('asset_transitions', 'edit',   'asset_transitions_edit',   'Recover equipment from a client site',     'operations'),

  ('asset_external_maintenance', 'view',   'asset_external_maintenance_view',   'Read maintenance and repair rounds at client sites', 'operations'),
  ('asset_external_maintenance', 'create', 'asset_external_maintenance_create', 'Record a service against equipment at a client site', 'operations'),
  ('asset_external_maintenance', 'edit',   'asset_external_maintenance_edit',   'Amend an external service round',                     'operations'),
  ('asset_external_maintenance', 'delete', 'asset_external_maintenance_delete', 'Delete an external service record or round',          'operations'),

  ('asset_external_reports', 'view',   'asset_external_reports_view',   'Read the external asset reports', 'operations'),
  ('asset_external_reports', 'export', 'asset_external_reports_export', 'Export an external asset report', 'operations')

-- >>>
-- ============================================================
-- 2. Super Admin holds every one of them.
-- ============================================================
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('asset_checkout', 'asset_loan_requests', 'asset_maintenance',
                      'asset_disposal', 'asset_stocktake', 'asset_reports',
                      'asset_obligations', 'asset_transitions',
                      'asset_external_maintenance', 'asset_external_reports')

-- >>>
-- ============================================================
-- 3. THE BACKFILL.
--
-- One statement, 32 pairs, one per new permission: every role that holds the OLD permission
-- which used to govern an act receives the NEW permission for the same act. No role gains or
-- loses authority today.
--
-- It reads `assets_internal_stocktake` and `assets_internal_approve`, so it MUST run before
-- statement 4 deletes them. That ordering is the whole reason they are separate statements.
--
-- `INSERT IGNORE` against `role_permissions`'s primary key is what makes a second run a no-op.
-- ============================================================
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT rp.`role_id`, np.`id`
  FROM `role_permissions` rp
  JOIN `permissions` op ON op.`id` = rp.`permission_id`
  JOIN (
              SELECT 'assets_internal_view'      AS old_name, 'asset_checkout_view'      AS new_name
    UNION ALL SELECT 'assets_internal_edit',      'asset_checkout_create'
    UNION ALL SELECT 'assets_internal_edit',      'asset_checkout_edit'
    UNION ALL SELECT 'assets_internal_delete',    'asset_checkout_delete'

    UNION ALL SELECT 'assets_internal_view',      'asset_loan_requests_view'
    UNION ALL SELECT 'assets_internal_approve',   'asset_loan_requests_approve'
    UNION ALL SELECT 'assets_internal_approve',   'asset_loan_requests_reject'
    UNION ALL SELECT 'assets_internal_edit',      'asset_loan_requests_edit'

    UNION ALL SELECT 'assets_internal_view',      'asset_maintenance_view'
    UNION ALL SELECT 'assets_internal_edit',      'asset_maintenance_create'
    UNION ALL SELECT 'assets_internal_edit',      'asset_maintenance_edit'
    UNION ALL SELECT 'assets_internal_delete',    'asset_maintenance_delete'

    UNION ALL SELECT 'assets_internal_view',      'asset_disposal_view'
    UNION ALL SELECT 'assets_internal_dispose',   'asset_disposal_create'
    UNION ALL SELECT 'assets_internal_dispose',   'asset_disposal_delete'

    UNION ALL SELECT 'assets_internal_view',      'asset_stocktake_view'
    UNION ALL SELECT 'assets_internal_edit',      'asset_stocktake_create'
    UNION ALL SELECT 'assets_internal_edit',      'asset_stocktake_edit'
    UNION ALL SELECT 'assets_internal_stocktake', 'asset_stocktake_approve'
    UNION ALL SELECT 'assets_internal_delete',    'asset_stocktake_delete'

    UNION ALL SELECT 'assets_internal_view',      'asset_reports_view'
    UNION ALL SELECT 'assets_internal_export',    'asset_reports_export'

    UNION ALL SELECT 'assets_external_view',      'asset_obligations_view'

    UNION ALL SELECT 'assets_external_view',      'asset_transitions_view'
    UNION ALL SELECT 'assets_external_assign',    'asset_transitions_create'
    UNION ALL SELECT 'assets_external_edit',      'asset_transitions_edit'

    UNION ALL SELECT 'assets_external_view',      'asset_external_maintenance_view'
    UNION ALL SELECT 'assets_external_edit',      'asset_external_maintenance_create'
    UNION ALL SELECT 'assets_external_edit',      'asset_external_maintenance_edit'
    UNION ALL SELECT 'assets_external_delete',    'asset_external_maintenance_delete'

    UNION ALL SELECT 'assets_external_view',      'asset_external_reports_view'
    UNION ALL SELECT 'assets_external_export',    'asset_external_reports_export'
  ) m ON m.old_name = op.`name`
  JOIN `permissions` np ON np.`name` = m.new_name

-- >>>
-- ============================================================
-- 4. Retire the two actions that now govern nothing.
--
-- The grants go first. There is a foreign key from `role_permissions.permission_id`, so
-- deleting the permission row while a grant still points at it either fails or cascades
-- depending on the constraint, and neither is a thing to leave to chance.
-- ============================================================
DELETE rp
  FROM `role_permissions` rp
  JOIN `permissions` p ON p.`id` = rp.`permission_id`
 WHERE p.`module` = 'assets_internal'
   AND p.`action` IN ('stocktake', 'approve')

-- >>>
DELETE FROM `permissions`
 WHERE `module` = 'assets_internal'
   AND `action` IN ('stocktake', 'approve')

-- >>>
-- ============================================================
-- 5. VERIFICATION.
--
-- `run-sql.js` does not print result sets, so this proves the statement parses and is here to be
-- run by hand afterwards. Expected on a database that has run everything above:
--
--   new_permissions    32
--   super_admin_grants 32
--   retired_rows        0
--   register_actions   14   (7 on assets_internal + 7 on assets_external)
-- ============================================================
SELECT
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` IN ('asset_checkout', 'asset_loan_requests', 'asset_maintenance',
                       'asset_disposal', 'asset_stocktake', 'asset_reports',
                       'asset_obligations', 'asset_transitions',
                       'asset_external_maintenance', 'asset_external_reports')) AS new_permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` IN ('asset_checkout', 'asset_loan_requests', 'asset_maintenance',
                         'asset_disposal', 'asset_stocktake', 'asset_reports',
                         'asset_obligations', 'asset_transitions',
                         'asset_external_maintenance', 'asset_external_reports')) AS super_admin_grants,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'assets_internal' AND `action` IN ('stocktake', 'approve')) AS retired_rows,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` IN ('assets_internal', 'assets_external')) AS register_actions
