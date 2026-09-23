-- ============================================================
-- HELPDESK SETTINGS — ticket categories as ROWS, and the two permission modules
--
-- WHAT THIS IS FOR
--
-- `helpdesk_tickets.category` was an ENUM of ten values fixed in the DDL:
--
--     ENUM('Hardware Issues','Software Issues','Network & Connectivity','System Performance',
--          'Security & Access','Billing & Payments','General Inquiry','Bug Report',
--          'Feature Request','Project Support')
--
-- Adding an eleventh meant an ALTER and a deploy. That is the same argument `tender_categories`,
-- `procurement_categories`, `asset_categories` and `asset_repair_categories` have already settled in
-- this schema. This file does it for the helpdesk, and it is shaped on `asset_repair_categories`
-- because that one converted an ENUM rather than starting from nothing.
--
-- It also adds the two permission modules a Helpdesk > Settings page needs:
-- `helpdesk_categories` and `helpdesk_notifications`.
--
-- ── WHY ENUM → VARCHAR AND NOT A FOREIGN KEY ──
--
-- `helpdesk_tickets.category` becomes VARCHAR(100) holding the NAME, matched to
-- `helpdesk_categories.name` by text. No foreign key. Four tables in this schema already make the
-- same bargain — `assets.category`, `tenders.category`, `asset_maintenance.kind` — and it is a
-- bargain rather than an oversight:
--
--   * A category any ticket names cannot be deleted; the endpoint refuses and deactivates instead.
--     So the dangling reference an FK would prevent is already prevented, one layer up.
--   * A rename cascades in the endpoint (`UPDATE helpdesk_tickets SET category = ?`), the same way
--     `asset-categories.ts` cascades onto `assets`.
--   * The name on the ticket IS the historical fact. A ticket raised under "Billing & Payments"
--     should still read that years later even if the master row is gone. An FK with CASCADE would
--     destroy that and an FK with RESTRICT would merely duplicate the endpoint's own refusal.
--
-- MySQL converts an ENUM to VARCHAR by writing the LABELS, not the ordinals, so every existing
-- ticket keeps the words it already had. Checked: nothing anywhere reads this column's ordinal — the
-- ticket list orders by `created_at`, never by `category`.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE COLLATION IS THE POINT OF THIS MIGRATION AS MUCH AS THE TABLE IS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- MEASURED on the live database, and it is not what the DDL claims:
--
--     helpdesk_tickets.category   utf8mb4_0900_ai_ci    <- the server default, NOT the table's
--     assets.category             utf8mb4_unicode_ci    vs asset_categories.name  unicode_ci  MATCH
--     asset_maintenance.kind      utf8mb4_unicode_ci    vs asset_repair_categories unicode_ci  MATCH
--     tenders.category            utf8mb4_0900_ai_ci    vs tender_categories.name unicode_ci  MISMATCH
--
-- `create_helpdesk_system.sql` ends its CREATE with `COLLATE=utf8mb4_unicode_ci`, but the live
-- column reports `utf8mb4_0900_ai_ci`, so that clause did not reach it.
--
-- That MISMATCH on the last line is a REAL, CURRENTLY-SHIPPING FAULT, not a theoretical one. It is
-- why `tests/sql/sql-shape.test.js` has a permanent failure on
-- `src/pages/api/public/tenders/index.ts:44` with ER_CANT_AGGREGATE_2COLLATIONS. Proven here by
-- running a deliberately mismatched join against this database, which threw:
--
--     Illegal mix of collations (utf8mb4_0900_ai_ci,IMPLICIT) and (utf8mb4_unicode_ci,IMPLICIT)
--
-- So creating `helpdesk_categories.name` as `utf8mb4_unicode_ci` — which is what every sibling
-- migration does — while leaving the ticket column at `0900_ai_ci` would have reproduced that exact
-- bug on a brand-new screen. The moment any endpoint joined the two, it would throw.
--
-- The fix is free, because this migration already restates the whole column: the MODIFY sets
-- `utf8mb4_unicode_ci`, so the ticket column ends up matching its master AND matching the two pairs
-- that already work. It is not a new convention; it is the one `assets` and `asset_maintenance` use.
--
-- This file deliberately does NOT touch `tenders.category`. That fault is older than this change, it
-- belongs to a different screen, and repairing it here would hide it inside a helpdesk migration.
--
-- ── NO CASE-FIXING PASS IS NEEDED, UNLIKE THE REPAIR-CATEGORIES PRECEDENT ──
--
-- `asset_repair_categories.sql` had to run five UPDATEs after its conversion, because its ENUM held
-- lowercase labels ('preventive') while the master's names were capitalised. Verified here: all ten
-- helpdesk labels are ALREADY capitalised exactly as they will be seeded, so the converted rows match
-- their master rows with no rewriting at all. The absence of those UPDATEs is a measurement, not an
-- omission.
--
-- THE SEED IS THE TEN THAT EXIST
--
-- So the day this runs, the category dropdown offers exactly what it offered before and every
-- existing ticket still validates. The migration changes what is POSSIBLE, not what is there.
-- `sort_order` preserves the ENUM's own order, because that is the order the public form has always
-- shown and a reshuffle would look like a change nobody asked for.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/helpdesk_settings.sql
-- ============================================================

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 1. THE MASTER
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Shaped on `asset_repair_categories`: a name, an icon for the screen, a note, a sort order and an
-- active flag. No `expects_next_due` equivalent — that was specific to a category of WORK, and this
-- is a category of PROBLEM.
--
-- `name` is VARCHAR(100) and so is the ticket column below, deliberately the same width: a category
-- that can be created but not stored on a ticket would fail on insert with a truncation the operator
-- cannot act on. The longest seeded label is 'Network & Connectivity' at 22 characters, so 100 is
-- room rather than a constraint.
--
-- COLLATE on the column, not just the table. The table-level clause is what failed to reach
-- `helpdesk_tickets.category`, so it is not trusted here.
CREATE TABLE IF NOT EXISTS `helpdesk_categories` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `icon`       VARCHAR(60)  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'bi-tag-fill',
  `notes`      VARCHAR(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sort_order` INT          NOT NULL DEFAULT 0,
  -- Deactivated rather than deleted is the NORMAL retirement for a category tickets already name.
  -- An inactive row disappears from the public form and stays readable on every ticket that used it.
  `is_active`  TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- UNIQUE on the name, because the name IS the key the tickets carry. Two rows called
  -- "Hardware Issues" would make a rename cascade ambiguous.
  UNIQUE KEY `uq_helpdesk_category_name` (`name`),
  KEY `idx_helpdesk_category_active` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 2. THE SEED — the ten the ENUM already held, in the ENUM's own order
-- ══════════════════════════════════════════════════════════════════════════════
--
-- INSERT IGNORE against the UNIQUE name, so a second run adds nothing and, more importantly, does NOT
-- reset a name, icon, note or sort order somebody has since changed on the Categories screen. The
-- same guard `asset_disposal_accounting.sql` uses for its own seed, and for the same reason.
INSERT IGNORE INTO `helpdesk_categories` (`name`, `icon`, `sort_order`) VALUES
  ('Hardware Issues',        'bi-cpu-fill',              1),
  ('Software Issues',        'bi-window-stack',          2),
  ('Network & Connectivity', 'bi-router-fill',           3),
  ('System Performance',     'bi-speedometer2',          4),
  ('Security & Access',      'bi-shield-lock-fill',      5),
  ('Billing & Payments',     'bi-receipt',               6),
  ('General Inquiry',        'bi-question-circle-fill',  7),
  ('Bug Report',             'bi-bug-fill',              8),
  ('Feature Request',        'bi-lightbulb-fill',        9),
  ('Project Support',        'bi-kanban-fill',          10)

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 3. THE TICKET COLUMN — ENUM to VARCHAR, and into the matching collation
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Guarded on DATA_TYPE, not on the column's existence. `category` has always been there; what this
-- changes is its TYPE. A guard on existence would be satisfied on the first run and would never
-- convert anything — the mistake `asset_repair_categories.sql` records for the same reason.
SET @hd_cat_type := (
  SELECT DATA_TYPE FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'helpdesk_tickets'
     AND COLUMN_NAME = 'category'
)

-- >>>
-- The whole definition is restated, because MODIFY COLUMN REPLACES rather than amends: anything left
-- out is lost. Read from the live column, not guessed:
--
--     NOT NULL         yes  — a ticket with no category is a ticket nobody can route
--     DEFAULT          NONE — there was none, and inventing one would let an insert that forgot the
--                             field succeed quietly with a category nobody chose
--     COLLATE          CHANGED, on purpose, from utf8mb4_0900_ai_ci to utf8mb4_unicode_ci so this
--                      column and `helpdesk_categories.name` can be compared at all
--
-- A bare `IF()` would not be safe here and `market_place_settings.sql` records why: MySQL resolves
-- BOTH branches of an `IF()` at prepare time, so one naming a column on a missing table fails with
-- ER_NO_SUCH_TABLE before the guard is read. The `IF()` below only picks a STRING; the statement it
-- picks is what gets prepared.
SET @hd_cat_ddl := IF(
  @hd_cat_type = 'enum',
  'ALTER TABLE `helpdesk_tickets`
     MODIFY COLUMN `category` VARCHAR(100)
       COLLATE utf8mb4_unicode_ci NOT NULL
       COMMENT ''helpdesk_categories.name, by text''',
  'DO 0'
)

-- >>>
PREPARE hd_cat_stmt FROM @hd_cat_ddl

-- >>>
EXECUTE hd_cat_stmt

-- >>>
DEALLOCATE PREPARE hd_cat_stmt

-- >>>
-- ── The SECOND run, and why this is separate from the block above ──
--
-- If the column was ALREADY varchar when this file ran — because a previous run converted it — the
-- guard above correctly does nothing, and the collation would stay whatever it was. This second guard
-- is keyed on the COLLATION rather than the type, so a half-applied first run still ends up matching
-- its master. Without it, "the type is already varchar" would silently mean "the collation was never
-- fixed", which is the failure mode that produces the tenders bug.
SET @hd_cat_coll := (
  SELECT COLLATION_NAME FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'helpdesk_tickets'
     AND COLUMN_NAME = 'category'
)

-- >>>
SET @hd_coll_ddl := IF(
  @hd_cat_coll IS NOT NULL AND @hd_cat_coll <> 'utf8mb4_unicode_ci',
  'ALTER TABLE `helpdesk_tickets`
     MODIFY COLUMN `category` VARCHAR(100)
       COLLATE utf8mb4_unicode_ci NOT NULL
       COMMENT ''helpdesk_categories.name, by text''',
  'DO 0'
)

-- >>>
PREPARE hd_coll_stmt FROM @hd_coll_ddl

-- >>>
EXECUTE hd_coll_stmt

-- >>>
DEALLOCATE PREPARE hd_coll_stmt

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 4. THE TWO PERMISSION MODULES
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Four actions each, the shape every settings-tab pair in this product uses. `view` opens the tab;
-- `create`, `edit` and `delete` are what the Categories screen reads, and what
-- `ModuleNotifications` reads for its own tab.
--
-- `category` is `helpdesk`, lowercase — MEASURED from the eleven existing helpdesk permissions, all
-- of which carry exactly that. `create_helpdesk_system.sql` inserts `'Helpdesk'` capitalised in its
-- own VALUES list, but the live rows are lowercase, and the live rows are what Roles Management
-- groups by.
--
-- The wording is borrowed from the disposal pair rather than invented, so a role copied from one
-- module to another behaves the same way.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('helpdesk_categories',    'view',   'helpdesk_categories_view',
   'Read the helpdesk ticket categories', 'helpdesk'),
  ('helpdesk_categories',    'create', 'helpdesk_categories_create',
   'Add a helpdesk ticket category', 'helpdesk'),
  ('helpdesk_categories',    'edit',   'helpdesk_categories_edit',
   'Change or deactivate a helpdesk ticket category', 'helpdesk'),
  ('helpdesk_categories',    'delete', 'helpdesk_categories_delete',
   'Remove a helpdesk ticket category no ticket uses', 'helpdesk'),
  ('helpdesk_notifications', 'view',   'helpdesk_notifications_view',
   'Read helpdesk notification settings', 'helpdesk'),
  ('helpdesk_notifications', 'create', 'helpdesk_notifications_create',
   'Add helpdesk notification settings', 'helpdesk'),
  ('helpdesk_notifications', 'edit',   'helpdesk_notifications_edit',
   'Change helpdesk notification settings', 'helpdesk'),
  ('helpdesk_notifications', 'delete', 'helpdesk_notifications_delete',
   'Remove helpdesk notification settings', 'helpdesk')

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 5. THE ONE SETTING THAT MUST BE SEEDED, AND WHY THIS DIFFERS FROM THE SIBLINGS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `asset_disposal_approval.sql` states plainly that it seeds NO `hr_module_settings` rows, because
-- `getModuleSettings()` fills every unset key from `NOTIFICATION_KEYS` and a row holding exactly the
-- default would mean nothing. That reasoning is right, and it does NOT hold here.
--
-- `NOTIFICATION_KEYS.email_profile` defaults to **'hr'**. For every module that was already on this
-- table that is correct — they email employees and applicants, and HR owns that mailbox. The helpdesk
-- does not: it emails CLIENTS from the support desk, and the shipped `support` profile owns exactly
-- the address this module's mail has always come from.
--
-- MEASURED, not assumed: with no row seeded, the new-ticket notification resolved its recipient to
-- `hr@ansartechnologies.my`. The hardcoded literal it replaced was `support@ansartechnologies.my`. So
-- relying on the default would have silently redirected every helpdesk notification to a different
-- department — a change nobody asked for, dressed up as "no change".
--
-- INSERT IGNORE, so it seeds once and never overwrites a profile somebody later chooses on the
-- Notification tab.
--
-- `notify_employee` and `cc_email` are deliberately NOT seeded. Their defaults ARE right: notifying is
-- on, and an empty `cc_email` is what makes the code fall back to this profile's own mailbox — which
-- is the behaviour the literal had. A seeded address would put a literal back into the system, just in
-- a table instead of in a TypeScript file, and it would then be wrong for anybody who changes profile.
INSERT IGNORE INTO `hr_module_settings` (`module`, `setting_key`, `value`)
VALUES ('helpdesk', 'email_profile', 'support')

-- >>>
-- ── 4a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `usePermissions` joins through
-- `role_permissions`, so an ungranted permission makes the control INVISIBLE rather than denied —
-- which reads as a broken screen rather than as a permission to ask for. Without this the new
-- Settings leaf simply would not appear, with nothing on screen saying a migration is outstanding.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('helpdesk_categories', 'helpdesk_notifications')
