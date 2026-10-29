-- ==============================================================================================
-- THE FALLBACK SERVICE FORM - one form that covers every category without its own
--
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- WHY THIS FILE EXISTS, AND THE MEASUREMENT THAT FORCED IT
-- ══════════════════════════════════════════════════════════════════════════════════════════════
--
-- `work_order_form_templates.category_id` was NOT NULL, so a service form could only ever bind to
-- a TOP-LEVEL `asset_categories` row, and only three of those have one: Computer & Laptop (1),
-- Network Equipment (3), CCTV & Security (9).
--
-- MEASURED on this database before this file ran:
--
--     488 assets, 0 with a category that matches no `asset_categories` row
--     242 resolve to an active template
--     246 resolve to NO template
--
--   uncovered, by unit count:
--     Office Furniture 55, Other 51, Tools & Instruments 47, Appliances 40,
--     Power & Electrical 25, Safety & PPE 13, Printer & Scanner 5, Mobile Device 4,
--     Vehicle 3, Server & Storage 2, BUILDING 1
--
-- NO TEMPLATE MEANT NO SHEET, AND NO SHEET MEANT NO PHOTOGRAPHS. Seen live on WO-2026-0002: the
-- unit was `7SP84BQ9J5N1 10 STEP DOUBLE SIDED ALUMINIUM LADDER`, whose category
-- `DOUBLE SIDED ALMUNIUM LADDER` hangs off 8 (Tools & Instruments). The phone therefore offered a
-- bare Mark done, the technician closed the unit, and the job carries no before photograph, no
-- after photograph and no checklist for it. The user's words: "sepatutnya kena ada dua gambar
-- untuk comply. lepas itu dia mark done macam tu je."
--
-- Compliance needs a before and an after photograph on EVERY preventive visit, whatever the device
-- is. Gating the whole evidence flow behind a per-category template was the wrong call, and this
-- file is the correction: ONE active fallback form, applying to any category that has no form of
-- its own. A specific category form always wins - see `TEMPLATE_RESOLUTION` in
-- `src/lib/work-order-sheets.ts`, which is the one place the resolution is written.
--
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- `uq_woft_active_cat` IS NOT TOUCHED, AND THAT IS DELIBERATE
-- ══════════════════════════════════════════════════════════════════════════════════════════════
--
-- It is `(category_id, active_key)`. Once `category_id` is nullable, the fallback row's pair is
-- (NULL, 1) - and a pair holding a NULL never compares equal to another pair in a unique index, so
-- that index cannot cap the fallbacks at one. It is also what still refuses a second ACTIVE form
-- for category 1, which this change must not weaken.
--
-- So the fallback gets its OWN generated column and its OWN unique index, by exactly the mechanism
-- `active_key` already uses on this table:
--
--     fallback_key TINYINT GENERATED ALWAYS AS (IF(is_active = 1 AND category_id IS NULL, 1, NULL))
--     UNIQUE KEY uq_woft_fallback (fallback_key)
--
-- One ACTIVE fallback carries 1 and collides with any second one. Every other row - a retired
-- fallback, or any form bound to a category - carries NULL and never collides with anything. That
-- keeps "a seeded template may be copied and retired" true for the fallback as well.
--
-- ── A FOREIGN KEY TOLERATES NULL ──
--
-- `fk_woft_category` is left exactly as it is. An InnoDB foreign key is satisfied by a NULL in the
-- referencing column - there is no parent to find, so there is nothing to refuse - which is why
-- this file does not drop and rebuild it. The verification at the foot proves the constraint is
-- still present after the column is widened.
--
-- IDEMPOTENT. Every ALTER reads `information_schema` first and becomes `DO 0` when the object is
-- already there; the head is `INSERT IGNORE` behind `uq_woft_name` and `uq_woft_fallback`; the
-- fields are `INSERT IGNORE` behind `uq_woff_key`; the groups and the steps carry no unique key by
-- the decision recorded in `work_order_form_templates.sql` section 3, so each is seeded by an
-- anti-join. Run it twice and the second run writes nothing.
-- ==============================================================================================

