-- Declare ROW_FORMAT=DYNAMIC on every table, and take root off the one view.
--
-- WHY
--
-- Importing a dump of this database into cPanel is refused with:
--
--   #1118 - Row size too large (> 8126). Changing some columns to TEXT or BLOB
--           or using ROW_FORMAT=DYNAMIC may help.
--
-- Nothing is wrong with the data. `innodb_default_row_format` differs between the two servers:
-- DYNAMIC here, COMPACT there. Under COMPACT the first 768 bytes of every long column stay
-- inside the row, and 24 of these tables are then wider than InnoDB's 8126-byte limit -
-- `system_settings` worst at about 39,972 bytes over 96 columns.
--
-- Every table is already stored Dynamic here, and not one of them SAID so. `SHOW CREATE TABLE`
-- prints ROW_FORMAT only when it was set explicitly, so every export - phpMyAdmin's and the
-- application's own backup - inherited whatever default the importing server had. Declaring it
-- makes the option part of the table definition, so it travels with every dump from now on
-- instead of being repaired afterwards.
--
-- ── WHY THIS IS NOW A LOOP AND NOT 172 WRITTEN-OUT STATEMENTS ──
--
-- It used to be one `ALTER TABLE` per line, 172 of them, typed out from a listing of the
-- database as it stood when the file was written. That list went stale, and the way it went
-- stale is the reason this is worth recording:
--
--   * the database has 217 base tables now
--   * 198 declared their row format, 19 did NOT
--   * the 19 are exactly the tables added AFTER the list was typed: the project-management
--     set, the mileage set, asset_disposals, asset_locations, helpdesk_categories
--
-- A hardcoded list cannot report that it is incomplete. Running the file reported "173
-- statements, 0 failed" while leaving 19 tables silent, and `tests/sql/sql-portability.test.js`
-- was the only thing that noticed - which means every migration that adds a table also had to
-- remember to come back and edit this file, and none of them did.
--
-- So the set is derived from `information_schema` at run time. A table added tomorrow is
-- covered without this file being touched.
--
-- `CREATE_OPTIONS NOT LIKE '%row_format=%'` is the filter, not `NOT LIKE '%DYNAMIC%'`: a table
-- that explicitly chose COMPRESSED made a decision, and silently rebuilding it as DYNAMIC would
-- overrule it. That matches `portableTableDdl`, which leaves a statement that states its own row
-- format alone. None currently do; the filter is there so that staying true costs nothing.
--
-- The candidate names are snapshotted into a temporary table BEFORE the loop runs. Fetching from
-- a cursor over `information_schema.TABLES` while `ALTER TABLE` changes the very rows it reads is
-- not a guarantee worth relying on.
--
-- ALTER TABLE ... ROW_FORMAT=DYNAMIC rebuilds each table. That is a copy of the data, not a
-- change to it: no column, index or value is touched. tests/sql/sql-portability.test.js checks
-- the result, and deploy/export-production-sql.js compares every row count against the database
-- before it writes a file.
--
-- The view is recreated without `DEFINER=root@localhost`. Restoring a view owned by another
-- account needs SUPER, which shared hosting does not grant, and a definer that does not exist on
-- the target server makes every query against it fail with error 1449.
--
-- Re-runnable, and now genuinely cheap on a second run: the filter finds nothing to do, so no
-- table is rebuilt at all. The old form rebuilt all 172 every time it was run.
--
-- Statements are separated by `-- >>>` for scripts/run-sql.js.
--
--   node scripts/run-sql.js database/set_row_format_dynamic.sql

-- >>>
DROP PROCEDURE IF EXISTS `declare_row_format`

-- >>>
CREATE PROCEDURE `declare_row_format`()
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_name VARCHAR(64);
  DECLARE cur CURSOR FOR SELECT `t` FROM `tmp_row_format_todo` ORDER BY `t`;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  /*
   * The snapshot. A TEMPORARY table is dropped with the connection, so a failed run leaves
   * nothing behind for the next one to trip over.
   */
  DROP TEMPORARY TABLE IF EXISTS `tmp_row_format_todo`;
  CREATE TEMPORARY TABLE `tmp_row_format_todo` (`t` VARCHAR(64) NOT NULL PRIMARY KEY);

  INSERT INTO `tmp_row_format_todo` (`t`)
  SELECT `TABLE_NAME`
    FROM information_schema.TABLES
   WHERE `TABLE_SCHEMA` = DATABASE()
     AND `TABLE_TYPE` = 'BASE TABLE'
     AND `ENGINE` = 'InnoDB'
     AND (`CREATE_OPTIONS` IS NULL OR `CREATE_OPTIONS` NOT LIKE '%row_format=%');

  OPEN cur;
  each_table: LOOP
    FETCH cur INTO v_name;
    IF v_done = 1 THEN
      LEAVE each_table;
    END IF;
    SET @ddl := CONCAT('ALTER TABLE `', v_name, '` ROW_FORMAT=DYNAMIC');
    PREPARE st FROM @ddl;
    EXECUTE st;
    DEALLOCATE PREPARE st;
  END LOOP;
  CLOSE cur;

  DROP TEMPORARY TABLE IF EXISTS `tmp_row_format_todo`;
END

-- >>>
CALL `declare_row_format`()

-- >>>
DROP PROCEDURE IF EXISTS `declare_row_format`

-- >>>
-- ── Report what is left, so "0 failed" cannot be mistaken for "all done" ──
--
-- `silent` MUST be 0. This is the line the old hardcoded version could not print, and the whole
-- reason 19 tables stayed undeclared through a run that reported success.
SELECT COUNT(*)                                                             AS `base_tables`,
       SUM(`CREATE_OPTIONS` LIKE '%row_format=DYNAMIC%')                    AS `declared_dynamic`,
       SUM(`CREATE_OPTIONS` IS NULL OR `CREATE_OPTIONS` NOT LIKE '%row_format=%') AS `silent`
  FROM information_schema.TABLES
 WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_TYPE` = 'BASE TABLE' AND `ENGINE` = 'InnoDB'

-- >>>
-- View `payroll_summary`, previously owned by root@localhost with SQL SECURITY DEFINER.
CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW `payroll_summary` AS select `pr`.`id` AS `id`,`pr`.`payslip_number` AS `payslip_number`,`pp`.`period_name` AS `period_name`,`pp`.`period_month` AS `period_month`,`pp`.`period_year` AS `period_year`,`pp`.`payment_date` AS `payment_date`,`e`.`full_name` AS `employee_name`,`e`.`employee_id` AS `employee_code`,`d`.`name` AS `department_name`,`pr`.`basic_salary` AS `basic_salary`,`pr`.`gross_salary` AS `gross_salary`,`pr`.`total_deductions` AS `total_deductions`,`pr`.`net_salary` AS `net_salary`,`pr`.`status` AS `status`,`pr`.`payment_date` AS `actual_payment_date`,`pr`.`created_at` AS `created_at` from (((`payroll_records` `pr` join `payroll_periods` `pp` on((`pr`.`payroll_period_id` = `pp`.`id`))) join `employees` `e` on((`pr`.`employee_id` = `e`.`id`))) left join `departments` `d` on((`e`.`department_id` = `d`.`id`)));
