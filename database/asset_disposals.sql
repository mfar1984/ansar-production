-- ============================================================
-- DISPOSAL / WRITE-OFF — the record, not just the status
--
-- WHAT ALREADY EXISTED, AND WHAT DID NOT
--
-- Writing an asset off was already possible and already gated: `assets.status` carries `retired`,
-- `disposed` and `lost`, `ASSET_DISPOSAL_STATUSES` names them, a separate `_dispose` permission is
-- enforced in three endpoints, and `asset_movements` records the change. Its own comment says
-- "'disposed' is a state, not a delete", and that was right.
--
-- What did NOT exist is the RECORD. A status tells you an asset is gone. It cannot tell you:
--
--   when it went, and under what authority
--   why — sold, scrapped, donated, traded in, or simply never found
--   what was received for it
--   what it was still worth on the register the day it left
--   and therefore whether the disposal made a gain or a loss
--
-- Those are the questions an audit asks, and `status = 'disposed'` answers none of them.
--
-- ONE DISPOSAL PER ASSET, AND HERE A UNIQUE INDEX REALLY WORKS
--
-- `UNIQUE (asset_id)`. Worth contrasting with `asset_checkouts`, where the equivalent constraint was
-- deliberately NOT used: there the rule is "one OPEN loan", the discriminator is a nullable
-- `returned_on`, and SQL treats two NULLs as distinct — so `UNIQUE (asset_id, returned_on)` would
-- have permitted two open rows and enforced nothing. A disposal has no nullable discriminator. An
-- asset is disposed of once, so a plain unique index says exactly that and the database enforces it
-- rather than the endpoint.
--
-- BOOK VALUE IS SNAPSHOTTED. GAIN OR LOSS IS NOT.
--
-- `book_value_at_disposal` is stored, and that is a deliberate exception to this module's usual rule
-- that a derived figure must never be frozen. Overdue is derived because it changes with the clock
-- and a stored flag would be wrong by morning. Book value at disposal is the opposite case: it is a
-- statement about ONE PAST DAY, computed from `purchase_cost`, `purchase_date` and
-- `useful_life_years` — every one of which can be CORRECTED afterwards. Recomputing it later would
-- silently restate a figure that may already be in a report somebody signed.
--
-- Gain or loss is NOT stored: it is `proceeds - book_value_at_disposal`, from two columns that are
-- both already frozen, so deriving it cannot drift. Storing it would be a third number to keep in
-- step with two that already agree.
--
-- `proceeds` NULL AND `proceeds` ZERO ARE DIFFERENT FACTS
--
-- NULL means no money was involved — scrapped, donated, or lost. `0.00` means it was sold and
-- nothing came back, which is a sale at nil value and a real loss on disposal. Collapsing them would
-- make every scrapped item look like a loss equal to its whole book value.
--
-- `previous_status` IS WHAT MAKES A MISTAKE UNDOABLE
--
-- Recording a disposal changes `assets.status`. If the record is deleted because it was entered
-- against the wrong asset, the status has to go back — and without this column there is nothing to
-- go back TO except a guess. `asset_movements` holds the change as free text, which a human can read
-- and a reversal cannot rely on. NOT NULL, because a reversal that cannot restore is not a reversal.
--
-- NO LEDGER POSTING, AND THAT IS A DECISION
--
-- A disposal of a fixed asset has an accounting entry behind it: remove the cost and the accumulated
-- depreciation, recognise the gain or loss. Nothing here posts to the general ledger, because the
-- accounting module is still being built and a posting written against a chart of accounts that is
-- still moving would have to be unpicked. The columns that a posting needs — `proceeds`,
-- `book_value_at_disposal`, `disposed_on` — are all captured, so the link can be added later from
-- data that is already correct rather than reconstructed from a status change.
--
-- Idempotent. Statement separator: a "-- >>>" line.
-- Run:  node scripts/run-sql.js database/asset_disposals.sql
-- ============================================================

