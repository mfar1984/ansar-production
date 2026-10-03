-- ═══════════════════════════════════════════════════════════════════════════════
-- ACCOUNTING — SALESPERSON AS MASTER DATA
--
-- WHAT IT WAS
--
-- `salesperson` was a free-text varchar(255) on eight sales tables and on `customers`, defaulting to
-- whatever the customer's own text said. There was no salespersons table at all. So "how much has
-- Aisyah sold" had no answer: "Aisyah", "aisyah", "Aisyah B." and "AB" were four people to the
-- database, and a login could not be tied to any of them.
--
-- WHAT IT BECOMES
--
--   salespersons              the master: code, name, location, active, and an OPTIONAL login
--   <table>.salesperson_id    the link, on all nine tables
--   <table>.salesperson       KEPT, as the printed snapshot — the same rule as customer_name beside
--                             customer_id. A document shows the name it was raised under even after
--                             the master is renamed, and the printed sheet already reads this column.
--
-- WHY THE LOGIN IS OPTIONAL (admin_id NULL)
--
-- A salesperson is a person the company sells through, not necessarily somebody who signs in. When one
-- leaves, their login is disabled and their sales history must stay attributed to them. A salesperson
-- that WAS a login row would vanish from history the day the login went. ON DELETE SET NULL on the
-- login keeps the salesperson and drops only the link.
--
-- THE LOGIN IS A ROW IN `admins`, NOT IN `users`
--
-- `admins` holds every account that signs in to this system — `/api/auth/login` reads its username and
-- password_hash, and Settings › Users lists its Administrator and Staff rows. `users` is a different,
-- EMPTY table that nothing signs in through. A first draft of this file pointed the link at `users`,
-- so no salesperson could ever have been linked to a real login. The name `admin_id` follows
-- `admin_roles.admin_id`, the existing column for the same reference.
--
-- WHY salesperson_id IS ON DELETE RESTRICT
--
-- Deleting a salesperson who has documents would orphan the attribution. The endpoint refuses first and
-- says why; RESTRICT is the database refusing too, for anything that bypasses the endpoint. A salesperson
-- who has left is set inactive, which keeps the history and removes them from the dropdown.
--
-- THE BACKFILL
--
-- Every distinct non-empty free-text name already stored becomes a salesperson with a generated code,
-- and the rows carrying that text are linked to it. On a database where nothing was ever typed this
-- inserts and updates nothing. Names are matched after TRIM and are otherwise exact, so variants of one
-- person become separate records — merging them is a person's decision, not a migration's.
--
-- PERMISSIONS, GRANTED BY DERIVATION
--
--   accounting_salespersons   view/create/edit/delete — the Accounting Settings screen. Granted to each
--                             role holding the same action on accounting_payment_terms, its sibling
--                             master-data list.
--   users-salesperson         view/edit — the Sales Person tab in User Management, which links a login.
--                             Granted to each role holding the same action on users-staff.
--
-- IDEMPOTENT. Every ALTER is behind an information_schema guard and every INSERT is guarded. Columns and
-- foreign keys are separate blocks, so a run that fails between them can be resumed.
--
-- Run:  node scripts/run-sql.js database/salespersons.sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- >>>
-- ── 1. The master ──
--
-- COLLATE is stated, not inherited: the database default is utf8mb4_0900_ai_ci, and every `salesperson`
-- column the backfill compares `name` against is utf8mb4_unicode_ci. Inheriting would make the join an
-- "Illegal mix of collations". ROW_FORMAT is stated so a dump carries it (database/set_row_format_dynamic.sql).
CREATE TABLE IF NOT EXISTS `salespersons` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(30) NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `description` VARCHAR(255) NULL DEFAULT NULL,
  `location` VARCHAR(255) NULL DEFAULT NULL,
  `email` VARCHAR(150) NULL DEFAULT NULL,
  `phone` VARCHAR(40) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `admin_id` INT NULL DEFAULT NULL,
  `created_by` VARCHAR(150) NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_salespersons_code` (`code`),
  UNIQUE KEY `uq_salespersons_admin` (`admin_id`),
  KEY `idx_salespersons_active` (`is_active`),
  CONSTRAINT `fk_salespersons_admin` FOREIGN KEY (`admin_id`)
    REFERENCES `admins` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
-- >>>
-- ── 2.1 customers: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'customers' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `customers`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_cust_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.1 customers: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_cust_salesperson') = 0,
  'ALTER TABLE `customers`
     ADD CONSTRAINT `fk_cust_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.2 sales_quotations: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_quotations' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `sales_quotations`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_sq_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.2 sales_quotations: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_sq_salesperson') = 0,
  'ALTER TABLE `sales_quotations`
     ADD CONSTRAINT `fk_sq_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.3 sales_orders: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_orders' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `sales_orders`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_so_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.3 sales_orders: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_so_salesperson') = 0,
  'ALTER TABLE `sales_orders`
     ADD CONSTRAINT `fk_so_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.4 delivery_orders: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `delivery_orders`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_do_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.4 delivery_orders: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_do_salesperson') = 0,
  'ALTER TABLE `delivery_orders`
     ADD CONSTRAINT `fk_do_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.5 proforma_invoices: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'proforma_invoices' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `proforma_invoices`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_pi_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.5 proforma_invoices: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_pi_salesperson') = 0,
  'ALTER TABLE `proforma_invoices`
     ADD CONSTRAINT `fk_pi_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.6 sales_invoices: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_invoices' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `sales_invoices`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_si_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.6 sales_invoices: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_si_salesperson') = 0,
  'ALTER TABLE `sales_invoices`
     ADD CONSTRAINT `fk_si_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.7 sales_credit_notes: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_credit_notes' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `sales_credit_notes`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_scn_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.7 sales_credit_notes: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_scn_salesperson') = 0,
  'ALTER TABLE `sales_credit_notes`
     ADD CONSTRAINT `fk_scn_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.8 sales_debit_notes: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sales_debit_notes' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `sales_debit_notes`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_sdn_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.8 sales_debit_notes: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_sdn_salesperson') = 0,
  'ALTER TABLE `sales_debit_notes`
     ADD CONSTRAINT `fk_sdn_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.9 cash_sales: the column ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cash_sales' AND COLUMN_NAME = 'salesperson_id') = 0,
  'ALTER TABLE `cash_sales`
     ADD COLUMN `salesperson_id` INT UNSIGNED NULL DEFAULT NULL AFTER `salesperson`,
     ADD KEY `idx_cs_salesperson` (`salesperson_id`)',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 2.9 cash_sales: the foreign key, in its own block so a failed run can resume ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_cs_salesperson') = 0,
  'ALTER TABLE `cash_sales`
     ADD CONSTRAINT `fk_cs_salesperson` FOREIGN KEY (`salesperson_id`)
     REFERENCES `salespersons` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0'
)
-- >>>
PREPARE stmt FROM @sql
-- >>>
EXECUTE stmt
-- >>>
DEALLOCATE PREPARE stmt
-- >>>
-- ── 3. Backfill: every distinct free-text name becomes a salesperson ──
--
-- A temporary code first, because the real one is built from the row's own id, which does not exist until
-- the row does. LEFT(MD5(...), 26) keeps 'TMP-' + hash inside varchar(30).
INSERT INTO `salespersons` (`code`, `name`, `created_by`)
SELECT CONCAT('TMP-', LEFT(MD5(n.name), 26)), n.name, 'migration'
  FROM (
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `customers` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `sales_quotations` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `sales_orders` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `delivery_orders` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `proforma_invoices` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `sales_invoices` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `sales_credit_notes` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `sales_debit_notes` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
  UNION
        SELECT DISTINCT TRIM(`salesperson`) AS name FROM `cash_sales` WHERE TRIM(COALESCE(`salesperson`, '')) <> ''
       ) n
 WHERE NOT EXISTS (SELECT 1 FROM `salespersons` s WHERE s.`name` = n.name)
   AND CHAR_LENGTH(n.name) <= 150
-- >>>
-- The real code: SP0001, SP0002, ... from the id. Only the temporary ones are touched.
UPDATE `salespersons`
   SET `code` = CONCAT('SP', LPAD(`id`, 4, '0'))
 WHERE `code` LIKE 'TMP-%'
-- >>>
-- ── 4. Link customers to the master, by its trimmed text ──
UPDATE `customers` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link sales_quotations to the master, by its trimmed text ──
UPDATE `sales_quotations` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link sales_orders to the master, by its trimmed text ──
UPDATE `sales_orders` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link delivery_orders to the master, by its trimmed text ──
UPDATE `delivery_orders` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link proforma_invoices to the master, by its trimmed text ──
UPDATE `proforma_invoices` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link sales_invoices to the master, by its trimmed text ──
UPDATE `sales_invoices` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link sales_credit_notes to the master, by its trimmed text ──
UPDATE `sales_credit_notes` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link sales_debit_notes to the master, by its trimmed text ──
UPDATE `sales_debit_notes` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 4. Link cash_sales to the master, by its trimmed text ──
UPDATE `cash_sales` x
  JOIN `salespersons` s ON s.`name` = TRIM(x.`salesperson`)
   SET x.`salesperson_id` = s.`id`
 WHERE x.`salesperson_id` IS NULL
   AND TRIM(COALESCE(x.`salesperson`, '')) <> ''
-- >>>
-- ── 5. accounting_salespersons: the permission rows, category read from accounting_payment_terms ──
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`)
SELECT 'accounting_salespersons', a.action, CONCAT('accounting_salespersons_', a.action),
       CONCAT(UPPER(LEFT(a.action, 1)), SUBSTRING(a.action, 2), ' salespersons'),
       (SELECT p.`category` FROM `permissions` p WHERE p.`module` = 'accounting_payment_terms' LIMIT 1)
  FROM (SELECT 'view' AS action UNION SELECT 'create' AS action UNION SELECT 'edit' AS action UNION SELECT 'delete' AS action) a
 WHERE EXISTS (SELECT 1 FROM `permissions` p WHERE p.`module` = 'accounting_payment_terms')
