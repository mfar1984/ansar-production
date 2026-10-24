-- ============================================================================================
-- WORK ORDER CREW - ONE table, NO trigger, NO new permission
--
-- Run:  node scripts/run-sql.js database/work_order_crew.sql
--
-- IDEMPOTENT. Run it twice and the second run changes nothing. Production applies a schema
-- change with `git pull` and a hand, and a hand runs things twice.
--
-- Statement separator is a `-- >>>` line, NOT a semicolon: scripts/run-sql.js splits on that
-- marker so a statement carrying internal semicolons travels as one block.
--
-- ============================================================================================
-- WHAT THIS FIXES, MEASURED
-- ============================================================================================
--
-- `work_orders.assignee_employee_id` is SINGULAR. A 115-asset preventive round - which exists on
-- this database today - is not one person's work, so there was nowhere to record the other people
-- who did it.
--
-- The only place several people were ever recorded was `asset_maintenance.performed_by`, which is
-- `VARCHAR(200)` commented 'our staff or the vendor' - a TYPED NAME. The maintenance screen's own
-- metric is `COUNT(DISTINCT m.performed_by) AS engineers`, so `AZAHARI`, `Azahari` and `AZAHARI `
-- counted as three engineers, nobody could be notified, and no hours could be attributed.
--
-- This table is the register of WHO WAS ON THE JOB. The close path then composes `performed_by`
-- from `employees.full_name` instead of from whatever was typed, which makes that existing metric
-- answer correctly without touching the shipped table.
--
-- ============================================================================================
-- ONE LEAD, MANY STAFF - AND THERE IS NO `role` COLUMN
-- ============================================================================================
--
-- `work_orders.assignee_employee_id` IS the Lead. It already exists, it is already singular, and
-- the register's `UNASSIGNED` predicate already reads it. This table holds the OTHER staff who do
-- the work.
--
-- `project_participants` in `database/project_management_chat.sql` is the house precedent and it
-- carries `role VARCHAR(80)`, `party_type ENUM('employee','client')` and `client_user_id`. NONE of
-- those three is copied here, and each omission is a decision rather than an oversight:
--
--   `role`           - there is exactly ONE possible value, "crew". A column with one possible
--                      value is a column that lies about being configurable. The Lead is the work
--                      order's own column; everybody in here is crew.
--   `party_type`     - no second kind of party exists to discriminate.
--   `client_user_id` - A CLIENT IS NOT CREW. A client does not get dispatched to a site and does
--                      not tick a checklist. Do not add either column back for symmetry with
--                      `project_participants`: that table is a CHAT ROOM, where a client genuinely
--                      is a participant, and this one is a WORK ASSIGNMENT.
--
-- ============================================================================================
-- NO FOREIGN KEY ON `employee_id`, AND THE REASON IS THE HOUSE REASON
-- ============================================================================================
--
-- `work_orders.assignee_employee_id`'s own DDL comment states it, and this matches that choice
-- word for word rather than inventing a second rule: no foreign key, following
-- `project_tasks.assignee_employee_id`, `project_risks.owner_employee_id` and
-- `project_ncrs.owner_employee_id`. A resigned employee changes STATUS, never disappears - so
-- there is no referential action to choose, and a job finished last year keeps naming the person
-- who did it.
--
-- `work_order_id` DOES carry one, ON DELETE CASCADE, exactly like `fk_woi_wo`: the crew of a
-- deleted work order is not a record of anything.
-- ============================================================================================

