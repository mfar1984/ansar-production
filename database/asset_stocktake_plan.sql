-- ============================================================
-- STOCK TAKE: a title, somebody responsible, and a planned window
--
-- WHAT WAS MISSING, AND WHY IT IS THREE COLUMNS RATHER THAN A NEW FEATURE
--
-- A named, assigned, dated "item checklist" was asked for: a heading somebody types, the person who
-- has to walk the store, and the period they have to do it in. The obvious reading is a new Work
-- Order table. It was rejected, and the reason is worth keeping because it will be re-argued.
--
-- `asset_stocktakes` and `asset_stocktake_lines` ALREADY carry a session with a reference, one line
-- per asset, a snapshot of what the register expected, found / not_found / found_elsewhere per line,
-- `counted_by` and `counted_at` per line, a counted-versus-expected progress figure, a discrepancy
-- count, a forward-only lifecycle, a printable sheet, a one-unclosed-session-per-scope guard, and a
-- separate permission for the reconcile step that writes `lost` onto real equipment.
--
-- A second table would duplicate every one of those. Two systems would then both tick assets off a
-- list and both compute progress, and somebody would eventually ask why the stock take says `found`
-- while the work order says unchecked. There is no answer to that question — both are right inside
-- their own system — and only one of them writes anything onto an asset.
--
-- So what was actually missing is exactly three facts, and they are columns:
--
--   `title`       a heading a human types. `ref_no` is machine-generated and stays the IDENTITY;
--                 the title is a LABEL. Nullable, because every existing session has none and the
--                 screen falls back to the reference.
--   `assigned_to` the person who must do it. `opened_by` is whoever clicked the button — an audit
--                 trail, not an assignment, and it cannot express "Rashid is doing the Level 3
--                 count" at all.
--   `starts_on` /
--   `due_on`      the planned window.
--
-- PLANNED DATES ARE NOT THE SAME COLUMNS AS `opened_on` / `closed_on`
--
-- `opened_on` and `closed_on` are STAMPED BY THE SERVER at the moment each thing happens. They are
-- history and cannot be chosen. `starts_on` and `due_on` are CHOSEN BY A HUMAN before anything
-- happens. They are a plan. Overwriting the first pair with the second would destroy the record of
-- when a count actually ran, which is the only figure an audit can use.
--
-- `starts_on` DELIBERATELY DOES NOT BLOCK COUNTING
--
-- A count that happens a day early is still a count, and refusing it would invent a rule nobody
-- asked for while making the store keeper wait for a date. The window is a plan; the screen shows
-- whether reality matched it. Only `due_on` drives anything, and only a signal: not closed and
-- `due_on < CURDATE()` reads as overdue.
--
-- THE CHECK CONSTRAINT, AND THE MySQL TRAP IT AVOIDS
--
-- `CHECK (due_on >= starts_on)` mirrors `ck_acheck_dates` on `asset_checkouts`, which the same schema
-- already uses for exactly this. Both columns are nullable, so with either side unset the expression
-- is NULL and MySQL treats it as satisfied — the constraint only fires when a human has supplied both
-- and got them the wrong way round.
--
-- This file has been checked against the failure this schema hit TWICE before —
-- ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN, once on `asset_site_documents` and once on
-- `asset_checkouts`. MySQL refuses a CHECK that names a column a foreign key writes through a
-- referential action. Here the CHECK names `starts_on` and `due_on`, and the only SET NULL is on
-- `assigned_to`. Different columns, so the constraint is accepted. That is why the dates are checked
-- and the assignee is not.
--
-- `assigned_to` IS SIGNED `INT`, NOT `INT UNSIGNED`
--
-- `employees.id` is SIGNED, which `asset_checkouts.employee_id` already records in its own column
-- comment. A FK from an UNSIGNED column to a SIGNED one is a type mismatch and MySQL refuses to
-- create it, with an error that names neither column helpfully.
--
-- ON DELETE SET NULL, never CASCADE: an employee leaving must not delete the count they performed.
-- The session and its evidence outlive the assignment.
--
-- Idempotent, in four independently guarded steps — columns, foreign key, check constraint, and the
-- permission check — so a half-applied run can be completed by running it again. Statement separator:
-- a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_stocktake_plan.sql
-- ============================================================

