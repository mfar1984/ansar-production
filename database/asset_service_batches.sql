-- ============================================================
-- SERVICE BATCHES — a round gets a NAME and a set of FILES
--
-- WHAT THIS IS FOR
--
-- Maintenance & Repairs lists one row per ROUND. Until now a round was DERIVED from
-- `(kind, service_date, client_id)` and nothing was stored: that was the right answer while there was
-- nothing to store, and it stops being the right answer the moment a round needs a TITLE somebody
-- typed and a set of ATTACHED FILES.
--
-- A file cannot hang on a tuple. Correcting a round's date rewrites `service_date` on every record —
-- so a file keyed on the old tuple would be orphaned by an edit the reader thinks of as a typo fix,
-- and there would be nothing left pointing at it to delete it with.
--
-- So the round becomes a ROW. `asset_service_batches` holds the title, `asset_service_batch_files`
-- holds the attachments, and `asset_maintenance.batch_id` says which round a record belongs to. The
-- grouping is then a foreign key rather than three columns that an UPDATE can move.
--
-- ── THE TITLE IS DELIBERATELY NOT UNIQUE ──
--
-- Asked for directly: "jadi tajuk ini boleh guna nama yang sama". Recording 115 units is several
-- sittings — tick some, set the date, attach the paperwork, save; come back and tick the rest under
-- the same title. Each sitting is its own batch with its own files, and the repeated title is how the
-- reader sees they belong together.
--
-- There is therefore NO unique index on `title`, and that is a decision rather than an omission. A
-- unique index would refuse the second sitting, which is the exact workflow this table exists for.
-- The index that IS here is a plain one, for finding every batch under a name.
--
-- ── WHAT HAPPENED TO `#N` ──
--
-- The list used to number rounds itself with `ROW_NUMBER()` — `Preventive #2`. That is gone, because
-- the title supersedes it: two answers to "which round is this" would eventually disagree, and the
-- one the reader typed wins over the one the database inferred.
--
-- The BACKFILL below is what makes that safe. Every existing round is named
-- `<client> — <Kind> <N>` with N computed exactly the way the old ordinal was, so nothing loses its
-- number — it becomes text somebody can edit instead of a figure they cannot.
--
-- ── ON DELETE CASCADE, BOTH WAYS, AND THE FOOT-GUN THAT COMES WITH IT ──
--
-- `asset_maintenance.batch_id` and `asset_service_batch_files.batch_id` both CASCADE from the batch.
-- The batch is the PARENT of both — a batch with no records is meaningless and a record pointing at a
-- batch that is gone breaks the list — so the invariant is structural rather than something an
-- endpoint has to remember.
--
-- The cost, stated plainly: deleting a row from `asset_service_batches` by hand takes its service
-- records with it. That is exactly what the Delete Round button is for and it goes through the
-- endpoint, which counts first, removes the FILES FROM DISK first, and writes an audit entry. A
-- CASCADE knows nothing about disk, so a hand-deleted batch would leave its attachments orphaned
-- there — the rows would be gone and the bytes would not.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_service_batches.sql
-- ============================================================

-- >>>
-- ── 1. The batch ──
-- No `kind`, no `service_date`, no `client_id`. All three live on the RECORDS and are derived for
-- display, because they are properties of the work and the round edit can change them. Duplicating
-- them here would be two places for one fact and nothing keeping them in step.
CREATE TABLE IF NOT EXISTS `asset_service_batches` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- 200 to match `asset_documents.title`, which is the other user-typed title in this module.
  `title`       VARCHAR(200) NOT NULL,
  `recorded_by` VARCHAR(150) DEFAULT NULL,
  `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  -- PLAIN, not UNIQUE. See the note above: the same title across several sittings is the workflow.
  KEY `idx_asb_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- Row format for a table an earlier run created without it. `CREATE TABLE IF NOT EXISTS` is skipped
-- where the table exists, so the clause above never reaches it; `CREATE_OPTIONS` records the
-- DECLARATION, which is what a dump carries.
SET @rf1 := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_service_batches'
     AND CREATE_OPTIONS LIKE '%row_format%'
)

-- >>>
SET @rf1sql := IF(@rf1 = 0,
  'ALTER TABLE `asset_service_batches` ROW_FORMAT=DYNAMIC',
  'SELECT ''asset_service_batches already declares its row format'' AS note')

-- >>>
PREPARE rf1stmt FROM @rf1sql

