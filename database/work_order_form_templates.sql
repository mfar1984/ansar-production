-- ============================================================================================
-- SERVICE FORM TEMPLATES - FOUR tables, FOUR permissions, THREE seeded templates
--
-- Design: .kiro/design/work-order-templates/README.md sections 3 and 5.
--
-- Run:  node scripts/run-sql.js database/work_order_form_templates.sql
--
-- IDEMPOTENT. Run it twice and the second run changes nothing. Production applies a schema
-- change with `git pull` and a hand, and a hand runs things twice.
--
-- Statement separator is a `-- >>>` line, NOT a semicolon: scripts/run-sql.js splits on that
-- marker, and it also DROPS every line that begins with `--`, so none of the prose below ever
-- reaches the server.
--
-- ============================================================================================
-- WHAT THIS IS FOR, MEASURED ON THIS DATABASE
-- ============================================================================================
--
-- A work order covers many assets. The external register holds 115 laptops for ONE client,
-- `JABATAN KEMAJUAN MASYARAKAT(KEMAS) NEGERI PAHANG`, across 16 sites, and the deliverable a
-- customer signs for a preventive round over them is ONE SERVICE FORM PER UNIT - not one
-- summary for 115.
--
-- A SERVICE FORM TEMPLATE is the master that defines what one asset's sheet looks like: the
-- heading printed on the paper, a Device Information block whose lines vary by device type, and
-- a numbered checklist grouped the way the printed table is grouped.
--
-- ============================================================================================
-- `work_order_templates` IS LEFT ALONE. THESE ARE NOT THE SAME TABLE, AND THE NAMES SAY SO
-- ============================================================================================
--
-- `work_order_templates` answers "which steps does this KIND of job need". It binds to
-- `type_name` - a row of `work_order_types` - and is referenced by `work_orders.template_id`
-- and `work_order_types.default_template_id`. NOTHING here touches it, adds a column to it, or
-- repoints anything at these tables.
--
--   work_order_templates        the job CHECKLIST    bound to the work order TYPE
--   work_order_form_templates   the per-asset SHEET  bound to the asset CATEGORY
--
-- A Preventive Maintenance work order over 115 laptops therefore produces ONE job checklist,
-- copied from `work_order_types.default_template_id`, and 115 service forms, one per unit. They
-- do not compete: the type picks the checklist, each asset picks its own sheet.
--
-- Folding `category_id` and `form_title` onto `work_order_templates` was the obvious shortcut
-- and it is the wrong one. `uq_woft_active_cat` below would collide with every existing
-- checklist template that has no category, and one table would be answering two questions.
--
-- ============================================================================================
-- THE BINDING IS A TOP-LEVEL `asset_categories` ROW, AND THAT WAS MEASURED, NOT CHOSEN
-- ============================================================================================
--
-- `assets.category` is FREE TEXT with 70+ distinct values, and the tail is one-offs:
-- `USB 2.0 MALE TO FEMALE CONVERTER`, `13A Unbreakable Fused Plug Top`. A device-type axis built
-- on it would need a template per spelling and would gain one every time somebody typed a new
-- value into the asset form.
--
-- `asset_categories` is a controlled two-level tree. VERIFIED on this database: 15 rows have
-- `parent_id IS NULL` - Computer & Laptop (1), Server & Storage (2), Network Equipment (3),
-- Printer & Scanner (4), Mobile Device (5), Vehicle (6), Tools & Instruments (8),
-- CCTV & Security (9), Power & Electrical (10), Software Licence (11), Other (12),
-- BUILDING (39) and three grouping parents (81, 82, 83). The granular values hang off those as
-- CHILDREN, so a template bound to a top-level row covers every child under it and a child
-- added on the Asset Categories screen is covered the moment it exists.
--
-- A FOREIGN KEY CANNOT EXPRESS "parent_id IS NULL". `fk_woft_category` guarantees the row
-- exists; it cannot guarantee the row is top level. So the rule is enforced in TWO places that
-- are both visible:
--
--   1. The seeds below each read `FROM asset_categories c WHERE c.id = ? AND c.parent_id IS NULL`,
--      so a seed against a child inserts nothing rather than writing a wrong binding.
--   2. `src/pages/api/admin/operations/work-orders/form-templates.ts` refuses a non-top-level
--      `category_id` on POST and PUT, with the reason in the message.
--
-- The precedent for varying a form by category already exists one module across:
-- `asset_categories.detail_form` is `enum('none','vehicle')` and `AssetRegister.tsx` reveals
-- seven extra fields when the chosen category carries `'vehicle'`.
-- ============================================================================================

