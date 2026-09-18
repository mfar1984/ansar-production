-- ============================================================
-- ASSET NUMBER -> 12-CHARACTER UNIQUE ID
--
-- `assets.asset_no` was `AST-YYYY-NNNN` for the internal register and `EXA-YYYY-NNNN` for the external
-- one. It becomes a 12-character random identifier from 34 characters: the digits and A-Z LESS `I` and
-- `O`. `H19A015B815Q` is the shape.
--
-- ── WHY THE PREFIX AND THE YEAR GO ──
--
-- The prefix encoded the REGISTER, which is already a column (`holder`). A unit moving between the two
-- therefore either kept a number contradicting its own holder or had to be renumbered, and renumbering
-- is what invalidates a printed sticker. The year encoded when it was entered, which `created_at`
-- already answers, and it forced a sequence that had to be read from the table under a retry.
--
-- ── WHY `I` AND `O` ARE NOT IN THE ALPHABET ──
--
-- The label prints the identifier in human-readable text precisely so a scuffed sticker can still be
-- typed in. A random string has no prefix, no year and no checksum to fall back on, so ONE misread
-- character is unrecoverable — and at 10pt, `O` is `0` and `I` is `1`. Two characters removed costs
-- nothing: 34^12 is 2.4 x 10^18.
--
-- The application's own `normaliseAssetUid` maps a typed `O` to `0` and `I` to `1` when resolving a
-- scan. That is only sound because nothing ever GENERATES them, which is why the exclusion here and
-- the mapping there are one decision. `src/lib/asset-uid.ts` holds both.
--
-- ── WHAT THIS BREAKS, STATED PLAINLY ──
--
-- EVERY LABEL ALREADY PRINTED BECOMES WRONG. The sticker carries the old string in the QR code and in
-- the text line, and the scan path is an exact match on `asset_no`. So this file sets
-- `label_printed_at = NULL` on every row it rewrites: that column is the ONLY thing driving the
-- register's "No label yet" warning, and without nulling it a warehouse of dead stickers would look
-- like a warehouse of labelled assets. Reprint the labels after running this.
--
-- AUDIT HISTORY KEEPS THE OLD NUMBERS. `activity_log` rows carry the number as frozen text —
-- `Asset: AST-2026-0098` — and they are history, not references. They are left exactly as they are.
-- `asset_uid_map` below is how anybody reads them afterwards.
--
-- NOTHING ELSE IN THE SCHEMA POINTS AT `asset_no`. Every child table references `assets(id)`; there is
-- no foreign key onto the number and no other table stores it as text. Checked across `database/`.
--
-- ── WHY RAND() HERE AND crypto AT RUNTIME ──
--
-- `newAssetUid()` in the application uses `node:crypto` with rejection sampling. SQL has no CSPRNG, so
-- this uses `RAND()`, and that is acceptable for one reason: an asset identifier does not need to be
-- unguessable. `RAND()` is uniform over [0,1), so `FLOOR(RAND() * 34)` is unbiased across 0..33 with no
-- modulo problem, and uniqueness is enforced by the EXISTS test below plus `uq_asset_no`.
--
-- ── IDEMPOTENT, AND THIS IS THE IMPORTANT PART ──
--
-- The loop selects ONLY rows whose `asset_no` still matches the old pattern. A second run finds none
-- and does nothing. Without that guard a re-run would re-randomise the whole register, invalidating a
-- second batch of freshly printed labels — which is exactly the mistake a hand makes when it is not
-- sure whether the first run finished.
--
-- `VARCHAR(30)` is unchanged. 12 fits, and tightening it to `CHAR(12)` would need a DATA_TYPE-guarded
-- ALTER for no benefit.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_uid.sql
-- ============================================================

