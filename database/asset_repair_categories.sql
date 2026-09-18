-- ============================================================
-- REPAIR CATEGORIES — the kinds of service, as ROWS instead of an ENUM
--
-- WHAT THIS IS FOR
--
-- `asset_maintenance.kind` was an ENUM of five values fixed in the DDL:
--
--     ENUM('preventive','corrective','inspection','calibration','upgrade')
--
-- Adding a sixth meant an ALTER and a deploy. That is the same argument `tender_categories` records
-- for itself — "adding one should not be a deploy" — and the same one `procurement_categories` and
-- `asset_categories` already settled. This finishes the job for the last hardcoded list in the asset
-- module.
--
-- The trigger was a specific request: the Under Repair action on the register should ask WHICH KIND
-- of repair, and that dropdown should be maintainable in Asset Settings rather than in a TypeScript
-- constant.
--
-- ONE VOCABULARY, NOT TWO
--
-- These five ARE `MAINTENANCE_KINDS` in `src/lib/assets.ts`. They are not a new list beside them.
-- `calibration` was already one of them, which is why a second "repair kinds" master would have put
-- the word in two places and guaranteed they drift.
--
-- The consequence is deliberate and worth stating: a row added here appears in the Maintenance &
-- Repairs Kind filter and in the Add Service form too, because those read the same column.
--
-- ── WHY ENUM → VARCHAR AND NOT A FOREIGN KEY ──
--
-- `asset_maintenance.kind` becomes VARCHAR(60) holding the NAME, matched to
-- `asset_repair_categories.name` by text. No foreign key. That is the same bargain three tables in
-- this schema already make — `assets.category` → `asset_categories.name`, `tenders.category` →
-- `tender_categories.name` — and it is a bargain rather than an oversight:
--
--   * A category that any record names cannot be deleted; the endpoint refuses and offers
--     deactivation instead. So the dangling-reference case an FK would prevent is already prevented.
--   * A rename cascades in the endpoint (`UPDATE asset_maintenance SET kind = ?`), the same way
--     `asset-categories.ts` already cascades a category rename onto `assets`.
--   * The name on the record IS the historical fact. A service recorded as "Calibration" should still
--     read "Calibration" years later even if the master row is gone, which an FK with CASCADE would
--     destroy and an FK with RESTRICT would merely duplicate the endpoint's own refusal.
--
-- MySQL converts an ENUM to VARCHAR by writing the LABELS, not the ordinals, so every existing row
-- keeps the word it already had. Nothing anywhere reads this column's ordinal — checked: it is always
-- ordered by `service_date`, never by `kind`.
--
-- THE SEED IS THE FIVE THAT EXIST
--
-- So the day this runs, every dropdown offers exactly what it offered before and every existing
-- record still validates. The migration changes what is POSSIBLE, not what is there.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_repair_categories.sql
-- ============================================================