-- ============================================================================================
-- 1. THE TEMPLATE HEAD
--
-- `name` is admin-facing and searched. `form_title` is the heading PRINTED on the sheet. They
-- are separate columns because the READERS are separate: the admin searches for
-- `Network Equipment Preventive Maintenance`, the customer reads
-- `NETWORK EQUIPMENT PREVENTIVE MAINTENANCE SERVICE FORM`. One string in both places means
-- either the admin list shouts or the sheet is under-titled.
--
-- `is_system` forbids DELETE, not EDIT. A seeded template may be copied and retired. Retiring
-- it stops it raising new sheets and leaves every sheet already raised exactly as it was
-- signed. The editor draws NO Delete control on a seeded template - a control that always
-- refuses is worse than one that is not drawn.
--
-- ── `active_key` IS A GENERATED COLUMN, AND THAT DETAIL IS LOAD BEARING ──
--
-- The rule being expressed is ONE ACTIVE TEMPLATE PER CATEGORY. Without it the server has no
-- basis for choosing which sheet to raise, and the ambiguity surfaces on a work order instead
-- of here.
--
-- CORRECTED, and do not revert it. The first draft wrote `UNIQUE KEY (category_id, is_active)`,
-- which does NOT say that. It permits one row per (category, is_active) PAIR, so a category can
-- hold exactly two templates for all time: one active and one retired. The SECOND retirement in
-- a category fails on a duplicate key - and `is_system` above promises a seeded template "may
-- be copied and retired", so the schema contradicted its own stated behaviour on the second
-- copy.
--
-- A NULL NEVER COMPARES EQUAL TO ANOTHER NULL IN A UNIQUE INDEX. That is the property that
-- makes the generated column work: every retired row carries NULL and so never collides with
-- another retired row, while at most one row per category can carry 1.
--
-- STORED rather than VIRTUAL because a unique index over a virtual generated column is
-- supported but re-evaluates the expression on every read of the index; STORED writes it once.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_form_templates` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(150) NOT NULL,
  `category_id` INT UNSIGNED NOT NULL,
  `form_title`  VARCHAR(200) NOT NULL,
  `description` VARCHAR(400) DEFAULT NULL,
  `is_active`   TINYINT(1) NOT NULL DEFAULT 1,
  `is_system`   TINYINT(1) NOT NULL DEFAULT 0,
  `created_by`  VARCHAR(191) DEFAULT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `active_key`  TINYINT GENERATED ALWAYS AS (IF(`is_active` = 1, 1, NULL)) STORED,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_woft_name` (`name`),
  UNIQUE KEY `uq_woft_active_cat` (`category_id`, `active_key`),
  CONSTRAINT `fk_woft_category` FOREIGN KEY (`category_id`)
    REFERENCES `asset_categories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 2. FIELD DEFINITIONS - one row per line printed in the DEVICE INFORMATION block
--
-- Nothing in the existing schema does any of this. `work_order_template_items` is a flat list
-- of step titles; it cannot express `Firmware Ver.` as a printed line with a type and a source.
--
-- ── `autofill_from` HOLDS AN `assets` COLUMN NAME OR NULL, AND IT IS VALIDATED IN CODE ──
--
-- `assets` has exactly 40 columns, verified on this database:
--
--   id, asset_no, holder, ownership, name, category, asset_class, brand, model, serial_no,
--   tag_no, label_printed_at, description, purchase_date, purchase_cost, useful_life_years,
--   vendor_id, tender_id, invoice_no, employee_id, department_id, location, location_id,
--   client_id, site_id, project_id, site_name, site_address, installed_on, pic_name,
--   pic_position, handed_over_on, status, is_loanable, condition_note, photo_path, notes,
--   created_by, created_at, updated_at
--
-- The endpoint validates a submitted value against an EXPLICIT ALLOW-LIST in TypeScript -
-- `AUTOFILL_COLUMNS` in `form-templates.ts` - and never against `information_schema` at request
-- time. Stage 4 interpolates the resolved value into a printed document, so an arbitrary string
-- here is an arbitrary string on a customer's paperwork; and a live schema read would make the
-- set of legal values depend on whatever columns happen to exist on the server that day.
--
-- `assets.category` IS a legal source even though section 1 above rejects it as a BINDING axis.
-- That is not a contradiction: free text is unusable as a KEY to select a template and
-- perfectly usable as a VALUE to print. A blank or a misspelling prints as itself and the
-- technician corrects it on the sheet. A wrong binding would raise the wrong sheet.
--
-- ── `field_key` IS STABLE ONCE A SHEET HAS BEEN RAISED ──
--
-- The Edit control changes the printed `label` and leaves the key alone. Renaming a key would
-- orphan every answer stored under the old one. `uq_woff_key` is what makes the key an
-- identifier rather than a convention.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_form_fields` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `template_id`   INT NOT NULL,
  `label`         VARCHAR(120) NOT NULL,
  `field_key`     VARCHAR(60)  NOT NULL,
  `input_type`    ENUM('text','textarea','date','number') NOT NULL DEFAULT 'text',
  `autofill_from` VARCHAR(60)  DEFAULT NULL,
  `is_required`   TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`    INT NOT NULL DEFAULT 0,
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_woff_key` (`template_id`, `field_key`),
  KEY `idx_woff_tpl` (`template_id`, `sort_order`),
  CONSTRAINT `fk_woff_tpl` FOREIGN KEY (`template_id`)
    REFERENCES `work_order_form_templates` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 3. CHECKLIST GROUPS
--
-- The printed DETAILS OF THE JOB PERFORMED table is GROUPED. `work_order_template_items` is a
-- flat list and cannot be, which is the third gap this file fills.
--
-- NO unique key on (template_id, title), deliberately: a group is renamed freely and two
-- templates both carry a group called `Handover`. The seed below is made idempotent by an
-- anti-join on (template_id, title) instead of by an index, so nothing here constrains what an
-- admin may type later.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_form_groups` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `template_id` INT NOT NULL,
  `title`       VARCHAR(150) NOT NULL,
  `sort_order`  INT NOT NULL DEFAULT 0,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wofg_tpl` (`template_id`, `sort_order`),
  CONSTRAINT `fk_wofg_tpl` FOREIGN KEY (`template_id`)
    REFERENCES `work_order_form_templates` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 4. CHECKLIST ITEMS
