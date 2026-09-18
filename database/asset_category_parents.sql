-- ============================================================
-- Asset Settings > Categories — TWO LEVELS, and a data repair
--
-- The register had grown to 61 categories in one flat list: 11 of the 12 seeded classes
-- (Computer & Laptop, Vehicle, Tools & Instruments …) sitting beside 50 product-level rows somebody
-- added as they went (COMPUTER MOUSE, WALL FAN, CORDLESS IMPACT DRIVER, SAFETY HELMET). Both kinds
-- were offered in the same dropdown with no indication which was which.
--
-- 11 of 12, not 12: `Office Furniture` had been deleted. It is restored below, and the statement that
-- does it carries the reason that matters more than the row.
--
-- ── EVERY NUMBER IN THIS FILE WAS RE-MEASURED ON 2026-08-21 ──
--
-- Against the PRODUCTION dump, after it was imported over the development database. An earlier version
-- of this file quoted 62 categories, 201 assets and 45 assets without a book value; those were the
-- development figures and every one of them was stale. The current figures are 61, 212 and 80. A
-- migration whose stated measurements do not match the database it runs on cannot be reviewed.
--
-- ── WHAT THIS DOES NOT DO, AND IT IS THE MOST IMPORTANT LINE IN THIS FILE ──
--
-- `assets.category` is NOT touched. It stays a VARCHAR holding the category NAME, and category names
-- stay UNIQUE across the whole table. So:
--
--   * not one of the 212 asset rows is re-pointed
--   * the CSV import, which matches a spreadsheet cell against a category NAME, keeps working
--   * `asset_models.category` — 85 rows across 58 distinct names — keeps working
--   * the ~15 SELECTs that read `a.category` for display keep working
--   * nothing is deleted and nothing is renamed by this file
--
-- The alternative was names unique only WITHIN a parent, which is tidier on paper and would have
-- forced `assets.category` to become a foreign key id. That reaches 14 read paths including the CSV
-- importer, where a cell reading "MOUSE" would stop identifying anything. The register already
-- solves the collision the cheap way, by prefixing: COMPUTER MOUSE against WIRELESS MOUSE.
--
-- `parent_id` therefore exists for exactly two jobs: GROUPING the list, and INHERITANCE of defaults.
--
-- ── SUB-CATEGORIES ARE OPTIONAL, AND THE NUMBER IS WHY ──
--
-- MEASURED: 127 of the 212 assets are classified on the seeded classes, and `Computer & Laptop` alone
-- holds 118. Those are the rows that become PARENTS. Making a sub-category compulsory would orphan 60%
-- of the register and force somebody to re-pick a classification that is already correct. So a parent
-- stays selectable on the asset form, and the sub-category picker offers "use the parent itself" first.
--
-- ── TWO LEVELS, NOT A TREE ──
--
-- `parent_id` self-references, so nothing in the column stops a third level. The ENDPOINT enforces
-- the cap: a category that has children cannot be given a parent, and a child cannot become one.
-- Without that cap the filter, the reports and every picker need recursion, and the register has one
-- filter and four pickers.
--
-- ON DELETE RESTRICT, not CASCADE and not SET NULL. Deleting a parent must not silently take its
-- children with it, and must not quietly promote them to top level either — both would rewrite the
-- classification of assets nobody was looking at. The endpoint refuses the delete and says so.
--
-- ── THE DATA REPAIR: `asset_class` WAS WRONG, AND IT WAS BLOCKING CHECKOUT ──
--
-- `asset_class` is not a label. `LOANABLE_CLASSES = ['movable']`, so the free-to-issue rule behind
-- Checkout & Loans filters on `a.asset_class = 'movable'`. Anything marked `fixed` can NEVER be
-- issued at the counter.
--
-- Measured: 25 internal assets were `fixed`, including a WIRELESS MOUSE, a ROOF RACK, a RATCHET TIE
-- DOWN and two MEDIUM-BACK OFFICE CHAIRs. `ASSET_CLASS_HINT` in `lib/assets.ts` defines `fixed` as
-- "Cannot be moved — land, buildings, a tower, buried cabling". A chair is not that.
--
-- And it was wrong in the other direction too: `BUILDING` was `movable`, which is precisely the
-- defect `asset_class` was introduced to prevent. Its own docblock reads "a building would have
-- appeared on the shelf as 'available to issue'. You cannot hand a building over a counter."
-- BUILDING holds no assets yet, so nothing is damaged — the next one recorded would have been.
--
-- The rule applied below: a child takes its PARENT's class. Two exceptions stay `fixed`, named
-- explicitly rather than pattern-matched — BUILDING and SPLIT UNIT AIRCONDITIONING, both of which
-- need a technician to remove.
--
-- ── WHY IT IS SAFE TO WRITE `assets.asset_class` AT ALL ──
--
-- That column is deliberately OWNED by the asset: `[id].ts` lets it be edited per unit, because
-- "a portable cabin under Building is movable". So a blanket update could in principle destroy a
-- deliberate override.
--
-- MEASURED FIRST, and re-measured on the production dump: zero assets disagree with their category's
-- class. Every one of the 212 was seeded at creation and none has been overridden. So this repair
-- cannot overwrite a decision anybody made, and the final SELECT reports exactly how many rows moved.
-- If that count is ever non-zero BEFORE this file runs, this statement stops being safe and the
-- disagreeing rows have to be read one by one first.
--
-- ── WHAT IS DELIBERATELY LEFT ALONE ──
--
-- 48 of the 61 categories carry no `useful_life_years`, so 80 assets carry no book value. Backfilling
-- that would change a depreciation figure that may already be in a signed report, and the module's
-- own rule is that a category's life is a DEFAULT for new assets and never retroactive. Inheritance
-- fixes it going forward; the existing 80 are an accounting decision, not a migration's.
--
-- 80, where the development database showed 45. The difference is not a regression: 11 assets were
-- recorded in production since, and they landed on product-level categories that carry no life. It is
-- the same gap getting wider every week, which is the argument for inheritance rather than against it.
--
-- `WATER FITER HOT AND COLD` is a typo. Not corrected here: renaming cascades onto `assets.category`
-- and the endpoint already does that safely, so it belongs in the UI where it is one edit and is
-- audit-logged.
--
-- Idempotent. Adding a column and its DDL are separate statements over a session variable.
-- Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_category_parents.sql
-- ============================================================

