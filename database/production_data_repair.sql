-- ============================================================================
-- FOUR DATA DEFECTS MEASURED ON THE PRODUCTION DATABASE
--
-- Run with:  node scripts/run-sql.js database/production_data_repair.sql
--
-- These are not schema gaps — `schema_repair_checks.sql` covers those. These are ROWS that
-- say the wrong thing, found by restoring the production dump of 2026-10-07 onto a
-- development machine and reading what the test suite then reported.
--
-- Every section states what it measured, so a second reader can re-measure rather than
-- trust this file.
--
-- IDEMPOTENT throughout. Each statement is written so that running it twice changes nothing
-- the second time, because a hand runs things twice.
-- ============================================================================

-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 1. THE LHDN CODE LABELS ARE DOUBLE-ENCODED
-- ════════════════════════════════════════════════════════════════════════════
--
-- `lhdn_codes.label` holds mojibake on every row carrying a non-ASCII character:
--
--     stored  Pa’anga        wanted  Pa’anga
--     stored  BolÃ­var        wanted  Bolívar
--     stored  goat’s milk    wanted  goat’s milk
--
-- MEASURED, not inferred. The stored bytes for the Tongan currency are
--
--     50 61  C3A2 E282AC E284A2  61 6E 67 61
--
-- which is "Pa" + U+00E2 + U+20AC + U+2122 + "anga" — the three characters you get by
-- reading the UTF-8 bytes of U+2019 (E2 80 99) as Latin-1 and encoding the result as UTF-8
-- a second time. A classic double encode, written at sync time.
--
-- IT WAS ALREADY THERE. The identical byte sequence is present in a schema dumped from
-- production BEFORE this repair work began, so the import did not cause it and re-importing
-- will not cure it.
--
-- ── THE ROUND-TRIP, AND WHY IT IS SAFE HERE SPECIFICALLY ──
--
-- `CONVERT(BINARY(CONVERT(label USING latin1)) USING utf8mb4)` reads each character back as
-- one Latin-1 byte and decodes the bytes as UTF-8, undoing the second encode. It is NOT
-- universally safe: a correctly stored `’` has no Latin-1 byte, so the conversion would
-- destroy it.
--
-- So it was measured against `src/data/lhdn/*.json`, the bundled files the application syncs
-- from and the suite compares to:
--
--     3854 rows, of which 3815 are pure ASCII and the round-trip is the identity
--       37 rows change
--        0 rows become NULL — nothing is destroyed
--       34 of the 37 then match the bundled label EXACTLY
--        0 of the 37 disagree with the bundled label afterwards
--
-- The three not counted are codes the bundled index did not carry to compare against; they
-- change in the same way as the 34 that were verified.
--
-- ── `IS NOT NULL` IS WHAT PROTECTS A ROW THAT IS ALREADY CORRECT ──
--
-- This is the condition that matters, and it was checked rather than assumed. On a repaired
-- row the conversion returns NULL, not a mangled string:
--
--     SELECT label, CONVERT(BINARY(CONVERT(label USING latin1)) USING utf8mb4)
--       FROM lhdn_codes WHERE list='currency' AND code='TOP'
--     ->  Pa’anga , NULL
--
-- U+2019 has no CP1252 byte, so the latin1 step cannot represent it and the re-decode is not
-- valid UTF-8. The row is therefore excluded. MEASURED after the first pass: zero rows in the
-- table contain a question mark, so nothing was substituted and nothing was lost.
--
-- ── IT NEEDS MORE THAN ONE PASS, BECAUSE SOME TEXT WAS ENCODED MORE THAN TWICE ──
--
-- The first pass repaired 37 rows and left 25 still differing, and those 25 were NOT correct
-- rows at risk — they carried another layer. `hourÃ‚Â ` repairs to `hourÂ `, which is itself
-- the double encode of U+00A0, the non-breaking space inside the LHDN unit descriptions.
--
-- MEASURED convergence: pass 1 changes 25, pass 2 changes 0. So the loop below is bounded at
-- 10, which is six times the depth ever observed, and stops the moment a pass changes nothing.
-- A fixed `run it twice` would be right today and silently insufficient on a third layer.
--
-- ── THE COMPARISON IS ON BYTES, AND THAT IS NOT A STYLE CHOICE ──
--
-- Written as a plain `label <> CONVERT(...)` this failed outright:
--
--     ER_CANT_AGGREGATE_2COLLATIONS: Illegal mix of collations
--     (utf8mb4_unicode_ci,IMPLICIT) and (utf8mb4_0900_ai_ci,IMPLICIT) for operation '<>'
--
-- `CONVERT(x USING utf8mb4)` carries the SERVER's default collation, which is
-- `utf8mb4_0900_ai_ci` on MySQL 8, while the column is `utf8mb4_unicode_ci`.
--
-- Adding `COLLATE utf8mb4_unicode_ci` would have silenced it and been WRONG. That collation
-- is accent-insensitive: under it `'Bolívar'` and `'BolÃ­var'` compare EQUAL, so the WHERE
-- would have matched nothing and the repair would have reported success having changed no
-- rows. The accents are the entire defect being repaired.
--
-- `CAST(... AS BINARY)` has no collation at all and compares byte for byte, which is the
-- question actually being asked, and it reads the same on MySQL and MariaDB.
DROP PROCEDURE IF EXISTS `repair_lhdn_encoding`

