-- SETTINGS > INTEGRATION > EASYPARCEL
--
-- Run with:  node scripts/run-sql.js database/easyparcel_integration.sql
--
-- Standalone. Depends on `permissions`, `roles` and `role_permissions` only, so it can be
-- applied before or after `market_place_orders.sql` in either order.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHAT THIS IS FOR
-- ══════════════════════════════════════════════════════════════════════════════
--
-- One row holding the EasyParcel Next Gen OAuth application, the tokens it was granted,
-- and the collection address every quotation is priced from.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- WHY THIS IS NOT A COLUMN GROUP ON `integrations`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Seven of the nine Integration tabs are column groups on the single `integrations` row,
-- served by `src/pages/api/admin/integration/[module].ts`. Reusing that was checked first
-- and it fails on two counts, both of them material:
--
--   1  `[module].ts` STORES SECRETS IN PLAIN TEXT. It has no crypto import at all - the
--      whole file is a spec map, `validateEnums`, `validateUrls`, `dropEmptySecrets`,
--      `buildUpdate` and one `UPDATE integrations SET ... WHERE id = 1`. It masks on the way
--      OUT, which stops a secret reaching the browser, and writes it verbatim on the way in.
--      A `refresh_token` with a ONE YEAR life is not a value to keep in clear.
--
--   2  IT HAS NO CONCEPT OF A TOKEN. `[module].ts` maps a form field to a column. OAuth
--      needs an authorize redirect, a state nonce to compare on return, a code exchanged
--      server-to-server, two expiry instants, and a refresh that rewrites the row without a
--      human present. None of that is a field somebody types.
--
-- `erp_myinvoice_integration` set the precedent and its endpoint records the same argument:
-- a static route file wins over `[module].ts` in the pages router, so `integration-easyparcel`
-- keeps the same permission naming and the same tab shell while owning its own storage.
--
-- Secrets here go through `src/lib/secret-store.ts` - AES-256-GCM, `enc:v1` prefix, and it
-- REFUSES to run without a 32-character `ENCRYPTION_KEY` rather than falling back to a
-- literal. `secret_storage` records which way the row was actually written, so the screen
-- can say so instead of claiming encryption it did not perform.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- EASYPARCEL SUPPORTS ONE GRANT TYPE: `authorization_code`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- From their own documentation: "Grant Types Supported: Authorization Code". There is no
-- client credentials flow, so this cannot be configured the way MyInvois is - a human has to
-- sign in to EasyParcel and approve the link.
--
--   1  the operator is sent to `https://api.easyparcel.com/oauth/login` with `client_id`,
--      `redirect_uri` and `state`
--   2  they sign in and choose WHICH EasyParcel account to link
--   3  EasyParcel redirects back to `redirect_uri` with `code` and `state`
--   4  the server POSTs to `https://api.easyparcel.com/oauth/token` with
--      `Authorization: Basic base64(client_id:client_secret)` and exchanges the code
--
-- That is why `redirect_uri` is STORED rather than derived. It must match the value
-- registered in the EasyParcel Developer Hub byte for byte - the OAuth specification
-- requires the authorization server to compare them - and this application is reachable on
-- more than one host. Deriving it from the request would silently produce a different URI on
-- localhost than in production and the exchange would be refused with no clue why.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THERE IS NO SANDBOX COLUMN, AND THAT IS NOT AN OMISSION
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Every other provider here has one: `payments_sandbox_mode`, and MyInvois has a whole
-- `environment` enum with a row per environment.
--
-- EasyParcel does not work that way, and their documentation is explicit: "The OAuth
-- application (Client ID and Client Secret) is not tied to a specific environment. A single
-- application can be used for both Sandbox and Live. The environment is determined by the
-- EasyParcel account that the user logs in with during authorization." Same endpoints, same
-- credentials; a token minted by a sandbox account can only ever reach sandbox.
--
-- So a Sandbox toggle would be a control that changes NOTHING. Switching it on while a live
-- account was authorized would tell the operator they were safe to test while every booking
-- spent real money. That is worse than having no toggle at all.
--
-- What the screen shows instead is `account_label` and `account_type`, read back from
-- `POST /account/get_account_information` at connect time - the name of the account that is
-- actually linked. To move from sandbox to live the operator disconnects and authorizes
-- again with the live account, which is exactly what the documentation prescribes:
-- "Existing access tokens cannot be converted from Sandbox to Live."
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE API VERSION IS A CONSTANT IN CODE, NOT A COLUMN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- EasyParcel versions by date in the path - `/open_api/2026-06/shipment/quotations` - and
-- FOUR versions are documented as live at once: 2025-09, 2025-12, 2026-03, 2026-06. A column
-- would let an operator move forward without a deployment, which sounds like a feature.
--
-- It is a foot-gun. The response shapes differ between those versions: 2025-09 has no
-- `is_pickup`/`is_dropoff` on a quotation and no `reference` on a shipment, and 2026-06 adds
-- a whole BYOC pricing block. Pointing the client at a version it was not written to parse
-- produces missing fields rather than an error, and the symptom appears as an empty courier
-- list. So the version lives beside the parser that depends on it, in
-- `src/lib/easyparcel.ts`, and moving it is a code change that gets read.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE COLLECTION ADDRESS IS HERE, NOT IN SHOP SETTINGS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `POST /shipment/quotations` needs a sender postcode, subdivision and country to price
-- anything, and `POST /shipment/submit_orders` needs the full sender object - name, phone
-- with an ISO country code, address line 1, city, postcode.
--
-- It sits with the courier account for the reason the Market Place Settings page already
-- states in its own header and its sidebar tooltip: "Courier and payment credentials stay in
-- Integration", because a courier account is something the COMPANY holds, not a property of
-- one shop. The address parcels leave from is part of that account's configuration.
--
-- It is NOT read from `POST /account/get_account_information`. That call returns the
-- account's `pickup_address`, and using it would look like a saving of ten fields. It is the
-- wrong source: the EasyParcel profile address is where that ACCOUNT was registered, which
-- need not be where this shop's stock is, and it can be edited on their portal by somebody
-- who has never seen this application. A second authority for the sender address means a
-- parcel collected from the wrong building with nothing on screen having changed.
--
-- `sender_state_code` holds the LETTER code - `swk`, `png` - which is canonical across this
-- database. `my-states.ts` records what the alternative cost: two code systems coexisted and
-- the holidays table printed a bare `14`. EasyParcel wants ISO 3166-2 (`MY-13`), and
-- `subdivisionCode()` converts at the boundary rather than storing a third format.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- NO TRACKING-NOTIFICATION SETTINGS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `submit_orders` accepts `feature.sms_tracking`, `feature.email_tracking` and
-- `feature.whatsapp_tracking`. They are BILLABLE PER SHIPMENT - the quotation response
-- prices them at MYR 0.20, 0.05 and 0.20 - and they are deliberately not configurable here.
--
-- Nobody asked for them, and every one of them spends wallet credit on every parcel. A
-- default of on would spend money nobody authorised; a default of off with three toggles
-- would be three controls built ahead of a decision. The client sends all three FALSE and
-- says so at the call site. Turning one on is a change with its own reasoning.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- THE PERMISSIONS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `integration-easyparcel`  view, edit, test
--
-- The same three as Email, Weather, Payments, SMS, Telegram and E-Invoice, because the
-- endpoint answers the same three things: read the row, write the row, and probe the
-- connection. `test` is separate for the reason the other six already record - a probe calls
-- a third party, and somebody who may read the configuration need not be able to make this
-- server talk to EasyParcel.
--
-- `tests/sql/integration-tabs.test.js` derives the tab list from `IntegrationLayout.tsx` and
-- asserts `view` and `edit` exist for every `permModule` it finds, so the module name here
-- must match the tab key exactly: `integration-easyparcel`.
--
-- ── THE CATEGORY IS `settings`, AND IT WAS CHECKED RATHER THAN GUESSED ──
--
-- The obvious answer was `integration`, and it is WRONG. The categories actually in use are
-- `accounting`, `application`, `dashboard`, `helpdesk`, `human_resources`, `operations`,
-- `settings` and `web_tools` - eight, and no `integration` among them. All nine existing
-- Integration tabs file under `settings`, because the Roles matrix groups by SIDEBAR SECTION
-- and Integration is a page inside Settings.
--
-- The list is CLOSED in `src/lib/permission-modules.ts` and cross-checked both ways by
-- `tests/sql/roles-endpoints.sql.test.js`. A permission whose category names no sidebar
-- section cannot be granted through the matrix at all - the row exists, the checkbox does
-- not, and the tab stays invisible to every role including Super Admin.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `CREATE TABLE IF NOT EXISTS` and `INSERT IGNORE`. Production runs this by hand and a hand
-- runs things twice. No ALTER, so no PREPARE guard is needed here.
--
-- ROW_FORMAT is DECLARED. `sql-portability.test.js` asserts every table states it, because
-- `mysqldump` writes only what a table declares and one that inherited the format takes the
-- IMPORTING server's default.
--
-- One statement per `-- >>>` block and no trailing semicolons.
-- ============================================================================

