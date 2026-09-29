-- ══════════════════════════════════════════════════════════════════════════════
-- SETIAP PERALIHAN FASA PROJEK PERLU DILULUSKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec: `.kiro/specs/project-management/` (Task 42)
--
-- Satu jadual baharu, empat kebenaran baharu. Tiada lajur ditambah pada `projects`.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- PENGGUNA PILIH "SETIAP PERALIHAN", DAN DATA MENYOKONGNYA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Diminta dari skrin. Saya syorkan hanya gate `closing` dan pengguna pilih kelima-
-- limanya. Saya bersandar pada "136 baris log fasa" untuk membantah, dan apabila
-- nombor itu dipecahkan ia membatalkan bantahan saya sendiri:
--
--   initiation -> planning     37
--   planning   -> executing    33
--   executing  -> monitoring    23
--   monitoring -> closing       22
--   closing    -> closing       21   (penutupan akhir)
--
-- SIFAR peralihan ke belakang. Setiap gerakan ke hadapan, satu langkah, sekali
-- sahaja. 21 projek buat kelima-lima gerakan — laluan penuh. Jadi seumur hidup satu
-- projek ada PALING BANYAK lima kelulusan, bukan aliran harian seperti yang saya
-- bayangkan. Pilihan pengguna betul dan hujah saya salah.
--
-- `closing -> closing` ialah sebabnya ada LIMA gate dan bukan empat: menandatangani
-- gate Closing ialah keputusan berasingan daripada memasuki Closing.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA JADUAL BARUHAN, DAN BUKAN MENDAFTARKAN `projects` TERUS
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Komen dalam `src/pages/api/admin/operations/projects/[id]/phase.ts` sendiri
-- meramalkan bahawa `projects` akan menyertai engine "dengan peta `statusWords`".
-- RAMALAN ITU SALAH, dan fail ini ialah tempat ia dibetulkan.
--
-- `applyApprovalAction` dalam `src/lib/approval-flow.ts` mengekod tetap tiga
-- pernyataan berbentuk:
--
--   UPDATE <table> SET status = ?, current_level = ? WHERE id = ?
--
-- `statusWords` hanya menukar PERKATAAN yang ditulis ke dalam `status`. Ia tidak
-- boleh mengalihkan tulisan itu ke lajur lain. Jadi mendaftarkan `projects` terus
-- akan menghasilkan dua kerosakan:
--
--   1. `projects.status` ialah enum('planning','ongoing','completed','on-hold') —
--      perkataan AWAM, diterbitkan daripada `phase` oleh `statusFromPhase()` dan
--      dibaca oleh halaman awam. Engine menulis `pending`/`approved` ke situ
--      bermakna satu lajur memegang dua makna yang bertelagah, dan MySQL akan
--      menolak perkataan yang bukan ahli ENUM itu.
--   2. Satu projek melalui LIMA gate berturutan. Satu `current_level` pada baris
--      projek tidak boleh membezakan "level 2 gate executing" daripada "level 2
--      gate closing". Permintaan kedua akan mewarisi kiraan permintaan pertama.
--
-- Jadi bentuknya ialah JADUAL PERMINTAAN, sama seperti `asset_loan_requests` dan
-- `petty_cash_requests`: satu baris per permintaan, dengan `status` dan
-- `current_level` milik permintaan itu sendiri. Register hanya bergerak apabila
-- rantaian selesai — corak yang `assets/disposals.ts` sudah rekodkan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `status` GUNA PERBENDAHARAAN ENGINE SENDIRI, JADI TIADA `statusWords`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- enum('pending','approved','rejected') — tepat tiga perkataan yang engine tulis.
-- `asset_disposals` dan `asset_loan_requests` buat perkara yang sama; `applicants`
-- dan `market_place` perlukan peta kerana lajur mereka ialah kitaran hayat lain.
--
-- Ada sebab kedua yang lebih keras: `src/pages/api/admin/hr/approval.ts` pada
-- laluan DELETE menarik balik baris terkandas dengan
-- `WHERE status = 'pending'` — satu literal. Modul yang menggunakan perkataan
-- `pending` tersendiri akan DILANGKAU di situ secara senyap.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- SATU PROJEK, SATU PERMINTAAN MENUNGGU — DAN IA TRIGGER, BUKAN LAJUR TERJANA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Dua permintaan gate menunggu pada satu projek ialah karut: gate mana yang sedang
-- ditunggu? MySQL tiada unique separa, jadi percubaan pertama menggunakan lajur
-- terjana — corak yang skema ini sudah guna pada `active_env_guard` dan
-- `operating_guard`:
--
--   pending_guard = IF(status = 'pending', project_id, NULL) STORED, dengan UNIQUE
--
-- IA TIDAK BOLEH DIGABUNGKAN DENGAN `ON DELETE CASCADE`, dan ini DIUJI dan bukan
-- diteka. Tiga CREATE TABLE dijalankan sebagai eksperimen:
--
--   lajur terjana + ON DELETE CASCADE    -> ER_CANNOT_ADD_FOREIGN
--   tiada lajur terjana + CASCADE        -> lulus
--   lajur terjana + ON DELETE RESTRICT   -> lulus
--
-- MySQL melarang CASCADE, SET NULL dan SET DEFAULT pada lajur asas bagi satu lajur
-- terjana tersimpan. Jadi ia satu pilihan antara dua, dan CASCADE menang:
--
--   RESTRICT bermakna satu projek yang pernah ada SEBARANG permintaan gate tidak
--   boleh dibuang lagi, selama-lamanya. `project_phase_log` sendiri cascade, jadi
--   RESTRICT di sini juga akan bercanggah dengan jadual jejak di sebelahnya.
--
-- Jadi pengawal itu menjadi TRIGGER. Ia mengekalkan jaminan peringkat pangkalan
-- data, dan skema ini sudah ada empat trigger `SIGNAL` — `trg_asdoc_one_source_ins`
-- ialah bentuk yang sama untuk soalan yang sama.
--
-- Diuji: pending pertama lulus, baris `approved` kedua pada projek yang sama lulus,
-- pending KEDUA ditolak dengan `ER_SIGNAL_EXCEPTION` dan kiraan baris tidak berubah.
-- Satu trigger boleh `SELECT` daripada jadualnya sendiri dalam MySQL; itu juga diuji
-- dan bukan diandaikan.
--
-- Endpoint memeriksanya juga di bawah `FOR UPDATE`: endpoint menolak itu budi
-- bahasa, pangkalan data menolak itu peraturan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `ON DELETE CASCADE`, DAN DI SINI IA BETUL
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Berbeza daripada `projects.customer_id` dan `client_users.customer_id`, yang
-- kedua-duanya SET NULL kerana benda yang dipautkan ada kewujudan tersendiri.
-- Satu permintaan gate TIDAK: ia permintaan TENTANG satu projek dan tiada makna
-- tanpanya. `project_phase_log` menggunakan CASCADE atas sebab yang sama.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- KEBENARAN: `project_approval` DAN `project_notifications` PERLU EMPAT, ADA DUA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Diukur:
--
--   project_approval                edit, view                 (2)
--   project_notifications           edit, view                 (2)
--   asset_disposal_approval         create, delete, edit, view  (4)
--   asset_disposal_notifications    create, delete, edit, view  (4)
--
-- `ApprovalWorkflow.tsx` menerbitkan butang Tambah dan Buangnya daripada
-- `${permModule}_create` dan `_delete`, dan `/api/admin/hr/approval` menuntut
-- `create` pada POST serta `delete` pada DELETE. Tanpa dua tindakan itu tab Gate
-- Approval akan render tanpa cara untuk menambah satu level — satu skrin yang
-- kelihatan rosak, bukan satu kebenaran untuk diminta.
--
-- `projects_delivery` sudah ada `approve` (5 tindakan), jadi tiada tindakan baharu
-- diperlukan untuk MEMUTUSKAN satu gate. Itu kekal kebenaran yang sama yang
-- menutup gate hari ini.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA BARIS `hr_module_settings` DISEMAI
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `NOTIFICATION_KEYS` dalam `src/lib/hr-module-settings.ts` membekalkan setiap
-- lalai, dan `getModuleSettings()` mengisinya apabila tidak ditetapkan. Baris
-- yang memegang tepat nilai lalai tidak bermakna apa-apa.
-- `asset_disposal_approval.sql` merekod keputusan yang sama. Nota ini ada supaya
-- ketiadaan itu dibaca sebagai keputusan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. Dijalankan dua kali memberi output yang sama.
-- Setiap ALTER dikawal melalui `information_schema` dan `PREPARE`, kerana MySQL
-- MELERAIKAN KEDUA-DUA CABANG satu `IF()` pada masa prepare — jadi satu `IF()`
-- yang menamakan jadual yang belum ada gagal sebelum pengawalnya dibaca.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── 1. Jadual permintaan ──
--
-- `CREATE TABLE IF NOT EXISTS` mencukupi di sini: tiada apa-apa untuk ditampal
-- pada jadual yang sudah ada, dan larian kedua tidak sepatutnya mengubah apa-apa.
CREATE TABLE IF NOT EXISTS `project_phase_requests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `project_id` INT NOT NULL,

  -- Fasa yang sama seperti `project_phase_log`, supaya jejak dan permintaan tidak
  -- boleh bercakap tentang perbendaharaan yang berbeza.
  `from_phase` ENUM('initiation','planning','executing','monitoring','closing') NOT NULL,
  `to_phase`   ENUM('initiation','planning','executing','monitoring','closing') NOT NULL,

  -- `advance` menggerakkan satu fasa. `complete` menandatangani gate Closing dan
  -- menetapkan `projects.status = 'completed'`.
  --
  -- Lajur ini WAJIB ada: bagi `complete`, `from_phase` dan `to_phase` KEDUA-DUANYA
  -- `closing`, jadi pasangan itu sendiri tidak boleh membezakan penutupan akhir
  -- daripada satu permintaan yang tidak bergerak. `project_phase_log` menyimpan
  -- pasangan yang sama atas sebab yang sama dan merekodkannya.
  `action` ENUM('advance','complete') NOT NULL DEFAULT 'advance',

  -- Tepat tiga perkataan yang engine tulis. Lihat nota di atas.
  `status` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',

  -- 0 bermakna tiada siapa menandatangani. `checkApproverTurn` membacanya, jadi ia
  -- tidak boleh diterbitkan daripada jejak: satu permintaan yang belum ditandatangani
  -- ada SIFAR baris jejak dan masih perlu menyatakan level mana ia menunggu.
  `current_level` INT UNSIGNED NOT NULL DEFAULT 0,

  -- Nama log masuk, sama seperti `project_phase_log.closed_by`. Bukan foreign key:
  -- ia BUKTI siapa meminta, dan akaun yang dibuang tidak sepatutnya memadam rekod itu.
  `requested_by` VARCHAR(150) NULL,
  `remark` TEXT NULL,

  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  -- Satu projek boleh memegang paling banyak SATU permintaan menunggu, dan itu
  -- dikuatkuasakan oleh dua trigger di bawah dan bukan oleh satu unique. Lihat nota
  -- di atas: satu lajur terjana tidak boleh hidup bersama `ON DELETE CASCADE`.
  KEY `idx_ppr_project` (`project_id`, `created_at`),
  -- Pertanyaan panas skrin kelulusan: semua yang menunggu, dan level mana.
  KEY `idx_ppr_pending` (`status`, `current_level`),
  -- ── `ON DELETE CASCADE` SAHAJA, DAN `ON UPDATE CASCADE` DITINGGALKAN DENGAN SEBAB ──
  --
  -- Larian pertama fail ini gagal dengan `ER_CANNOT_ADD_FOREIGN`, dan puncanya bukan
  -- ketidakpadanan jenis: `projects.id` ialah `int` bertanda dan
  -- `project_phase_log.project_id` memaut kepadanya dengan CASCADE/CASCADE tanpa
  -- masalah.
  --
  -- Puncanya ialah `pending_guard` di atas. Ia lajur terjana TERSIMPAN yang MEMBACA
  -- `project_id`, dan MySQL melarang `ON UPDATE CASCADE` pada lajur yang dirujuk oleh
  -- satu lajur terjana. `ON DELETE CASCADE` dibenarkan kerana ia membuang seluruh
  -- baris, jadi nilai terjana itu pergi bersamanya.
  --
  -- Tiada apa yang hilang. `projects.id` ialah `AUTO_INCREMENT` dan tidak pernah
  -- dikemas kini, jadi `ON UPDATE CASCADE` di sini memang beban mati —
  -- `project_phase_log` memegangnya dan tidak pernah melaksanakannya.
  CONSTRAINT `fk_ppr_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Satu permintaan untuk menutup satu gate fasa. Register bergerak hanya bila rantaian selesai.'