-- >>>
SET @acp_col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_categories'
     AND COLUMN_NAME = 'parent_id'
)

-- >>>
SET @acp_col_ddl := IF(
  @acp_col = 0,
  'ALTER TABLE `asset_categories`
     ADD COLUMN `parent_id` INT UNSIGNED DEFAULT NULL
       COMMENT ''asset_categories.id of the parent. NULL means this IS a parent. Two levels only''
       AFTER `name`,
     ADD KEY `idx_asset_cat_parent` (`parent_id`)',
  'DO 0'
)

-- >>>
PREPARE acp_col_stmt FROM @acp_col_ddl

-- >>>
EXECUTE acp_col_stmt

-- >>>
DEALLOCATE PREPARE acp_col_stmt

-- >>>
-- The foreign key is added separately, so a re-run that already has the column does not try to add
-- the constraint twice.
SET @acp_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_categories'
     AND CONSTRAINT_NAME = 'fk_asset_cat_parent'
)

-- >>>
SET @acp_fk_ddl := IF(
  @acp_fk = 0,
  'ALTER TABLE `asset_categories`
     ADD CONSTRAINT `fk_asset_cat_parent` FOREIGN KEY (`parent_id`)
       REFERENCES `asset_categories` (`id`) ON DELETE RESTRICT',
  'DO 0'
)

-- >>>
PREPARE acp_fk_stmt FROM @acp_fk_ddl

-- >>>
EXECUTE acp_fk_stmt

-- >>>
DEALLOCATE PREPARE acp_fk_stmt