-- >>>
CREATE PROCEDURE `repair_lhdn_encoding`()
BEGIN
  DECLARE v_pass INT DEFAULT 0;
  DECLARE v_changed INT DEFAULT 1;

  WHILE v_pass < 10 AND v_changed > 0 DO
    UPDATE `lhdn_codes`
       SET `label` = CONVERT(BINARY(CONVERT(`label` USING latin1)) USING utf8mb4)
     WHERE CONVERT(BINARY(CONVERT(`label` USING latin1)) USING utf8mb4) IS NOT NULL
       AND CAST(`label` AS BINARY)
        <> CAST(CONVERT(BINARY(CONVERT(`label` USING latin1)) USING utf8mb4) AS BINARY);
    SET v_changed = ROW_COUNT();

    /* `extra` carries the same text for some lists and was written by the same sync, so it has
       the same defect, the same guard and the same number of layers. */
    UPDATE `lhdn_codes`
       SET `extra` = CONVERT(BINARY(CONVERT(`extra` USING latin1)) USING utf8mb4)
     WHERE `extra` IS NOT NULL
       AND CONVERT(BINARY(CONVERT(`extra` USING latin1)) USING utf8mb4) IS NOT NULL
       AND CAST(`extra` AS BINARY)
        <> CAST(CONVERT(BINARY(CONVERT(`extra` USING latin1)) USING utf8mb4) AS BINARY);
    SET v_changed = v_changed + ROW_COUNT();

    SET v_pass = v_pass + 1;
  END WHILE;
END

-- >>>
CALL `repair_lhdn_encoding`()

-- >>>
DROP PROCEDURE IF EXISTS `repair_lhdn_encoding`