-- >>>
-- ── 5. accounting_salespersons: granted to every role holding the SAME action on accounting_payment_terms ──
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT rp.`role_id`, np.`id`
  FROM `role_permissions` rp
  JOIN `permissions` sp ON sp.`id` = rp.`permission_id` AND sp.`module` = 'accounting_payment_terms'
  JOIN `permissions` np ON np.`module` = 'accounting_salespersons' AND np.`action` = sp.`action`
-- >>>
-- ── 5. users-salesperson: the permission rows, category read from users-staff ──
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`)
SELECT 'users-salesperson', a.action, CONCAT('users-salesperson_', a.action),
       CONCAT(UPPER(LEFT(a.action, 1)), SUBSTRING(a.action, 2), ' salesperson logins'),
       (SELECT p.`category` FROM `permissions` p WHERE p.`module` = 'users-staff' LIMIT 1)
  FROM (SELECT 'view' AS action UNION SELECT 'edit' AS action) a
 WHERE EXISTS (SELECT 1 FROM `permissions` p WHERE p.`module` = 'users-staff')
-- >>>
-- ── 5. users-salesperson: granted to every role holding the SAME action on users-staff ──
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT rp.`role_id`, np.`id`
  FROM `role_permissions` rp
  JOIN `permissions` sp ON sp.`id` = rp.`permission_id` AND sp.`module` = 'users-staff'
  JOIN `permissions` np ON np.`module` = 'users-salesperson' AND np.`action` = sp.`action`
-- >>>
-- ── 6. Verification ──
--
-- Expect: salespersons_table 1, login_fk 1, linked_columns 9, fks 9, and for each module its action count
-- with grants > 0. A grants figure of 0 means the sidebar entry renders for nobody, including Super Admin.
-- login_fk 0 means the login link points somewhere other than `admins`, where every account signs in.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'salespersons') AS salespersons_table,
  (SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'salespersons' AND COLUMN_NAME = 'admin_id'
      AND REFERENCED_TABLE_NAME = 'admins') AS login_fk,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'salesperson_id'
      AND TABLE_NAME IN ('customers', 'sales_quotations', 'sales_orders', 'delivery_orders', 'proforma_invoices', 'sales_invoices', 'sales_credit_notes', 'sales_debit_notes', 'cash_sales')) AS linked_columns,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME LIKE 'fk\_%\_salesperson') AS fks,
  (SELECT COUNT(*) FROM `salespersons`) AS salespersons,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'accounting_salespersons') AS sp_actions,
  (SELECT COUNT(*) FROM `role_permissions` rp JOIN `permissions` p ON p.`id` = rp.`permission_id`
    WHERE p.`module` = 'accounting_salespersons') AS sp_grants,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'users-salesperson') AS login_actions,
  (SELECT COUNT(*) FROM `role_permissions` rp JOIN `permissions` p ON p.`id` = rp.`permission_id`
    WHERE p.`module` = 'users-salesperson') AS login_grants