-- >>>
-- ── The parents this file needs, created if they are not there ──
--
-- `Appliances` and `Safety & PPE` are genuinely NEW: six appliance rows and one PPE row had no
-- sensible home among the seeded classes. `Power & Electrical` is cabling and distribution, not a
-- refrigerator, and a safety helmet is not an instrument.
--
-- ── EVERY PARENT THE MAPPING JOINS ON IS LISTED HERE, AND THAT IS THE POINT ──
--
-- Seven of these nine already exist as seeded classes. Listing them looks redundant and is not, and the
-- bug that proves it cost an hour:
--
-- MEASURED on the production dump: `Office Furniture` is ABSENT. It is seeded by `operations_assets.sql`
-- as `('Office Furniture', 'bi-lamp', 10, 7)`, it held no assets, so the Categories screen allowed it to
-- be deleted — and somebody did. `FURNITURE` holds the 8 desks instead.
--
-- The mapping statements below join a child to its parent BY NAME. A join whose parent name matches
-- nothing does not fail: it matches zero rows, reports success, and leaves all ten furniture children at
-- top level. The verification SELECT could not see it either, because a child that never got a parent
-- has `parent_id NULL` — the same value a real parent has. The run printed `orphan_children: 0` and was
-- wrong about ten rows.
--
-- ── AND "IT IS IN THE SEED FILE" IS NOT EVIDENCE THAT IT EXISTS ──
--
-- The first version of the test for this accepted a parent that was EITHER created here OR present in
-- `operations_assets.sql`. It passed with `Office Furniture` removed from this statement, because the
-- seed file still names it. That is exactly the situation that broke: seeded once, deleted later.
-- Calibration caught it — the mutation did not go red.
--
-- So the rule is that a parent the mapping joins on must be created HERE. Five of these nine can still
-- be deleted from the register today, because they hold no assets of their own and the DELETE guard only
-- refuses a category in use: Server & Storage, Network Equipment, Mobile Device, CCTV & Security and
-- Office Furniture. Any one of them going missing before a re-run would silently drop its children.
--
-- `Appliances` and `Safety & PPE` are the two that are genuinely new. The other seven carry their
-- seeded values, so a row that has to be recreated comes back as it was rather than as a guess.
--
-- INSERT IGNORE on a UNIQUE name: a re-run adds nothing, and an existing row is left EXACTLY as it is.
-- This cannot overwrite a category somebody has edited — which is why listing a row that already exists
-- costs nothing.
INSERT IGNORE INTO `asset_categories`
  (`name`, `asset_class`, `icon`, `useful_life_years`, `default_loanable`, `sort_order`, `is_active`)
VALUES
  ('Computer & Laptop',   'movable', 'bi-laptop',           4, 1,  1, 1),
  ('Printer & Scanner',   'movable', 'bi-printer',          4, 0,  4, 1),
  ('Mobile Device',       'movable', 'bi-phone',            3, 1,  5, 1),
  ('Office Furniture',    'movable', 'bi-lamp',            10, 0,  7, 1),
  ('Tools & Instruments', 'movable', 'bi-tools',            5, 1,  8, 1),
  ('CCTV & Security',     'movable', 'bi-camera-video',     5, 0,  9, 1),
  ('Power & Electrical',  'movable', 'bi-lightning-charge', 7, 0, 10, 1),
  ('Appliances',          'movable', 'bi-plug',             5, 0, 13, 1),
  ('Safety & PPE',        'movable', 'bi-shield-check',     3, 1, 14, 1)

