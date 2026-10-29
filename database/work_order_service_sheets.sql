-- ============================================================================================
-- PER-ASSET SERVICE SHEETS - THE INSTANCE
--
-- `work_order_form_templates` is the MASTER: what one asset's signed sheet looks like. This file
-- is the RECORD: one asset's answers, ticks, photographs and signature for one visit.
--
-- The user's complaint that produced it: "click report tak boleh camni, dia kena 1 persatu" -
-- one at a time. A preventive round on this database is 115 laptops at one client across 16
-- sites, and one report for 115 units is not a document a customer signs.
--
-- Idempotent. Statements are separated by `-- >>>` and applied with
-- `node scripts/run-sql.js database/work_order_service_sheets.sql`. Every ALTER is guarded by an
-- `information_schema` read, because MySQL 8.0.45 has no `ADD COLUMN IF NOT EXISTS`.
--
-- ============================================================================================
-- 1. WHY A SEPARATE TABLE AND NOT COLUMNS ON `work_order_assets`
--
-- Two measured reasons, and either on its own is sufficient.
--
-- `WORK_ORDER_ASSET_SELECT` IN `lib/work-orders-db.ts` IS SHARED BY FOUR STATEMENTS, one of them
-- the staff PWA's detail endpoint. Fifteen more columns on `work_order_assets` would widen that
-- payload for every reader - including a phone on mobile data rendering 115 rows - to carry
-- fields only the sheet screen and the printed document ever look at.
--
-- AND THE RELATIONSHIP IS 0..1, NOT 1:1. Template resolution was measured against the live
-- register on 2026-10-29:
--
--     488 assets, 0 with an unmatched category
--     242 resolve to an active template   202 Laptop & Desktop, 25 CCTV, 15 Network
--     246 resolve to NO template
--
-- So a nullable block of columns would be NULL on more than half the rows. An asset with no
-- template gets no sheet and MUST still work on the work order; that is 246 of 488, not an edge
-- case. `uq_woss_link` is what enforces the 0..1 - at most one sheet per owning link row.
--
-- ── THE RESOLUTION ITSELF, AND WHY `COALESCE` IS LOAD BEARING ──
--
--     LEFT JOIN asset_categories ac ON ac.name = a.category
--     LEFT JOIN work_order_form_templates t
--            ON t.category_id = COALESCE(ac.parent_id, ac.id) AND t.is_active = 1
--
-- `assets.category` is free text; `asset_categories` is a two-level tree and a template binds to
-- a TOP-LEVEL row. `COALESCE(ac.parent_id, ac.id)` is required because "Computer & Laptop" is
-- BOTH an `assets.category` value and a top-level `asset_categories` row, while
-- "COMPUTER KEYBOARD" is one of its children. Reading `ac.parent_id` alone loses every asset
-- filed under a parent's own name - which on this database is the 115-unit KEMAS round.
--
-- ============================================================================================
-- 2. THE SHEET HEAD
--
-- ── `form_no` IS DERIVED FROM A MAXIMUM, NEVER FROM A ROW COUNT ──
--
-- `WO-YYMMDD-NNN`. The allocator reads `MAX(form_no)` for the prefix and the date and adds one;
-- `uq_woss_form_no` is the real guarantee and the caller retries on `ER_DUP_ENTRY`. A count
-- would reissue a number the moment ANY sheet is deleted, and a reused number on a document a
-- customer has signed is indefensible - there would be two different sheets answering to one
-- reference with nothing on either saying which is which.
--
-- MEASURED, because the difference between the two derivations is one case and it is worth
-- pinning: with 001, 002 and 003 raised, deleting 002 leaves the maximum at 003 and the next
-- number is 004. A count would have answered 003 and collided with the sheet that still holds it.
--
-- Deleting the HIGHEST sheet does free its number under either derivation, and that is ACCEPTED
-- rather than hidden. Only an UNSUBMITTED sheet can be deleted at all - `WorkOrderAssetSetError`
-- in `lib/work-orders-db.ts` refuses an asset-set edit that would drop a submitted one - and an
-- unsubmitted sheet carries no ticks, no photographs and no signature. The case this numbering
-- exists to prevent is a number reused on a document somebody signed, and the guard is what
-- closes it.
--
-- ── THE SNAPSHOTS, AND WHAT THEY PROTECT AGAINST ──
--
-- `template_name`, `form_title`, `category_name`, `asset_no`, `asset_name`, `serial_no` are
-- COPIED at creation. `work_order_form_templates.form_title` is editable and an asset can be
-- renamed or retagged, so without the copies a sheet somebody signed in January would print a
-- different heading and a different device in June. `fk_woss_template` is ON DELETE SET NULL for
-- the same reason: losing the master must not alter the record.
--
-- ── TWO IDENTITY SPACES, AND THE COLUMNS SAY WHICH ──
--
-- `submitted_by_employee_id` is an `employees.id` - a technician with an EMPLOYEE session, from
-- the PWA. `reopened_by` and `not_required_by` are `admins.username` VARCHARs - an office user
-- with an ADMIN session. They are deliberately different types because they are different
-- identity spaces: `permissions` is keyed to admin roles and an employee has no row in it. A
-- single `decided_by VARCHAR` would read as one thing and silently hold two.
--
-- NO FOREIGN KEY on `submitted_by_employee_id`, matching
-- `work_order_assets.completed_by_employee_id`: a technician who leaves must keep being named on
-- the sheet they signed.
--
-- `asset_id` carries NO foreign key either, and that is a decision. It is a SNAPSHOT for
-- indexing - the asset's printed identity is already copied into the three columns above - and
-- the owning `work_order_assets` row already holds `fk_woas_asset` ON DELETE CASCADE, so the
-- sheet disappears with the asset through `fk_woss_link` regardless. A second cascade would
-- change no behaviour and add a constraint to reason about.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_service_sheets` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `work_order_asset_id` INT NOT NULL,
  `work_order_id`      INT NOT NULL,
  `asset_id`           INT NOT NULL,
  `template_id`        INT DEFAULT NULL,
  `form_no`            VARCHAR(40) NOT NULL,

  -- Snapshots taken at creation. Never updated.
  `template_name`      VARCHAR(150) NOT NULL,
  `form_title`         VARCHAR(200) NOT NULL,
  `category_name`      VARCHAR(150) DEFAULT NULL,
  `asset_no`           VARCHAR(60)  NOT NULL,
  `asset_name`         VARCHAR(200) NOT NULL,
  `serial_no`          VARCHAR(120) DEFAULT NULL,
  -- The work order number, printed in the second reference cell of the title band. The approved
  -- mock labels that cell `Contract Ref.`; there is no contract reference column anywhere in this
  -- application, and a printed label with nothing behind it is worse than a different label. The
  -- geometry is unchanged - two cells, two aligned colons - and the sheet prints what it has.
  `work_order_no`      VARCHAR(40)  NOT NULL,

  -- What the visit recorded. All typed on the phone.
  `commence_at`        DATETIME DEFAULT NULL,
  `completed_at`       DATETIME DEFAULT NULL,
  `attended_by`        VARCHAR(200) DEFAULT NULL,
  `customer_remarks`   VARCHAR(1000) DEFAULT NULL,
  -- Prints under BEFORE MAINTENANCE on the photo page.
  `arrival_note`       VARCHAR(1000) DEFAULT NULL,
  -- Prints under AFTER MAINTENANCE on the photo page.
  `completion_summary` VARCHAR(1000) DEFAULT NULL,
  `notes`              VARCHAR(1000) DEFAULT NULL,

  -- The customer acknowledgement.
  `customer_name`        VARCHAR(200) DEFAULT NULL,
  `customer_designation` VARCHAR(150) DEFAULT NULL,
  -- THE FULL VALUE, stored once. The API never sends it unmasked without
  -- `work_order_sheets_ic`, and the printed sheet always masks it. See section 6.
  `customer_ic`          VARCHAR(40)  DEFAULT NULL,
  -- A basename under `.uploads-private/work-order-sheets/`, never a URL. Outside `public/`, so
  -- Next's static handler cannot reach it; read back only through a session-checked route.
  `signature_path`       VARCHAR(255) DEFAULT NULL,
  `no_signature_reason`  VARCHAR(300) DEFAULT NULL,

  -- Lifecycle.
  `submitted_at`             DATETIME DEFAULT NULL,
  `submitted_by_employee_id` INT DEFAULT NULL,
  `engineer_name`            VARCHAR(200) DEFAULT NULL,
  `reopened_at`          DATETIME DEFAULT NULL,
  `reopened_by`          VARCHAR(191) DEFAULT NULL,
  `reopen_reason`        VARCHAR(300) DEFAULT NULL,
  `not_required_at`      DATETIME DEFAULT NULL,
  `not_required_by`      VARCHAR(191) DEFAULT NULL,
  `not_required_reason`  VARCHAR(300) DEFAULT NULL,

  `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_woss_link` (`work_order_asset_id`),
  UNIQUE KEY `uq_woss_form_no` (`form_no`),
  KEY `idx_woss_wo` (`work_order_id`, `id`),
  KEY `idx_woss_asset` (`asset_id`),
  KEY `idx_woss_submitted` (`work_order_id`, `submitted_at`),
  CONSTRAINT `fk_woss_link` FOREIGN KEY (`work_order_asset_id`)
    REFERENCES `work_order_assets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_woss_wo` FOREIGN KEY (`work_order_id`)
    REFERENCES `work_orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_woss_template` FOREIGN KEY (`template_id`)
    REFERENCES `work_order_form_templates` (`id`) ON DELETE SET NULL,
  -- A SUBMITTED sheet is signed or it says why it is not. Without this a submit with neither
  -- would be a sheet nobody acknowledged, and nothing on the paper would admit it.
  CONSTRAINT `chk_woss_ack` CHECK (
    `submitted_at` IS NULL
    OR `signature_path` IS NOT NULL
    OR (`no_signature_reason` IS NOT NULL AND `no_signature_reason` <> '')
  ),
  -- A signature belongs to a NAMED person. An image over a blank name proves nothing.
  CONSTRAINT `chk_woss_signer` CHECK (
    `signature_path` IS NULL
    OR (`customer_name` IS NOT NULL AND `customer_name` <> '')
  ),
  CONSTRAINT `chk_woss_reopen` CHECK (
    `reopened_at` IS NULL
    OR (`reopened_by` IS NOT NULL AND `reopen_reason` IS NOT NULL AND `reopen_reason` <> '')
  ),
  CONSTRAINT `chk_woss_notreq` CHECK (
    `not_required_at` IS NULL
    OR (`not_required_by` IS NOT NULL
        AND `not_required_reason` IS NOT NULL AND `not_required_reason` <> '')
  ),
  -- A sheet cannot be both signed off and declared unnecessary. The office marks it not required
  -- BEFORE anybody goes to the unit; once a technician has submitted it, the record stands.
  CONSTRAINT `chk_woss_exclusive` CHECK (
    `not_required_at` IS NULL OR `submitted_at` IS NULL
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 3. THE SHEET'S OWN FIELDS - the printed DEVICE INFORMATION block
--
-- Copied from `work_order_form_fields` at creation, with `autofill_from` RESOLVED against the
-- asset there and then. The sheet holds VALUES, the template holds DEFINITIONS, and the copy is
-- what makes a signed sheet immune to a later template edit.
--
-- ── `autofill_from` IS VALIDATED AGAINST A CODE ALLOW-LIST, NEVER `information_schema` ──
--
-- `src/lib/work-order-sheet-autofill.ts` holds the 40 `assets` column names as a literal, and
-- both the template editor and the sheet raiser read that one list. Two reasons it is not a live
-- schema read: the resolved value is INTERPOLATED INTO A PRINTED DOCUMENT, so an arbitrary
-- string accepted here is an arbitrary string on a customer's paperwork and the shape of an
-- injection; and a live read would make the legal set depend on whichever columns happen to
-- exist on the server that day, so one template would mean two things on two databases.
--
-- THERE IS NO `ip_address` ON `assets`, so the IP Address field on the Network and CCTV
-- templates is TYPED - `source_column` is NULL on it and the technician enters it per visit.
--
-- `is_typed` is what the paper reads off: a value the technician entered prints UNDERLINED
-- (`.sfp__v--typed`), a value the register supplied prints plain. That distinction is on the
-- approved mock and it is a real one - one is a reading taken that day, the other is a fact the
-- register already held.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_sheet_fields` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `sheet_id`      INT NOT NULL,
  `label`         VARCHAR(120) NOT NULL,
  `field_key`     VARCHAR(60)  NOT NULL,
  `input_type`    ENUM('text','textarea','date','number') NOT NULL DEFAULT 'text',
  -- The `assets` column the value was autofilled FROM, or NULL for a typed field. Kept so the
  -- sheet can say where a value came from without re-resolving a template that may have changed.
  `source_column` VARCHAR(60)  DEFAULT NULL,
  `is_required`   TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`    INT NOT NULL DEFAULT 0,
  `value`         VARCHAR(500) DEFAULT NULL,
  `is_typed`      TINYINT(1) NOT NULL DEFAULT 0,
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wossf_key` (`sheet_id`, `field_key`),
  KEY `idx_wossf_sheet` (`sheet_id`, `sort_order`),
  CONSTRAINT `fk_wossf_sheet` FOREIGN KEY (`sheet_id`)
    REFERENCES `work_order_service_sheets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 4. THE SHEET'S OWN CHECKLIST
--
-- ══════════════════════════════════════════════════════════════════════════════
-- A SEPARATE TABLE FROM `work_order_items`, AND NOT A NULLABLE COLUMN ON IT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `work_order_items` stays the JOB-LEVEL checklist - what to do on the visit, six steps, once.
-- It is written by `employee/work-orders/[id]/items.ts`, read by the PWA, constrained by
-- `chk_woi_state` and `chk_woi_required_not_skipped`, and it is what starts the job on the first
-- tick.
--
-- A nullable `sheet_id` on that shipped table would mean every existing query needs
-- `AND sheet_id IS NULL`, and ONE FORGOTTEN CLAUSE leaks 115 x 14 = 1,610 rows into a 6-item
-- list. `work_order_assets` was added as a new table rather than overloading
-- `work_orders.asset_id` for exactly this reason, and that decision is recorded in
-- `work_order_assets.sql`.
--
-- ── THE GROUP IS A COLUMN, NOT A TABLE ──
--
-- `work_order_form_groups` exists because a template's groups are edited as a list. A SHEET's
-- groups are frozen the moment it is raised, so a third owned table would buy one join per
-- sheet and nothing else. `group_title` and `group_sort` carry the heading the printed
-- DETAILS OF THE JOB PERFORMED table draws as a spanning row.
--
-- `sort_order` is the step number PRINTED on the sheet, running 1..14 across the whole checklist
-- rather than restarting inside each group - which is what the approved mock shows, with the
-- group titles as lettered spanning rows between them.
--
-- ── THREE STATES, AND `na` NEEDS A REASON ──
--
-- `pending` prints an empty Check cell, `done` prints a tick, `na` prints `N / A`. A template
-- binds to a TOP-LEVEL category, so one form covers a switch and an access point and a few steps
-- will not apply to every unit - `N / A` is the honest answer and `chk_wossi_na_reason` makes the
-- technician say which. An unexplained `N / A` on a signed document is a gap a customer can
-- reasonably object to.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_sheet_items` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `sheet_id`    INT NOT NULL,
  `group_title` VARCHAR(150) NOT NULL,
  `group_sort`  INT NOT NULL DEFAULT 0,
  `title`       VARCHAR(255) NOT NULL,
  `notes`       VARCHAR(400) DEFAULT NULL,
  `is_required` TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`  INT NOT NULL DEFAULT 0,
  `state`       ENUM('pending','done','na') NOT NULL DEFAULT 'pending',
  -- The printed Comment column.
  `remark`      VARCHAR(1000) DEFAULT NULL,
  `decided_at`  DATETIME DEFAULT NULL,
  -- `employees.id`. The phone is the only writer of a sheet checklist.
  `decided_by`  INT DEFAULT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wossi_sheet` (`sheet_id`, `group_sort`, `sort_order`),
  CONSTRAINT `fk_wossi_sheet` FOREIGN KEY (`sheet_id`)
    REFERENCES `work_order_service_sheets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_wossi_na_reason` CHECK (
    `state` <> 'na' OR (`remark` IS NOT NULL AND `remark` <> '')
  ),
  -- `pending` carries no decision, and a decided step carries one. The pairing is what stops a
  -- reset leaving a timestamp that claims somebody ticked it.
  CONSTRAINT `chk_wossi_decided` CHECK (
    (`state` = 'pending' AND `decided_at` IS NULL)
    OR (`state` <> 'pending' AND `decided_at` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 5. THE PHOTOGRAPHS
--
-- ── TWO CLOCKS, BOTH RECORDED ──
--
-- `device_at` is the phone's own clock at the moment of capture and `server_at` is this
-- server's. A phone clock is settable and often wrong; the server's is the authoritative one and
-- is what the printed evidence strip quotes. Keeping both means a discrepancy is visible rather
-- than silently resolved in favour of whichever one the code happened to read.
--
-- ── GPS IS BEST-EFFORT AND NULLABLE ──
--
-- `navigator.geolocation` needs a permission grant the technician can refuse, and indoors it
-- frequently never answers. A NOT NULL column would make a refused prompt a failed upload. The
-- printed strip says `GPS recorded` only when there is one.
--
-- `file_path` is a BASENAME under `.uploads-private/work-order-sheets/`, never a URL. The files
-- are outside `public/`, so Next's static handler cannot serve them, and they are read back only
-- through a session-checked route built on the `lib/hr-receipts.ts` pattern - basename rebuild,
-- escape guard, `Cache-Control: private, no-store`.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_sheet_photos` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `sheet_id`   INT NOT NULL,
  `kind`       ENUM('before','after') NOT NULL,
  `file_path`  VARCHAR(255) NOT NULL,
  `caption`    VARCHAR(200) DEFAULT NULL,
  `device_at`  DATETIME DEFAULT NULL,
  `server_at`  DATETIME NOT NULL,
  `gps_lat`    DECIMAL(10,7) DEFAULT NULL,
  `gps_lng`    DECIMAL(10,7) DEFAULT NULL,
  `taken_by_employee_id` INT DEFAULT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wossp_sheet` (`sheet_id`, `kind`, `sort_order`),
  CONSTRAINT `fk_wossp_sheet` FOREIGN KEY (`sheet_id`)
    REFERENCES `work_order_service_sheets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- 6. PERMISSIONS - TWO NEW KEYS, AND THE ARGUMENT FOR REUSING THE REST
--
-- Most of this feature is governed by permissions that already exist, and their descriptions
-- stay true:
--
--   work_orders_view   the Service Sheets list on the Worksheet tab, and printing a sheet. A
--                      sheet is part of the work order; "View work orders" covers reading it.
--   work_orders_edit   marking a sheet NOT REQUIRED. That is an office administrative decision
--                      taken BEFORE anybody visits the unit, and "Edit work orders" covers it.
--
-- TWO acts are not covered by anything shipped, and each gets one key:
--
--   work_order_sheets_reopen
--     Reopening a sheet a technician has SUBMITTED. If it was signed, the signature and the
--     customer's name are already on it, so reopening puts a signed customer document back into
--     an editable state. That is not "edit a work order" - every role holding
--     `work_orders_edit` today would silently acquire it, which is the exact widening
--     `work_order_form_templates.sql` section 6 argues against for `work_order_templates_*`.
--
--   work_order_sheets_ic
--     Revealing the FULL identity card number of the customer who signed. Every other reader -
--     the list, the printed sheet, the PWA - gets it masked, in SQL, the way
--     `employee/profile` masks an NRIC. No work-order permission's description says anything
--     about a third party's identity document, and the one that would have to be stretched to
--     cover it is `work_orders_view`, which nearly everybody has.
--
-- A non-CRUD action is precedented in this table: `market_place_products` carries `submit` and
-- `approve`, `market_place_orders` carries `receive` and `ship`, `market_place_tracking`
-- carries `sync`. An action set is read off the endpoint that answers it, and a guessed
-- `_delete` here would be a checkbox in the Roles matrix granting nothing.
--
-- ── MUST SHIP WITH `src/lib/permission-modules.ts` IN THE SAME CHANGE ──
--
-- `tests/sql/roles-endpoints.sql.test.js` reads `MODULE_ORDER` out of that source file and
-- `SELECT DISTINCT module FROM permissions` out of this database, and it fails BOTH directions.
-- Seeding these two rows without the `MODULE_ORDER` entry is red; adding the entry without
-- these rows is red.
--
-- `category` is 'operations', lowercase, matching the rows this module already has.
-- ============================================================================================
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('work_order_sheets', 'reopen', 'work_order_sheets_reopen',
   'Reopen a submitted service sheet on a work order', 'operations'),
  ('work_order_sheets', 'ic',     'work_order_sheets_ic',
   'Reveal the full identity card number on a signed service sheet', 'operations')
-- >>>
-- ── The Super Admin grant ──
--
-- `leafVisible()` calls `has(leaf.perm)` and `usePermissions` joins through `role_permissions`.
-- The SERVER has a Super Admin shortcut; the CLIENT does not. So an ungranted permission makes
-- the control INVISIBLE rather than refused, which reads as a broken screen with no error
-- anywhere to explain it.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'work_order_sheets'
-- >>>
-- ============================================================================================
-- 7. THE GUARDED ALTERS
--
-- `CREATE TABLE IF NOT EXISTS` above covers a fresh install. These cover the case it cannot: a
-- table left behind by an earlier, shorter version of this file. `ADD COLUMN`, `ADD KEY` and
-- `ADD CONSTRAINT` have no `IF NOT EXISTS` form in MySQL 8.0.45, so each reads
-- `information_schema` first and becomes `DO 0` when the object is already there. This is the
-- shape `work_order_assets.sql` and `work_order_form_templates.sql` section 5 use.
--
-- Only the columns an earlier draft could plausibly have omitted are guarded. Guarding all
-- forty-odd would be forty statements that have never once done anything, and a file nobody
-- reads to the end is a file whose real statements get missed.
-- ============================================================================================
SET @woss_wono := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_service_sheets'
     AND COLUMN_NAME = 'work_order_no'
)
-- >>>
SET @sql := IF(@woss_wono = 0,
  'ALTER TABLE `work_order_service_sheets`
     ADD COLUMN `work_order_no` VARCHAR(40) NOT NULL DEFAULT '''' AFTER `serial_no`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woss_eng := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_service_sheets'
     AND COLUMN_NAME = 'engineer_name'
)
-- >>>
SET @sql := IF(@woss_eng = 0,
  'ALTER TABLE `work_order_service_sheets`
     ADD COLUMN `engineer_name` VARCHAR(200) DEFAULT NULL AFTER `submitted_by_employee_id`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @wossf_typed := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_sheet_fields'
     AND COLUMN_NAME = 'is_typed'
)
-- >>>
SET @sql := IF(@wossf_typed = 0,
  'ALTER TABLE `work_order_sheet_fields`
     ADD COLUMN `is_typed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `value`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woss_uq_form := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_service_sheets'
     AND INDEX_NAME = 'uq_woss_form_no'
)
-- >>>
SET @sql := IF(@woss_uq_form = 0,
  'ALTER TABLE `work_order_service_sheets`
     ADD UNIQUE KEY `uq_woss_form_no` (`form_no`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woss_uq_link := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_service_sheets'
     AND INDEX_NAME = 'uq_woss_link'
)
-- >>>
SET @sql := IF(@woss_uq_link = 0,
  'ALTER TABLE `work_order_service_sheets`
     ADD UNIQUE KEY `uq_woss_link` (`work_order_asset_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ============================================================================================
-- 8. VERIFICATION
--
-- Expected on a correct apply: sheet_tbl 1, field_tbl 1, item_tbl 1, photo_tbl 1,
-- uq_link 1, uq_form 1, fk_link_cascade 1, fk_wo_cascade 1, fk_tpl_setnull 1,
-- fields_cascade 1, items_cascade 1, photos_cascade 1, ack_check 1, na_check 1,
-- perms 2, super_grant 2, asset_fk 0.
--
-- `asset_fk 0` is an ABSENCE asserted on purpose: section 2 argues why `asset_id` carries no
-- foreign key, and a zero here is what makes that checkable rather than a comment somebody reads
-- past. The same technique `work_order_assets.sql` uses for `employee_fk`.
--
-- `resolvable` and `no_template` re-derive the template resolution from the live register, so a
-- reader sees the 242 / 246 split this file's reasoning rests on rather than taking it on trust.
-- ============================================================================================
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_service_sheets')   AS sheet_tbl,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_sheet_fields')     AS field_tbl,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_sheet_items')      AS item_tbl,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_sheet_photos')     AS photo_tbl,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_service_sheets'
      AND INDEX_NAME = 'uq_woss_link')                                              AS uq_link,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_service_sheets'
      AND INDEX_NAME = 'uq_woss_form_no')                                           AS uq_form,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woss_link'
      AND DELETE_RULE = 'CASCADE')                                             AS fk_link_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woss_wo'
      AND DELETE_RULE = 'CASCADE')                                               AS fk_wo_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woss_template'
      AND DELETE_RULE = 'SET NULL')                                             AS fk_tpl_setnull,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_wossf_sheet'
      AND DELETE_RULE = 'CASCADE')                                              AS fields_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_wossi_sheet'
      AND DELETE_RULE = 'CASCADE')                                               AS items_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_wossp_sheet'
      AND DELETE_RULE = 'CASCADE')                                              AS photos_cascade,
  (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_woss_ack')        AS ack_check,
  (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'chk_wossi_na_reason')                                     AS na_check,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'work_order_sheets')              AS perms,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE p.`module` = 'work_order_sheets'
      AND LOWER(TRIM(r.`name`)) = 'super admin')                                   AS super_grant,
  (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_service_sheets'
      AND COLUMN_NAME = 'asset_id' AND REFERENCED_TABLE_NAME IS NOT NULL)             AS asset_fk,
  (SELECT COUNT(*) FROM `assets` a
     LEFT JOIN `asset_categories` ac ON ac.`name` = a.`category`
     JOIN `work_order_form_templates` t
       ON t.`category_id` = COALESCE(ac.`parent_id`, ac.`id`) AND t.`is_active` = 1)  AS resolvable,
  (SELECT COUNT(*) FROM `assets` a
     LEFT JOIN `asset_categories` ac ON ac.`name` = a.`category`
     LEFT JOIN `work_order_form_templates` t
       ON t.`category_id` = COALESCE(ac.`parent_id`, ac.`id`) AND t.`is_active` = 1
    WHERE t.`id` IS NULL)                                                           AS no_template,
  (SELECT COUNT(*) FROM `work_order_service_sheets`)                                 AS sheets_now
