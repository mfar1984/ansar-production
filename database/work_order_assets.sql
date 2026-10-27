-- ============================================================================================
-- WORK ORDER ASSETS - ONE table, ONE column on `work_orders`, ONE trigger
--
-- Run:  node scripts/run-sql.js database/work_order_assets.sql
--
-- IDEMPOTENT. Run it twice and the second run changes nothing. Production applies a schema
-- change with `git pull` and a hand, and a hand runs things twice.
--
-- Statement separator is a `-- >>>` line, NOT a semicolon: scripts/run-sql.js splits on that
-- marker so a CREATE TRIGGER body carrying internal semicolons travels as one block.
--
-- ============================================================================================
-- WHAT THIS FIXES, MEASURED ON THIS DATABASE
-- ============================================================================================
--
-- `work_orders.asset_id` is SINGULAR, and the create form offered a native `<select>` over it.
-- The external register on this database holds 115 units for ONE client,
-- `JABATAN KEMAJUAN MASYARAKAT(KEMAS) NEGERI PAHANG`, spread across 16 sites - 26 at KEMAS
-- PAHANG (HQ), 9 at KEMAS KUANTAN, 7 at KEMAS TEMERLOH, and so on. Every one of those 115 rows
-- is named `ASUS`, so the option label read `FUVR757UGZD0 - ASUS (External Assets)` one hundred
-- and fifteen times over.
--
-- A preventive round over that register was therefore either 115 work orders, or one work order
-- naming one unit and lying about the other 114.
--
-- The ASSET module already solved this. `assets/history.ts` takes `?asset_ids=1,2,3` and records
-- ONE service against a whole batch - "one engineer, one visit, one date, a hundred units" - and
-- the history side is `asset_service_batches` (6 rounds) plus `asset_maintenance.batch_id`
-- (120 records). The INSTRUCTION side was the odd one out. This table makes the two agree.
--
-- ============================================================================================
-- `work_orders.asset_id` IS KEPT, AND IT IS NOT A SECOND ANSWER - READ THIS BEFORE "TIDYING" IT
-- ============================================================================================
--
-- `work_order_assets` is the ONLY store of WHICH ASSETS ARE ON A JOB. Nothing reads
-- `work_orders.asset_id` as that set, and `tests/sql/work-order-shape.test.js` fails if anything
-- starts to.
--
-- The column stays because of ONE reader that genuinely needs a single scalar, and it is not a
-- screen - it is `trg_wo_write_rules_ins` / `trg_wo_write_rules_upd` in
-- `database/work_order_module.sql`. That pair IS the one-origin rule:
--
--   IF ((CASE WHEN NEW.`asset_id` IS NULL THEN 0 ELSE 1 END) + ... ) <> 1 THEN SIGNAL
--
-- It counts four columns ON THE `work_orders` ROW, BEFORE INSERT. A trigger on `work_orders`
-- cannot see `work_order_assets`, because at that instant the work order has no id and the asset
-- rows do not exist. Dropping `asset_id` therefore means rewriting both bodies to count three.
--
-- And that is where it stops being a tidy-up. `work_order_module.sql` is on the packager's
-- `MIGRATIONS` list, declares `asset_id` inline in `CREATE TABLE IF NOT EXISTS work_orders`, and
-- recreates the trigger pair with `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER`. Production runs
-- that file by hand. Re-running it after a drop would restore a FOUR-origin trigger over a table
-- with three origin columns, and an asset work order - which would then populate none of the four
-- - would be refused at INSERT with "a work order is against exactly one thing". A shipped
-- idempotent migration would have become a landmine that fires on the second apply.
--
-- So the column is the ORIGIN ANCHOR and nothing else: it says THIS IS AN ASSET JOB, it is the
-- first asset picked, and `trg_woas_origin_ins` below makes the two halves consistent from
-- the other side. One column, one meaning, one answer to "which assets".
--
-- ============================================================================================
-- THE SAME STATE VOCABULARY AS THE CHECKLIST, DELIBERATELY
-- ============================================================================================
--
-- `state ENUM('pending','done','skipped')` is `work_order_items.state` word for word. A second
-- vocabulary for the same idea - `open/closed`, or a `tinyint is_done` - would be a translation
-- layer between two tables that are read side by side on one screen, and the PWA would need a map
-- to render them in one list.
--
-- THE ASSET IS THE UNIT OF COMPLETION. `work_order_items` stays the INSTRUCTION - what to do on
-- each asset - and is still ticked; see the note in `src/lib/work-orders-db.ts`. There is NO
-- per-asset-per-step table: `asset_maintenance` is one row per asset, so 115 x 6 would be 690 step
-- rows that no screen downstream can read.
--
-- ============================================================================================
-- NO `is_required`, AND THAT IS A DECISION
-- ============================================================================================
--
-- `work_order_items.is_required` distinguishes "this procedure must be performed" from "do it if
-- you can", and `chk_woi_required_not_skipped` enforces it. An asset has no such distinction: it
-- is either on the job or it is not. A column whose only value would ever be 0 is a column that
-- lies about being configurable - the same reason `work_order_crew.sql` refused a `role` column.
-- A skip still needs a REASON, which is what `chk_woas_state` enforces below.
--
-- ============================================================================================
-- THE OBJECT PREFIX IS `woas`, NOT `woa`, AND THAT IS NOT A STYLE CHOICE
-- ============================================================================================
--
-- `woa` is ALREADY TAKEN by `work_order_approvals`: `fk_woa_wo`, `idx_woa_wo`, `idx_woa_pending`,
-- `trg_woa_one_pending_ins` and `trg_woa_one_pending_upd` all exist on this database today.
--
-- InnoDB foreign key names are SCHEMA-GLOBAL, not per table. This file was first written with
-- `fk_woa_wo` and the whole `CREATE TABLE` failed with ER_FK_DUP_NAME - which also took out the
-- six guarded ALTERs after it, because they ALTER a table that was never created. So the prefix is
-- what makes the file run at all, and `woas` keeps it one character away from the three siblings
-- already in use: `woi` items, `woc` crew, `woa` approvals.
-- ============================================================================================
CREATE TABLE IF NOT EXISTS `work_order_assets` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `work_order_id` INT NOT NULL,
  -- `assets.id` is INT UNSIGNED, matching `work_orders.asset_id` and `asset_maintenance.asset_id`.
  `asset_id`      INT UNSIGNED NOT NULL,
  `state`         ENUM('pending','done','skipped') NOT NULL DEFAULT 'pending',
  `skip_reason`   VARCHAR(300) DEFAULT NULL,
  -- DATETIME, not DATE. `work_order_items.decided_on` is a DATE because an office ticks a list on
  -- a day; a technician closes 26 units at a site over an afternoon and the ORDER matters when the
  -- phone and the office disagree about what was done.
  `completed_at`  DATETIME DEFAULT NULL,
  -- NO foreign key, following `work_orders.assignee_employee_id` and `work_order_crew.employee_id`:
  -- a resigned employee changes STATUS and never disappears, so there is no referential action to
  -- choose and a job closed last year keeps naming who closed it.
  `completed_by_employee_id` INT DEFAULT NULL,
  -- The `asset_maintenance` row this asset's completion produced. NULL until done, and NULL again
  -- if the round is later deleted from Maintenance & Repairs - the work still happened.
  `maintenance_id` INT UNSIGNED DEFAULT NULL,
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- An asset is on a job ONCE. This is also what makes the asset-set PUT safe to re-send: a
  -- replace that raced itself would otherwise list every unit twice and double the service records.
  UNIQUE KEY `uq_woas_asset` (`work_order_id`, `asset_id`),
  -- "Which jobs is this asset on" - the asset register's own direction of travel.
  KEY `idx_woas_asset` (`asset_id`),
  -- The done/total figure the PWA shows at the top of a 115-row list, and the pending filter under
  -- it. Both are one index read on this key rather than a scan per render.
  KEY `idx_woas_state` (`work_order_id`, `state`),
  CONSTRAINT `fk_woas_wo` FOREIGN KEY (`work_order_id`)
    REFERENCES `work_orders` (`id`) ON DELETE CASCADE,
  -- CASCADE, matching `fk_amaint_asset` on `asset_maintenance`. `asset_id` is NOT NULL here - it is
  -- the whole point of the row - so SET NULL is not available, and a row saying "this asset is on
  -- this job" about an asset that no longer exists is a record of nothing.
  CONSTRAINT `fk_woas_asset` FOREIGN KEY (`asset_id`)
    REFERENCES `assets` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_woas_maint` FOREIGN KEY (`maintenance_id`)
    REFERENCES `asset_maintenance` (`id`) ON DELETE SET NULL,
  -- `chk_woi_state`'s shape, applied to the asset: a decision carries WHEN it was made, a skip
  -- carries WHY, and `pending` carries neither.
  --
  -- `maintenance_id` is DELIBERATELY NOT NAMED in here. MySQL 8 refuses a CHECK over a column
  -- carrying a referential action with error 3823 - the exact trap `work_order_module.sql`
  -- section 4 records for `chk_wo_one_origin` - and `fk_woas_maint` is ON DELETE SET NULL. The
  -- rule "only a done row carries a maintenance id" lives in the write path and in
  -- `tests/sql/work-order-shape.test.js` instead.
  CONSTRAINT `chk_woas_state` CHECK (
       (`state` = 'pending' AND `completed_at` IS NULL     AND `skip_reason` IS NULL)
    OR (`state` = 'done'    AND `completed_at` IS NOT NULL AND `skip_reason` IS NULL)
    OR (`state` = 'skipped' AND `completed_at` IS NOT NULL AND `skip_reason` IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- THE GUARDED ALTERS - one per object, each reading INFORMATION_SCHEMA first
--
-- `CREATE TABLE IF NOT EXISTS` above covers a fresh install. These cover the case it cannot: a
-- `work_order_assets` that already exists from an earlier, shorter version of this file.
-- `ADD KEY` and `ADD CONSTRAINT` have no `IF NOT EXISTS` form in MySQL 8.0.45, so each is wrapped
-- in a prepared statement that becomes `DO 0` when the object is already there. This is the shape
-- `work_order_crew.sql` and `work_order_module.sql` sections 10 and 11 already use.
-- ============================================================================================
SET @woas_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND INDEX_NAME = 'uq_woas_asset'
)
-- >>>
SET @sql := IF(@woas_uq = 0,
  'ALTER TABLE `work_order_assets`
     ADD UNIQUE KEY `uq_woas_asset` (`work_order_id`, `asset_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woas_idx_asset := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND INDEX_NAME = 'idx_woas_asset'
)
-- >>>
SET @sql := IF(@woas_idx_asset = 0,
  'ALTER TABLE `work_order_assets` ADD KEY `idx_woas_asset` (`asset_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woas_idx_state := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND INDEX_NAME = 'idx_woas_state'
)
-- >>>
SET @sql := IF(@woas_idx_state = 0,
  'ALTER TABLE `work_order_assets` ADD KEY `idx_woas_state` (`work_order_id`, `state`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woas_fk_wo := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND CONSTRAINT_NAME = 'fk_woas_wo'
)
-- >>>
SET @sql := IF(@woas_fk_wo = 0,
  'ALTER TABLE `work_order_assets`
     ADD CONSTRAINT `fk_woas_wo` FOREIGN KEY (`work_order_id`)
       REFERENCES `work_orders` (`id`) ON DELETE CASCADE',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woas_fk_asset := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND CONSTRAINT_NAME = 'fk_woas_asset'
)
-- >>>
SET @sql := IF(@woas_fk_asset = 0,
  'ALTER TABLE `work_order_assets`
     ADD CONSTRAINT `fk_woas_asset` FOREIGN KEY (`asset_id`)
       REFERENCES `assets` (`id`) ON DELETE CASCADE',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woas_fk_maint := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_assets'
     AND CONSTRAINT_NAME = 'fk_woas_maint'
)
-- >>>
SET @sql := IF(@woas_fk_maint = 0,
  'ALTER TABLE `work_order_assets`
     ADD CONSTRAINT `fk_woas_maint` FOREIGN KEY (`maintenance_id`)
       REFERENCES `asset_maintenance` (`id`) ON DELETE SET NULL',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ============================================================================================
-- `work_orders.batch_id` - THE ROUND EVERY ASSET ON THIS JOB IS CLOSED INTO
--
-- This is the user's "setiap pm yang dibuat akan menggunakan group work order yang sama": every
-- asset closed under one work order lands in the SAME `asset_service_batches` round, so
-- Maintenance & Repairs shows one round of 115 records and not 115 rounds of one - with no change
-- to that screen at all, because it already groups by `batch_id`.
--
-- ── CREATED WHEN THE FIRST ASSET IS CLOSED, NOT WHEN THE JOB IS ISSUED ──
--
-- Both were available and the lazy one is right, for a reason that is on the Maintenance screen:
-- `assets/maintenance.ts` groups by `batch_id` and states there is DELIBERATELY no fallback for
-- `batch_id IS NULL`. A batch written at issue time, for a job that is then cancelled, or whose
-- assets are every one of them skipped, is an EMPTY ROUND on that screen - a row that exists and
-- holds nothing, which is the state that file exists to prevent.
--
-- `asset_maintenance.batch_id` also carries `fk_amaint_batch`, so the batch must exist before the
-- first record regardless. Writing it inside the transaction that produces that first record is
-- therefore both the earliest it CAN be written and the latest it NEED be - which is exactly what
-- `assets/history.ts` already does for `?asset_ids=`.
--
-- ON DELETE SET NULL, matching all seven existing `work_orders` foreign keys: deleting a round
-- from Maintenance & Repairs must not delete the work order that produced it.
-- ============================================================================================
SET @wo_batch_col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_orders'
     AND COLUMN_NAME = 'batch_id'
)
-- >>>
SET @sql := IF(@wo_batch_col = 0,
  'ALTER TABLE `work_orders`
     ADD COLUMN `batch_id` INT UNSIGNED DEFAULT NULL AFTER `maintenance_id`',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @wo_batch_idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_orders'
     AND INDEX_NAME = 'idx_wo_batch'
)
-- >>>
SET @sql := IF(@wo_batch_idx = 0,
  'ALTER TABLE `work_orders` ADD KEY `idx_wo_batch` (`batch_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @wo_batch_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_orders'
     AND CONSTRAINT_NAME = 'fk_wo_batch'
)
-- >>>
SET @sql := IF(@wo_batch_fk = 0,
  'ALTER TABLE `work_orders`
     ADD CONSTRAINT `fk_wo_batch` FOREIGN KEY (`batch_id`)
       REFERENCES `asset_service_batches` (`id`) ON DELETE SET NULL',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ============================================================================================
-- THE ONE-ORIGIN RULE, FROM THE ASSET SIDE
--
-- `trg_wo_write_rules_ins` guarantees a work order is born with exactly one of its four origin
-- columns populated. That is half the rule now: it says nothing about whether a TICKET-origin work
-- order can also carry a list of assets.
--
-- This trigger is the other half. An asset may only be listed on a work order whose origin IS
-- assets - `asset_id` populated, and therefore none of the other three. Without it, a ticket job
-- could accumulate an asset list that no screen renders and that the close path would never
-- service: a set of rows that exist and do nothing.
--
-- It also pins the anchor. `asset_id IS NULL` is refused, so `work_order_assets` can never hold a
-- job that the one-origin trigger does not already classify as an asset job. That is what makes
-- "the anchor is always one of the listed assets" an invariant rather than a convention, and it is
-- why the create path writes the `work_orders` row FIRST.
--
-- BEFORE INSERT only. There is deliberately no UPDATE twin: `work_order_assets` rows are REPLACED
-- (deleted and re-inserted) when a draft's asset set changes, and the only columns an UPDATE ever
-- touches are the four decision columns, which `chk_woas_state` governs. A twin would be a second
-- body to keep in step with nothing extra to enforce - the asymmetry `work_order_module.sql`
-- section 5 argues for its own pair, in the other direction.
--
-- `CREATE TRIGGER` has no `IF NOT EXISTS` form, so it is preceded by `DROP TRIGGER IF EXISTS`.
-- That is what makes this section re-runnable.
-- ============================================================================================
DROP TRIGGER IF EXISTS `trg_woas_origin_ins`
-- >>>
CREATE TRIGGER `trg_woas_origin_ins`
BEFORE INSERT ON `work_order_assets`
FOR EACH ROW
BEGIN
  DECLARE anchor INT UNSIGNED;
  DECLARE others TINYINT;
  SELECT `asset_id`,
         (`ticket_id` IS NOT NULL) + (`project_id` IS NOT NULL) + (`sales_order_id` IS NOT NULL)
    INTO anchor, others
    FROM `work_orders`
   WHERE `id` = NEW.`work_order_id`;
  IF others > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'That work order was raised against a ticket, a project or a sales order, so assets cannot be listed on it.';
  END IF;
  IF anchor IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'A work order must be raised against an asset before assets can be listed on it.';
  END IF;
END
-- >>>
-- ============================================================================================
-- NO PERMISSION ROWS, AND THAT IS THE DECISION
--
-- Choosing which assets a job covers is part of raising or editing the work order, so it needs
-- `work_orders_create` and `work_orders_edit` - both seeded by `work_order_permissions.sql`.
-- Closing an asset from the PWA introduces no permission name at all: a technician's authority
-- over the job they were sent to comes from being ON it, which is the shared `ON_THIS_JOB`
-- predicate every self-service work-order statement already filters on.
--
-- The OFFICE close still checks the asset module's own `_create` permission, because that write
-- genuinely lands in `asset_maintenance`. That check already exists in
-- `work-orders/[id]/transition.ts` and is unchanged.
-- ============================================================================================
-- >>>
-- ── VERIFICATION. Printed by scripts/run-sql.js, so a reader sees the shape that resulted. ──
--
-- Expected: tbl 1, uq_cols 2, idx_asset 1, idx_state_cols 2, fk_wo_cascade 1, fk_asset_cascade 1,
--           fk_maint_setnull 1, state_check 1, employee_fk 0, required_col 0, origin_trigger 1,
--           wo_batch_col 1, wo_batch_fk_setnull 1, anchor_kept 1.
--
-- `uq_cols` is TWO and `idx_state_cols` is TWO, and that is the point of reading them from
-- `STATISTICS`: that view holds one row PER COLUMN of an index. A check written as `> 0` would
-- pass on a unique key that had silently lost its second column, which is the mistake that would
-- let one asset be listed on one job twice.
--
-- `employee_fk 0` and `required_col 0` are ABSENCES asserted on purpose. Each is a decision argued
-- in the header, and a zero here is what makes it checkable rather than a comment somebody reads
-- past.
--
-- `anchor_kept 1` is `work_orders.asset_id` still existing. It is verified as a PRESENCE because
-- the temptation is to drop it, and the header explains at length why that converts
-- `work_order_module.sql` into a file that fails on its second apply.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets')            AS tbl,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets'
      AND INDEX_NAME = 'uq_woas_asset')                                               AS uq_cols,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets'
      AND INDEX_NAME = 'idx_woas_asset')                                              AS idx_asset,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets'
      AND INDEX_NAME = 'idx_woas_state')                                              AS idx_state_cols,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woas_wo'
      AND DELETE_RULE = 'CASCADE')                                                   AS fk_wo_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woas_asset'
      AND DELETE_RULE = 'CASCADE')                                                   AS fk_asset_cascade,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woas_maint'
      AND DELETE_RULE = 'SET NULL')                                                  AS fk_maint_setnull,
  (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_woas_state')      AS state_check,
  (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets'
      AND COLUMN_NAME = 'completed_by_employee_id'
      AND REFERENCED_TABLE_NAME IS NOT NULL)                                         AS employee_fk,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_assets'
      AND COLUMN_NAME = 'is_required')                                               AS required_col,
  (SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE()
      AND TRIGGER_NAME = 'trg_woas_origin_ins')                                 AS origin_trigger,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders'
      AND COLUMN_NAME = 'batch_id')                                                  AS wo_batch_col,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_wo_batch'
      AND DELETE_RULE = 'SET NULL')                                                  AS wo_batch_fk_setnull,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders'
      AND COLUMN_NAME = 'asset_id')                                                  AS anchor_kept,
  (SELECT COUNT(*) FROM `work_order_assets`)                                         AS rows_now