--
-- The same shape as `work_order_template_items` plus `group_id`, so the two lists read the same
-- way on a screen that shows them side by side: `title`, `notes`, `is_required`, `sort_order`.
--
-- `sort_order` is the step number PRINTED ON THE SHEET, running 1..14 across the whole template
-- rather than restarting inside each group. The printed checklist is numbered continuously -
-- `sheets.html` shows steps 1 to 14 down one table with the group titles as spanning rows - so
-- a per-group counter would have to be re-derived at print time and could disagree with what a
-- technician ticked.
--
-- `group_id` and not `template_id`: a group OWNS its items, and `fk_wofg_tpl` already chains to
-- the template. Carrying both would allow an item whose group belongs to a different template.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_form_items` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `group_id`    INT NOT NULL,
  `title`       VARCHAR(255) NOT NULL,
  `notes`       VARCHAR(400) DEFAULT NULL,
  `is_required` TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`  INT NOT NULL DEFAULT 0,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wofi_grp` (`group_id`, `sort_order`),
  CONSTRAINT `fk_wofi_grp` FOREIGN KEY (`group_id`)
    REFERENCES `work_order_form_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 5. THE GUARDED ALTERS - one per object, each reading INFORMATION_SCHEMA first
--
-- `CREATE TABLE IF NOT EXISTS` above covers a fresh install. These cover the case it cannot: a
-- `work_order_form_templates` that already exists from an earlier, shorter version of this file
-- - which for this table is not hypothetical, because the FIRST DRAFT of the design shipped
-- `UNIQUE KEY (category_id, is_active)` and no `active_key` at all.
--
-- `ADD COLUMN`, `ADD KEY` and `ADD CONSTRAINT` have no `IF NOT EXISTS` form in MySQL 8.0.45, so
-- each is wrapped in a prepared statement that becomes `DO 0` when the object is already there.
-- This is the shape `work_order_assets.sql` and `work_order_module.sql` sections 10 and 11 use.
--
-- THE ORDER MATTERS. `active_key` is added BEFORE `uq_woft_active_cat`, because the index names
-- the column. The wrong order fails with ER_KEY_COLUMN_DOES_NOT_EXITS and takes out nothing
-- else, which is a confusing half-applied file rather than a clean failure.
-- ============================================================================================
SET @woft_active_key := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND COLUMN_NAME = 'active_key'
)
-- >>>
SET @sql := IF(@woft_active_key = 0,
  'ALTER TABLE `work_order_form_templates`
     ADD COLUMN `active_key` TINYINT
       GENERATED ALWAYS AS (IF(`is_active` = 1, 1, NULL)) STORED AFTER `updated_at`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ── The WRONG index, dropped if an earlier draft put it there ──
--
-- `uq_woft_active_cat` over (`category_id`, `is_active`) is the first draft's mistake, and it is
-- the one state where this file cannot simply ADD: the name is taken by an index that caps a
-- category at two templates for all time. Read the COLUMN LIST, not just the name - an index
-- that is present but wrong passes every `COUNT(*) > 0` check ever written about it.
SET @woft_wrong_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND INDEX_NAME = 'uq_woft_active_cat'
     AND COLUMN_NAME = 'is_active'
)
-- >>>
SET @sql := IF(@woft_wrong_uq > 0,
  'ALTER TABLE `work_order_form_templates` DROP INDEX `uq_woft_active_cat`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woft_uq_active := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND INDEX_NAME = 'uq_woft_active_cat'
)
-- >>>
SET @sql := IF(@woft_uq_active = 0,
  'ALTER TABLE `work_order_form_templates`
     ADD UNIQUE KEY `uq_woft_active_cat` (`category_id`, `active_key`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woft_uq_name := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND INDEX_NAME = 'uq_woft_name'
)
-- >>>
SET @sql := IF(@woft_uq_name = 0,
  'ALTER TABLE `work_order_form_templates` ADD UNIQUE KEY `uq_woft_name` (`name`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woft_fk_cat := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND CONSTRAINT_NAME = 'fk_woft_category'
)
-- >>>
SET @sql := IF(@woft_fk_cat = 0,
  'ALTER TABLE `work_order_form_templates`
     ADD CONSTRAINT `fk_woft_category` FOREIGN KEY (`category_id`)
       REFERENCES `asset_categories` (`id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ============================================================================================
-- 6. PERMISSIONS - FOUR NEW KEYS, AND THE ARGUMENT FOR NOT REUSING THE OLD ONES
--
-- `work_order_templates_*` was NOT reused, and that was a decision rather than an oversight.
--
-- Its shipped description, written in `database/work_order_permissions.sql` section 3, is
-- "View work order checklist templates" / "Add a work order checklist template" and so on. A
-- SERVICE FORM template governs what is printed on a document a CUSTOMER SIGNS. Reusing the key
-- would make four shipped descriptions false - the Roles matrix would offer a checkbox reading
-- "checklist template" that also grants authority over signed paperwork - and it would widen
-- that permission's blast radius without anybody granting it. Every role holding
-- `work_order_templates_edit` today would silently acquire the new screen.
--
-- The precedent is already in that same file, twice over. `work_order_types` and
-- `work_order_templates` are separate modules "because naming a kind of work is not the same
-- authority as deciding who signs a work order off", and `asset_categories` /
-- `asset_repair_categories` are two modules over two lists on ONE tabbed screen for exactly the
-- same reason.
--
-- FOUR actions, each governing a real control, read off the screen rather than guessed:
--
--   view    the tab itself, and the read-only mode
--   create  Add Service Form
--   edit    the editor, the field rows, the checklist rows, and Retire
--   delete  the Remove control - which is NOT DRAWN AT ALL on an `is_system = 1` template
--
-- No `_export`. Nothing exports in this release and a checkbox granting nothing is worse than
-- its absence - the same rule `work_order_permissions.sql` applied to `work_orders`.
--
-- ── MUST SHIP WITH `src/lib/permission-modules.ts` IN THE SAME CHANGE ──
--
-- `tests/sql/roles-endpoints.sql.test.js` reads `MODULE_ORDER` out of that source file and
-- `SELECT DISTINCT module FROM permissions` out of this database, and it fails BOTH directions:
-- a module listed with no permissions, and a module holding permissions but absent from the
-- list. Seeding these four rows without the `MODULE_ORDER` entry is red; adding the entry
-- without these rows is red.
--
-- `category` is 'operations', LOWERCASE, matching the 28 rows this module already has.
-- `INSERT IGNORE` against the unique index on `permissions`.`name` is what makes it idempotent.
-- ============================================================================================
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_forms', 'view',   'work_order_forms_view',
   'View service form templates for work orders',   'operations'),
  ('work_order_forms', 'create', 'work_order_forms_create',
   'Add a service form template for work orders',   'operations'),
  ('work_order_forms', 'edit',   'work_order_forms_edit',
   'Update a service form template for work orders','operations'),
  ('work_order_forms', 'delete', 'work_order_forms_delete',
   'Delete a service form template for work orders','operations')
-- >>>
-- ── The Super Admin grant, and it is not decoration ──
--
-- `leafVisible()` calls `has(leaf.perm)` and `usePermissions` joins through `role_permissions`.
-- The SERVER has a Super Admin shortcut; the CLIENT does not. So an ungranted permission makes
-- the control INVISIBLE rather than refused - which reads as a broken screen, with no error
-- anywhere to explain it.
--
-- `LOWER(TRIM(r.name)) = 'super admin'` - the same predicate `work_order_permissions.sql` uses.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'work_order_forms'
-- >>>
-- ============================================================================================
-- 7. THE THREE SEEDED TEMPLATES
--
-- Content is taken VERBATIM from `.kiro/design/work-order-templates/index.html`, which is the
-- approved design. Nothing here is paraphrased and nothing is invented.
--
--   1  Laptop & Desktop Preventive Maintenance   category 1   12 fields  4 groups  14 steps   8 required
--   2  Network Equipment Preventive Maintenance  category 3   12 fields  5 groups  14 steps   9 required
--   3  CCTV & Security Preventive Maintenance    category 9   12 fields  4 groups  14 steps  10 required
--
-- Chosen by MEASURED unit counts in the register rather than by what sounded representative:
-- 119 under Computer & Laptop, about 21 under Network Equipment, about 24 under CCTV &
-- Security. Server & Storage was REJECTED - category 2 exists and the register holds zero of
-- them, so a template for it would be a design for demand that does not exist.
--
-- ── WHY TEMPLATE 1 IS NAMED `Laptop & Desktop` AND NOT `Computer & Laptop` ──
--
-- `Computer & Laptop` is the name of the CATEGORY it binds to, which is already printed beside
-- the template on the screen. The gallery's editor frame 1A carries
-- `Laptop & Desktop Preventive Maintenance` in the Template name field and
-- `LAPTOP & DESKTOP PREVENTIVE MAINTENANCE SERVICE FORM` in the Printed heading field, and
-- README section 3 quotes the second string word for word. Naming the template after its own
-- category would make the editor read `Computer & Laptop -> Computer & Laptop Preventive
-- Maintenance`.
--
-- ── IDEMPOTENT, AND HOW ──
--
-- Templates and fields carry unique keys, so `INSERT IGNORE` is enough: `uq_woft_name` on the
-- head and `uq_woff_key (template_id, field_key)` on the fields.
--
-- Groups and items carry NONE, by the decision recorded in section 3, so each is seeded by an
-- ANTI-JOIN: a derived `UNION ALL` set joined to its parent with
-- `AND NOT EXISTS (SELECT 1 FROM <target> WHERE ...)`. VERIFIED on MySQL 8.0.45 that
-- `INSERT ... SELECT` may read the table it is inserting into - error 1093 applies to UPDATE
-- and DELETE, not to this - and that running the identical statement twice inserts one row.
-- The derived sets hold no internal duplicates, so the result does not depend on whether the
-- optimiser materialises the SELECT.
--
-- ── EVERY TEMPLATE IS BOUND THROUGH `parent_id IS NULL` ──
--
-- Each head INSERT reads `FROM asset_categories c WHERE c.id = ? AND c.parent_id IS NULL`. If
-- the tree is ever reshaped so that 1, 3 or 9 is no longer top level, the seed inserts NOTHING
-- rather than writing a binding the endpoint would refuse. The verification SELECT at the foot
-- prints the template count, so that shows up as a figure instead of as silence.
-- ============================================================================================
INSERT IGNORE INTO `work_order_form_templates`
  (`name`, `category_id`, `form_title`, `description`, `is_active`, `is_system`, `created_by`)
SELECT 'Laptop & Desktop Preventive Maintenance', c.`id`,
       'LAPTOP & DESKTOP PREVENTIVE MAINTENANCE SERVICE FORM',
       'Quarterly round on every laptop and desktop. One sheet per unit, signed on site.',
       1, 1, 'migration'
  FROM `asset_categories` c
 WHERE c.`id` = 1 AND c.`parent_id` IS NULL
-- >>>
INSERT IGNORE INTO `work_order_form_templates`
  (`name`, `category_id`, `form_title`, `description`, `is_active`, `is_system`, `created_by`)
SELECT 'Network Equipment Preventive Maintenance', c.`id`,
       'NETWORK EQUIPMENT PREVENTIVE MAINTENANCE SERVICE FORM',
       'Half-yearly round on switches, access points and patch panels. One sheet per device.',
       1, 1, 'migration'
  FROM `asset_categories` c
 WHERE c.`id` = 3 AND c.`parent_id` IS NULL
-- >>>
INSERT IGNORE INTO `work_order_form_templates`
  (`name`, `category_id`, `form_title`, `description`, `is_active`, `is_system`, `created_by`)
SELECT 'CCTV & Security Preventive Maintenance', c.`id`,
       'CCTV & SECURITY SYSTEM PREVENTIVE MAINTENANCE SERVICE FORM',
       'Quarterly round on cameras, recorders and door access devices. One sheet per device.',
       1, 1, 'migration'
  FROM `asset_categories` c
 WHERE c.`id` = 9 AND c.`parent_id` IS NULL
-- >>>
-- ============================================================================================
-- 7a. TEMPLATE 1 FIELDS - 8 fill from the register, 4 the technician types
--
-- Every sheet in the product prints Asset No., Brand, Model and Serial No. That is shared ON
-- PURPOSE: a sheet has to say which unit it is. The other eight lines are what the template
-- actually decides, and they do not overlap between the three.
-- ============================================================================================
INSERT IGNORE INTO `work_order_form_fields`
  (`template_id`, `label`, `field_key`, `input_type`, `autofill_from`, `is_required`, `sort_order`)
SELECT t.`id`, s.`label`, s.`field_key`, s.`input_type`, s.`autofill_from`,
       s.`is_required`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Asset No.'            AS `label`, 'asset_no'             AS `field_key`,
                     'text'                 AS `input_type`, 'asset_no'        AS `autofill_from`,
                     1                      AS `is_required`, 1                AS `sort_order`
    UNION ALL SELECT 'Brand',                'brand',                'text',     'brand',          1,  2
    UNION ALL SELECT 'Model',                'model',                'text',     'model',          1,  3
    UNION ALL SELECT 'Serial No.',           'serial_no',            'text',     'serial_no',      1,  4
    UNION ALL SELECT 'Asset Tag',            'tag_no',               'text',     'tag_no',         0,  5
    UNION ALL SELECT 'Site',                 'site',                 'text',     'site_name',      0,  6
    UNION ALL SELECT 'Purchase Date',        'purchase_date',        'date',     'purchase_date',  0,  7
    UNION ALL SELECT 'Condition on Arrival', 'condition_on_arrival', 'textarea', 'condition_note', 0,  8
    UNION ALL SELECT 'Operating System',     'operating_system',     'text',     NULL,             1,  9
    UNION ALL SELECT 'Processor / RAM',      'processor_ram',        'text',     NULL,             0, 10
    UNION ALL SELECT 'Storage',              'storage',              'text',     NULL,             0, 11
    UNION ALL SELECT 'Battery Health',       'battery_health_pct',   'number',   NULL,             1, 12
       ) s
 WHERE t.`name` = 'Laptop & Desktop Preventive Maintenance'
-- >>>
-- ============================================================================================
-- 7b. TEMPLATE 2 FIELDS - 6 fill from the register, 6 the technician types
--
-- ── `ip_address` SEEDS WITH `autofill_from = NULL`, AND THAT IS NOT AN OMISSION ──
--
-- THERE IS NO `ip_address` COLUMN ON `assets`. Verified: the table has exactly 40 columns and
-- none of them is it. The reference sheet prints an IP Address line, so the field exists and
-- the technician types it.
--
-- THE USER HAS NOT YET CHOSEN between leaving it a typed field and adding an asset column.
-- README section 5 states the open question and both options with their costs: a typed field is
-- a reading taken on the day and nothing can warn that a switch's address changed between
-- rounds; an `assets.ip_address` column is a 41st column that the great majority of rows -
-- 119 laptops, a desk fan, a plug top - will never have, needing a place on the asset form and
-- about 45 rows backfilled by hand. A middle path exists: reveal the field on the asset form
-- for categories 3 and 9 only, through the `detail_form` mechanism that already works that way
-- for `'vehicle'`.
--
-- Until that is decided, NULL is the honest value. It affects templates 2 and 3.
-- ============================================================================================
INSERT IGNORE INTO `work_order_form_fields`
  (`template_id`, `label`, `field_key`, `input_type`, `autofill_from`, `is_required`, `sort_order`)
SELECT t.`id`, s.`label`, s.`field_key`, s.`input_type`, s.`autofill_from`,
       s.`is_required`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Asset No.'           AS `label`, 'asset_no'          AS `field_key`,
                     'text'                AS `input_type`, 'asset_no'     AS `autofill_from`,
                     1                     AS `is_required`, 1             AS `sort_order`
    UNION ALL SELECT 'Device Type',         'device_type',       'text',   'category',   1,  2
    UNION ALL SELECT 'Brand',               'brand',             'text',   'brand',      1,  3
    UNION ALL SELECT 'Model',               'model',             'text',   'model',      1,  4
    UNION ALL SELECT 'Serial No.',          'serial_no',         'text',   'serial_no',  1,  5
    UNION ALL SELECT 'Rack / Cabinet',      'rack_cabinet',      'text',   'location',   0,  6
    UNION ALL SELECT 'IP Address',          'ip_address',        'text',   NULL,         1,  7
    UNION ALL SELECT 'Firmware Ver.',       'firmware_version',  'text',   NULL,         1,  8
    UNION ALL SELECT 'Ports Used / Total',  'ports_used_total',  'text',   NULL,         0,  9
    UNION ALL SELECT 'Uplink Port',         'uplink_port',       'text',   NULL,         0, 10
    UNION ALL SELECT 'PoE Load',            'poe_load_w',        'number', NULL,         0, 11
    UNION ALL SELECT 'Config Backup Ref.',  'config_backup_ref', 'text',   NULL,         1, 12
       ) s
 WHERE t.`name` = 'Network Equipment Preventive Maintenance'
-- >>>
-- ============================================================================================
-- 7c. TEMPLATE 3 FIELDS - 7 fill from the register, 5 the technician types
--
-- `ip_address` is NULL here for the reason given in 7b above.
-- ============================================================================================
INSERT IGNORE INTO `work_order_form_fields`
  (`template_id`, `label`, `field_key`, `input_type`, `autofill_from`, `is_required`, `sort_order`)
SELECT t.`id`, s.`label`, s.`field_key`, s.`input_type`, s.`autofill_from`,
       s.`is_required`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Asset No.'             AS `label`, 'asset_no'            AS `field_key`,
                     'text'                  AS `input_type`, 'asset_no'       AS `autofill_from`,
                     1                       AS `is_required`, 1               AS `sort_order`
    UNION ALL SELECT 'Device Type',           'device_type',         'text',   'category',     1,  2
    UNION ALL SELECT 'Brand',                 'brand',               'text',   'brand',        1,  3
    UNION ALL SELECT 'Model',                 'model',               'text',   'model',        1,  4
    UNION ALL SELECT 'Serial No.',            'serial_no',           'text',   'serial_no',    1,  5
    UNION ALL SELECT 'Mounting Position',     'mounting_position',   'text',   'location',     1,  6
    UNION ALL SELECT 'Installed On',          'installed_on',        'date',   'installed_on', 0,  7
    UNION ALL SELECT 'IP Address',            'ip_address',          'text',   NULL,           1,  8
    UNION ALL SELECT 'Channel No.',           'channel_no',          'text',   NULL,           1,  9
    UNION ALL SELECT 'Recorder / Controller', 'recorder_controller', 'text',   NULL,           1, 10
    UNION ALL SELECT 'Lens / Resolution',     'lens_resolution',     'text',   NULL,           0, 11
    UNION ALL SELECT 'Recording Retention',   'retention_days',      'number', NULL,           1, 12
       ) s
 WHERE t.`name` = 'CCTV & Security Preventive Maintenance'
-- >>>
-- ============================================================================================
-- 7d. THE CHECKLIST GROUPS - 4, 5 and 4
--
-- Templates 1 and 2 both carry a group called `Handover`. They are different rows under
-- different templates, so the anti-join predicate is (template_id, title) and not title alone.
-- ============================================================================================
INSERT INTO `work_order_form_groups` (`template_id`, `title`, `sort_order`)
SELECT t.`id`, s.`title`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Physical & Cleaning'         AS `title`, 1 AS `sort_order`
    UNION ALL SELECT 'Power & Battery',             2
    UNION ALL SELECT 'Operating System & Security', 3
    UNION ALL SELECT 'Handover',                    4
       ) s
 WHERE t.`name` = 'Laptop & Desktop Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_groups` g
      WHERE g.`template_id` = t.`id` AND g.`title` = s.`title`
   )
-- >>>
INSERT INTO `work_order_form_groups` (`template_id`, `title`, `sort_order`)
SELECT t.`id`, s.`title`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Enclosure & Environment'     AS `title`, 1 AS `sort_order`
    UNION ALL SELECT 'Power & Cabling',             2
    UNION ALL SELECT 'Configuration & Firmware',    3
    UNION ALL SELECT 'Link & Throughput',           4
    UNION ALL SELECT 'Handover',                    5
       ) s
 WHERE t.`name` = 'Network Equipment Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_groups` g
      WHERE g.`template_id` = t.`id` AND g.`title` = s.`title`
   )