-- >>>
CREATE TABLE IF NOT EXISTS `asset_disposals` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `asset_id`      INT UNSIGNED NOT NULL,

  -- WHY it left. Six answers, and they are not interchangeable: `sold` and `traded_in` bring value
  -- back, `scrapped` and `donated` do not, `lost` is an incident rather than a decision, and
  -- `written_off` is the accounting act for something with no value left and nothing to collect.
  `disposal_kind` ENUM('sold', 'scrapped', 'donated', 'traded_in', 'lost', 'written_off')
                  NOT NULL DEFAULT 'scrapped',
  `disposed_on`   DATE         NOT NULL,
  `reason`        VARCHAR(500) DEFAULT NULL,

  -- ── Money ──
  -- NULL means no money was involved. 0.00 means it was sold for nothing, which is a different fact
  -- and a real loss. See the header.
  `proceeds`      DECIMAL(15,2) DEFAULT NULL
                  COMMENT 'NULL = not a sale. 0.00 = sold for nothing',
  -- SNAPSHOT, computed as at `disposed_on` when the record is written. Never recomputed: the inputs
  -- can be corrected afterwards and this figure may already be in a signed report.
  `book_value_at_disposal` DECIMAL(15,2) DEFAULT NULL
                  COMMENT 'Straight-line NBV as at disposed_on, frozen. NULL = not depreciable',

  -- ── Authority ──
  -- Free text rather than an employee foreign key: an approval may come from a director, a committee
  -- or a client, and three nullable columns would still not cover it. `approval_ref` is where a
  -- minute number or a memo reference goes.
  `approved_by`   VARCHAR(200) DEFAULT NULL,
  `approval_ref`  VARCHAR(120) DEFAULT NULL,
  -- Who took it: a buyer, a charity, a recycler.
  `recipient`     VARCHAR(200) DEFAULT NULL,

  -- ── Reversal ──
  -- The status the asset held before this record set it. NOT NULL: a reversal that cannot restore
  -- the previous state is not a reversal, it is a second guess.
  `previous_status` ENUM('in_store', 'in_use', 'under_repair', 'retired', 'disposed', 'lost')
                  NOT NULL,

  `recorded_by`   VARCHAR(150) DEFAULT NULL,
  `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- One disposal per asset, enforced by the database. See the header for why this works here and
  -- deliberately does not in `asset_checkouts`.
  UNIQUE KEY `uq_disposal_asset` (`asset_id`),
  KEY `idx_disposal_date` (`disposed_on`),
  KEY `idx_disposal_kind` (`disposal_kind`, `disposed_on`),
  -- CASCADE, like `asset_movements` and `asset_maintenance`: the disposal record is part of this
  -- asset's history and has no meaning without it. Deleting the asset row is a different act from
  -- writing it off, and the register keeps the written-off asset precisely so it stays findable.
  CONSTRAINT `fk_disposal_asset` FOREIGN KEY (`asset_id`)
    REFERENCES `assets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- >>>
-- ── Permissions ──
--
-- NONE ARE ADDED. `assets_internal_dispose` and `assets_external_dispose` already exist, seeded by
-- `operations_assets.sql`, whose comment already states the reasoning: "writing an asset off removes
-- it from the register's value and cannot be undone by editing. Separate from `_delete`, which
-- erases the record entirely."
--
-- This statement is a CHECK, not a change: it fails loudly here rather than letting the screen ship
-- against a permission nobody can grant. A module whose permission is missing renders for no role
-- including Super Admin, which is how a working page comes to look broken.
SELECT
  (SELECT COUNT(*) FROM `permissions`
    WHERE `name` IN ('assets_internal_dispose', 'assets_external_dispose'))     AS dispose_perms,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE p.`name` IN ('assets_internal_dispose', 'assets_external_dispose')
      AND LOWER(TRIM(r.`name`)) = 'super admin')                               AS granted_to_super,
  (SELECT COUNT(*) FROM `asset_disposals`)                                     AS disposals