-- >>>
-- ── 2. `chk_ppr_forward` — satu permintaan tidak boleh menamakan gerakan ke belakang ──
--
-- Gate ke hadapan sahaja, dan pengukuran menyokongnya: SIFAR daripada 136 gerakan
-- pada produksi pergi ke belakang. Gerakan ke belakang ialah PEMBALIKAN, bukan gate
-- yang ditutup, dan ia perlu rekod serta kuasanya sendiri — `phase.ts` sudah
-- merekodkan keputusan itu dan tidak menawarkannya.
--
-- `advance`  : tepat satu langkah ke hadapan, empat pasangan.
-- `complete` : kedua-duanya `closing`.
--
-- Kelima-lima pasangan DISENARAIKAN dan bukan dikira dengan `FIELD()`. Aritmetik
-- atas kedudukan ENUM lebih pendek dan lebih teruk: pembaca terpaksa mempercayai
-- urutan pengisytiharan, dan menyusun semula ENUM itu suatu hari akan menukar makna
-- kekangan ini tanpa menyentuh fail ini. Disenaraikan, seluruh kitaran hayat
-- kelihatan di sini dan ia memadankan matriks yang diukur baris demi baris.
SET @ppr_chk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE()
     AND CONSTRAINT_NAME = 'chk_ppr_forward'
)