-- >>>
EXECUTE rf1stmt

-- >>>
DEALLOCATE PREPARE rf1stmt

-- >>>
-- ── 2. The attachments ──
-- Shaped on `asset_documents`, which is the module's other file table, so the endpoint, the gated
-- file reader and the delete path all behave the same way. `file_path` is relative to the PRIVATE
-- root: a service report carries prices and a client's site layout, so none of this may sit behind a
-- guessable URL that Next serves to anyone who has it.
CREATE TABLE IF NOT EXISTS `asset_service_batch_files` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `batch_id`    INT UNSIGNED NOT NULL,
  `file_path`   VARCHAR(400) NOT NULL COMMENT 'relative to the PRIVATE uploads root',
  `file_name`   VARCHAR(255) NOT NULL COMMENT 'as supplied by the browser, display only',
  `mime_type`   VARCHAR(120) DEFAULT NULL,
  `file_size`   INT UNSIGNED DEFAULT NULL,
  `uploaded_by` VARCHAR(150) DEFAULT NULL,
  `uploaded_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_asbf_batch` (`batch_id`),
  -- The gated file endpoint and the delete path both look a file up BY PATH, so this is the index
  -- that matters as much as the batch one.
  KEY `idx_asbf_path` (`file_path`),
  CONSTRAINT `fk_asbf_batch` FOREIGN KEY (`batch_id`)
    REFERENCES `asset_service_batches` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
SET @rf2 := (
  SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_service_batch_files'
     AND CREATE_OPTIONS LIKE '%row_format%'
)

-- >>>
SET @rf2sql := IF(@rf2 = 0,
  'ALTER TABLE `asset_service_batch_files` ROW_FORMAT=DYNAMIC',
  'SELECT ''asset_service_batch_files already declares its row format'' AS note')

-- >>>
PREPARE rf2stmt FROM @rf2sql

-- >>>
EXECUTE rf2stmt

-- >>>
DEALLOCATE PREPARE rf2stmt

-- >>>
-- ── 3. The pointer on the record ──
-- NULLABLE, and it stays nullable after the backfill. Making it NOT NULL would be tidier and would
-- mean the next writer of `asset_maintenance` MUST create a batch first — a real constraint to want,
-- and not worth the risk here: a single INSERT that forgot it would fail at run time on a screen
-- somebody is using, rather than being caught by the endpoint that owns the table.
--
-- Guarded on the COLUMN's existence, not on the table's, so a re-run adds nothing.
SET @has_batch := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance'
     AND COLUMN_NAME = 'batch_id'
)

-- >>>
SET @batch_ddl := IF(@has_batch = 0,
  'ALTER TABLE `asset_maintenance`
     ADD COLUMN `batch_id` INT UNSIGNED DEFAULT NULL
       COMMENT ''asset_service_batches.id — the round this record belongs to'' AFTER `id`,
     ADD KEY `idx_amaint_batch` (`batch_id`),
     ADD CONSTRAINT `fk_amaint_batch` FOREIGN KEY (`batch_id`)
       REFERENCES `asset_service_batches` (`id`) ON DELETE CASCADE',
  'SELECT ''asset_maintenance.batch_id already exists'' AS note')

-- >>>
PREPARE batch_stmt FROM @batch_ddl

-- >>>
EXECUTE batch_stmt

-- >>>
DEALLOCATE PREPARE batch_stmt

