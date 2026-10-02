-- ═══════════════════════════════════════════════════════════════════════════════
-- APPLICATION > STRATEGIC PARTNER — `partners_create`, so an application can be keyed in
--
-- WHY THE PERMISSION DID NOT EXIST
--
-- The `partners` module was seeded with view, edit, delete, approve and reject — and no
-- `create`. That was not an omission; it was the model saying out loud that nobody creates
-- a strategic partnership application. Applicants create them, through the public form at
-- /business/partners, and the admin screen exists to review what arrived.
--
-- WHAT CHANGED
--
-- A partner who applies by email, by telephone, or on a paper form at an event is still an
-- applicant. There was no way to get them into the review queue, so the only options were to
-- ask them to fill the web form again, or to skip the queue entirely by adding them straight
-- to the client database — which records an accepted partner nobody ever approved.
--
-- So the admin screen gains a form, and the authority to use it needs a name.
--
-- WHY NOT JUST USE `partners_edit`
--
-- Editing an application that somebody submitted and CREATING one are different authorities.
-- The second can put a company into the approval queue that never asked to be there, and the
-- reviewer at the far end cannot tell from the row whether the applicant exists. Separable or
-- the control does not exist — the same argument `accounting_permissions.sql` makes for keeping
-- credit notes apart from debit notes.
--
-- WHO IT IS GRANTED TO, AND WHY IT IS DERIVED
--
-- Every role that already holds `partners_edit`. NOT a hardcoded 'super-admin' like
-- `legal_refund_return_permissions.sql` does, and the difference is deliberate: that file
-- seeded a BRAND NEW module nobody held. This one adds an action to a module three roles
-- already hold with approve, delete, edit, reject and view. Granting it to super-admin alone
-- would leave HR & Finance able to approve and delete a partner application but not key one
-- in, which is a shape nobody chose.
--
-- Derived from the grants rather than listed, so it is correct on a server whose roles are not
-- the ones on this machine.
--
-- `category` is read from the module's OWN existing rows rather than written as a literal. The
-- Roles matrix groups by `permissions.category`, so a guessed value would file this action
-- under a different heading from the other five on the same module.
--
-- IDEMPOTENT. `INSERT IGNORE` against the unique index on `name`, and the grant is an
-- anti-joined INSERT IGNORE on (role_id, permission_id). Run it as many times as you like.
--
-- Run on the server:  node scripts/run-sql.js database/partner_manual_entry.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── The permission ──
--
-- The category comes from an existing `partners` row. If the module were somehow absent the
-- SELECT yields nothing and this inserts nothing, which is the right failure: a `create` action
-- on a module that does not exist would appear in the matrix under a heading of its own with
-- nothing beside it.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`)
SELECT 'partners', 'create', 'partners_create',
       'Key in a strategic partner application received outside the web form',
       p.`category`
  FROM `permissions` p
 WHERE p.`module` = 'partners'
 LIMIT 1

-- >>>
-- ── The grant: every role that may already edit a partner application ──
--
-- On this development database that is Super Admin, HR & Finance and Storekeeper, each holding
-- all five existing actions. The server may differ, which is exactly why this reads the table.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT rp.`role_id`, new_perm.`id`
  FROM `role_permissions` rp
  JOIN `permissions` edit_perm ON edit_perm.`id` = rp.`permission_id`
                              AND edit_perm.`name` = 'partners_edit'
  CROSS JOIN `permissions` new_perm
 WHERE new_perm.`name` = 'partners_create'

-- >>>
-- ── Verification ──
--
-- Expect ONE row. `actions` must be 6 — view, edit, delete, approve, reject, create — and
-- `create_grants` must equal `edit_grants`. If `create_grants` is 0 the grant matched nothing
-- and the button will be invisible to everybody including Super Admin, with nothing on screen
-- saying why; `hasPermission` is a plain list lookup with no super-admin bypass on the client.
SELECT p.`category`,
       COUNT(*) AS actions,
       (SELECT COUNT(*) FROM `role_permissions` rp
          JOIN `permissions` x ON x.`id` = rp.`permission_id`
         WHERE x.`name` = 'partners_create') AS create_grants,
       (SELECT COUNT(*) FROM `role_permissions` rp
          JOIN `permissions` x ON x.`id` = rp.`permission_id`
         WHERE x.`name` = 'partners_edit') AS edit_grants
  FROM `permissions` p
 WHERE p.`module` = 'partners'
 GROUP BY p.`category`