-- >>>
SET @sql := IF(@ppr_chk = 0,
  'ALTER TABLE `project_phase_requests`
     ADD CONSTRAINT `chk_ppr_forward` CHECK (
       (`action` = ''advance'' AND (
            (`from_phase` = ''initiation'' AND `to_phase` = ''planning'')
         OR (`from_phase` = ''planning''   AND `to_phase` = ''executing'')
         OR (`from_phase` = ''executing''  AND `to_phase` = ''monitoring'')
         OR (`from_phase` = ''monitoring'' AND `to_phase` = ''closing'')
       ))
       OR (`action` = ''complete'' AND `from_phase` = ''closing'' AND `to_phase` = ''closing'')
     )',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ════════════════════════════════════════════════════════════════════════════
-- 3. SATU PERMINTAAN MENUNGGU PER PROJEK — DUA TRIGGER
-- ════════════════════════════════════════════════════════════════════════════
--
-- `DROP` dahulu supaya fail ini idempotent: `CREATE TRIGGER` tiada bentuk
-- `IF NOT EXISTS`. Bentuk yang sama seperti `trg_asdoc_one_source_ins` dalam
-- `asset_sites_models.sql`.
DROP TRIGGER IF EXISTS `trg_ppr_one_pending_ins`

-- >>>
CREATE TRIGGER `trg_ppr_one_pending_ins`
BEFORE INSERT ON `project_phase_requests`
FOR EACH ROW
BEGIN
  IF NEW.`status` = 'pending' AND EXISTS (
    SELECT 1 FROM `project_phase_requests`
     WHERE `project_id` = NEW.`project_id` AND `status` = 'pending'
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This project already has a gate request waiting for approval. Decide that one first.';
  END IF;
END

-- >>>
-- Kenapa UPDATE juga: satu permintaan yang sudah DITOLAK boleh dikembalikan kepada
-- `pending` oleh satu UPDATE, dan itu akan memintas trigger INSERT sepenuhnya.
-- `id <> NEW.id` mengecualikan baris itu sendiri, jika tidak setiap UPDATE pada satu
-- baris yang menunggu akan menolak dirinya sendiri.
DROP TRIGGER IF EXISTS `trg_ppr_one_pending_upd`

-- >>>
CREATE TRIGGER `trg_ppr_one_pending_upd`
BEFORE UPDATE ON `project_phase_requests`
FOR EACH ROW
BEGIN
  IF NEW.`status` = 'pending' AND EXISTS (
    SELECT 1 FROM `project_phase_requests`
     WHERE `project_id` = NEW.`project_id` AND `status` = 'pending' AND `id` <> NEW.`id`
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This project already has a gate request waiting for approval. Decide that one first.';
  END IF;
END

-- >>>
-- ── 4. Kebenaran ──
--
-- `project_approval` dan `project_notifications` masing-masing ada `view` dan
-- `edit` sahaja. Mereka mendapat `create` dan `delete`, memadankan
-- `asset_disposal_approval` dan setiap adik-beradik kelulusan yang lain.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_approval',      'create', 'project_approval_create',
   'Tambah satu level kelulusan gate projek', 'operations'),
  ('project_approval',      'delete', 'project_approval_delete',
   'Buang satu level kelulusan gate projek', 'operations'),
  ('project_notifications', 'create', 'project_notifications_create',
   'Tambah tetapan notifikasi projek', 'operations'),
  ('project_notifications', 'delete', 'project_notifications_delete',
   'Buang tetapan notifikasi projek', 'operations')

-- >>>
-- ── 4a. Berikannya kepada Super Admin ──
--
-- PELAYAN ada pintasan Super Admin; KLIEN tiada. `usePermissions` menyertai melalui
-- `role_permissions`, jadi satu kebenaran yang tidak diberi menjadikan kawalan itu
-- TIDAK KELIHATAN dan bukan ditolak — yang dibaca sebagai skrin rosak.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`module` IN ('project_approval', 'project_notifications')

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  tbl 1   fwd_chk 1   triggers 2   fk_cascade 1   approval_perms 4
--            notify_perms 4   granted 8   pending_now 0
--
-- `fk_cascade 1` ialah baris yang penting di sini, dan ia BERTENTANGAN dengan dua
-- migrasi terakhir dengan sengaja: satu permintaan gate tiada kewujudan tanpa
-- projeknya, jadi CASCADE betul di sini walaupun SET NULL betul di sana.
--
-- `triggers 2` ialah yang kedua penting. SATU trigger tidak mencukupi: tanpa yang
-- BEFORE UPDATE, satu permintaan yang ditolak boleh dikembalikan kepada `pending`
-- dan memintas pengawal sepenuhnya.
SELECT
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests')   AS tbl,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'chk_ppr_forward')                                    AS fwd_chk,
  (SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE TRIGGER_SCHEMA = DATABASE()
      AND EVENT_OBJECT_TABLE = 'project_phase_requests')                          AS triggers,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'fk_ppr_project'
      AND DELETE_RULE = 'CASCADE')                                                AS fk_cascade,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_approval')        AS approval_perms,
  (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_notifications')   AS notify_perms,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`module` IN ('project_approval', 'project_notifications'))            AS granted,
  (SELECT COUNT(*) FROM `project_phase_requests` WHERE `status` = 'pending')      AS pending_now