-- >>>
-- ── THE MAP, WRITTEN BEFORE ANYTHING IS REWRITTEN ──
--
-- Old number -> new ID, one row per asset migrated.
--
-- Not optional bookkeeping. After this runs, every printed sticker, every audit entry, every paper
-- delivery order and everybody's memory still says `AST-2026-0098`, and without this table that string
-- becomes permanently unanswerable. It is also what lets the register's search and the stock take
-- scanner recognise an out-of-date label and name its replacement instead of answering "no such asset"
-- about a unit somebody is holding.
--
-- `old_asset_no` is UNIQUE, which is a second idempotency guard: a re-run that somehow reached the
-- INSERT would be refused by the index rather than writing a second row for the same asset.
--
-- ROW_FORMAT=DYNAMIC is DECLARED, not inherited. `sql-portability.test.js` runs SHOW CREATE TABLE over
-- every table and fails any that does not state it, because a dump of a table that merely inherited the
-- server default restores as whatever the importing server prefers.
CREATE TABLE IF NOT EXISTS `asset_uid_map` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id`     INT UNSIGNED NOT NULL,
  `old_asset_no` VARCHAR(30)  NOT NULL COMMENT 'AST-YYYY-NNNN or EXA-YYYY-NNNN, as printed on the old sticker',
  `new_asset_no` VARCHAR(30)  NOT NULL COMMENT 'the 12-character unique ID that replaced it',
  `migrated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_auidmap_old` (`old_asset_no`),
  KEY `idx_auidmap_asset` (`asset_id`),
  KEY `idx_auidmap_new` (`new_asset_no`),
  -- CASCADE, unlike the SET NULL everywhere else in this schema. This row describes a RENAME of one
  -- asset; if the asset is deleted the rename is not history about anything, and a map row pointing at
  -- a gone asset would make the search resolve an old sticker to nothing with extra steps.
  CONSTRAINT `fk_auidmap_asset` FOREIGN KEY (`asset_id`)
    REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- >>>
DROP PROCEDURE IF EXISTS ansar_asset_uid_migrate

-- >>>
-- ── THE REWRITE ──
--
-- A LOOP with `LIMIT 1` rather than a CURSOR, on purpose: the loop updates the very table it reads, and
-- each UPDATE removes that row from the matching set, so the loop is self-terminating and never reads a
-- result set that is being modified underneath it.
--
-- `v_guard` is a hard stop. If an UPDATE ever failed to change the value the SELECT would keep finding
-- the same row for ever, and a migration that hangs on a live database is worse than one that stops and
-- says so. 100,000 is far above any real register — this one holds about 200 assets.
CREATE PROCEDURE ansar_asset_uid_migrate()
BEGIN
  -- ── EVERY STRING VARIABLE DECLARES ITS COLLATION, AND THAT IS NOT DECORATION ──
  --
  -- A procedure variable takes the CONNECTION's collation, which on MySQL 8 is `utf8mb4_0900_ai_ci`.
  -- `assets.asset_no` is `utf8mb4_unicode_ci`. So `WHERE asset_no = v_uid` mixed two collations and the
  -- CALL failed outright with:
  --
  --     ER_CANT_AGGREGATE_2COLLATIONS: Illegal mix of collations
  --       (utf8mb4_unicode_ci,IMPLICIT) and (utf8mb4_0900_ai_ci,IMPLICIT) for operation '='
  --
  -- MEASURED on this database, not anticipated — the first run of this file stopped there with nothing
  -- migrated. Declaring the collation explicitly is what makes the comparison legal, and it makes the
  -- file independent of whatever collation the connection happens to arrive with on the server.
  DECLARE v_id       INT UNSIGNED;
  DECLARE v_old      VARCHAR(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  DECLARE v_uid      VARCHAR(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  DECLARE v_i        TINYINT;
  DECLARE v_tries    SMALLINT;
  DECLARE v_guard    INT DEFAULT 0;
  DECLARE v_done     TINYINT DEFAULT 0;
  DECLARE v_alphabet VARCHAR(34) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
                     DEFAULT '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  row_loop: LOOP
    SET v_done = 0;
    SET v_guard = v_guard + 1;
    IF v_guard > 100000 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'asset_uid: the loop is not making progress; nothing further was changed';
    END IF;

    -- The OLD pattern is the whole guard. Case-insensitive under utf8mb4_unicode_ci, so a hand-entered
    -- `ast-2026-0098` is caught too.
    SELECT `id`, `asset_no` INTO v_id, v_old
      FROM `assets`
     WHERE `asset_no` REGEXP '^(AST|EXA)-[0-9]{4}-[0-9]+$'
     ORDER BY `id`
     LIMIT 1;

    IF v_done = 1 THEN
      LEAVE row_loop;
    END IF;

    SET v_tries = 0;
    gen_loop: LOOP
      SET v_uid = '';
      SET v_i = 0;
      WHILE v_i < 12 DO
        -- SUBSTRING is 1-based. RAND() is [0,1), so FLOOR(RAND()*34) is 0..33 and the index is 1..34.
        SET v_uid = CONCAT(v_uid, SUBSTRING(v_alphabet, 1 + FLOOR(RAND() * 34), 1));
        SET v_i = v_i + 1;
      END WHILE;

      SET v_tries = v_tries + 1;

      -- Checked against the live table, so IDs handed out earlier in this same run are included.
      IF NOT EXISTS (SELECT 1 FROM `assets` WHERE `asset_no` = v_uid) THEN
        LEAVE gen_loop;
      END IF;

      IF v_tries >= 50 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'asset_uid: 50 consecutive collisions, which is impossible by chance; check the alphabet';
      END IF;
    END LOOP;

    -- ONE statement for both facts. `label_printed_at` is nulled in the same UPDATE as the rename so
    -- there is no window in which the register believes a label exists for a number that has changed.
    UPDATE `assets`
       SET `asset_no` = v_uid,
           `label_printed_at` = NULL
     WHERE `id` = v_id;

    INSERT INTO `asset_uid_map` (`asset_id`, `old_asset_no`, `new_asset_no`)
    VALUES (v_id, v_old, v_uid);
  END LOOP;
END

-- >>>
CALL ansar_asset_uid_migrate()

-- >>>
-- The procedure is not left behind. It is a one-time rewrite, and a procedure that renumbers the asset
-- register is not something to leave one CALL away from a live database.
DROP PROCEDURE IF EXISTS ansar_asset_uid_migrate

-- >>>
-- ── VERIFICATION, in the house style ──
--
-- `old_format_remaining` MUST be 0. `bad_shape` must be 0 — anything that is not 12 characters drawn
-- from the alphabet, which also catches an `I` or an `O` arriving from somewhere unexpected.
-- `labels_to_reprint` is the number of stickers that are now wrong; it is expected to equal `migrated`
-- on a first run, and it is the queue the register's "No label yet" warning will show.
SELECT
  (SELECT COUNT(*) FROM `assets`
    WHERE `asset_no` REGEXP '^(AST|EXA)-[0-9]{4}-[0-9]+$')            AS `old_format_remaining`,
  (SELECT COUNT(*) FROM `asset_uid_map`)                              AS `migrated`,
  (SELECT COUNT(*) FROM `assets`
    WHERE `asset_no` NOT REGEXP '^[0-9A-HJ-NP-Z]{12}$')               AS `bad_shape`,
  (SELECT COUNT(*) FROM `assets` WHERE `label_printed_at` IS NULL)    AS `labels_to_reprint`,
  (SELECT COUNT(*) FROM `assets`)                                     AS `assets_total`