-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 2. TWO CLIENT-PORTAL PERMISSIONS ARE GRANTED TO AN ADMIN ROLE
-- ════════════════════════════════════════════════════════════════════════════
--
-- `client_projects_view` and `client_helpdesk_view` were each granted to role 1, Super Admin.
--
-- They are not admin permissions. `src/lib/permission-modules.ts` says so in the line above
-- their labels: "Held by a client session, never by an admin role. They appear in the matrix
-- with no grants." `src/pages/api/client/projects/index.ts` says the same at length — a
-- client session holds no role and no `role_permissions` row, `resolveAdmin` returns null for
-- it by design, and the names exist so the PORTAL sidebar has something to check and the
-- Roles matrix can show what a client can reach.
--
-- So the grants control nothing, and they are worse than inert: they render two ticked
-- checkboxes in the Roles matrix that an administrator can reasonably read as conferring
-- access. A checkbox that does nothing is a lie about who can see what.
--
-- SAFE TO REVOKE, and this does not come back. Super Admin does not depend on
-- `role_permissions` rows at all — `src/lib/api-guard.ts` resolves `isSuperAdmin` from the
-- role NAME and `can()` returns true for it unconditionally. Nothing in `src/` inserts a
-- blanket grant, so there is no sync to undo this.
DELETE `rp`
  FROM `role_permissions` `rp`
  JOIN `permissions` `p` ON `p`.`id` = `rp`.`permission_id`
 WHERE `p`.`module` IN ('client_projects', 'client_helpdesk')

-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 3. FIVE ASSET CATEGORIES WERE NEVER GIVEN A PARENT
-- ════════════════════════════════════════════════════════════════════════════
--
-- `database/asset_category_parents.sql` maps sub-categories to the fifteen parents by NAME.
-- Its own header records the trap: "A mapping statement whose parent name matches nothing is
-- a silent no-op, and an unmapped child looks identical to a parent" — because both carry
-- `parent_id NULL`.
--
-- These five were added to the register AFTER that file was written, so no statement in it
-- names them. They sit at top level, which puts them in the parent pickers and the grouped
-- filter as though they were categories of their own.
--
--     HEAVY DUTY FOLDING ALUMINUM LADDER   a tool
--     MAINTENANCE WARNING BARICADE         site safety equipment
--     MIFARE CARD                          an access credential
--     Proximity ID Smart Card              an access credential
--     IBC TANK                             a bulk storage vessel, and the one with no home
--
-- `IBC TANK` goes under `Other` deliberately rather than being forced into
-- `Tools & Instruments`. It is not a tool, and `Other` is the parent the taxonomy provides
-- for exactly this. Inventing a parent for one row would be a worse answer.
--
-- Idempotent: `parent_id IS NULL` means a row already mapped is not touched, and a parent
-- corrected by hand afterwards is not overwritten.
UPDATE `asset_categories` `c`
  JOIN `asset_categories` `p` ON `p`.`name` = 'Tools & Instruments' AND `p`.`parent_id` IS NULL
   SET `c`.`parent_id` = `p`.`id`
 WHERE `c`.`name` = 'HEAVY DUTY FOLDING ALUMINUM LADDER' AND `c`.`parent_id` IS NULL

-- >>>
UPDATE `asset_categories` `c`
  JOIN `asset_categories` `p` ON `p`.`name` = 'Safety & PPE' AND `p`.`parent_id` IS NULL
   SET `c`.`parent_id` = `p`.`id`
 WHERE `c`.`name` = 'MAINTENANCE WARNING BARICADE' AND `c`.`parent_id` IS NULL

-- >>>
UPDATE `asset_categories` `c`
  JOIN `asset_categories` `p` ON `p`.`name` = 'CCTV & Security' AND `p`.`parent_id` IS NULL
   SET `c`.`parent_id` = `p`.`id`
 WHERE `c`.`name` IN ('MIFARE CARD', 'Proximity ID Smart Card') AND `c`.`parent_id` IS NULL

-- >>>
UPDATE `asset_categories` `c`
  JOIN `asset_categories` `p` ON `p`.`name` = 'Other' AND `p`.`parent_id` IS NULL
   SET `c`.`parent_id` = `p`.`id`
 WHERE `c`.`name` = 'IBC TANK' AND `c`.`parent_id` IS NULL