-- >>>
INSERT INTO `work_order_form_groups` (`template_id`, `title`, `sort_order`)
SELECT t.`id`, s.`title`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Camera, Housing & View'              AS `title`, 1 AS `sort_order`
    UNION ALL SELECT 'Recording & Storage',                 2
    UNION ALL SELECT 'Network & Power',                     3
    UNION ALL SELECT 'Access Control Devices, where fitted',4
       ) s
 WHERE t.`name` = 'CCTV & Security Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_groups` g
      WHERE g.`template_id` = t.`id` AND g.`title` = s.`title`
   )
-- >>>
-- ============================================================================================
-- 7e. TEMPLATE 1 CHECKLIST - 14 steps, 8 of them required
--
-- Step text is verbatim from the gallery. `sort_order` is the number printed on the sheet.
-- ============================================================================================
INSERT INTO `work_order_form_items` (`group_id`, `title`, `is_required`, `sort_order`)
SELECT g.`id`, s.`title`, s.`is_required`, s.`sort_order`
  FROM `work_order_form_groups` g
  JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
  JOIN (
              SELECT 'Physical & Cleaning' AS `grp`,
                     'External casing, screen and keyboard cleaned' AS `title`,
                     1 AS `is_required`, 1 AS `sort_order`
    UNION ALL SELECT 'Physical & Cleaning',         'Fan, heatsink and air vents blown out',          1,  2
    UNION ALL SELECT 'Physical & Cleaning',         'Thermal paste checked, reapplied if needed',     0,  3
    UNION ALL SELECT 'Physical & Cleaning',         'Hinges, ports and cables inspected for damage',  1,  4
    UNION ALL SELECT 'Power & Battery',             'Battery health report captured',                 1,  5
    UNION ALL SELECT 'Power & Battery',             'Charger and power adapter tested',               1,  6
    UNION ALL SELECT 'Power & Battery',             'Shutdown and cold boot verified',                0,  7
    UNION ALL SELECT 'Operating System & Security', 'Operating system updates applied',               1,  8
    UNION ALL SELECT 'Operating System & Security', 'BIOS and firmware version checked',              0,  9
    UNION ALL SELECT 'Operating System & Security', 'Antivirus definitions updated',                  1, 10
    UNION ALL SELECT 'Operating System & Security', 'Disk health read and recorded',                  0, 11
    UNION ALL SELECT 'Operating System & Security', 'Temporary files cleared, free space reported',   0, 12
    UNION ALL SELECT 'Handover',                    'User data intact and user signed off',           1, 13
    UNION ALL SELECT 'Handover',                    'Asset label present and legible',                0, 14
       ) s ON s.`grp` = g.`title`
 WHERE t.`name` = 'Laptop & Desktop Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_items` i
      WHERE i.`group_id` = g.`id` AND i.`title` = s.`title`
   )