-- >>>
-- ── The mapping: 49 children onto 9 parents ──
--
-- By NAME on both sides, because the name is what `assets.category` holds and what a reader
-- recognises. Idempotent: re-running sets the same values.
--
-- ROOF RACK and CAR JUMPER ELECTRIC are under Tools & Instruments and NOT under Vehicle, which looks
-- wrong for about a second and is deliberate. `detail_form` is inherited, so a child of Vehicle would
-- be asked for a number plate and a chassis number. A roof rack has neither.
--
-- BUILDING is absent from every list below: it becomes a PARENT.
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Computer & Laptop'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('COMPUTER KEYBOARD', 'COMPUTER MICRO DESKTOP', 'COMPUTER MOUSE',
                    'COMPUTER MONITOR 20 INCH', 'COMPUTER TOWER DESKTOP', 'WIRELESS KEYBOARD',
                    'WIRELESS MOUSE', 'FLASH DRIVE')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Printer & Scanner'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('LABEL PRINTER', 'LAMINATE MACHINE')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Mobile Device'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('ANDROID PLAYER')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Office Furniture'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('FURNITURE', 'SOFA', 'SIDE TABLE', 'OFFICE DESK', 'MEDIUM-BACK OFFICE CHAIR',
                    'SHOE AND STORAGE CABINETS', 'BANQUET TABLE',
                    'STACKABLE 3 LAYER OFFICE LETTER', 'WHITE BOARD', 'STACKABLE BOX')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Tools & Instruments'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('LASER LEVEL METER', 'LASER DISTANCE METER', 'METER ROLLER STAND REEL',
                    'CORDLESS CIRCULAR SAW', 'DRILL BIT SET', 'CORDLESS ELECTRIC SCREWDRIVER',
                    'CORDLESS KNIFE SAW', 'CORDLESS IMPACT DRIVER', 'WIRED IMPACT DRILL',
                    'RATCHET TIE DOWN', 'SPOT LIGHT TRIPOD STAND', 'ENGINE BLOWER',
                    'ENGINE WATER JET', 'TIME LAPSE CAMERA', 'ACTION CAMERA', 'ROOF RACK',
                    'CAR JUMPER ELECTRIC')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'CCTV & Security'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('WIRELESS CCTV CAMERA', 'BODY CAMERA')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Power & Electrical'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('PORTABLE POWER STATION', 'SOLAR LAMP')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Appliances'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('AIR COOLER', 'SPLIT UNIT AIRCONDITIONING', 'WALL FAN', 'REFRIGERATOR',
                    'WATER FITER HOT AND COLD', 'AIRCOND REMOTE CONTROL')

-- >>>
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`name` = 'Safety & PPE'
   SET c.`parent_id` = p.`id`
 WHERE c.`name` IN ('SAFETY HELMET')

-- >>>
-- ── Repair 1: the two categories that genuinely cannot be carried ──
--
-- Named rather than derived. BUILDING was `movable`, which would have put the next building recorded
-- onto the Checkout shelf. A SPLIT UNIT air-conditioner is bolted to a wall with a refrigerant line
-- through it.
UPDATE `asset_categories`
   SET `asset_class` = 'fixed'
 WHERE `name` IN ('BUILDING', 'SPLIT UNIT AIRCONDITIONING')

-- >>>
-- ── Repair 2: every other child takes its parent's class ──
--
-- A join rather than a list of names, so the rule is visible instead of fifteen hand-picked rows. The
-- two exceptions above are excluded by name.
UPDATE `asset_categories` c
  JOIN `asset_categories` p ON p.`id` = c.`parent_id`
   SET c.`asset_class` = p.`asset_class`
 WHERE c.`asset_class` <> p.`asset_class`
   AND c.`name` NOT IN ('BUILDING', 'SPLIT UNIT AIRCONDITIONING')

-- >>>
-- ── Repair 3: bring the ASSETS into line with their corrected category ──
--
-- This is the statement that unblocks the counter. It is safe because zero assets disagreed with
-- their category before this file ran — measured, not assumed — so there is no per-unit override to
-- destroy. Any deliberate exception is re-applied per asset afterwards, which is what the editable
-- field on the asset form is for.
UPDATE `assets` a
  JOIN `asset_categories` c ON c.`name` = a.`category`
   SET a.`asset_class` = c.`asset_class`
 WHERE a.`asset_class` <> c.`asset_class`

-- >>>
-- ── Repair 4: the empty vehicle rows ──
--
-- Not a category repair, and it is here rather than in its own file because it is the same kind of
-- work on the same module, and because the code fix and this clean-up are worthless apart: fixing the
-- code leaves six junk rows behind, and deleting the rows without the code fix means they come back on
-- the next save.
--
-- MEASURED on the production dump: `asset_vehicles` held 9 rows and only 3 were vehicles. The other
-- six carried seven NULLs each — asset 186 (MANAGING DIRECTOR OFFICE DESK), 203 (LABEL PRINTER) and
-- 207, 209, 210, 211 (four OFFICE DESKs under FURNITURE) — created by a real user on a real save.
--
-- Cause, fixed in `saveVehicleRow`: the asset form posts all seven vehicle keys on every save whether
-- the section is on screen or not, and the EDIT endpoint's guard is `f in body`. So every asset edited
-- since the profile shipped got a row.
--
-- Deleting them loses nothing: every one of the seven columns is NULL, so there is no value to lose.
-- The condition names all seven rather than testing a single column, so a row holding only a colour or
-- only a road-tax date is KEPT — those are vehicle details somebody typed.
--
-- Nothing reads these rows today. Both readers in `AssetRegister.tsx` test VALUES, never the row's
-- existence, which is why six desks with vehicle rows never showed a plate field to anybody.
DELETE FROM `asset_vehicles`
 WHERE `plate_no`   IS NULL
   AND `chassis_no` IS NULL
   AND `engine_no`  IS NULL
   AND `fuel_type`  IS NULL
   AND `colour`     IS NULL
   AND `registered_on`  IS NULL
   AND `road_tax_until` IS NULL