-- >>>
-- ── 4. The backfill ──
--
-- Every existing service record gets a batch, so the list has nothing to fall back on and no second
-- code path for "records with no round". One batch per `(kind, service_date, client_id)` — the exact
-- key the derived round used — so what was on screen yesterday is what is on screen today.
--
-- WHY A STAGING TABLE AND NOT ONE CLEVER STATEMENT
--
-- The mapping is the problem: the batch ids are only known AFTER the insert, and `title` is the only
-- column that could join them back. Titles are unique across this backfill by construction, but they
-- are deliberately NOT unique in general, so a join on title is safe here and nowhere else. Rather
-- than write a statement whose correctness depends on a property that stops holding the moment a user
-- reuses a name, the mapping is made explicit in a table that is dropped at the end.
--
-- It also means each step below is readable on its own, and a half-run can be inspected.
CREATE TABLE IF NOT EXISTS `_asb_backfill` (
  `kind`         VARCHAR(60)  NOT NULL,
  `service_date` DATE         NOT NULL,
  `client_id`    INT UNSIGNED DEFAULT NULL,
  `title`        VARCHAR(200) NOT NULL,
  `batch_id`     INT UNSIGNED DEFAULT NULL,
  KEY `idx_bf_key` (`kind`, `service_date`),
  KEY `idx_bf_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- Emptied rather than assumed empty, so a re-run after a failure starts clean.
DELETE FROM `_asb_backfill`

-- >>>
-- One row per round that has no batch yet, with the title it will get.
--
-- `ROW_NUMBER() OVER (PARTITION BY client_id, kind ORDER BY service_date ASC)` is the SAME ordinal
-- the screen used to compute, so `KEMAS PAHANG — Preventive 3` is the round that read `Preventive #3`
-- before this migration. Oldest first, so the numbers do not shift.
--
-- `COALESCE(company_name, 'Internal Assets')` — an internal round has no client, and a title starting
-- with an em dash would read as a mistake.
INSERT INTO `_asb_backfill` (`kind`, `service_date`, `client_id`, `title`)
SELECT g.`kind`, g.`service_date`, g.`client_id`,
       CONCAT(COALESCE(cu.`company_name`, 'Internal Assets'), ' — ', g.`kind`, ' ', g.`seq`)
  FROM (
    SELECT x.`kind`, x.`service_date`, x.`client_id`,
           ROW_NUMBER() OVER (PARTITION BY x.`client_id`, x.`kind`
                              ORDER BY x.`service_date` ASC) AS `seq`
      FROM (SELECT DISTINCT m.`kind`, m.`service_date`, a.`client_id`
              FROM `asset_maintenance` m
              JOIN `assets` a ON a.`id` = m.`asset_id`
             WHERE m.`batch_id` IS NULL) x
  ) g
  LEFT JOIN `client_users` cu ON cu.`id` = g.`client_id`

-- >>>
-- The batches themselves. `recorded_by` says where they came from, because a title nobody typed
-- should not look as though somebody did.
INSERT INTO `asset_service_batches` (`title`, `recorded_by`)
SELECT `title`, 'backfill' FROM `_asb_backfill`

-- >>>
-- The mapping, joined on the title. Safe HERE and only here — see the note above. `recorded_by` is in
-- the join so a batch a user created earlier with a colliding title cannot be claimed by the backfill.
UPDATE `_asb_backfill` s
  JOIN `asset_service_batches` b
    ON b.`title` = s.`title` AND b.`recorded_by` = 'backfill'
   SET s.`batch_id` = b.`id`

-- >>>
-- And the records. `s.client_id <=> a.client_id` because `client_id` is NULL on every internal asset
-- and `NULL = NULL` is NULL, not true — a plain equals would leave the whole internal register
-- unbatched.
UPDATE `asset_maintenance` m
  JOIN `assets` a ON a.`id` = m.`asset_id`
  JOIN `_asb_backfill` s
    ON s.`kind` = m.`kind`
   AND s.`service_date` = m.`service_date`
   AND s.`client_id` <=> a.`client_id`
   SET m.`batch_id` = s.`batch_id`
 WHERE m.`batch_id` IS NULL AND s.`batch_id` IS NOT NULL

-- >>>
DROP TABLE IF EXISTS `_asb_backfill`

-- >>>
-- ── Verification ──
-- `unbatched` must read 0 — that is the whole point of the backfill, and any other number means the
-- list will hide those records. `orphan_batches` must read 0 too: a batch with no records is a round
-- that renders as an empty row.
SELECT
  (SELECT COUNT(*) FROM `asset_service_batches`)                                AS batches,
  (SELECT COUNT(*) FROM `asset_maintenance` WHERE `batch_id` IS NULL)           AS unbatched,
  (SELECT COUNT(*) FROM `asset_service_batches` b
    WHERE NOT EXISTS (SELECT 1 FROM `asset_maintenance` m
                       WHERE m.`batch_id` = b.`id`))                            AS orphan_batches,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance'
      AND COLUMN_NAME = 'batch_id')                                             AS pointer_column,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'asset_maintenance'
      AND CONSTRAINT_NAME = 'fk_amaint_batch')                                  AS pointer_fk,
  (SELECT COUNT(*) FROM `asset_service_batch_files`)                            AS files,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN ('asset_service_batches', 'asset_service_batch_files')
      AND CREATE_OPTIONS LIKE '%row_format%')                                   AS row_formats