-- >>>
-- ── The master ──
-- Shaped on `tender_categories`, which is the closest sibling: a name, an icon for the screen, a sort
-- order and an active flag. No `useful_life_years` and no `default_loanable` — those belong to a
-- category of EQUIPMENT, and this is a category of WORK.
CREATE TABLE IF NOT EXISTS `asset_repair_categories` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(60)  NOT NULL,
  `icon`       VARCHAR(60)  NOT NULL DEFAULT 'bi-wrench-adjustable',
  -- Whether a record of this kind normally schedules the next visit. Preventive and calibration do;
  -- a corrective repair is finished when it is finished. It seeds nothing and gates nothing — it is
  -- the hint the service form shows beside Next Due, so the person recording knows whether leaving
  -- it empty is normal or an omission.
  `expects_next_due` TINYINT(1) NOT NULL DEFAULT 0,
  `notes`      VARCHAR(300) DEFAULT NULL,
  `sort_order` INT          NOT NULL DEFAULT 0,
  `is_active`  TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_repair_cat_name` (`name`),
  KEY `idx_repair_cat_active` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- >>>
-- The five that already exist, in the order they were declared in the ENUM, so the dropdown reads
-- the same as it did before. `INSERT IGNORE` against the unique name: a re-run adds nothing.
INSERT IGNORE INTO `asset_repair_categories`
  (`name`, `icon`, `expects_next_due`, `notes`, `sort_order`) VALUES
  ('Preventive',  'bi-shield-check',       1,
   'Scheduled servicing. The next visit is the whole point of the record.',                    1),
  ('Corrective',  'bi-wrench-adjustable',  0,
   'Something broke and was fixed. Finished when it is finished.',                             2),
  ('Inspection',  'bi-search',             1,
   'A look at it without necessarily doing anything, usually on a cycle.',                      3),
  ('Calibration', 'bi-rulers',             1,
   'Brought back within tolerance. Instruments carry a due date by regulation.',                4),
  ('Upgrade',     'bi-arrow-up-circle',    0,
   'More capable than before rather than merely working again.',                                5)

-- >>>
-- ── The column ──
-- Guarded on DATA_TYPE, not on the column's existence: `kind` has always been there, and what this
-- migration changes is its TYPE. A guard on existence would be satisfied on the first run and would
-- never convert anything.
SET @kind_type := (
  SELECT DATA_TYPE FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance'
     AND COLUMN_NAME = 'kind'
)

-- >>>
-- The whole definition is restated, because MODIFY COLUMN replaces rather than amends: anything left
-- out is lost. NOT NULL and the default are written out deliberately — read from the original DDL,
-- not guessed. Dropping NOT NULL here would let a service record exist with no kind at all.
--
-- The DEFAULT changes case with the column: the ENUM's lowercase 'corrective' becomes 'Corrective',
-- matching the seeded row, because the master's names are what the dropdown shows and a default that
-- did not match a row would render as a blank selection.
SET @kind_ddl := IF(
  @kind_type = 'enum',
  'ALTER TABLE `asset_maintenance`
     MODIFY COLUMN `kind` VARCHAR(60)
       COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''Corrective''
       COMMENT ''asset_repair_categories.name, by text''',
  'DO 0'
)

-- >>>
PREPARE kind_stmt FROM @kind_ddl

-- >>>
EXECUTE kind_stmt

-- >>>
DEALLOCATE PREPARE kind_stmt

-- >>>
-- ── The existing rows ──
-- MySQL wrote the ENUM's LABELS when it converted, so every row now holds a lowercase word:
-- 'preventive', 'corrective' and so on. The master's names are capitalised, and the screen matches
-- them by text — so an unconverted row would show as an unknown kind and would not match its own
-- category.
--
-- Run unconditionally and matched on the lowercase form, so it is a no-op on the second run.
UPDATE `asset_maintenance` SET `kind` = 'Preventive'  WHERE `kind` = 'preventive'

-- >>>
UPDATE `asset_maintenance` SET `kind` = 'Corrective'  WHERE `kind` = 'corrective'

-- >>>
UPDATE `asset_maintenance` SET `kind` = 'Inspection'  WHERE `kind` = 'inspection'

-- >>>
UPDATE `asset_maintenance` SET `kind` = 'Calibration' WHERE `kind` = 'calibration'

-- >>>
UPDATE `asset_maintenance` SET `kind` = 'Upgrade'     WHERE `kind` = 'upgrade'

-- >>>
-- ── The permissions ──
-- Its own module, for the same reason `asset_categories` is: a role can maintain the register without
-- redefining the vocabulary every service record is classified by.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('asset_repair_categories', 'view',   'asset_repair_categories_view',
   'View repair categories',   'operations'),
  ('asset_repair_categories', 'create', 'asset_repair_categories_create',
   'Add a repair category',    'operations'),
  ('asset_repair_categories', 'edit',   'asset_repair_categories_edit',
   'Change a repair category', 'operations'),
  ('asset_repair_categories', 'delete', 'asset_repair_categories_delete',
   'Remove a repair category', 'operations')

-- >>>
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'asset_repair_categories'

-- >>>
-- ── Verification ──
-- `kind_is_varchar` must read 1, `categories` 5 or more, `unmatched_rows` 0, and `permissions` 4.
-- `unmatched_rows` is the one that matters most: a record still holding a lowercase word would show on
-- the Maintenance screen as a kind no category matches, and its filter would never find it.
SELECT
  (SELECT COUNT(*) FROM `asset_repair_categories`)                              AS categories,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance'
      AND COLUMN_NAME = 'kind' AND DATA_TYPE = 'varchar')                       AS kind_is_varchar,
  -- `unmatched_rows` is the figure that matters, and it replaces a case-comparison expression that
  -- used `||` for concatenation. In MySQL `||` is OR unless PIPES_AS_CONCAT is set, so that check
  -- would have compared a string against a boolean and reported nonsense. This asks the question
  -- directly instead: is there a service record whose kind no category matches.
  (SELECT COUNT(*) FROM `asset_maintenance` m
    WHERE NOT EXISTS (SELECT 1 FROM `asset_repair_categories` c
                       WHERE c.`name` = m.`kind`))                              AS unmatched_rows,
  (SELECT COUNT(*) FROM `permissions`
    WHERE `module` = 'asset_repair_categories')                                 AS permissions