-- >>>
-- ============================================================================================
-- 7f. TEMPLATE 2 CHECKLIST - 14 steps, 9 of them required
--
-- Step 13 reads "access points only" and that wording is the visible cost of one template per
-- TOP-LEVEL category: this one covers a switch and an access point, so a step that does not
-- apply to the unit in hand prints N / A on the sheet. README section 7 records the alternative
-- - a template per child, which would be 70+ templates to maintain - and leaves it open.
-- ============================================================================================
INSERT INTO `work_order_form_items` (`group_id`, `title`, `is_required`, `sort_order`)
SELECT g.`id`, s.`title`, s.`is_required`, s.`sort_order`
  FROM `work_order_form_groups` g
  JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
  JOIN (
              SELECT 'Enclosure & Environment' AS `grp`,
                     'Cabinet, device and fan filters cleaned' AS `title`,
                     1 AS `is_required`, 1 AS `sort_order`
    UNION ALL SELECT 'Enclosure & Environment',  'Rack mounting and earthing checked',                       0,  2
    UNION ALL SELECT 'Enclosure & Environment',  'Ambient temperature at the cabinet recorded',              1,  3
    UNION ALL SELECT 'Power & Cabling',          'Power supply and PoE load verified',                       1,  4
    UNION ALL SELECT 'Power & Cabling',          'Patch leads re-dressed and labelled',                      1,  5
    UNION ALL SELECT 'Power & Cabling',          'Fibre connectors inspected and cleaned',                   0,  6
    UNION ALL SELECT 'Configuration & Firmware', 'Firmware version checked against the approved build',      1,  7
    UNION ALL SELECT 'Configuration & Firmware', 'Running configuration backed up',                          1,  8
    UNION ALL SELECT 'Configuration & Firmware', 'Administrator credentials and SNMP community verified',     1,  9
    UNION ALL SELECT 'Configuration & Firmware', 'VLAN and trunk configuration confirmed',                   0, 10
    UNION ALL SELECT 'Link & Throughput',        'Port status and error counters read',                      1, 11
    UNION ALL SELECT 'Link & Throughput',        'Uplink throughput tested',                                 0, 12
    UNION ALL SELECT 'Link & Throughput',        'Wireless coverage and channel plan checked, access points only', 0, 13
    UNION ALL SELECT 'Handover',                 'Device reachable from the monitoring server',              1, 14
       ) s ON s.`grp` = g.`title`
 WHERE t.`name` = 'Network Equipment Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_items` i
      WHERE i.`group_id` = g.`id` AND i.`title` = s.`title`
   )