-- ==============================================================================================
-- 1. `category_id` BECOMES NULLABLE
--
-- NULL means "any category that has no form of its own". It is read in exactly one place, and that
-- place is `TEMPLATE_RESOLUTION`.
--
-- ── THE ORDER IS MODIFY, THEN THE GENERATED COLUMN, THEN THE INDEX ──
--
-- A STORED generated column records a dependency on the columns its expression names, and MySQL
-- refuses some alterations to a column another column is generated from. Widening `category_id`
-- BEFORE `fallback_key` exists avoids the question entirely; and the index names `fallback_key`,
-- so it cannot be added first either. The wrong order fails on one statement and leaves a
-- half-applied file, which is harder to read than a clean failure.
--
-- Read from `IS_NULLABLE` rather than from the column's presence: the column is always there, and
-- the only fact worth testing is whether it still refuses NULL.
-- ==============================================================================================
SET @woft_cat_nullable := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND COLUMN_NAME = 'category_id'
     AND IS_NULLABLE = 'YES'
)
-- >>>
SET @sql := IF(@woft_cat_nullable = 0,
  'ALTER TABLE `work_order_form_templates`
     MODIFY COLUMN `category_id` INT UNSIGNED NULL',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ==============================================================================================
-- 2. `fallback_key` - THE GENERATED COLUMN THAT CAPS THE FALLBACK AT ONE
--
-- STORED rather than VIRTUAL, for the reason `active_key` records: a unique index over a virtual
-- generated column re-evaluates the expression on every read of the index, while STORED writes it
-- once.
-- ==============================================================================================
SET @woft_fallback_col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND COLUMN_NAME = 'fallback_key'
)
-- >>>
SET @sql := IF(@woft_fallback_col = 0,
  'ALTER TABLE `work_order_form_templates`
     ADD COLUMN `fallback_key` TINYINT
       GENERATED ALWAYS AS (IF(`is_active` = 1 AND `category_id` IS NULL, 1, NULL)) STORED
       AFTER `active_key`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ==============================================================================================
-- 3. `uq_woft_fallback` - AT MOST ONE ACTIVE FALLBACK
-- ==============================================================================================
SET @woft_uq_fallback := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_form_templates'
     AND INDEX_NAME = 'uq_woft_fallback'
)
-- >>>
SET @sql := IF(@woft_uq_fallback = 0,
  'ALTER TABLE `work_order_form_templates`
     ADD UNIQUE KEY `uq_woft_fallback` (`fallback_key`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ==============================================================================================
-- 4. THE SEEDED FALLBACK HEAD
--
-- `is_system = 1`, so no Remove control is drawn for it and the endpoint refuses a delete. It may
-- still be corrected, copied and retired, which is what `is_system` has always meant on this table.
--
-- NAMED FOR WHAT IT IS. "General Preventive Maintenance" is the form; the printed heading is what
-- the customer reads off the paper. Neither mentions a category, because this one has none.
-- ==============================================================================================
INSERT IGNORE INTO `work_order_form_templates`
  (`name`, `category_id`, `form_title`, `description`, `is_active`, `is_system`, `created_by`)
VALUES
  ('General Preventive Maintenance', NULL,
   'GENERAL PREVENTIVE MAINTENANCE SERVICE FORM',
   'Applies to any asset whose device category has no service form of its own. One sheet per unit, with a before and an after photograph.',
   1, 1, 'migration')
-- >>>
-- ==============================================================================================
-- 4a. THE DEVICE INFORMATION BLOCK - TRUE OF ANY ASSET
--
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- EVERY SOURCE IS A COLUMN `assets` ACTUALLY HAS, AND THE LIST IS CHECKED AT THE FOOT
-- ══════════════════════════════════════════════════════════════════════════════════════════════
--
-- Eleven lines, all eleven autofilled: asset_no, name, category, brand, model, serial_no, tag_no,
-- location, site_name, installed_on, condition_note. `AUTOFILL_COLUMNS` in
-- `src/lib/work-order-sheets.ts` is the allow-list the raiser reads them through, and
-- `bad_autofill` in the verification SELECT joins `information_schema.COLUMNS` to prove none of
-- them is wrong rather than trusting this comment.
--
-- NOTHING DEVICE-SPECIFIC. There is no Operating System line, no Battery Health, no IP Address and
-- no Firmware Ver.: this form raises the sheet for a ladder, a desk, a fan and a fire extinguisher,
-- and a printed line that is blank on every one of them is a line that makes the paperwork look
-- unfinished.
--
-- ── ONLY TWO LINES ARE REQUIRED, AND THAT IS NOT LAZINESS ──
--
-- `asset_no` and the asset's name, because a sheet has to say WHICH unit it is. Brand, model and
-- serial number are blank in the register for most of the 246 units this form exists for - a
-- 10-step aluminium ladder has no model number - so marking them required would demand that a
-- technician invent a value before they could file the sheet.
--
-- ── WHICH FALLBACK ROW THE CHILDREN ATTACH TO ──
--
-- `WHERE t.category_id IS NULL AND t.is_active = 1`, not `WHERE t.name = '...'`. `uq_woft_fallback`
-- guarantees that predicate matches at most one row, and it keeps working if somebody renames the
-- form - which they are allowed to do, because `is_system` forbids delete and not edit. Keying the
-- children off the name would silently seed nothing after a rename.
-- ==============================================================================================
INSERT IGNORE INTO `work_order_form_fields`
  (`template_id`, `label`, `field_key`, `input_type`, `autofill_from`, `is_required`, `sort_order`)
SELECT t.`id`, s.`label`, s.`field_key`, s.`input_type`, s.`autofill_from`,
       s.`is_required`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Asset No.'            AS `label`, 'asset_no'            AS `field_key`,
                     'text'                 AS `input_type`, 'asset_no'       AS `autofill_from`,
                     1                      AS `is_required`, 1               AS `sort_order`
    UNION ALL SELECT 'Asset Name',           'asset_name',          'text',     'name',            1,  2
    UNION ALL SELECT 'Device Type',          'device_type',         'text',     'category',        0,  3
    UNION ALL SELECT 'Brand',                'brand',               'text',     'brand',           0,  4
    UNION ALL SELECT 'Model',                'model',               'text',     'model',           0,  5
    UNION ALL SELECT 'Serial No.',           'serial_no',           'text',     'serial_no',       0,  6
    UNION ALL SELECT 'Asset Tag',            'tag_no',              'text',     'tag_no',          0,  7
    UNION ALL SELECT 'Location',             'location',            'text',     'location',        0,  8
    UNION ALL SELECT 'Site',                 'site',                'text',     'site_name',       0,  9
    UNION ALL SELECT 'Installed On',         'installed_on',        'date',     'installed_on',    0, 10
    UNION ALL SELECT 'Condition on Arrival', 'condition_on_arrival','textarea', 'condition_note',  0, 11
       ) s
 WHERE t.`category_id` IS NULL AND t.`is_active` = 1
-- >>>
-- ==============================================================================================
-- 4b. THE CHECKLIST GROUPS - FOUR, AND EVERY ONE OF THEM APPLIES TO ANYTHING
--
-- The seeded per-category forms group by what the device HAS: `Power & Battery`,
-- `Configuration & Firmware`, `Recording & Storage`. None of those means anything on a chair. These
-- four group by what a person can OBSERVE and are true of a ladder, a laptop and a fire
-- extinguisher alike.
--
-- Anti-joined on (template_id, title), the shape `work_order_form_templates.sql` section 7d uses,
-- because a group deliberately carries no unique key.
-- ==============================================================================================
INSERT INTO `work_order_form_groups` (`template_id`, `title`, `sort_order`)
SELECT t.`id`, s.`title`, s.`sort_order`
  FROM `work_order_form_templates` t
  JOIN (
              SELECT 'Condition & Cleanliness'    AS `title`, 1 AS `sort_order`
    UNION ALL SELECT 'Identification',             2
    UNION ALL SELECT 'Safety & Function',          3
    UNION ALL SELECT 'Environment & Storage',      4
       ) s
 WHERE t.`category_id` IS NULL AND t.`is_active` = 1
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_groups` g
      WHERE g.`template_id` = t.`id` AND g.`title` = s.`title`
   )
-- >>>
-- ==============================================================================================
-- 4c. THE CHECKLIST - 7 STEPS, 5 OF THEM REQUIRED
--
-- The steps the user named, in the user's terms: visual condition, physical damage, cleanliness,
-- labelling and asset tag legible, safe to operate, moving or wearing parts, environment and
-- storage.
--
-- REQUIRED are the five that can be answered about ANY unit standing in front of you, and a
-- required step cannot be marked N / A - `chk_wossi_na_remark` and the submit endpoint both hold
-- that rule, so marking a step required is a promise that it is always answerable.
--
-- NOT REQUIRED are the two that are not always a thing: a desk has no moving or wearing parts, and
-- a unit bolted to a wall has no storage arrangement to assess. Those print N / A with a comment,
-- which is the honest answer rather than a forced tick.
--
-- `sort_order` runs 1..7 across the whole template rather than restarting inside each group, which
-- is the number printed in the sheet's No. column.
-- ==============================================================================================
INSERT INTO `work_order_form_items` (`group_id`, `title`, `is_required`, `sort_order`)
SELECT g.`id`, s.`title`, s.`is_required`, s.`sort_order`
  FROM `work_order_form_groups` g
  JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
  JOIN (
              SELECT 'Condition & Cleanliness' AS `grp`,
                     'Overall visual condition inspected and recorded' AS `title`,
                     1 AS `is_required`, 1 AS `sort_order`
    UNION ALL SELECT 'Condition & Cleanliness', 'Physical damage, cracks, dents or corrosion checked',       1, 2
    UNION ALL SELECT 'Condition & Cleanliness', 'Unit cleaned and wiped down',                               1, 3
    UNION ALL SELECT 'Identification',          'Asset label and asset tag present and legible',             1, 4
    UNION ALL SELECT 'Safety & Function',       'Safe to operate, no exposed hazard',                        1, 5
    UNION ALL SELECT 'Safety & Function',       'Moving, wearing and consumable parts checked',              0, 6
    UNION ALL SELECT 'Environment & Storage',   'Storage, mounting and surrounding environment checked',     0, 7
       ) s ON s.`grp` = g.`title`
 WHERE t.`category_id` IS NULL AND t.`is_active` = 1
   AND NOT EXISTS (
     SELECT 1 FROM `work_order_form_items` i
      WHERE i.`group_id` = g.`id` AND i.`title` = s.`title`
   )
-- >>>
-- ==============================================================================================
-- VERIFICATION. Printed by scripts/run-sql.js, so a reader sees the shape that resulted.
--
-- EXPECTED, and these are the numbers to compare a second run against:
--
--   cat_nullable 1      `category_id` now accepts NULL
--   fallback_gen 1      `fallback_key` is GENERATED and STORED, read from EXTRA
--   uq_fallback 1       `uq_woft_fallback` exists and holds exactly one column
--   uq_fallback_col 1   and that column is `fallback_key`
--   uq_active_cols 2    `uq_woft_active_cat` is UNCHANGED - still two columns
--   uq_active_is_key 1  and its second column is still `active_key`
--   fk_category 1       `fk_woft_category` survived the widening
--   fallback_tpl 1       exactly ONE active fallback head
--   fallback_system 1    and it is seeded
--   templates 4          the three category forms plus this one
--   fb_fields 11         the Device Information block
--   fb_autofill 11       every line fills from the register
--   fb_required_fields 2 asset_no and asset_name
--   fb_groups 4
--   fb_items 7
--   fb_required 5
--   bad_autofill 0       no autofill_from on ANY template names a column `assets` lacks
--   covered 488          every asset in the register now resolves to a form
--   uncovered 0          and this is the figure the whole file exists to move
--
-- `covered` and `uncovered` re-derive the coverage with the SAME expression
-- `TEMPLATE_RESOLUTION` uses - `COALESCE(ac.parent_id, ac.id)` for the specific form, then the
-- fallback. A migration that claims to fix coverage and does not measure it is a claim nobody can
-- check, and the before figures are in this file's header to compare against.
-- ==============================================================================================
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND COLUMN_NAME = 'category_id' AND IS_NULLABLE = 'YES')                   AS cat_nullable,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND COLUMN_NAME = 'fallback_key' AND EXTRA LIKE '%STORED GENERATED%')      AS fallback_gen,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_fallback')                                       AS uq_fallback,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_fallback' AND COLUMN_NAME = 'fallback_key')      AS uq_fallback_col,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_active_cat')                                     AS uq_active_cols,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_form_templates'
      AND INDEX_NAME = 'uq_woft_active_cat' AND COLUMN_NAME = 'active_key'
      AND SEQ_IN_INDEX = 2)                                                      AS uq_active_is_key,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_TYPE = 'FOREIGN KEY'
      AND CONSTRAINT_NAME = 'fk_woft_category')                                  AS fk_category,
  (SELECT COUNT(*) FROM `work_order_form_templates`
    WHERE `category_id` IS NULL AND `is_active` = 1)                             AS fallback_tpl,
  (SELECT COUNT(*) FROM `work_order_form_templates`
    WHERE `category_id` IS NULL AND `is_active` = 1 AND `is_system` = 1)         AS fallback_system,
  (SELECT COUNT(*) FROM `work_order_form_templates`)                             AS templates,
  (SELECT COUNT(*) FROM `work_order_form_fields` f
     JOIN `work_order_form_templates` t ON t.`id` = f.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1)                         AS fb_fields,
  (SELECT COUNT(*) FROM `work_order_form_fields` f
     JOIN `work_order_form_templates` t ON t.`id` = f.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1
      AND f.`autofill_from` IS NOT NULL)                                         AS fb_autofill,
  (SELECT COUNT(*) FROM `work_order_form_fields` f
     JOIN `work_order_form_templates` t ON t.`id` = f.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1
      AND f.`is_required` = 1)                                                   AS fb_required_fields,
  (SELECT COUNT(*) FROM `work_order_form_groups` g
     JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1)                         AS fb_groups,
  (SELECT COUNT(*) FROM `work_order_form_items` i
     JOIN `work_order_form_groups` g ON g.`id` = i.`group_id`
     JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1)                         AS fb_items,
  (SELECT COUNT(*) FROM `work_order_form_items` i
     JOIN `work_order_form_groups` g ON g.`id` = i.`group_id`
     JOIN `work_order_form_templates` t ON t.`id` = g.`template_id`
    WHERE t.`category_id` IS NULL AND t.`is_active` = 1 AND i.`is_required` = 1) AS fb_required,
  (SELECT COUNT(*) FROM `work_order_form_fields` f
    WHERE f.`autofill_from` IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS ic
                       WHERE ic.TABLE_SCHEMA = DATABASE() AND ic.TABLE_NAME = 'assets'
                         AND ic.COLUMN_NAME = f.`autofill_from`))                 AS bad_autofill,
  (SELECT COUNT(*) FROM `assets` a
     LEFT JOIN `asset_categories` ac ON ac.`name` = a.`category`
    WHERE COALESCE(
            (SELECT t.`id` FROM `work_order_form_templates` t
              WHERE t.`category_id` = COALESCE(ac.`parent_id`, ac.`id`) AND t.`is_active` = 1),
            (SELECT fb.`id` FROM `work_order_form_templates` fb
              WHERE fb.`category_id` IS NULL AND fb.`is_active` = 1)
          ) IS NOT NULL)                                                          AS covered,
  (SELECT COUNT(*) FROM `assets` a
     LEFT JOIN `asset_categories` ac ON ac.`name` = a.`category`
    WHERE COALESCE(
            (SELECT t.`id` FROM `work_order_form_templates` t
              WHERE t.`category_id` = COALESCE(ac.`parent_id`, ac.`id`) AND t.`is_active` = 1),
            (SELECT fb.`id` FROM `work_order_form_templates` fb
              WHERE fb.`category_id` IS NULL AND fb.`is_active` = 1)
          ) IS NULL)                                                              AS uncovered
