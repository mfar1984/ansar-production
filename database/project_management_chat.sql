-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — peserta, perbualan, bacaan, dan log fasa
--
-- Spec: .kiro/specs/project-management/  (Task 4)
-- Bergantung pada: database/project_management_schema.sql
--
-- Empat table, kesemuanya BAHARU, jadi tiada apa yang sudah wujud terdedah kepada
-- risiko. Ia bentuk asas chat: siapa boleh bercakap, apa yang dikatakan, apa yang
-- sudah dibaca, dan bila satu fasa ditutup.
--
-- IDEMPOTENT SECARA BINAAN. Lima pernyataan: empat `CREATE TABLE IF NOT EXISTS` dan
-- satu SELECT verifikasi. Tiada ALTER, tiada PREPARE/EXECUTE, tiada data disemai.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_chat.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── SIAPA yang terlibat dalam satu projek ──
--
-- `party_type` mendiskriminasikan dua identiti yang pangkalan data ini pegang secara
-- berasingan dan tidak pernah gabungkan: `employees` dan `client_users`. TEPAT SATU
-- daripada `employee_id` dan `client_user_id` ditetapkan.
--
-- `can_message` BERASINGAN daripada sekadar menjadi peserta. Seorang jurutera boleh
-- disenaraikan pada satu projek untuk laporan sumber tanpa diberi kuasa menulis kepada
-- client. Dan seorang wakil client boleh dinamakan tanpa diberi akses chat semasa satu
-- pertikaian. Ia pintu ke bilik socket `project_<id>`, dan SERVER yang membacanya —
-- bukan browser. `server.js` mengesahkan event `join` melalui `verifySessionHash`
-- tetapi setiap event LAIN tidak: `new_reply` membaca `data.clientId` terus daripada
-- payload tanpa semakan. Hari ini kosnya loceng palsu. Dengan kandungan mesej ia
-- menjadi suntikan teks ke dalam perbualan client yang sewenang-wenangnya.
--
-- ── DUA INDEKS UNIK, DAN BUKAN SATU. MYSQL YANG MEMUTUSKAN INI, DUA KALI. ──
--
-- Versi pertama menggunakan UNIQUE (project_id, party_type, employee_id, client_user_id)
-- dan komennya mendakwa itu menghalang client yang sama ditambah dua kali. DIUJI, dan
-- ia TIDAK: MySQL menganggap NULL sebagai BERBEZA dalam indeks unik, jadi dua baris
-- (99, 'client', NULL, 1) dan (99, 'client', NULL, 1) kedua-duanya DITERIMA kerana
-- `employee_id` NULL pada kedua-duanya. Dibuktikan dengan memasukkan peserta yang sama
-- dua kali dan melihat kedua-duanya berjaya.
--
-- Dua pembetulan dicuba dan DITOLAK oleh MySQL 8.0.45, kedua-duanya atas sebab yang
-- SERUPA — `client_user_id` ialah lajur FK dengan tindakan rujukan CASCADE:
--
--   1. CHECK `chk_pp_one_party` untuk memaksa tepat satu id ditetapkan:
--      ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN — Column
--      'client_user_id' cannot be used in a check constraint: needed in a foreign key
--      constraint 'fk_pp_client_user' referential action.
--
--   2. Lajur dihasilkan STORED `party_ref` = COALESCE(employee_id, client_user_id),
--      supaya indeks unik tidak mengandungi NULL:
--      ER_CANNOT_ADD_FOREIGN. Satu lajur asas bagi lajur STORED tidak boleh berada
--      dalam FK yang mempunyai ON DELETE/ON UPDATE CASCADE.
--
-- VIRTUAL diterima, dan indeks unik atas VIRTUAL juga diterima — itu juga diukur. Ia
-- TIDAK digunakan, dan sebabnya bukan kesederhanaan: satu indeks atas
-- (project_id, party_type, party_ref) mengunci pada `party_type`, jadi satu baris yang
-- tersalah label 'employee' dengan `client_user_id` ditetapkan akan LEPAS. Itu tepat
-- baris rosak yang CHECK sepatutnya tangkap dan tidak boleh.
--
-- Yang digunakan ialah DUA indeks unik, setiap satu merangkumi SATU lajur nullable:
--
--   uq_pp_employee (project_id, employee_id)     — menolak pekerja yang sama dua kali
--   uq_pp_client   (project_id, client_user_id)  — menolak client yang sama dua kali
--
-- Ia berfungsi kerana NULL adalah BERBEZA — perangai yang sama yang merosakkan versi
-- pertama, kini digunakan sebagai alat. Pada satu baris client, `employee_id` ialah
-- NULL, jadi `uq_pp_employee` tidak mengikatnya; `uq_pp_client` yang mengikatnya. Pada
-- satu baris pekerja, sebaliknya.
--
-- Diukur, enam sisipan, empat diterima:
--   client 1 pada projek 99          DITERIMA
--   client 1 pada projek 99 lagi     DITOLAK  ER_DUP_ENTRY
--   employee 1 pada projek 99        DITERIMA
--   employee 1 pada projek 99 lagi   DITOLAK  ER_DUP_ENTRY
--   employee 2 pada projek 99        DITERIMA
--   client 1 pada projek 100         DITERIMA
--
-- Ia juga lebih kuat daripada indeks tunggal: ia tidak bergantung pada `party_type`
-- sama sekali.
--
-- ── CASCADE DIPILIH BERBANDING CHECK, JADI `party_type` MEMIKUL BEBAN ──
--
-- Kerana CHECK tidak boleh wujud bersama cascade, invarian satu-pihak dikuatkuasakan
-- oleh endpoint dalam Task 8, dan `join_project` menapis pada `party_type` DAHULU:
--
--   WHERE project_id = ? AND can_message = 1
--     AND ((party_type = 'client'   AND client_user_id = ?)
--       OR (party_type = 'employee' AND employee_id    = ?))
--
-- Diskriminator itu menyahtaksakan tanpa CHECK, DENGAN SYARAT setiap query menapis
-- atasnya. Itu menjadikan `party_type` MEMIKUL BEBAN, dan
-- `tests/sql/project-management.test.js` menegaskan tiada query menyentuh table ini
-- tanpanya.
--
-- Cascade pula bukan kemudahan: tanpanya, memadam akaun client meninggalkan baris
-- peserta yang menunjuk ke akaun yang tiada, dan baris itu masih mempunyai
-- `can_message = 1`. `helpdesk_tickets.client_id` sudah menggunakan cascade atas sebab
-- yang sama.
--
-- `employees` TIDAK mendapat FK: seorang pekerja yang keluar dari syarikat tidak
-- sepatutnya memadam rekod bahawa dia ada dalam projek itu. `client_users.id`,
-- `employees.id` dan `projects.id` kesemuanya `int` BERTANDA — diukur — jadi FK di
-- bawah berada DALAM `CREATE TABLE` dan bukan dalam satu ALTER berpengawal.
CREATE TABLE IF NOT EXISTS `project_participants` (
  `id`             INT NOT NULL AUTO_INCREMENT,
  `project_id`     INT NOT NULL,
  `party_type`     ENUM('employee','client') NOT NULL
                   COMMENT 'MEMIKUL BEBAN: setiap query mesti menapis atasnya. Lihat nota di atas',
  `employee_id`    INT NULL DEFAULT NULL,
  `client_user_id` INT NULL DEFAULT NULL,
  `role`           VARCHAR(80) NOT NULL DEFAULT ''
                   COMMENT 'Project Manager, Site Engineer, Client Representative',
  `can_message`    TINYINT(1) NOT NULL DEFAULT 1
                   COMMENT 'pintu ke bilik socket project_<id>. join_project membaca lajur INI',
  `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pp_employee` (`project_id`, `employee_id`),
  UNIQUE KEY `uq_pp_client` (`project_id`, `client_user_id`),
  KEY `idx_pp_project` (`project_id`),
  KEY `idx_pp_employee` (`employee_id`),
  KEY `idx_pp_client` (`client_user_id`),
  KEY `idx_pp_can_message` (`project_id`, `can_message`),
  CONSTRAINT `fk_pp_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pp_client_user` FOREIGN KEY (`client_user_id`)
    REFERENCES `client_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── APA yang dikatakan ──
--
-- Bentuknya diambil daripada `helpdesk_replies` (`database/create_helpdesk_system.sql`),
-- SATU-SATUNYA model thread mesej dalam aplikasi ini, hampir lajur demi lajur:
-- sender_type, sender_id, nama yang dicache, mesej, lampiran JSON, satu bendera
-- dalaman, created_at.
--
-- `sender_name` dicache pada baris, sama seperti `helpdesk_replies.replied_by_name`.
-- Itu penyahnormalan yang disengajakan: satu thread mesti kekal boleh dibaca selepas
-- akaun penghantar dipadam, dan JOIN kepada dua table identiti berbeza bergantung pada
-- `sender_type` akan menjadi dua LEFT JOIN pada setiap bacaan thread.
--
-- `is_internal` ialah satu-satunya bendera keterlihatan, mengikut
-- `helpdesk_replies.is_internal_note`. Penapisan berlaku DALAM SQL pada endpoint
-- client, bukan dalam browser: satu tab yang disembunyikan bermakna data itu tetap
-- dihantar.
--
-- TIADA lajur `updated_at` dan tiada pemadaman lembut, juga mengikut
-- `helpdesk_replies`. Satu mesej dalam perbualan yang client sudah baca bukan
-- dokumen — menyuntingnya bermakna menulis semula rekod, dan `project_chat_delete`
-- ialah kebenaran berasingan atas sebab itu.
CREATE TABLE IF NOT EXISTS `project_messages` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `project_id`  INT NOT NULL,
  `sender_type` ENUM('admin','employee','client') NOT NULL,
  `sender_id`   INT NULL DEFAULT NULL
                COMMENT 'employees.id atau client_users.id. NULL untuk admin, kerana admin_sessions tiada id admin',
  `sender_name` VARCHAR(255) NOT NULL
                COMMENT 'dicache supaya thread kekal boleh dibaca selepas akaun dipadam',
  `message`     TEXT NOT NULL,
  `attachments` JSON NULL DEFAULT NULL,
  `is_internal` TINYINT(1) NOT NULL DEFAULT 0
                COMMENT 'client tidak pernah melihat baris ini. Ditapis DALAM SQL, bukan dalam browser',
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pm_project` (`project_id`, `id`),
  KEY `idx_pm_project_public` (`project_id`, `is_internal`, `id`),
  KEY `idx_pm_created` (`created_at`),
  CONSTRAINT `fk_pm_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── APA yang sudah dibaca ──
--
-- Lajur yang `helpdesk_replies` tidak ada. Akibatnya boleh dilihat hari ini:
-- `NotificationBell.tsx:53` mengira `notifications.filter(n => !n.read).length` DALAM
-- INGATAN, jadi kiraan belum-baca hilang setiap kali halaman dimuat semula. Satu
-- carian menyeluruh untuk `unread` dalam schema memulangkan sifar lajur.
--
-- Untuk satu loceng notifikasi itu boleh dimaafkan. Untuk satu chat ia tidak: kiraan
-- belum-baca ialah sebab seseorang membuka perbualan itu.
--
-- SATU baris per pembaca per projek, menyimpan id mesej TERAKHIR yang mereka lihat.
-- Bukan satu baris per mesej per pembaca: pada seratus mesej dan lima peserta itu lima
-- ratus baris untuk menjawab satu soalan, dan soalan itu sentiasa "berapa banyak
-- selepas tanda saya".
--
-- Kiraan belum-baca menjadi:
--   SELECT COUNT(*) FROM project_messages
--    WHERE project_id = ? AND id > COALESCE(<last_read_message_id>, 0)
--
-- `reader_type` dan `reader_id` dan bukan FK, kerana ia menunjuk ke TIGA table
-- identiti berbeza bergantung pada `reader_type`, dan satu lajur tidak boleh mempunyai
-- tiga foreign key.
--
-- ── `reader_id` UNTUK ADMIN IALAH `admins.id`, BUKAN 0 ──
--
-- Versi pertama komen ini berkata 0, dengan alasan `admin_sessions` tiada lajur id
-- admin. Alasan itu SALAH untuk endpoint HTTP. `resolveAdmin()` dalam
-- `src/lib/api-guard.ts` mencari `admins WHERE username = ?` dan memulangkan
-- `adminId`, jadi setiap permintaan HTTP memang ada id admin.
--
-- Yang tiada id admin ialah `deploy/session-verify.js`, kerana ia membaca
-- `admin_sessions` sahaja — dan ia tidak pernah menulis tanda bacaan. Ia hanya
-- memutuskan keahlian bilik socket.
--
-- 0 untuk semua admin akan bermakna SATU tanda bacaan dikongsi: admin A membuka
-- perbualan dan lencana belum-baca admin B hilang, tanpa B pernah melihatnya. Itu
-- tepat kegagalan yang table ini wujud untuk mengelak.
--
-- `('admin', 5)` dan `('employee', 5)` ialah baris BERBEZA, kerana `reader_type` ada
-- dalam indeks unik.
--
-- `uq_pmr_reader` tidak mengandungi lajur nullable, jadi ia menolak pendua tanpa
-- helah — tidak seperti `project_participants` di atas.
CREATE TABLE IF NOT EXISTS `project_message_reads` (
  `id`                   INT NOT NULL AUTO_INCREMENT,
  `project_id`           INT NOT NULL,
  `reader_type`          ENUM('admin','employee','client') NOT NULL,
  `reader_id`            INT NOT NULL DEFAULT 0
                         COMMENT 'admins.id, employees.id atau client_users.id, mengikut reader_type',
  `last_read_message_id` INT NOT NULL DEFAULT 0,
  `updated_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pmr_reader` (`project_id`, `reader_type`, `reader_id`),
  CONSTRAINT `fk_pmr_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── BILA satu fasa ditutup ──
--
-- Lima Process Group PMBOK ialah satu lajur `phase` pada `projects`, dan itu menjawab
-- DI MANA projek itu sekarang. Ia tidak boleh menjawab bila ia tiba di sana, siapa
-- memutuskan, atau mengapa — iaitu setiap soalan yang audit tanya selepas itu.
--
-- Bentuk yang sama seperti `asset_disposals` kepada `assets.status`: status berkata di
-- mana benda itu, table log berkata bagaimana ia tiba di sana.
--
-- `closed_by` ialah nama pengguna daripada sesi, bukan satu id, atas sebab yang sama
-- `project_messages.sender_id` boleh NULL: `admin_sessions` tidak mempunyai id admin.
CREATE TABLE IF NOT EXISTS `project_phase_log` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `project_id` INT NOT NULL,
  `from_phase` ENUM('initiation','planning','executing','monitoring','closing') NOT NULL,
  `to_phase`   ENUM('initiation','planning','executing','monitoring','closing') NOT NULL,
  `closed_by`  VARCHAR(191) NOT NULL
               COMMENT 'nama pengguna daripada sesi. admin_sessions tiada id admin',
  `remark`     TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ppl_project` (`project_id`, `id`),
  CONSTRAINT `fk_ppl_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan, satu baris per table:
--   project_participants   cols 8   fks 2   uniques 2
--   project_message_reads  cols 6   fks 1   uniques 1
--   project_messages       cols 9   fks 1   uniques 0
--   project_phase_log      cols 7   fks 1   uniques 0
--
-- `uniques` tidak mengira PRIMARY: information_schema melabelkannya 'PRIMARY KEY'.
SELECT t.TABLE_NAME,
       (SELECT COUNT(*) FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME) AS cols,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'FOREIGN KEY') AS fks,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'UNIQUE') AS uniques
  FROM information_schema.TABLES t
 WHERE t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_NAME IN ('project_participants','project_messages',
                        'project_message_reads','project_phase_log')
 ORDER BY t.TABLE_NAME
