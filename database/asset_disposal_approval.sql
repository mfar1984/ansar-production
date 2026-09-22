-- ════════════════════════════════════════════════════════════════════════════
-- ASSET DISPOSAL — THE APPROVAL CHAIN
-- ════════════════════════════════════════════════════════════════════════════
--
-- Writing a company asset off stops being a single act and becomes a REQUEST that a named
-- person signs. Recording one already captured when, why, under whose authority and what
-- it was worth; what it could not do was stop the recorder being the only person involved.
--
-- ── WHAT THIS CHANGES ABOUT THE REGISTER, AND WHY IT IS THE POINT ──
--
-- Before: one transaction wrote the disposal row, moved `assets.status` to disposed, and
-- wrote a movement. The asset left the register's value the instant somebody pressed the
-- button.
--
-- After: recording writes the row with `status = 'pending'` and TOUCHES NOTHING ELSE. The
-- asset keeps its status, keeps its book value and stays in every report until the LAST
-- approval level signs. That is not a nicety — a pending write-off that had already
-- removed the asset from the register's value would mean a refusal could not put things
-- back, because a month-end report may already have been run against the gap.
--
-- ── THE FREE-TEXT `approved_by` AND `approval_ref` STAY, AND THAT IS DELIBERATE ──
--
-- They look like exactly what this chain replaces. They are not. `asset_disposals.sql`
-- records what they are for: an approval may come from a DIRECTOR, a COMMITTEE or a
-- CLIENT, and `approval_ref` is where a board minute number or a memo reference goes.
-- That is authority from OUTSIDE this application, and no in-system chain can hold it.
--
-- So the two answer different questions and both are worth keeping:
--
--   approved_by / approval_ref   who authorised it in the real world, and under what paper
--   status / current_level       who signed it off IN THIS SYSTEM, and how far it has got
--
-- Deleting the free text would lose the minute number; skipping the chain would leave the
-- register with no in-system accountability at all.
--
-- ── WHY THE `status` DEFAULT IS `approved` AND NOT `pending` ──
--
-- The ALTER has to backfill EVERY EXISTING ROW, and every existing row is a disposal that
-- ALREADY happened: its asset has already been moved and its movement has already been
-- written. Defaulting to `pending` would retroactively declare every historical write-off
-- unapproved, and the screen would then show a queue of things that were settled years ago
-- while their assets sat disposed — a contradiction the reader cannot resolve.
--
-- `approved` is therefore the honest backfill. The endpoint NAMES the column explicitly on
-- every insert, so the default is never what decides a new row.
--
-- ── `rejected` IS A REAL STATE, NOT A DELETION ──
--
-- A refused disposal is evidence that somebody asked and was told no. It keeps its row, its
-- reason and its trail. `asset_disposals` has `UNIQUE KEY uq_disposal_asset (asset_id)`, so
-- a rejected row still occupies its asset's one slot — which is correct while the refusal
-- stands, and is cleared the same way a mistake always was: `asset_disposal_delete`.
--
-- ── WHAT THIS FILE DOES *NOT* DO ──
--
-- It creates no table. `status` and `current_level` are the only two columns the shared
-- engine needs on a module's own table; `recorded_by` and `created_at` already say who
-- asked and when, so no `submitted_by` or `submitted_at` is added — two columns holding a
-- copy of two others is two chances for them to disagree.
--
-- It seeds NO `hr_module_settings` rows. `getModuleSettings()` fills every key in
-- `NOTIFICATION_KEYS` when it is unset, so seeded rows holding exactly the defaults would
-- mean nothing. This note exists so the absence reads as a decision.
--
-- ── IT NEEDS `asset_disposals.sql`, AND SURVIVES THE WRONG ORDER ──
--
-- Every ALTER is guarded on its table AND its column through a PREPARE. A bare `IF()` is
-- not enough, and `market_place_settings.sql` records why: MySQL RESOLVES BOTH BRANCHES of
-- an `IF()` at prepare time, so an `IF()` naming a column on a table that does not exist
-- fails with ER_NO_SUCH_TABLE before the guard is ever read. Run this first and it reports
-- 0 for what it skipped; apply `asset_disposals.sql` and run it again.
--
-- IDEMPOTENT. Production applies it by hand, and a hand runs things twice.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Does the table exist? ──
SET @ad_table := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
)
-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 2. `status` — WHERE THE DISPOSAL HAS GOT TO
-- ════════════════════════════════════════════════════════════════════════════
--
-- Three values, and the ORDER is the lifecycle rather than the alphabet, because
-- `ORDER BY status` on an ENUM sorts by DECLARATION order. `pending` first is what puts the
-- queue at the top of a sorted list.
--
-- `approved` and `rejected` are the words the SHARED ENGINE writes. Unlike
-- `market_place_products` — whose column holds neither, so its call site has to map them —
-- this ENUM uses the engine's own vocabulary, so no `statusWords` mapping is needed and
-- none is passed. Worth stating, because the two modules look inconsistent side by side and
-- the difference is in the column, not the caller.
SET @ad_status := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
     AND COLUMN_NAME = 'status'
)
-- >>>
SET @sql := IF(@ad_table = 1 AND @ad_status = 0,
  'ALTER TABLE `asset_disposals`
     ADD COLUMN `status` ENUM(''pending'', ''approved'', ''rejected'')
         NOT NULL DEFAULT ''approved''
         COMMENT ''DEFAULT approved so the ALTER backfills history correctly; the endpoint always names it''
         AFTER `previous_status`',
  'SELECT ''status: already present, or asset_disposals is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 3. `current_level` — HOW MANY LEVELS HAVE SIGNED
-- ════════════════════════════════════════════════════════════════════════════
--
-- 0 means nobody has. `checkApproverTurn` reads this to decide whose turn it is, so it is
-- not derivable from the trail: a disposal submitted and not yet signed has ZERO trail rows
-- and still has to be able to say which level it is waiting on.
--
-- Guarded separately from `status`. A half-applied first run may have landed one and not the
-- other, and re-adding an existing column is an error rather than a no-op.
SET @ad_level := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
     AND COLUMN_NAME = 'current_level'
)
-- >>>
SET @sql := IF(@ad_table = 1 AND @ad_level = 0,
  'ALTER TABLE `asset_disposals`
     ADD COLUMN `current_level` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `status`',
  'SELECT ''current_level: already present, or asset_disposals is not there yet'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ── 3a. The index the queue is read through ──
--
-- The approval screen's one hot query is "everything pending, and which level it waits on".
-- Without this it is a full scan of the disposal register, which grows for ever because a
-- disposal is never deleted in the ordinary course of things.
SET @ad_idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
     AND INDEX_NAME = 'idx_disposal_pending'
)
-- >>>
SET @sql := IF(@ad_table = 1 AND @ad_idx = 0 AND @ad_status = 0,
  'ALTER TABLE `asset_disposals`
     ADD KEY `idx_disposal_pending` (`status`, `current_level`)',
  'SELECT ''idx_disposal_pending: already present, or the columns are not new'' AS note')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 4. THE PERMISSIONS