-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 4. `Other` CARRIES NO USEFUL LIFE, SO FIFTEEN SUB-CATEGORIES RESOLVE NONE
-- ════════════════════════════════════════════════════════════════════════════
--
-- A sub-category's life is `COALESCE(c.useful_life_years, p.useful_life_years)`. `Other` has
-- NULL, so all fifteen of its children resolve to nothing: STORAGE BOX -95 LITTER, GPS
-- RECEIVER, HDMI FACEPLATE, DESK STAND MICROPHONE, DOOR CLOSER, ELECTROMAGNETIC LOCK,
-- ELECTROMAGNETIC LOCK BRACKET FOR FRAMELESS DOOR, USB 2.0 MALE TO FEMALE CONVERTER, AUDIO
-- JACK CABLE, XLR cable, AUDIO CABLE, HUM ILUMINATOR, HD VIDEO CONVERTER, VOCAL TRAINER,
-- BEACON LIGHT. An asset registered under any of them is offered no life, so it is recorded
-- with no book value.
--
-- ── THIS IS NOT THE BACKFILL `asset_category_parents.sql` REFUSED, AND THE DIFFERENCE WAS
--    CHECKED BEFORE WRITING IT ──
--
-- That file's header declines to backfill lives: "Backfilling that would change a
-- depreciation figure that may already be in a signed report, and the module's own rule is
-- that a category's life is a DEFAULT for new assets and never retroactive."
--
-- That caution is about writing `assets.useful_life_years`. This writes a CATEGORY. Measured:
-- `assets` carries its own `useful_life_years` column, the COALESCE appears only in the asset
-- register's options query where it SEEDS a new asset, and the register form fills the field
-- only when it is empty — `tests/sql/asset-category-tree.test.js` holds that rule as "the
-- seed still only fills an EMPTY life". So not one existing asset's figure moves. The 49
-- assets already under `Other` keep whatever they carry.
--
-- FIVE YEARS, and the reason is the contents rather than a preference. `Other` holds cables,
-- converters, locks, faceplates, beacon lights, storage boxes and small instruments. Five is
-- the register's own modal life — Server & Storage, Network Equipment, Tools & Instruments,
-- CCTV & Security and Appliances all carry it — and these items sit squarely among them.
--
-- Idempotent and non-destructive: `IS NULL` means a figure set by hand later is never
-- overwritten.
UPDATE `asset_categories`
   SET `useful_life_years` = 5
 WHERE `name` = 'Other' AND `parent_id` IS NULL AND `useful_life_years` IS NULL

-- >>>
-- ── Report the result of all four, so "0 failed" cannot mean "nothing happened" ──
--
-- Expected after a successful run:  lhdn_mojibake 0   client_grants 0
--                                  unparented 0       other_life 5
SELECT
  (SELECT COUNT(*) FROM `lhdn_codes`
    WHERE CONVERT(BINARY(CONVERT(`label` USING latin1)) USING utf8mb4) IS NOT NULL
      AND CAST(`label` AS BINARY)
       <> CAST(CONVERT(BINARY(CONVERT(`label` USING latin1)) USING utf8mb4) AS BINARY)) AS `lhdn_mojibake`,
  (SELECT COUNT(*) FROM `role_permissions` `rp` JOIN `permissions` `p` ON `p`.`id` = `rp`.`permission_id`
    WHERE `p`.`module` IN ('client_projects', 'client_helpdesk'))                   AS `client_grants`,
  (SELECT COUNT(*) FROM `asset_categories`
    WHERE `parent_id` IS NULL
      AND `name` NOT IN ('Computer & Laptop', 'Server & Storage', 'Network Equipment',
                         'Printer & Scanner', 'Mobile Device', 'Vehicle', 'Office Furniture',
                         'Tools & Instruments', 'CCTV & Security', 'Power & Electrical',
                         'Software Licence', 'Other', 'Appliances', 'Safety & PPE',
                         'BUILDING'))                                               AS `unparented`,
  (SELECT `useful_life_years` FROM `asset_categories`
    WHERE `name` = 'Other' AND `parent_id` IS NULL)                                 AS `other_life`