-- >>>
-- ── 1. The row ──
CREATE TABLE IF NOT EXISTS `easyparcel_integration` (
  -- Always 1. TINYINT rather than INT because a second row is not a thing that should look
  -- possible, and the endpoint only ever writes `WHERE id = 1`.
  `id` TINYINT UNSIGNED NOT NULL DEFAULT 1,

  -- ── The OAuth application, from the EasyParcel Developer Hub ──

  `client_id` VARCHAR(255) NOT NULL DEFAULT '',
  -- TEXT, not VARCHAR, and the first draft of this file got it wrong - which is worth
  -- recording because the failure would have been silent.
  --
  -- This column holds CIPHERTEXT, not the secret. `secret-store.ts` produces
  -- `enc:v1:<24 hex iv>:<32 hex tag>:<hex payload>`, and the payload is TWO hex characters
  -- per plaintext byte. So the overhead is 64 fixed characters plus a doubling: a 255-character
  -- secret becomes 575. `VARCHAR(500)` was chosen with a comment claiming it avoided
  -- truncation, and the arithmetic was never done. MySQL would have TRUNCATED the value, and a
  -- truncated AES-GCM ciphertext fails its authentication tag on decrypt - which surfaces as
  -- "ENCRYPTION_KEY has changed", pointing at the environment instead of at this column.
  --
  -- TEXT removes the guess rather than replacing it with a larger one. It is the same
  -- reasoning the two token columns below already follow, and there is nothing to lose: this
  -- table has one row and this column is never indexed.
  --
  -- NULL-able because MySQL does not allow a DEFAULT on a TEXT column, so `INSERT (id)
  -- VALUES (1)` below would be refused by a NOT NULL one. NULL is the honest value anyway:
  -- it means no secret has been entered, which is exactly what `maskSecrets` reports to the
  -- screen as `client_secret_set: false`.
  `client_secret` TEXT NULL DEFAULT NULL,
  -- Must match the Developer Hub registration byte for byte. See the header.
  `redirect_uri` VARCHAR(500) NOT NULL DEFAULT '',

  -- ── The authorize round trip ──
  --
  -- `oauth_state` is the CSRF nonce: generated when the operator presses Connect, compared
  -- when EasyParcel redirects back, and cleared either way. Without the comparison, anyone
  -- who could reach the callback could bind this system to THEIR EasyParcel account, and
  -- every subsequent booking would be paid for from their wallet and shipped from their
  -- address.
  --
  -- ONE nonce, because this is a single-row table and connecting is a single act by a single
  -- operator. `oauth_state_at` is what makes it expire - a nonce that never goes stale is a
  -- nonce that can be replayed months later.
  `oauth_state`    VARCHAR(64) NULL DEFAULT NULL,
  `oauth_state_at` DATETIME    NULL DEFAULT NULL,

  -- ── The tokens ──
  --
  -- TEXT, not VARCHAR. EasyParcel does not document a maximum length and the sample values
  -- are opaque; an access token in this family is commonly a JWT of several hundred
  -- characters, and encryption roughly doubles it. A length guess that is too small
  -- truncates a credential.
  --
  -- Both are encrypted through `secret-store.ts`. The refresh token especially: its
  -- documented life is 31557600 seconds, a full year, so it is the single most valuable
  -- string in this table.
  `access_token`             TEXT     NULL DEFAULT NULL,
  `access_token_expires_at`  DATETIME NULL DEFAULT NULL,
  `refresh_token`            TEXT     NULL DEFAULT NULL,
  `refresh_token_expires_at` DATETIME NULL DEFAULT NULL,

  -- Which way the secrets in this row were ACTUALLY written. Stored rather than assumed, so
  -- the screen can report the truth: a deployment with no `ENCRYPTION_KEY` cannot encrypt,
  -- and a banner claiming it did would be a lie the operator acts on.
  `secret_storage` ENUM('plaintext','encrypted') NOT NULL DEFAULT 'plaintext',

  -- ── Which EasyParcel account is linked ──
  --
  -- Read back from `POST /account/get_account_information` at connect time. This is how the
  -- environment is surfaced - see the header on why there is no Sandbox toggle. A demo
  -- account and a live account have different names, and the name is the only honest signal
  -- available.
  `account_label` VARCHAR(160) NULL DEFAULT NULL,
  `account_type`  VARCHAR(40)  NULL DEFAULT NULL,
  `connected_at`  DATETIME     NULL DEFAULT NULL,
  `connected_by`  VARCHAR(150) NULL DEFAULT NULL,

  -- ── The collection address. Every parcel leaves from here ──
  --
  -- `NOT NULL DEFAULT ''` rather than NULL-able: these are not optional facts that might not
  -- apply, they are required fields that have not been filled in yet, and the endpoint
  -- refuses a booking while any of the required ones is blank. Empty string says "not yet
  -- entered"; NULL would say "does not apply", which is never true here.
  `sender_name`         VARCHAR(150) NOT NULL DEFAULT '',
  `sender_company`      VARCHAR(150) NOT NULL DEFAULT '',
  `sender_phone`        VARCHAR(30)  NOT NULL DEFAULT '',
  `sender_email`        VARCHAR(190) NOT NULL DEFAULT '',
  `sender_address_1`    VARCHAR(200) NOT NULL DEFAULT '',
  `sender_address_2`    VARCHAR(200) NOT NULL DEFAULT '',
  `sender_city`         VARCHAR(100) NOT NULL DEFAULT '',
  `sender_postcode`     VARCHAR(10)  NOT NULL DEFAULT '',
  -- The LETTER code. See the header.
  `sender_state_code`   VARCHAR(8)   NOT NULL DEFAULT '',
  `sender_country_code` CHAR(2)      NOT NULL DEFAULT 'MY',

  -- How many days ahead a booking asks the courier to collect.
  --
  -- `collection_date` is REQUIRED on `submit_orders` and it is a real commitment: the courier
  -- turns up. Today would mean a parcel booked at 18:00 was promised for collection that
  -- evening, and the 7-day cancellation window is measured from this date. 1 means tomorrow,
  -- which is the assumption the endpoint would otherwise hardcode - and a hardcoded business
  -- decision is one nobody can change without a deployment.
  `collection_lead_days` TINYINT UNSIGNED NOT NULL DEFAULT 1,

  -- ── The connection probe ──
  --
  -- The same three columns `erp_myinvoice_integration` carries, for the same reason: a test
  -- result that is not stored is a test the operator has to repeat to remember.
  `last_test`    DATETIME NULL DEFAULT NULL,
  `test_status`  ENUM('success','failed') NULL DEFAULT NULL,
  `test_message` TEXT     NULL DEFAULT NULL,

  `updated_by` VARCHAR(150) NULL DEFAULT NULL,
  `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 2. The row itself ──
--
-- Created here rather than lazily on first read. `getSettingsRow()` creates `system_settings`
-- on demand, which works but means the first GET of a fresh install performs a write - and a
-- GET that writes is a GET that fails behind a read-only replica. Every default is in the
-- DDL above, so this is the whole row.
INSERT IGNORE INTO `easyparcel_integration` (`id`) VALUES (1)

-- >>>
-- ── 3. The permissions ──
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('integration-easyparcel', 'view', 'integration-easyparcel_view', 'Read the EasyParcel courier configuration',   'settings'),
  ('integration-easyparcel', 'edit', 'integration-easyparcel_edit', 'Change the EasyParcel courier configuration', 'settings'),
  ('integration-easyparcel', 'test', 'integration-easyparcel_test', 'Probe the EasyParcel connection',             'settings')

-- >>>
-- ── 3a. Grant them to Super Admin ──
--
-- The SERVER has a Super Admin bypass; the CLIENT does not. `IntegrationLayout` filters its
-- ribbon on `hasPermission('integration-easyparcel_view')`, which joins through
-- `role_permissions` - so without this the TAB ITSELF is invisible, which reads as the
-- feature not having shipped.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` = 'integration-easyparcel'

-- >>>
-- ── 4. Report what landed ──
--
-- `encryption_ready` is not here and cannot be: whether `ENCRYPTION_KEY` is set is a
-- property of the deployment environment, not of the database. The tab reports it, from
-- `encryptionConfigured()`.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'easyparcel_integration')  AS integration_table,
  (SELECT COUNT(*) FROM `easyparcel_integration`)                               AS integration_rows,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'easyparcel_integration')  AS column_count,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'integration-easyparcel') AS permissions,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` = 'integration-easyparcel')                                 AS granted_to_super_admin