CREATE TABLE IF NOT EXISTS `work_order_crew` (
  `id`            INT NOT NULL AUTO_INCREMENT,
  `work_order_id` INT NOT NULL,
  -- NO foreign key. See the header: this follows `work_orders.assignee_employee_id`.
  `employee_id`   INT NOT NULL,
  -- The admin username who sent this person, matching `work_orders.created_by`'s width and type.
  -- Sending somebody else to a client site is a decision, so it carries a name.
  `added_by`      VARCHAR(150) DEFAULT NULL,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- One person is on a job once. This is also what makes the crew PUT safe to re-send: a replace
  -- that raced itself would otherwise double every name.
  UNIQUE KEY `uq_woc_member` (`work_order_id`, `employee_id`),
  -- The PHONE's query reads BY EMPLOYEE: "which work orders am I on". Without this index that is a
  -- full scan on every self-service load, and the `EXISTS` subquery in the shared predicate is the
  -- one statement on the employee hot path.
  KEY `idx_woc_employee` (`employee_id`),
  CONSTRAINT `fk_woc_wo` FOREIGN KEY (`work_order_id`)
    REFERENCES `work_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ============================================================================================
-- THE GUARDED ALTERS - one per object, each reading INFORMATION_SCHEMA first
--
-- `CREATE TABLE IF NOT EXISTS` above covers a fresh install. These cover the case the first run
-- cannot: a `work_order_crew` that already exists from an earlier, shorter version of this file.
-- `ADD KEY` and `ADD CONSTRAINT` have no `IF NOT EXISTS` form in MySQL 8.0.45, so each is wrapped
-- in a prepared statement that becomes `DO 0` when the object is already there.
--
-- This is the same shape `work_order_module.sql` sections 10 and 11 use, and it is why BOTH files
-- exit 0 on a second apply.
-- ============================================================================================
SET @woc_idx := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_crew'
     AND INDEX_NAME = 'idx_woc_employee'
)
-- >>>
SET @sql := IF(@woc_idx = 0,
  'ALTER TABLE `work_order_crew` ADD KEY `idx_woc_employee` (`employee_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woc_uq := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_crew'
     AND INDEX_NAME = 'uq_woc_member'
)
-- >>>
SET @sql := IF(@woc_uq = 0,
  'ALTER TABLE `work_order_crew`
     ADD UNIQUE KEY `uq_woc_member` (`work_order_id`, `employee_id`)',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
SET @woc_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND TABLE_NAME = 'work_order_crew'
     AND CONSTRAINT_NAME = 'fk_woc_wo'
)
-- >>>
SET @sql := IF(@woc_fk = 0,
  'ALTER TABLE `work_order_crew`
     ADD CONSTRAINT `fk_woc_wo` FOREIGN KEY (`work_order_id`)
       REFERENCES `work_orders` (`id`) ON DELETE CASCADE',
  'DO 0')
-- >>>
PREPARE s FROM @sql
-- >>>
EXECUTE s
-- >>>
DEALLOCATE PREPARE s
-- >>>
-- ============================================================================================
-- NO PERMISSION ROWS, AND THAT IS THE DECISION
--
-- Adding or removing crew needs `work_orders_edit` for an existing work order and
-- `work_orders_create` for a new one. Both already exist - `work_order_permissions.sql` seeds 28
-- of them - so there is nothing to insert and no role to re-grant.
--
-- The EMPLOYEE side introduces no permission name at all. Its authority is OWNERSHIP: every
-- self-service statement filters on "the Lead or the crew of this work order", read out of the
-- session row. That is the shape every other ESS endpoint already uses, and it is why the Self
-- Service sidebar entries carry no `perm`.
-- ============================================================================================
-- >>>
-- ── VERIFICATION. Printed by scripts/run-sql.js, so a reader sees the shape that resulted. ──
--
-- Expected: tbl 1, uq_cols 2, idx_employee 1, fk_cascade 1, employee_fk 0, role_col 0,
--           party_col 0, client_col 0, triggers 0, crew_perms 0.
--
-- `uq_cols` is TWO, not one, and that is the point of reading it from `STATISTICS`: that view
-- holds one row PER COLUMN of an index, so a two-column unique key reports 2. A check expecting 1
-- would fail on a correct schema, and a check written as `> 0` would pass on a unique key that had
-- silently lost its second column - which is the mistake that would let one person be added to one
-- job twice.
--
-- `employee_fk 0`, `role_col 0`, `party_col 0` and `client_col 0` are ABSENCES asserted on
-- purpose. Each is a decision argued in the header, and a zero here is what makes it checkable
-- rather than a comment somebody reads past.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew')              AS tbl,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND INDEX_NAME = 'uq_woc_member')                                              AS uq_cols,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND INDEX_NAME = 'idx_woc_employee')                                           AS idx_employee,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_woc_wo'
      AND DELETE_RULE = 'CASCADE')                                                   AS fk_cascade,
  (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND COLUMN_NAME = 'employee_id' AND REFERENCED_TABLE_NAME IS NOT NULL)         AS employee_fk,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND COLUMN_NAME = 'role')                                                      AS role_col,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND COLUMN_NAME = 'party_type')                                                AS party_col,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'work_order_crew'
      AND COLUMN_NAME = 'client_user_id')                                            AS client_col,
  (SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE() AND EVENT_OBJECT_TABLE = 'work_order_crew')    AS triggers,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` LIKE 'work_order_crew%')        AS crew_perms,
  (SELECT COUNT(*) FROM `work_order_crew`)                                           AS rows_now