-- >>>
-- ── Verification, reported rather than assumed ──
--
-- `orphan_children` and `three_deep` must both be 0. `assets_reclassified` must be 0 on a SECOND run:
-- a non-zero value there on a re-run would mean something is fighting this file.
--
-- ── `named_children_unmapped` IS THE ONE THAT EARNED ITS PLACE ──
--
-- It lists the FIFTEEN names that are meant to be parents, and counts every other row still sitting at
-- top level. It MUST be 0.
--
-- Every other line in this SELECT read as clean while ten furniture rows were unmapped, because the
-- mapping joins by NAME and `Office Furniture` had been deleted from the register. A parent name that
-- matches nothing makes its UPDATE a no-op, and an unmapped child is `parent_id NULL` — exactly what a
-- parent looks like. `parents` read 25 instead of 15 and nothing said so.
--
-- The short list is deliberate: fifteen parent names, not the forty-nine child names repeated from the
-- statements above. A check that restates what it is checking goes stale with it.
SELECT
  (SELECT COUNT(*) FROM `asset_categories`)                                    AS categories,
  (SELECT COUNT(*) FROM `asset_categories` WHERE `parent_id` IS NULL)          AS parents,
  (SELECT COUNT(*) FROM `asset_categories` WHERE `parent_id` IS NOT NULL)      AS children,
  (SELECT COUNT(*) FROM `asset_categories`
    WHERE `parent_id` IS NULL
      AND `name` NOT IN ('Computer & Laptop', 'Server & Storage', 'Network Equipment',
                         'Printer & Scanner', 'Mobile Device', 'Vehicle', 'Office Furniture',
                         'Tools & Instruments', 'CCTV & Security', 'Power & Electrical',
                         'Software Licence', 'Other', 'Appliances', 'Safety & PPE',
                         'BUILDING'))                                          AS named_children_unmapped,
  (SELECT COUNT(*) FROM `asset_categories` c
     LEFT JOIN `asset_categories` p ON p.`id` = c.`parent_id`
    WHERE c.`parent_id` IS NOT NULL AND p.`id` IS NULL)                        AS orphan_children,
  (SELECT COUNT(*) FROM `asset_categories` c
     JOIN `asset_categories` p ON p.`id` = c.`parent_id`
    WHERE p.`parent_id` IS NOT NULL)                                           AS three_deep,
  (SELECT COUNT(*) FROM `assets` a
     JOIN `asset_categories` c ON c.`name` = a.`category`
    WHERE a.`asset_class` <> c.`asset_class`)                                   AS assets_reclassified,
  (SELECT COUNT(*) FROM `assets` WHERE `holder` = 'internal' AND `asset_class` <> 'movable')
                                                                               AS internal_not_issuable,
  (SELECT COUNT(*) FROM `assets` a
     LEFT JOIN `asset_categories` c ON c.`name` = a.`category`
    WHERE a.`category` IS NOT NULL AND a.`category` <> '' AND c.`id` IS NULL)   AS assets_with_no_category_row,
  (SELECT COUNT(*) FROM `asset_vehicles`)                                       AS vehicle_rows,
  (SELECT COUNT(*) FROM `asset_vehicles`
    WHERE `plate_no` IS NULL AND `chassis_no` IS NULL AND `engine_no` IS NULL
      AND `fuel_type` IS NULL AND `colour` IS NULL
      AND `registered_on` IS NULL AND `road_tax_until` IS NULL)                 AS empty_vehicle_rows
