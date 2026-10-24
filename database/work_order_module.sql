-- ============================================================================================
-- WORK ORDER MODULE - the schema: SEVEN tables, FOUR triggers, ONE column on a shipped table
--
-- Design: .agents/pipeline/2026-10-24_00-59-07/02-design.md sections 3, 9.1
--
-- Run:  node scripts/run-sql.js database/work_order_module.sql
--
-- IDEMPOTENT. Run it twice and the second run changes nothing. Production applies a schema
-- change with `git pull` and a hand, and a hand runs things twice.
--
-- Statement separator is a `-- >>>` line, NOT a semicolon: scripts/run-sql.js splits on that
-- marker so a CREATE TRIGGER body carrying internal semicolons travels as one statement.
--
-- ── THE ONE PRECONDITION THIS FILE CANNOT CREATE FOR ITSELF ──
--
-- Eight of the nine foreign-key targets are created or ALTERed by a file in `database/`.
-- `sales_orders` is NOT: there is no `CREATE TABLE ... sales_orders` anywhere in `database/*.sql`.
-- It is a legacy accounting table and it must already exist before this file runs. Verified on
-- the development database: it exists as ENGINE=InnoDB with an `int` signed primary key, so
-- `fk_wo_sorder` is creatable here. `fk_wo_sorder` is declared INLINE - the same bargain
-- `operations_assets.sql` makes with the equally legacy `helpdesk_tickets` - which means that on
-- a database without `sales_orders` the whole `CREATE TABLE work_orders` fails with errno 1215
-- and nothing explains why. So the closing verification SELECT reports the presence of EVERY FK
-- target BY NAME: a failed run says which table was missing instead of leaving an errno to read.
--
-- ── SIGNED vs UNSIGNED - read this before adding a foreign key ──
--
--   assets.id             int unsigned  ->  work_orders.asset_id        INT UNSIGNED
--   vendors.id            int unsigned  ->  work_orders.vendor_id       INT UNSIGNED
--   asset_maintenance.id  int unsigned  ->  work_orders.maintenance_id  INT UNSIGNED
--   helpdesk_tickets.id   int SIGNED    ->  work_orders.ticket_id       INT
--   projects.id           int SIGNED    ->  work_orders.project_id      INT
--   sales_orders.id       int SIGNED    ->  work_orders.sales_order_id  INT
--
-- Measured against the live database immediately before this file was written. A foreign key
-- across a signed/unsigned mismatch fails with errno 3780 and the message names neither column.
--
-- Every new table id is `INT` SIGNED, matching the `project_*` family. That is what makes
-- `project_timesheets.work_order_id INT` a type match.
--
-- ── CREATION ORDER IS LOAD BEARING ──
--
--   1. work_order_types                 (no FK out; its default_template_id FK comes at step 10)
--   2. work_order_templates             (no FK out - the type is text, not a key)
--   3. work_order_template_items        -> work_order_templates
--   4. work_orders                      -> work_order_templates, assets, helpdesk_tickets,
--                                          projects, sales_orders, vendors, asset_maintenance
--   5. work_orders triggers (ins + upd) the one-origin and snapshot rules
--   6. work_order_items                 -> work_orders
--   7. work_order_approvals             -> work_orders
--   8. work_order_approvals triggers    the one-pending rule
--   9. work_order_numbering             (no FK out)
--  10. ALTER work_order_types ADD fk_wotype_default_tpl  (breaks the types <-> templates cycle)
--  11. ALTER project_timesheets         the column, the index and the FK, one guard EACH
--  12. seeds: 4 types, 1 numbering row
--
-- Step 12 is last only for a reader stepping through. All four seeded types carry
-- `default_template_id` NULL, so the seed does NOT depend on step 10 having run. Stated so
-- nobody "fixes" a dependency that is not there.
--
-- `CREATE INDEX IF NOT EXISTS` is NOT used: it is MariaDB-only and MySQL 8 rejects it. Every
-- guarded object goes through SET @x := ... / PREPARE / EXECUTE / DEALLOCATE, because MySQL
-- resolves BOTH branches of an `IF()` at prepare time, so an `IF()` naming a table that does not
-- exist yet fails before its guard is read.
--
-- `CREATE TRIGGER` has no `IF NOT EXISTS` form, so each is preceded by `DROP TRIGGER IF EXISTS`.
-- Without that the file succeeds on the first run and fails on the second, which is the run
-- production makes.
-- ============================================================================================

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 1. work_order_types - the kinds, as ROWS
--
-- Project Manager, Preventive Maintenance, Corrective Maintenance and Services are DATA, not
-- an ENUM, so an operator can add a kind without a migration.
--
-- THREE FLAGS, THREE NAMED EFFECTS. A fourth flag needs a fourth named effect before it is
-- added.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_types` (
  `id`                  INT NOT NULL AUTO_INCREMENT,
  `name`                VARCHAR(60)  NOT NULL,
  `icon`                VARCHAR(60)  NOT NULL DEFAULT 'bi-card-checklist',
  -- Whether work of this kind normally schedules the next visit.
  --
  -- NOT A HINT ONLY. It GATES the close dialog: when this is 1, the close dialog REQUIRES
  -- `next_due` before it will accept a close - "A preventive job records when the next one is
  -- due." `operations_assets.sql` calls `next_due` "the whole point of a preventive record", so
  -- a preventive close with NULL is a real loss rather than a tidiness question. It still seeds
  -- nothing: the value is captured per work order, twice over (the create form and the close
  -- dialog), never copied from here.
  `expects_next_due`    TINYINT(1)   NOT NULL DEFAULT 0,
  -- Which `asset_repair_categories.name` a closed ASSET-origin work order DEFAULTS to, by text.
  -- NULL means this kind proposes no default; the close dialog then asks.
  --
  -- ── THIS IS A HINT THAT MAY GO STALE, AND THAT IS DELIBERATE ──
  --
  -- `asset-repair-categories.ts` cascades a rename onto `asset_maintenance.kind` and nothing
  -- else - it does not know this column exists. So renaming a repair category leaves this value
  -- pointing at a name that is gone. The close dialog therefore RESOLVES it against the ACTIVE
  -- master when it opens and falls back to "empty and required" rather than carrying a dead
  -- default into a service record.
  --
  -- The alternative was to teach `asset-repair-categories.ts` about this table. Rejected:
  -- counting a work order TYPE in that endpoint's usage figure would make a repair category
  -- UNDELETABLE because something DEFAULTS to it - a usage guard nobody asked for, raised by a
  -- settings row rather than by a record. Degrading a default is cheaper than blocking a delete.
  `maintenance_kind`    VARCHAR(60)  DEFAULT NULL,
  -- The form's default checklist; the operator can override it per work order.
  `default_template_id` INT          DEFAULT NULL,
  `notes`               VARCHAR(300) DEFAULT NULL,
  `sort_order`          INT          NOT NULL DEFAULT 0,
  `is_active`           TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wotype_name`    (`name`),
  KEY        `idx_wotype_active` (`is_active`, `sort_order`),
  -- Declared by hand so the foreign key added at step 10 adopts a NAMED index instead of
  -- letting MySQL invent one.
  KEY        `idx_wotype_tpl`    (`default_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 2. work_order_templates - the reusable checklist
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_templates` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(150) NOT NULL,
  -- The kind this list is FOR, by NAME, the same bargain `work_orders.type_name` makes.
  -- Nullable: a generic checklist that fits any kind is a real thing.
  `type_name`   VARCHAR(60)  DEFAULT NULL,
  `description` VARCHAR(400) DEFAULT NULL,
  `is_active`   TINYINT(1)   NOT NULL DEFAULT 1,
  `created_by`  VARCHAR(191) DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wotpl_name`    (`name`),
  KEY        `idx_wotpl_active` (`is_active`, `name`),
  KEY        `idx_wotpl_type`   (`type_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 3. work_order_template_items - the steps of the reusable checklist
--
-- No `duration_days`. A project template item becomes a dated task; a work order checklist step
-- is a thing to tick inside one job that already has a date. Carrying a duration would invite
-- somebody to schedule each step, which is a project, not a work order.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_template_items` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `template_id` INT NOT NULL,
  `title`       VARCHAR(255) NOT NULL,
  `notes`       VARCHAR(400) DEFAULT NULL,
  -- The ONE addition beyond the project item shape: a step that may not be skipped.
  `is_required` TINYINT(1)   NOT NULL DEFAULT 0,
  `sort_order`  INT          NOT NULL DEFAULT 0,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_wotli_template` (`template_id`, `sort_order`),
  -- ON DELETE CASCADE only. `work_order_templates.id` is AUTO_INCREMENT and is never updated,
  -- so ON UPDATE CASCADE would be dead weight - the same observation
  -- `project_phase_approval.sql` records about `project_phase_log`.
  CONSTRAINT `fk_wotli_template` FOREIGN KEY (`template_id`)
    REFERENCES `work_order_templates` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 4. work_orders - the instruction
--
-- There is NO `hours` column: labour is recorded in `project_timesheets` against
-- `work_order_id`, so hours are approved by the one approval path that already exists for them.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_orders` (
  `id`             INT NOT NULL AUTO_INCREMENT,
  -- WO-2026-0001 at the seeded settings. VARCHAR(50), NOT 30, and the arithmetic is the reason:
  -- `nextReference` returns `${prefix}-${year}-${padded}`, `chk_wonum_prefix` allows a
  -- 20-character prefix and `chk_wonum_padding` allows padding 8, so the longest reference an
  -- operator can configure is 20 + 1 + 4 + 1 + 8 = 34. At 30 an operator setting both maxima
  -- would make every create fail with ER_DATA_TOO_LONG, INSIDE the create transaction, AFTER
  -- the reference was allocated. 50 is also what the five project references declare - they are
  -- the family that has an editable numbering master, and this is the sixth.
  `work_order_no`  VARCHAR(50)  NOT NULL,
  -- The TYPE, by NAME, not by foreign key: a work order is evidence of an instruction, and the
  -- word that was true when it was raised must stay readable after the settings row is renamed
  -- or retired. The rename cascade in `types.ts` keeps live rows in step; a retired type keeps
  -- filtering the register.
  `type_name`      VARCHAR(60)  NOT NULL,
  `title`          VARCHAR(255) NOT NULL,
  -- VARCHAR(5000), not TEXT. Every other free-text column here declares its cap and has a
  -- matching `str(.., n)` validator; a bare TEXT would be the one unbounded input in the module,
  -- capped in neither place.
  `description`    VARCHAR(5000) DEFAULT NULL,

  -- ── ORIGIN: four nullable FKs, EXACTLY ONE populated at write time ──
  `asset_id`       INT UNSIGNED DEFAULT NULL,
  `ticket_id`      INT          DEFAULT NULL,
  `project_id`     INT          DEFAULT NULL,
  `sales_order_id` INT          DEFAULT NULL,

  -- ── THE THREE FACTS THAT MAKE IT AN INSTRUCTION ──
  `status`         ENUM('draft','open','in_progress','completed','closed','cancelled')
                   NOT NULL DEFAULT 'draft',
  `scheduled_date` DATE         NOT NULL,
  -- No foreign key, following `project_tasks.assignee_employee_id`,
  -- `project_risks.owner_employee_id` and `project_ncrs.owner_employee_id`. A resigned employee
  -- changes STATUS, never disappears.
  `assignee_employee_id` INT    DEFAULT NULL,

  `priority`       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  -- Subcontracted work, independent of the origin.
  `vendor_id`      INT UNSIGNED DEFAULT NULL,

  -- ── THE CHECKLIST SNAPSHOT ──
  -- The name is stored beside the id so a deleted template leaves the work order still saying
  -- which list it was raised from.
  `template_id`    INT          DEFAULT NULL,
  `template_name`  VARCHAR(150) DEFAULT NULL,

  `next_due`       DATE         DEFAULT NULL,
  `estimated_cost` DECIMAL(15,2) DEFAULT NULL,
  -- A NOTE, not a parts list. Nothing is decremented anywhere: there is no stock module.
  `materials_note` VARCHAR(500) DEFAULT NULL,

  -- ── CLOSE-OUT ──
  `started_on`     DATE         DEFAULT NULL,
  `completed_on`   DATE         DEFAULT NULL,
  `completion_note` VARCHAR(1000) DEFAULT NULL,
  `actual_cost`    DECIMAL(15,2) DEFAULT NULL,
  `closed_on`      DATE         DEFAULT NULL,
  `closed_by`      VARCHAR(150) DEFAULT NULL,
  -- The `asset_maintenance` row this work order produced, so the service history is reachable
  -- from the instruction and the instruction from the history. NULL when no service row was due.
  `maintenance_id` INT UNSIGNED DEFAULT NULL,
  `cancel_reason`  VARCHAR(400) DEFAULT NULL,

  `created_by`     VARCHAR(150) DEFAULT NULL,
  `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wo_no` (`work_order_no`),
  -- The register's hot read: what is outstanding, in due order. `status` leads because every
  -- figure on the screen is scoped by it.
  KEY `idx_wo_status_due`  (`status`, `scheduled_date`),
  KEY `idx_wo_type`        (`type_name`, `scheduled_date`),
  KEY `idx_wo_assignee`    (`assignee_employee_id`, `status`),
  KEY `idx_wo_asset`       (`asset_id`),
  KEY `idx_wo_ticket`      (`ticket_id`),
  KEY `idx_wo_project`     (`project_id`),
  KEY `idx_wo_sales_order` (`sales_order_id`),
  KEY `idx_wo_vendor`      (`vendor_id`),
  KEY `idx_wo_template`    (`template_id`),
  KEY `idx_wo_maintenance` (`maintenance_id`),

  -- ── SET NULL ON ALL SEVEN, and the reasoning is `asset_maintenance.ticket_id`'s own ──
  -- "deleting a ticket must not delete the record that the machine was serviced." Deleting the
  -- thing a work order was ABOUT must not delete the record that somebody was told to do work.
  CONSTRAINT `fk_wo_asset`    FOREIGN KEY (`asset_id`)       REFERENCES `assets` (`id`)               ON DELETE SET NULL,
  CONSTRAINT `fk_wo_ticket`   FOREIGN KEY (`ticket_id`)      REFERENCES `helpdesk_tickets` (`id`)     ON DELETE SET NULL,
  CONSTRAINT `fk_wo_project`  FOREIGN KEY (`project_id`)     REFERENCES `projects` (`id`)             ON DELETE SET NULL,
  CONSTRAINT `fk_wo_sorder`   FOREIGN KEY (`sales_order_id`) REFERENCES `sales_orders` (`id`)         ON DELETE SET NULL,
  CONSTRAINT `fk_wo_vendor`   FOREIGN KEY (`vendor_id`)      REFERENCES `vendors` (`id`)              ON DELETE SET NULL,
  CONSTRAINT `fk_wo_template` FOREIGN KEY (`template_id`)    REFERENCES `work_order_templates` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_wo_maint`    FOREIGN KEY (`maintenance_id`) REFERENCES `asset_maintenance` (`id`)    ON DELETE SET NULL,

  -- ══════════════════════════════════════════════════════════════════════════════════════════
  -- THERE IS NO `chk_wo_one_origin` AND NO `chk_wo_template_snap`, AND THE REASON IS MEASURED.
  -- DO NOT ADD ONE BACK.
  --
  -- MySQL 8.0.45 refuses a CHECK over a column that carries a foreign-key referential action:
  --   ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN (3823) - "Column 'asset_id'
  --   cannot be used in a check constraint: needed in a foreign key constraint referential
  --   action."
  -- All four origin columns and `template_id` carry ON DELETE SET NULL, so both CHECKs are
  -- impossible. ALTER-adding them afterwards is refused the same way. The restriction is PER
  -- COLUMN, which is why the four CHECKs below - naming only `status`, the dates, the costs and
  -- `cancel_reason` - are accepted and fire.
  --
  -- `database/asset_sites_models.sql` hit this identical refusal for the identical problem and
  -- resolved it with a BEFORE INSERT / BEFORE UPDATE pair. The same pair is below. Dropping the
  -- SET NULL instead was rejected: an FK with no action is NO ACTION, which BLOCKS the parent
  -- delete (1451), so a work order would make its asset undeletable and its template
  -- undeletable - a usage guard nobody asked for.
  -- ══════════════════════════════════════════════════════════════════════════════════════════

  -- Every comparison that touches a nullable column is wrapped, because a CHECK PASSES on
  -- UNKNOWN - the same note `chk_pts_decided` carries.
  CONSTRAINT `chk_wo_stage` CHECK (
       (`status` IN ('draft','open','cancelled'))
    OR (`status` = 'in_progress' AND `started_on`   IS NOT NULL)
    OR (`status` = 'completed'   AND `completed_on` IS NOT NULL)
    OR (`status` = 'closed'      AND `completed_on` IS NOT NULL AND `closed_on` IS NOT NULL)),

  -- FOUR conjuncts. The fourth is the one a single `next_due >= scheduled_date` clause misses:
  -- a job scheduled in January and closed in December could record its next visit in February,
  -- ten months in the past. Both clauses together are satisfiable precisely because the close
  -- dialog can re-enter the date. Neither names an FK column, so error 3823 does not reach them.
  CONSTRAINT `chk_wo_dates` CHECK (
        (`started_on`   IS NULL OR `completed_on` IS NULL OR `completed_on` >= `started_on`)
    AND (`completed_on` IS NULL OR `closed_on`    IS NULL OR `closed_on`    >= `completed_on`)
    AND (`next_due`     IS NULL OR `next_due` >= `scheduled_date`)
    AND (`next_due`     IS NULL OR `completed_on` IS NULL OR `next_due` >= `completed_on`)),

  CONSTRAINT `chk_wo_cancel` CHECK (`status` = 'cancelled' OR `cancel_reason` IS NULL),
  CONSTRAINT `chk_wo_cost`   CHECK ((`estimated_cost` IS NULL OR `estimated_cost` >= 0)
                                AND (`actual_cost`    IS NULL OR `actual_cost`    >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 5. The two write-time rules on `work_orders`, as a trigger pair
--
-- One BEFORE INSERT, one BEFORE UPDATE, and THE BODIES ARE NOT IDENTICAL. Each IF carries its
-- own MESSAGE_TEXT so a failure names which rule fired.
-- ════════════════════════════════════════════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS `trg_wo_write_rules_ins`

-- >>>
-- INSERT is STRICT. There is no OLD row, so the rule can only be `<> 1`: a work order is BORN
-- with exactly one origin.
CREATE TRIGGER `trg_wo_write_rules_ins`
BEFORE INSERT ON `work_orders`
FOR EACH ROW
BEGIN
  IF ((CASE WHEN NEW.`asset_id`       IS NULL THEN 0 ELSE 1 END)
    + (CASE WHEN NEW.`ticket_id`      IS NULL THEN 0 ELSE 1 END)
    + (CASE WHEN NEW.`project_id`     IS NULL THEN 0 ELSE 1 END)
    + (CASE WHEN NEW.`sales_order_id` IS NULL THEN 0 ELSE 1 END)) <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'A work order is against exactly one thing: an asset, a ticket, a project or a sales order.';
  END IF;
  IF NEW.`template_id` IS NOT NULL AND NEW.`template_name` IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'A work order that names a template must also store the template name it was created from.';
  END IF;
END

-- >>>
DROP TRIGGER IF EXISTS `trg_wo_write_rules_upd`

-- >>>
-- ── THE UPDATE BODY IS DELIBERATELY ASYMMETRIC. DO NOT "TIDY" IT TO `<> 1`. ──
--
-- MySQL does not activate triggers for foreign-key referential actions, so when a cascade
-- SET NULLs the one origin this row had, nothing fires and the row is left with zero origins.
-- That part is fine. What a strict `<> 1` body then does to that row is not: it computes
-- `new_n = 0` on EVERY later write and SIGNALs, so the orphaned work order becomes PERMANENTLY
-- FROZEN - it cannot be transitioned, cannot be cancelled, cannot be edited, and
-- `updated_at ON UPDATE CURRENT_TIMESTAMP` means even a title correction trips it. The lifecycle
-- gives `work_orders` four UPDATE paths and all four would fail on that row.
--
-- So: two origins is ALWAYS refused; zero origins is refused only when this row HAD one, which
-- is what makes it a USER clearing the origin rather than a row the cascade already emptied.
--
-- `asset_site_documents` gets away with identical bodies because its post-cascade row has no
-- UPDATE path at all - an attachment is deleted, never edited. That file is a precedent for the
-- trigger PAIR, not for identical bodies.
--
-- The snapshot rule is one-directional for the same family of reason: `fk_wo_template` is
-- ON DELETE SET NULL, so after a template is deleted the row legitimately holds a NAME with no
-- ID - that is the whole point of the snapshot. "Both or neither" would make that row
-- un-editable. The invariant worth enforcing is that an id never arrives without the name that
-- was true when it did.
CREATE TRIGGER `trg_wo_write_rules_upd`
BEFORE UPDATE ON `work_orders`
FOR EACH ROW
BEGIN
  DECLARE new_n TINYINT;
  DECLARE old_n TINYINT;
  SET new_n = (NEW.`asset_id`       IS NOT NULL) + (NEW.`ticket_id`      IS NOT NULL)
            + (NEW.`project_id`     IS NOT NULL) + (NEW.`sales_order_id` IS NOT NULL);
  SET old_n = (OLD.`asset_id`       IS NOT NULL) + (OLD.`ticket_id`      IS NOT NULL)
            + (OLD.`project_id`     IS NOT NULL) + (OLD.`sales_order_id` IS NOT NULL);
  IF new_n > 1 OR (new_n = 0 AND old_n > 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'A work order is against exactly one thing: an asset, a ticket, a project or a sales order.';
  END IF;
  IF NEW.`template_id` IS NOT NULL AND NEW.`template_name` IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT =
      'A work order that names a template must also store the template name it was created from.';
  END IF;
END

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 6. work_order_items - the COPIED checklist
--
-- No `template_item_id`, and the absence is the design: these rows belong to the instruction,
-- not to the list they were copied from, so editing the template later changes nothing here.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_items` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `work_order_id` INT NOT NULL,
  `title`         VARCHAR(255) NOT NULL,
  `notes`         VARCHAR(400) DEFAULT NULL,
  `is_required`   TINYINT(1)   NOT NULL DEFAULT 0,
  `sort_order`    INT          NOT NULL DEFAULT 0,
  -- A copied checklist nobody can tick is a printed list.
  `state`         ENUM('pending','done','skipped') NOT NULL DEFAULT 'pending',
  `skip_reason`   VARCHAR(300) DEFAULT NULL,
  -- `decided_on` / `decided_by`, NOT `done_on` / `done_by`, and the names matter.
  --
  -- A SKIPPED step was not done. Columns called `done_on` and `done_by` on a skipped row would
  -- record a date a step was done and a person who did it, for work that did not happen - a row
  -- that reads as a false record.
  --
  -- `decided_on` / `decided_by` / `skip_reason` is `project_timesheets`' own vocabulary, and
  -- that is the table whose `chk_pts_decided` is the model for the CHECK below. House words
  -- reused rather than extended.
  `decided_on`    DATE         DEFAULT NULL,
  `decided_by`    VARCHAR(150) DEFAULT NULL,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_woi_wo` (`work_order_id`, `sort_order`),
  -- CASCADE from the work order, not from the template.
  CONSTRAINT `fk_woi_wo` FOREIGN KEY (`work_order_id`)
    REFERENCES `work_orders` (`id`) ON DELETE CASCADE,
  -- Neither CHECK names an FK column, so error 3823 does not reach them. The invariant is
  -- `chk_pts_decided`'s: a state change carries a who and a when, and a state that was not
  -- decided carries neither.
  CONSTRAINT `chk_woi_state` CHECK (
       (`state` = 'pending' AND `decided_on` IS NULL     AND `decided_by` IS NULL     AND `skip_reason` IS NULL)
    OR (`state` = 'done'    AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL AND `skip_reason` IS NULL)
    OR (`state` = 'skipped' AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL AND `skip_reason` IS NOT NULL)),
  -- THIS is what makes `is_required` mean something. Without it, "complete" is whatever the
  -- technician says.
  CONSTRAINT `chk_woi_required_not_skipped` CHECK (`state` <> 'skipped' OR `is_required` = 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 7. work_order_approvals - the request table
--
-- A request table rather than two columns on `work_orders`, because `applyApprovalAction`
-- hard-codes `UPDATE <table> SET status = ?, current_level = ? WHERE id = ?` and
-- `work_orders.status` is a LIFECYCLE word that the register publishes. One column cannot hold
-- two vocabularies, and MySQL would refuse `pending` against that ENUM anyway.
--
-- No `action` column. `project_phase_requests` needs one because a project crosses five gates;
-- a work order is issued ONCE, so there is nothing for an `action` column to distinguish.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_approvals` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `work_order_id` INT NOT NULL,
  -- Exactly the three words the engine writes, so NO `statusWords` map. There is a second,
  -- harder reason: `src/pages/api/admin/hr/approval.ts` pulls stranded rows back with a literal
  -- `WHERE status = 'pending'`, so a module carrying its own pending word is silently skipped.
  `status`        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  -- 0 means nobody has signed. `checkApproverTurn` reads it, so it cannot be derived from the
  -- trail: an unsigned request has zero trail rows and still has to say which level it waits for.
  `current_level` INT UNSIGNED NOT NULL DEFAULT 0,
  -- `ctx.username`, following `project_phase_requests.requested_by`. Not a foreign key: it is
  -- EVIDENCE of who asked, and a deleted account must not erase that.
  `requested_by`  VARCHAR(150) DEFAULT NULL,
  `remark`        TEXT         DEFAULT NULL,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_woa_wo`      (`work_order_id`, `created_at`),
  KEY `idx_woa_pending` (`status`, `current_level`),
  -- CASCADE, and here it is right: a request has no existence without the work order it is
  -- about. The same argument `project_phase_requests` records - and the same reason the one
  -- pending guard below is a trigger pair rather than a stored generated column, which MySQL
  -- refuses to combine with ON DELETE CASCADE on its base column.
  CONSTRAINT `fk_woa_wo` FOREIGN KEY (`work_order_id`)
    REFERENCES `work_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 8. One pending request per work order, by two triggers ──
DROP TRIGGER IF EXISTS `trg_woa_one_pending_ins`

-- >>>
CREATE TRIGGER `trg_woa_one_pending_ins`
BEFORE INSERT ON `work_order_approvals`
FOR EACH ROW
BEGIN
  IF NEW.`status` = 'pending' AND EXISTS (
    SELECT 1 FROM `work_order_approvals`
     WHERE `work_order_id` = NEW.`work_order_id` AND `status` = 'pending'
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This work order already has an approval request waiting. Decide that one first.';
  END IF;
END

-- >>>
-- Why UPDATE too: a REJECTED request can be put back to `pending` by an UPDATE, which bypasses
-- the INSERT trigger entirely. `id <> NEW.id` excludes the row itself, or every UPDATE to a
-- waiting row would refuse itself.
DROP TRIGGER IF EXISTS `trg_woa_one_pending_upd`

-- >>>
CREATE TRIGGER `trg_woa_one_pending_upd`
BEFORE UPDATE ON `work_order_approvals`
FOR EACH ROW
BEGIN
  IF NEW.`status` = 'pending' AND EXISTS (
    SELECT 1 FROM `work_order_approvals`
     WHERE `work_order_id` = NEW.`work_order_id` AND `status` = 'pending' AND `id` <> NEW.`id`
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This work order already has an approval request waiting. Decide that one first.';
  END IF;
END

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 9. work_order_numbering - its own master, shaped on `project_numbering`
--
-- The CHECK maxima are what set `work_orders.work_order_no` at VARCHAR(50): prefix 20 + 1 +
-- year 4 + 1 + padding 8 = 34.
-- ════════════════════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `work_order_numbering` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `table_key`  VARCHAR(50)  NOT NULL,
  `label`      VARCHAR(100) NOT NULL,
  `prefix`     VARCHAR(20)  NOT NULL,
  `padding`    INT          NOT NULL DEFAULT 4,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wonum_table` (`table_key`),
  CONSTRAINT `chk_wonum_prefix`  CHECK (CHAR_LENGTH(TRIM(`prefix`)) BETWEEN 2 AND 20),
  CONSTRAINT `chk_wonum_padding` CHECK (`padding` BETWEEN 2 AND 8)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 10. work_order_types.default_template_id - the foreign key, added LAST of the two tables
--
-- Declared here rather than inline because `work_order_types` is created before
-- `work_order_templates`; inline the two would be mutually dependent at CREATE time.
--
-- ON DELETE SET NULL: deleting a template clears the default rather than blocking the delete,
-- which agrees with `projects/templates.ts`'s recorded decision that a template has no usage
-- guard because applying it COPIES. No CHECK names this column, so error 3823 does not apply.
--
-- ONE GUARD PER OBJECT, here and in section 11. One ALTER can carry one guard.
-- ════════════════════════════════════════════════════════════════════════════════════════════
SET @wotype_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_types'
     AND CONSTRAINT_NAME = 'fk_wotype_default_tpl'
)

-- >>>
SET @sql := IF(@wotype_fk = 0,
  'ALTER TABLE `work_order_types`
     ADD CONSTRAINT `fk_wotype_default_tpl` FOREIGN KEY (`default_template_id`)
       REFERENCES `work_order_templates` (`id`) ON DELETE SET NULL',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 11. project_timesheets.work_order_id - the ONE column on a shipped table
--
-- Labour on a work order is recorded as timesheet hours, so it travels the approval path that
-- already exists for hours instead of a second one invented here.
--
-- THREE SEPARATE GUARDS - COLUMNS, STATISTICS, TABLE_CONSTRAINTS - and the split is not
-- tidiness. One ALTER can carry one guard, so guarded on COLUMNS alone a re-run after a
-- partially applied run would skip all three ADDs and leave the index and the foreign key
-- missing, silently and with no error.
--
-- SET NULL, not CASCADE: deleting a work order must not delete the record that somebody worked
-- three hours. `project_id` is NOT touched and stays NOT NULL - hours belong to a project
-- first; the work order is an extra fact about them, not a replacement for one.
--
-- No CHECK on `project_timesheets` names this column, so the table's check count stays at 3.
-- ════════════════════════════════════════════════════════════════════════════════════════════
SET @pts_col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'project_timesheets'
     AND COLUMN_NAME = 'work_order_id'
)

-- >>>
SET @sql := IF(@pts_col = 0,
  'ALTER TABLE `project_timesheets`
     ADD COLUMN `work_order_id` INT DEFAULT NULL
       COMMENT ''work_orders.id - the instruction these hours were worked against''',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
SET @pts_idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'project_timesheets'
     AND INDEX_NAME = 'idx_pts_work_order'
)

-- >>>
SET @sql := IF(@pts_idx = 0,
  'ALTER TABLE `project_timesheets` ADD KEY `idx_pts_work_order` (`work_order_id`)',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
SET @pts_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'project_timesheets'
     AND CONSTRAINT_NAME = 'fk_pts_work_order'
)

-- >>>
SET @sql := IF(@pts_fk = 0,
  'ALTER TABLE `project_timesheets`
     ADD CONSTRAINT `fk_pts_work_order` FOREIGN KEY (`work_order_id`)
       REFERENCES `work_orders` (`id`) ON DELETE SET NULL',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 12. Seeds
--
-- Four kinds, INSERT IGNORE on `uq_wotype_name`, so a second run adds nothing and an operator's
-- edits survive.
--
-- `Preventive` and `Corrective` are real `asset_repair_categories.name` values - the live five
-- are Preventive, Corrective, Inspection, Calibration and Upgrade, all active, verified before
-- this file was written, so both seeded `maintenance_kind` values resolve.
--
-- `Services` and `Project Work` seed `maintenance_kind` NULL ON PURPOSE: no existing category
-- honestly means either, and inventing one would put a word in a machine's service history that
-- nobody chose.
--
-- All four seed `default_template_id` NULL: the module ships with no templates, so there is
-- nothing to default to. The operator sets it on the Types tab once they have written one.
-- ════════════════════════════════════════════════════════════════════════════════════════════
INSERT IGNORE INTO `work_order_types`
  (`name`, `icon`, `expects_next_due`, `maintenance_kind`, `default_template_id`, `notes`, `sort_order`, `is_active`)
VALUES
  ('Preventive Maintenance', 'bi-shield-check',       1, 'Preventive', NULL,
   'Scheduled servicing. Normally records when the next visit is due.', 1, 1),
  ('Corrective Maintenance', 'bi-wrench-adjustable',  0, 'Corrective', NULL,
   'Repair work raised because something failed.',                      2, 1),
  ('Services',               'bi-tools',              0, NULL,         NULL,
   'Service work that is not maintenance of an owned asset.',           3, 1),
  ('Project Work',           'bi-kanban',             0, NULL,         NULL,
   'Work instructed as part of a project.',                             4, 1)

-- >>>
-- ── The one numbering row ──
--
-- `ON DUPLICATE KEY UPDATE id = id` and NOT `INSERT IGNORE`: both leave the row alone, but this
-- form says so out loud. An operator who sets the prefix to JOB keeps JOB across every later
-- run of this file. That is the only thing proving the row is configuration rather than a
-- constant.
INSERT INTO `work_order_numbering` (`table_key`, `label`, `prefix`, `padding`)
VALUES ('work_orders', 'Work order number', 'WO', 4)
ON DUPLICATE KEY UPDATE `id` = `id`

-- >>>
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- VERIFICATION
--
-- EXPECTED, every number stated so a failed run says which object is missing rather than
-- leaving an errno 1215 to interpret:
--
--   tbl_types 1   tbl_templates 1   tbl_template_items 1   tbl_work_orders 1
--   tbl_items 1   tbl_approvals 1   tbl_numbering 1
--   dynamic_rows 7        <- ROW_FORMAT=DYNAMIC on all seven
--   trg_work_orders 2     trg_approvals 2
--   wo_fks 7              wo_fks_setnull 7      <- all seven origins/links SET NULL
--   wo_checks 4           woi_checks 2
--   no_origin_check 0     no_snap_check 0       <- MUST be 0. See the comment in section 4
--   pts_cols 15           pts_fks 3   pts_checks 3
--   pts_wo_nullable YES   pts_project_notnull NO
--   pts_idx 1             pts_fk_setnull 1
--   seeded_types 4        seeded_numbering 1
--
-- FK TARGETS, every one by name - each MUST read 1. `sales_orders` is the one with no migration
-- in `database/`, so if this file failed, read that column first.
--   t_assets 1  t_tickets 1  t_projects 1  t_sales_orders 1  t_vendors 1
--   t_asset_maintenance 1  t_project_timesheets 1
-- ════════════════════════════════════════════════════════════════════════════════════════════
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_types')            AS tbl_types,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_templates')        AS tbl_templates,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_template_items')   AS tbl_template_items,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders')                 AS tbl_work_orders,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_items')            AS tbl_items,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_approvals')        AS tbl_approvals,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_numbering')        AS tbl_numbering,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME LIKE 'work_order%'
      AND CREATE_OPTIONS LIKE '%row_format=DYNAMIC%')                               AS dynamic_rows,
  (SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE() AND EVENT_OBJECT_TABLE = 'work_orders')       AS trg_work_orders,
  (SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE()
      AND EVENT_OBJECT_TABLE = 'work_order_approvals')                              AS trg_approvals,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY')                                          AS wo_fks,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders'
      AND DELETE_RULE = 'SET NULL')                                                 AS wo_fks_setnull,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_orders'
      AND CONSTRAINT_TYPE = 'CHECK')                                                AS wo_checks,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_items'
      AND CONSTRAINT_TYPE = 'CHECK')                                                AS woi_checks,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'chk_wo_one_origin')                                    AS no_origin_check,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'chk_wo_template_snap')                                 AS no_snap_check,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets')          AS pts_cols,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY')                                          AS pts_fks,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets'
      AND CONSTRAINT_TYPE = 'CHECK')                                                AS pts_checks,
  (SELECT IS_NULLABLE FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets'
      AND COLUMN_NAME = 'work_order_id')                                            AS pts_wo_nullable,
  (SELECT IS_NULLABLE FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets'
      AND COLUMN_NAME = 'project_id')                                               AS pts_project_notnull,
  (SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets'
      AND INDEX_NAME = 'idx_pts_work_order')                                        AS pts_idx,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_pts_work_order'
      AND DELETE_RULE = 'SET NULL')                                                 AS pts_fk_setnull,
  (SELECT COUNT(*) FROM `work_order_types`)                                         AS seeded_types,
  (SELECT COUNT(*) FROM `work_order_numbering`)                                     AS seeded_numbering,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'assets')                      AS t_assets,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'helpdesk_tickets')            AS t_tickets,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects')                    AS t_projects,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_orders')                AS t_sales_orders,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vendors')                     AS t_vendors,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance')           AS t_asset_maintenance,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_timesheets')          AS t_project_timesheets
