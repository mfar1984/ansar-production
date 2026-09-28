-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — leaf Settings
--
-- Spec: .kiro/specs/project-management/  (Task 35 — leaf Projects › Settings)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_tasks.sql  (project_tasks, untuk Apply)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- ENAM TAB DISPESIFIKASI. EMPAT DIBINA. DUA TIDAK PATUT DIBINA, DAN INI SEBABNYA.
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Leaf ini membawa `anyPerm` enam modul, satu per tab:
--
--   tab              modul                   tindakan disemai      dibina?
--   Phases           project_phases          edit, view            YA
--   Categories       project_categories      CRUD penuh            YA
--   WBS Templates    project_templates       CRUD penuh            YA
--   Numbering        project_settings        edit, view            YA
--   Gate Approval    project_approval        edit, view            TIDAK
--   Notifications    project_notifications   edit, view            TIDAK
--
-- ── MENGAPA `Notifications` TIDAK DIBINA ──
--
-- Diukur pada pangkalan data ini: TIADA table notifikasi, TIADA baris giliran e-mel, TIADA
-- log e-mel. Sifar. Tiada apa dalam modul Project Management menghantar satu mesej kepada
-- sesiapa.
--
-- Jadi satu tab Notifications akan mengkonfigurasikan sesuatu yang tidak wujud. Ia akan
-- menerima satu alamat, menyimpannya, dan tiada apa akan membacanya — satu borang yang
-- kelihatan berfungsi dan tidak berbuat apa-apa. Itu lebih buruk daripada satu tab yang
-- dilumpuhkan, kerana tab yang dilumpuhkan mengatakan kebenaran.
--
-- Task 30 sudah membuat keputusan yang sama untuk sebab yang sama: tiada e-mel dihantar
-- bila satu laporan kemajuan diterbitkan, kerana `project_notifications` tiada table dan
-- tiada penghantar.
--
-- ── MENGAPA `Gate Approval` TIDAK DIBINA ──
--
-- Satu "gate" ialah sempadan antara dua fasa. `projects.phase` ialah ENUM lima nilai, jadi
-- ada EMPAT sempadan. Satu tab boleh mengkonfigurasikan sama ada melintasi setiap satu
-- memerlukan tandatangan, dan oleh siapa.
--
-- Masalahnya ialah tiada apa akan MENEGAKKANNYA. `projects.phase` ditulis hari ini oleh
-- `projects_delivery_edit` dan tiada satu pun semakan antara fasa. Jadi:
--
--   bina setting sahaja      → suis tanpa kunci di belakangnya. Itu masalah Notifications.
--   bina penegakan juga      → menukar cara daftar HIDUP menulis `phase`, dengan mod
--                              kegagalan "tiada siapa boleh mengalihkan projek lagi"
--
-- Yang kedua bukan kerja setting, ia kerja daftar, dan tiada siapa memintanya. Jadi tab itu
-- kekal dilumpuhkan dan tooltipnya MENAMAKAN halangan itu, bukan satu fasa.
--
-- ── DAN LEAF ITU MASIH JADI HIDUP ──
--
-- Empat daripada enam tab wujud, jadi lencana SOON hilang daripada sidebar dan dua tab
-- dipaparkan DILUMPUHKAN di dalam — tepat peraturan yang `ConfigLayout` sudah ikut, dan
-- yang sebabnya direkod di sana: satu tab yang boleh diklik tanpa halaman ialah cara
-- Activity Logs kelihatan rosak.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- LIMA TABLE, DAN SETIAP SATU MENIRU SESUATU YANG SUDAH ADA DI SINI
-- ═══════════════════════════════════════════════════════════════════════════════
--
--   project_categories       meniru `tender_categories` (id, name, icon, sort_order, is_active)
--   project_phase_settings   baharu, tetapi dikunci pada ENUM yang sudah ada
--   project_templates        meniru `kpi_templates`
--   project_template_items   meniru `kpi_template_items`
--   project_numbering        meniru `accounting_document_numbers` (44 baris, hidup)
--
-- Tiada satu pun daripada lima ini mencipta bentuk baharu. Itu penting: sembilan table
-- `*_categories` sudah ada dalam pangkalan data ini dengan lajur yang sama, dan yang
-- kesepuluh dengan bentuk sendiri ialah satu table yang tiada siapa boleh baca dengan
-- meneka.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `projects.category` TIDAK DISENTUH, DAN ITU KEPUTUSAN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `projects.category` ialah `varchar(100) NOT NULL` yang memegang NAMA. Ia kekal begitu.
--
-- Presedennya tepat: `tenders.category` juga varchar yang memegang nama, dan
-- `tender_categories` hanyalah SENARAI yang dropdown tawarkan. Endpointnya membawa satu
-- penjaga — satu kategori yang mana-mana tender namakan tidak boleh dipadam — dan endpoint
-- ini membawa penjaga yang sama terhadap `projects`.
--
-- Satu foreign key `category_id` dipertimbangkan dan DITOLAK: ia bermakna satu migrasi ke
-- atas `projects`, satu lajur baharu, satu backfill, dan menukar setiap query yang membaca
-- `p.category` — untuk integriti yang penjaga padam sudah berikan. `projects` kosong hari
-- ini, jadi backfill itu murah; tetapi query itu tidak, dan `/api/public/projects` membaca
-- lajur yang sama.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `project_phase_settings` TIDAK MENYIMPAN LABEL, DAN ITU SENGAJA
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `project_phases` menyemai DUA tindakan: `edit` dan `view`. Tiada `create`, tiada `delete`.
-- Itu bersetuju dengan skema: `projects.phase` ialah ENUM lima nilai tetap, jadi tiada fasa
-- boleh ditambah atau dibuang. Tab itu mengubah SIFAT lima itu.
--
-- Tetapi bukan LABELNYA. `PROJECT_PHASE_LABEL` dalam `src/lib/projects.ts` dibaca oleh lapan
-- skrin sebagai satu peta pemalar. Menjadikannya boleh dikonfigurasi bermakna lapan skrin
-- itu perlu MENGAMBILNYA daripada satu endpoint sebelum ia boleh melukis satu lencana — dan
-- satu lencana yang menunggu satu fetch ialah satu lencana yang berkelip.
--
-- Jadi yang boleh dikonfigurasi ialah tiga perkara yang TIDAK menyentuh satu pun daripada
-- lapan skrin itu:
--
--   description     ditunjukkan dalam pemilih fasa, supaya "monitoring" bermakna sesuatu
--   sort_order      susunan pemilih itu
--   is_selectable   bersara satu fasa tanpa memadamnya
--
-- `is_selectable` ialah yang berguna: matikan `monitoring` dan projek yang sudah berada di
-- dalamnya KEKAL di dalamnya, tetapi tiada projek baharu boleh masuk. Satu ENUM tidak boleh
-- menyatakan itu, dan memadam nilai ENUM akan mematahkan setiap baris yang memegangnya.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `project_numbering` — DAN MENGAPA IA TIDAK MENUKAR CARA NOMBOR DIJANA
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `nextReference()` dalam `src/lib/operations-db.ts` TIDAK mempunyai table pembilang. Ia
-- membaca MAX daripada table itu sendiri, ditapis `prefix-YYYY-%`, dan menambah satu. Dua
-- belas tapak panggilan menghantar prefix sebagai literal.
--
-- Lima daripadanya milik modul ini:
--
--   projects                  project_no    PRJ
--   project_changes           change_no     CHG
--   project_reports           report_no     RPT
--   project_ncrs              ncr_no        NCR
--   project_client_approvals  approval_no   APR
--
-- Table ini disemai dengan LIMA itu dan nilai yang sama yang sudah digunakan. Jadi pada hari
-- pertama tiada apa berubah — itulah ujiannya.
--
-- `nextReference` kini membaca table ini dan menggunakan prefix serta padding DI SITU kalau
-- satu baris ada. Argumen `prefix` yang dihantar menjadi DEFAULT, bukan digantikan. Tujuh
-- tapak panggilan lain tiada baris, jadi tingkah laku mereka tidak boleh berubah walau
-- sedikit.
--
-- ── SATU KESAN SAMPINGAN YANG DINYATAKAN, BUKAN DISEMBUNYIKAN ──
--
-- Kerana nombor seterusnya DITERBITKAN daripada MAX, menukar satu prefix di tengah tahun
-- memulakan satu siri baharu daripada 0001. `APR-2026-0007` kekal, dan yang seterusnya jadi
-- `PA-2026-0001`. Tiada pertembungan — unique masih ditegakkan — tetapi daftar itu kini
-- membawa dua siri.
--
-- Itu BUKAN bug yang diperkenalkan oleh table ini; ia sifat penerbitan MAX. Dan ia risiko
-- yang sama `accounting_document_numbers` sudah terima dengan 44 baris boleh sunting. Yang
-- table ini tambah ialah satu tempat untuk menukarnya dengan sengaja, bukannya satu
-- penyuntingan kod. Skrin memberitahu pembaca sebelum ia menyimpan.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Lima `CREATE TABLE IF NOT EXISTS`, dua `INSERT ... ON DUPLICATE KEY UPDATE id = id` untuk
-- benih, dan satu baris pengesahan. `id = id` ialah satu no-op yang sengaja: jalankan dua
-- kali dan benih itu TIDAK menimpa apa yang operator telah ubah.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Categories — senarai yang dropdown daftar tawarkan
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `project_categories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  -- UNIQUE pada nama, kerana nama ITULAH nilai yang `projects.category` simpan. Dua kategori
  -- bernama sama akan menjadikan penjaga padam tidak boleh memutuskan yang mana digunakan.
  `name` VARCHAR(100) NOT NULL,
  `icon` VARCHAR(40) NULL DEFAULT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  -- Bersara satu kategori tanpa memadamnya. Projek yang sudah menamakannya kekal sah; ia
  -- hanya hilang daripada pemilih.
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pcat_name` (`name`),
  KEY `idx_pcat_order` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. Phases — sifat lima nilai ENUM yang sudah ada
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `project_phase_settings` (
  `id` INT NOT NULL AUTO_INCREMENT,
  -- ENUM yang SAMA seperti `projects.phase`. Kalau kedua-duanya menyimpang, satu baris di
  -- sini akan menerangkan satu fasa yang tiada projek boleh berada di dalamnya.
  `phase` ENUM('initiation','planning','executing','monitoring','closing') NOT NULL,
  `description` VARCHAR(400) NULL DEFAULT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  -- Tiada label di sini. Lihat nota di atas: lapan skrin membaca `PROJECT_PHASE_LABEL`
  -- sebagai pemalar, dan satu lencana yang menunggu satu fetch ialah satu lencana berkelip.
  `is_selectable` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pph_phase` (`phase`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

-- Benih: lima fasa, dalam susunan kitaran hayat.
--
-- `id = id` menjadikan INSERT ini satu no-op pada larian kedua. Menimpa `description` akan
-- membuang apa yang operator tulis, dan satu migrasi yang memadam kerja tangan adalah
-- lebih buruk daripada satu yang tidak berjalan.
INSERT INTO `project_phase_settings` (`phase`, `description`, `sort_order`, `is_selectable`) VALUES
  ('initiation', 'Scope agreed and the contract signed. Nothing is being built yet.', 1, 1),
  ('planning',   'The plan is being written: tasks, dates, milestones and who does what.', 2, 1),
  ('executing',  'The work is being done. Most of a project lives here.', 3, 1),
  ('monitoring', 'Delivered and under watch: defects, inspections and the defect liability period.', 4, 1),
  ('closing',    'Handover, final documents and the last certificate. The plan is no longer changing.', 5, 1)
ON DUPLICATE KEY UPDATE `id` = `id`;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3 + 4. WBS Templates — satu senarai kerja standard, dan barisnya
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Meniru `kpi_templates` + `kpi_template_items`, yang sudah membawa 10 dan 65 baris. Satu
-- template ialah satu senarai bernama; satu item ialah satu task yang akan dicipta.

CREATE TABLE IF NOT EXISTS `project_templates` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(150) NOT NULL,
  `description` VARCHAR(400) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(191) NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ptpl_name` (`name`),
  KEY `idx_ptpl_active` (`is_active`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

CREATE TABLE IF NOT EXISTS `project_template_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `template_id` INT NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `notes` VARCHAR(400) NULL DEFAULT NULL,
  -- Nullable. Satu template yang mengatakan APA kerja itu tanpa mengatakan berapa lama ia
  -- mengambil masa masih berguna; memaksa satu tempoh akan menjadikan seseorang menaip 1.
  `duration_days` INT NULL DEFAULT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ptli_template` (`template_id`, `sort_order`),
  CONSTRAINT `fk_ptli_template` FOREIGN KEY (`template_id`)
    REFERENCES `project_templates` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  -- Sifar hari bukan satu tempoh, dan negatif akan menjadikan satu tarikh mundur bila
  -- template itu dikenakan.
  CONSTRAINT `chk_ptli_duration` CHECK (`duration_days` IS NULL OR `duration_days` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. Numbering — prefix dan padding untuk lima rujukan modul ini
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `project_numbering` (
  `id` INT NOT NULL AUTO_INCREMENT,
  -- Nama table, kerana itulah yang `nextReference` sudah terima sebagai argumen pertamanya.
  -- Mengunci pada nama table dan bukan satu kunci yang dicipta bermakna satu baris tidak
  -- boleh merujuk kepada sesuatu yang fungsi itu tidak boleh jana.
  `table_key` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `prefix` VARCHAR(20) NOT NULL,
  `padding` INT NOT NULL DEFAULT 4,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pnum_table` (`table_key`),
  -- Satu prefix kosong akan menjana `-2026-0001`, yang mana LIKE `-2026-%` juga memadankan
  -- setiap rujukan table lain yang mengandungi rentetan itu.
  CONSTRAINT `chk_pnum_prefix` CHECK (CHAR_LENGTH(TRIM(`prefix`)) BETWEEN 2 AND 20),
  -- Padding di bawah 2 memberi `APR-2026-1`, yang tidak akan disusun sebagai teks. Di atas 8
  -- ialah satu nombor yang tiada siapa akan capai.
  CONSTRAINT `chk_pnum_padding` CHECK (`padding` BETWEEN 2 AND 8)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

-- Benih: LIMA nilai yang sama yang kod sudah hantar hari ini. Diukur daripada setiap tapak
-- panggilan `nextReference`, bukan diteka.
--
-- Jadi pada hari pertama table ini tidak mengubah satu rujukan pun. Itulah ujiannya.
INSERT INTO `project_numbering` (`table_key`, `label`, `prefix`, `padding`) VALUES
  ('projects',                 'Project number',        'PRJ', 4),
  ('project_changes',          'Change request',        'CHG', 4),
  ('project_reports',          'Progress report',       'RPT', 4),
  ('project_ncrs',             'Non-conformance',       'NCR', 4),
  ('project_client_approvals', 'Client approval',       'APR', 4)
ON DUPLICATE KEY UPDATE `id` = `id`;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- PENGESAHAN — apa yang operator baca atas pelayan
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Jangkaan:  categories 0   phases 5   templates 0   items 0   numbering 5   checks 3
--
-- `phases 5` dan `numbering 5` ialah BENIH, jadi ia mesti tepat 5 setiap satu. Kalau
-- `numbering` bukan 5, `nextReference` akan jatuh kembali kepada literal untuk yang hilang
-- — tidak rosak, tetapi tab Numbering tidak akan memaparkan baris itu dan tiada siapa
-- boleh mengubahnya.
--
-- Kalau `phases` bukan 5, satu fasa tiada penerangan dan pemilih akan memaparkan satu
-- pilihan kosong.
--
-- `categories 0`, `templates 0` dan `items 0` ialah jangkaan pada pemasangan PERTAMA sahaja.
-- Selepas operator menambah kategori, nombor itu naik — dan itu betul. Yang penting ialah
-- table itu ADA, yang mana tiga kiraan itu buktikan dengan tidak gagal.
--
-- `checks 3` ialah `chk_ptli_duration`, `chk_pnum_prefix` dan `chk_pnum_padding` merentas
-- lima table itu.

SELECT (SELECT COUNT(*) FROM `project_categories`) AS categories,
       (SELECT COUNT(*) FROM `project_phase_settings`) AS phases,
       (SELECT COUNT(*) FROM `project_templates`) AS templates,
       (SELECT COUNT(*) FROM `project_template_items`) AS items,
       (SELECT COUNT(*) FROM `project_numbering`) AS numbering,
       (SELECT COUNT(*) FROM information_schema.table_constraints
         WHERE table_schema = DATABASE() AND constraint_type = 'CHECK'
           AND table_name IN ('project_categories','project_phase_settings','project_templates',
                              'project_template_items','project_numbering')) AS checks;