-- >>>
SET @st_title := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
     AND COLUMN_NAME = 'title'
)

-- >>>
-- Two indexes, and each one serves a query this change creates.
--
-- `idx_astake_due` leads on `due_on` rather than `state`: the overdue predicate is
-- `state <> 'closed' AND due_on < CURDATE()`, neither side an equality, so the optimiser has to
-- range-scan one and filter the other. `due_on` is the more selective of the two — `state` has four
-- values and most rows sit in one of them.
--
-- `idx_astake_assignee` serves "the counts assigned to me", which is the store keeper's own list.
SET @st_ddl := IF(
  @st_title = 0,
  'ALTER TABLE `asset_stocktakes`
     ADD COLUMN `title` VARCHAR(200) DEFAULT NULL
       COMMENT ''A heading a human types. ref_no stays the identity; this is a label''
       AFTER `ref_no`,
     ADD COLUMN `assigned_to` INT DEFAULT NULL
       COMMENT ''employees.id - SIGNED. Who must walk the store, not who clicked the button''
       AFTER `scope_location`,
     ADD COLUMN `starts_on` DATE DEFAULT NULL
       COMMENT ''PLANNED start, chosen. Does not block counting. opened_on is the stamped fact''
       AFTER `opened_on`,
     ADD COLUMN `due_on` DATE DEFAULT NULL
       COMMENT ''PLANNED finish, chosen. Drives the overdue signal only''
       AFTER `starts_on`,
     ADD KEY `idx_astake_due` (`due_on`, `state`),
     ADD KEY `idx_astake_assignee` (`assigned_to`, `state`)',
  'DO 0'
)

-- >>>
PREPARE st_stmt FROM @st_ddl

-- >>>
EXECUTE st_stmt

-- >>>
DEALLOCATE PREPARE st_stmt

-- >>>
-- ── The foreign key, guarded separately ──
--
-- Its own guard rather than being folded into the ALTER above, so a run that added the columns and
-- then failed can be completed by running the file again. A guard on the COLUMN would report the
-- work as done while the constraint was still missing.
SET @st_fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
     AND CONSTRAINT_NAME = 'fk_astake_assignee'
)

-- >>>
SET @st_fk_ddl := IF(
  @st_fk = 0,
  'ALTER TABLE `asset_stocktakes`
     ADD CONSTRAINT `fk_astake_assignee` FOREIGN KEY (`assigned_to`)
       REFERENCES `employees` (`id`) ON DELETE SET NULL',
  'DO 0'
)

-- >>>
PREPARE st_fk_stmt FROM @st_fk_ddl

-- >>>
EXECUTE st_fk_stmt

-- >>>
DEALLOCATE PREPARE st_fk_stmt

-- >>>
-- ── The date check, guarded separately for the same reason ──
SET @st_ck := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
     AND CONSTRAINT_NAME = 'ck_astake_plan' AND CONSTRAINT_TYPE = 'CHECK'
)

-- >>>
SET @st_ck_ddl := IF(
  @st_ck = 0,
  'ALTER TABLE `asset_stocktakes`
     ADD CONSTRAINT `ck_astake_plan` CHECK (`due_on` >= `starts_on`)',
  'DO 0'
)

-- >>>
PREPARE st_ck_stmt FROM @st_ck_ddl

-- >>>
EXECUTE st_ck_stmt

-- >>>
DEALLOCATE PREPARE st_ck_stmt

-- >>>
-- ── Verification ──
--
-- Four columns, one foreign key, one check constraint. `assigned_to` is reported as a SIGNED `int`
-- rather than `int unsigned`, because that is the one value in this file that MySQL would refuse
-- silently at FK creation time on a database where `employees.id` differs from the one this was
-- written against.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
      AND COLUMN_NAME IN ('title', 'assigned_to', 'starts_on', 'due_on'))   AS columns_present,
  (SELECT COLUMN_TYPE FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
      AND COLUMN_NAME = 'assigned_to')                                      AS assignee_type,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
      AND CONSTRAINT_NAME = 'fk_astake_assignee')                           AS fk_present,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
      AND CONSTRAINT_NAME = 'ck_astake_plan')                               AS date_check_present,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_stocktakes'
      AND INDEX_NAME IN ('idx_astake_due', 'idx_astake_assignee'))          AS index_parts