-- >>>
-- ============================================================================================
-- 7g. TEMPLATE 3 CHECKLIST - 14 steps, 10 of them required
--
-- The fourth group is `Access Control Devices, where fitted`, and that qualifier is the point:
-- category 9's children are not all cameras - it also holds `ELECTROMAGNETIC LOCK`,
-- `LCD Fingerprint Access Controller` and `BIOMETRIC TIME ATTENDANCE SYSTEM` - so steps 13 and
-- 14 print N / A on a camera's sheet. This is the template where one-per-top-level-category is
-- most visibly a compromise, which is why README section 2 chose it for the set of three.
-- ============================================================================================
INSERT INTO `work_order_form_items` (`group_id`, `title`, `is_required`, `sort_order`)
SELECT g.`id`, s.`title`, s.`is_required`, s.`sort_order`
  FROM `work_order_form_groups` g
  JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
  JOIN (
              SELECT 'Camera, Housing & View' AS `grp`,
                     'Lens, dome and housing cleaned' AS `title`,
                     1 AS `is_required`, 1 AS `sort_order`
    UNION ALL SELECT 'Camera, Housing & View', 'Mounting bracket and weather seal checked',                  1,  2
    UNION ALL SELECT 'Camera, Housing & View', 'Field of view confirmed against the site plan',              1,  3
    UNION ALL SELECT 'Camera, Housing & View', 'Focus and zoom adjusted, image sharpness checked',           0,  4
    UNION ALL SELECT 'Camera, Housing & View', 'Infrared illuminator tested in low light',                   0,  5
    UNION ALL SELECT 'Recording & Storage',    'Recorder disk health and free space read',                   1,  6
    UNION ALL SELECT 'Recording & Storage',    'Retention period verified against the contract',             1,  7
    UNION ALL SELECT 'Recording & Storage',    'Playback of a recorded clip verified',                       1,  8
    UNION ALL SELECT 'Recording & Storage',    'Recorder date and time synchronised',                        1,  9
    UNION ALL SELECT 'Network & Power',        'Power over Ethernet injector or adaptor load tested',        1, 10
    UNION ALL SELECT 'Network & Power',        'Cable route and connectors inspected',                       0, 11
    UNION ALL SELECT 'Network & Power',        'Device reachable from the recorder and the monitoring client',1, 12
    UNION ALL SELECT 'Access Control Devices, where fitted',
                     'Lock holding force, reader enrolment and exit release tested',                         1, 13
    UNION ALL SELECT 'Access Control Devices, where fitted',
                     'Door position sensor and alarm verified',                                              0, 14
       ) s ON s.`grp` = g.`title`
 WHERE t.`name` = 'CCTV & Security Preventive Maintenance'
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_items` i
      WHERE i.`group_id` = g.`id` AND i.`title` = s.`title`
   )
-- >>>
-- ============================================================================================
-- VERIFICATION. Printed by scripts/run-sql.js, so a reader sees the shape that resulted.
--
-- EXPECTED, and these are the numbers to compare a second run against:
--
--   tables 4            the four tables exist
--   gen_stored 1        `active_key` is GENERATED and STORED, read from EXTRA
--   uq_active_cols 2    `uq_woft_active_cat` holds TWO columns
--   uq_active_is_key 1  and the second of them is `active_key`, NOT `is_active`
--   uq_active_wrong 0   the first draft's index is not present
--   fks 4               fk_woft_category, fk_woff_tpl, fk_wofg_tpl, fk_wofi_grp
--   perms 4  grants 4   the four permission rows, all granted to Super Admin
--   templates 3         the three seeded heads
--   system 3            all three carry is_system = 1
--   top_level_bound 3   all three bind to a row with parent_id IS NULL
--   fields 36           12 per template
--   autofill 21         8 + 6 + 7
--   typed 15            4 + 6 + 5
--   ip_typed 2          both IP Address fields have autofill_from NULL
--   groups 13           4 + 5 + 4
--   items 42            14 per template
--   required 27         8 + 9 + 10
--   bad_autofill 0      no autofill_from names a column `assets` does not have
--
-- `uq_active_cols` is read as a COUNT OF COLUMNS and `uq_active_is_key` names the second one,
-- because `information_schema.STATISTICS` holds one row PER COLUMN of an index. A check written
-- as `COUNT(*) > 0` on the index NAME would pass on the first draft's wrong index, which is the
-- exact mistake this file exists to correct.
--
-- `bad_autofill` is the schema half of the allow-list. The endpoint refuses an unknown column
-- name on write; this proves none of the 21 seeded ones is wrong, by joining
-- `information_schema.COLUMNS` rather than by trusting the table above.
-- ============================================================================================
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN ('work_order_form_templates', 'work_order_form_fields',
                         'work_order_form_groups', 'work_order_form_items'))        AS tables,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND COLUMN_NAME = 'active_key' AND EXTRA LIKE '%STORED GENERATED%')          AS gen_stored,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_active_cat')                                       AS uq_active_cols,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_active_cat' AND COLUMN_NAME = 'active_key'
      AND SEQ_IN_INDEX = 2)                                                        AS uq_active_is_key,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_active_cat' AND COLUMN_NAME = 'is_active')         AS uq_active_wrong,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = 'FOREIGN KEY'
      AND CONSTRAINT_NAME IN ('fk_woft_category', 'fk_woff_tpl',
                              'fk_wofg_tpl', 'fk_wofi_grp'))                       AS fks,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'work_order_forms')         AS perms,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `roles` r ON r.`id` = rp.`role_id`
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` = 'work_order_forms')                                         AS grants,
  (SELECT COUNT(*) FROM `work_order_form_templates`)                               AS templates,
  (SELECT COUNT(*) FROM `work_order_form_templates` WHERE `is_system` = 1)         AS system_tpl,
  (SELECT COUNT(*) FROM `work_order_form_templates` ft
     JOIN `asset_categories` c ON c.`id` = ft.`category_id`
    WHERE c.`parent_id` IS NULL)                                                   AS top_level_bound,
  (SELECT COUNT(*) FROM `work_order_form_fields`)                                  AS fields,
  (SELECT COUNT(*) FROM `work_order_form_fields`
    WHERE `autofill_from` IS NOT NULL)                                             AS autofill,
  (SELECT COUNT(*) FROM `work_order_form_fields` WHERE `autofill_from` IS NULL)    AS typed,
  (SELECT COUNT(*) FROM `work_order_form_fields`
    WHERE `field_key` = 'ip_address' AND `autofill_from` IS NULL)                  AS ip_typed,
  (SELECT COUNT(*) FROM `work_order_form_groups`)                                  AS groups_n,
  (SELECT COUNT(*) FROM `work_order_form_items`)                                   AS items,
  (SELECT COUNT(*) FROM `work_order_form_items` WHERE `is_required` = 1)           AS required,
  (SELECT COUNT(*) FROM `work_order_form_fields` f
    WHERE f.`autofill_from` IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS ic
                       WHERE ic.TABLE_SCHEMA = DATABASE() AND ic.TABLE_NAME = 'assets'
                         AND ic.COLUMN_NAME = f.`autofill_from`))                  AS bad_autofill