-- ════════════════════════════════════════════════════════════════════════════
--
-- `asset_disposal` already has view, create and delete, seeded by `asset_disposals.sql`.
-- It gains `approve`, and two new modules arrive for the settings tabs.
--
-- ── WHY `approve` AND NOT `edit` ──
--
-- `asset_disposal` has no `edit` and deliberately never did: there is no PUT, because a
-- disposal record is evidence and is reversed rather than rewritten. Approving is not an
-- edit either — it is the act that moves a company asset out of the register's value. The
-- person who RECORDS a write-off must not be able to sign it off, which is the whole reason
-- the chain exists, so `create` and `approve` are separate by construction.
--
-- ── AND NO `reject` ──
--
-- Refusing SHARES `approve`. `applyApprovalAction` takes `'approve' | 'reject'` as one
-- call, and a separate permission would allow a role that can only ever say yes — which is
-- not an approver, it is a rubber stamp.
--
-- ── WHY TWO NEW MODULES AND NOT ONE ──
--
-- Naming who signs off a write-off is not the same authority as choosing which mailbox the
-- decision is emailed from, and neither is the same as recording a disposal. Equipment Loan
-- splits its two the same way — `asset_loan_approval` and `asset_loan_notifications` — and
-- these are the same two shared engines on the same two shared tables.
--
-- Four actions each, matching every sibling notification and approval module. Only view and
-- edit are reachable from the screen; create and delete are seeded for consistency with the
-- siblings rather than invented here, so a role copied from one module to another behaves
-- the same way.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('asset_disposal',               'approve', 'asset_disposal_approve',
   'Approve or refuse a submitted asset disposal', 'operations'),
  ('asset_disposal_approval',      'view',    'asset_disposal_approval_view',
   'Read the asset disposal approval chain', 'operations'),
  ('asset_disposal_approval',      'create',  'asset_disposal_approval_create',
   'Add an asset disposal approval level', 'operations'),
  ('asset_disposal_approval',      'edit',    'asset_disposal_approval_edit',
   'Change an asset disposal approval level', 'operations'),
  ('asset_disposal_approval',      'delete',  'asset_disposal_approval_delete',
   'Remove an asset disposal approval level', 'operations'),
  ('asset_disposal_notifications', 'view',    'asset_disposal_notifications_view',
   'Read asset disposal notification settings', 'operations'),
  ('asset_disposal_notifications', 'create',  'asset_disposal_notifications_create',
   'Add asset disposal notification settings', 'operations'),
  ('asset_disposal_notifications', 'edit',    'asset_disposal_notifications_edit',
   'Change asset disposal notification settings', 'operations'),
  ('asset_disposal_notifications', 'delete',  'asset_disposal_notifications_delete',
   'Remove asset disposal notification settings', 'operations')
-- >>>
-- ── 4a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `usePermissions` joins through
-- `role_permissions`, so an ungranted permission makes the control INVISIBLE rather than
-- denied — which reads as a broken screen rather than as a permission to ask for.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND (p.`module` IN ('asset_disposal_approval', 'asset_disposal_notifications')
        OR (p.`module` = 'asset_disposal' AND p.`action` = 'approve'))
-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 5. WHAT LANDED
-- ════════════════════════════════════════════════════════════════════════════
--
-- Read this after running the file. Every figure is what it should be on a database that
-- already has `asset_disposals`; a 0 where a 1 is expected names the thing that did not
-- apply rather than leaving the reader to guess.
--
-- `pending_after` is the one worth reading twice: it must be 0 on a first run against
-- existing history. Anything else means the backfill declared settled write-offs unapproved.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
      AND COLUMN_NAME = 'status')                                          AS status_col,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
      AND COLUMN_NAME = 'current_level')                                   AS level_col,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_disposals'
      AND INDEX_NAME = 'idx_disposal_pending')                             AS pending_idx,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'asset_disposal' AND `action` = 'approve')            AS approve_perm,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'asset_disposal_approval')                            AS approval_perms,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'asset_disposal_notifications')                       AS notify_perms,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND (p.`module` IN ('asset_disposal_approval', 'asset_disposal_notifications')
           OR (p.`module` = 'asset_disposal' AND p.`action` = 'approve'))) AS granted_to_super,
  (SELECT COUNT(*) FROM `asset_disposals`)                                 AS disposals,
  (SELECT COUNT(*) FROM `asset_disposals` WHERE `status` = 'pending')       AS pending_after
