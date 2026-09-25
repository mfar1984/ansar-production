-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — dokumen projek, dan yang mana antaranya client boleh lihat
--
-- Spec: .kiro/specs/project-management/  (Task 27 — Phase 2, tab Documents)
-- Bergantung pada: database/project_management_schema.sql
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `is_client_visible` LALAI 0. MILESTONE LALAI 1. INI SENGAJA.
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `project_milestones.is_client_visible` lalai 1, dan itu betul di sana: satu titik
-- pemeriksaan bertarikh ialah tepat apa yang client mahu lihat, dan sebuah milestone
-- yang tersembunyi secara tidak sengaja hanya bermakna portal itu kurang lengkap.
--
-- Satu DOKUMEN ialah sebaliknya. Satu lukisan as-built, satu pecahan kos, satu laporan
-- ujian yang gagal — memuat naik satu daripadanya dan ia muncul di portal client secara
-- lalai ialah satu PENDEDAHAN, dan pendedahan tidak boleh dibatalkan. Client sudah
-- memuat turunnya sebelum sesiapa perasan.
--
-- Itu juga sebab `project_documents_share` ialah kebenaran yang BERASINGAN daripada
-- `project_documents_create`. `project_management_modules.sql` merekod hujahnya:
-- memuat naik satu lukisan ke dalam satu projek dan MENANDAKANNYA kelihatan kepada pihak
-- luar ialah dua keputusan, dan bukan semestinya oleh orang yang sama.
--
-- `chk_pd_shared` di bawah menguatkuasakan bahawa satu dokumen yang dikongsi SELALU
-- mempunyai tarikh — jadi "bila kita berikan ini kepada mereka" tidak boleh hilang.
-- Satu CHECK boleh dilakukan di sini kerana `is_client_visible` dan `shared_at` tiada
-- dalam mana-mana kunci; `database/project_management_risk.sql` merekod probe yang
-- membuktikan had itu hanya tentang lajur FK.
--
-- ── FAIL PERGI KE AKAR PERIBADI, BUKAN KE `public/` ──
--
-- `file_path` ialah satu laluan RELATIF di bawah `.uploads-private/projects/`, tanpa
-- garis miring di depan. Bukan `/uploads/...`.
--
-- Semua yang di bawah `public/` disajikan oleh Next kepada sesiapa yang tahu laluannya,
-- tanpa sesi dan tanpa semakan kebenaran. Satu nama fail yang dijana ialah kekaburan,
-- bukan kawalan akses: laluan itu terbocor sebaik ia muncul dalam satu sejarah pelayar,
-- satu log proxy atau satu tangkapan skrin, dan selepas itu ia berfungsi selama-lamanya
-- — termasuk selepas hubungan dengan client itu tamat.
--
-- Jadi setiap fail dibaca hanya melalui `api/admin/operations/files/[...path].ts`, yang
-- menyemak sesi, baris yang merujuk laluan itu, kebenaran, dan bagi satu client,
-- pemilikan — sebelum satu bait pun disalurkan.
--
-- ── SATU BARIS MEMILIKI SATU FAIL. TIADA RUJUKAN. ──
--
-- `asset_site_documents` membenarkan satu baris merujuk satu `tender_documents` yang ada
-- dan bukan menyalinnya, dan itu betul di sana. Ia TIDAK dibina di sini, walaupun
-- `projects.tender_id` wujud dan kertas kerja tender satu projek sudah ada.
--
-- Sebab: satu model rujukan memerlukan satu cabang kedua pada POST, satu query pilihan,
-- dan satu keadaan ketiga (`source_removed`) apabila dokumen tender yang dirujuk dipadam.
-- Itu tiga perkara yang tiada siapa telah minta. Menambahnya kemudian ialah satu ALTER
-- yang menjadikan `file_path` NULLABLE — dan `uq_pd_path` di bawah kekal berfungsi, kerana
-- MySQL menganggap NULL sebagai berbeza dalam satu indeks unik.
--
-- ── `revision` ADALAH TEKS, BUKAN SATU RANTAIAN ──
--
-- Satu lajur `supersedes_id` DIPERTIMBANGKAN dan ditolak. Ia satu graf: A menggantikan B
-- menggantikan A boleh wujud, jadi ia memerlukan satu pengawal kitaran — masalah graf
-- KEDUA dalam modul ini selepas kebergantungan tugas. Satu label revisi campur urutan
-- muat naik sudah mengatakan yang mana terkini, dan satu rantaian versi sebenar ialah
-- satu lajur dengan satu FK-sendiri apabila ada sesiapa yang memintanya.
--
-- `project_documents_edit` masih bermakna: ia menyunting jenis, tajuk, revisi dan nota
-- satu baris — satu dokumen yang dimuat naik dengan jenis yang salah ialah kes sebenar.
--
-- ── `project_attachments` SUDAH MATI, DAN TIDAK DISENTUH ──
--
-- Satu table `project_attachments` wujud, daripada `database/patches/` sebelum disiplin
-- migrasi. Ia dirujuk SIFAR kali dalam `src/` — diukur — dan ia tiada jenis dokumen,
-- tiada tajuk, tiada penanda keterlihatan client dan tiada rekod siapa memuat naik.
-- Ia TIDAK dijatuhkan di sini: barisnya bukan milik perubahan ini untuk dimusnahkan.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_documents.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Dokumen ──
CREATE TABLE IF NOT EXISTS `project_documents` (
  `id`                INT NOT NULL AUTO_INCREMENT,
  `project_id`        INT NOT NULL,
  `doc_type`          ENUM('drawing','specification','contract','report','certificate',
                           'handover','general') NOT NULL DEFAULT 'general',
  `title`             VARCHAR(200) NOT NULL,
  `revision`          VARCHAR(20) NULL DEFAULT NULL COMMENT 'label sahaja, bukan satu rantaian versi',
  `notes`             VARCHAR(400) NULL DEFAULT NULL,
  `file_path`         VARCHAR(400) NOT NULL
                      COMMENT 'relatif kepada .uploads-private, tanpa garis miring di depan',
  `file_name`         VARCHAR(255) NOT NULL COMMENT 'nama yang pengguna kenal, untuk pautan muat turun',
  `mime_type`         VARCHAR(120) NULL DEFAULT NULL,
  `file_size`         INT UNSIGNED NULL DEFAULT NULL,
  `is_client_visible` TINYINT(1) NOT NULL DEFAULT 0
                      COMMENT 'LALAI 0, tidak seperti milestone. Lihat nota di kepala fail',
  `shared_by`         VARCHAR(191) NULL DEFAULT NULL,
  `shared_at`         TIMESTAMP NULL DEFAULT NULL COMMENT 'dipautkan kepada penanda oleh chk_pd_shared',
  `uploaded_by`       VARCHAR(191) NULL DEFAULT NULL,
  `uploaded_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  /*
   * Satu fail, satu baris.
   *
   * Penyelesai dalam `files/[...path].ts` mencari `WHERE file_path = ? LIMIT 1`. Kalau dua
   * baris berkongsi satu laluan, memadam satu daripadanya akan memadam fail yang satu lagi
   * tunjuk — dan muat turun yang kedua kemudian 404 pada semakan fail, bukan pada semakan
   * kebenaran, jadi tiada apa akan mengatakan sebabnya.
   *
   * Nama yang dijana menjadikan perlanggaran hampir mustahil; indeks ini menjadikannya
   * mustahil. Tiga table dokumen yang lain tidak mempunyainya, dan ini tambahan, bukan
   * pembetulan kepada mereka.
   */
  UNIQUE KEY `uq_pd_path` (`file_path`),
  /* Satu projek dalam urutan papar: menjawab tab Documents dalam satu bacaan indeks. */
  KEY `idx_pd_project` (`project_id`, `doc_type`, `id`),
  /* Apa yang portal client tanya, dan tiada yang lain. */
  KEY `idx_pd_client` (`project_id`, `is_client_visible`),
  CONSTRAINT `fk_pd_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  /*
   * Satu dokumen yang dikongsi SELALU mempunyai tarikh, dan satu yang tidak dikongsi tidak
   * pernah ada.
   *
   * "Bila kita berikan ini kepada mereka" ialah soalan yang ditanya apabila sesuatu telah
   * salah, dan ia tidak boleh dijawab oleh satu penanda boolean sahaja. Arah sebaliknya
   * juga penting: satu `shared_at` yang tertinggal selepas satu dokumen ditarik semula akan
   * mendakwa ia masih dikongsi.
   */
  CONSTRAINT `chk_pd_shared` CHECK (
    (`is_client_visible` = 1 AND `shared_at` IS NOT NULL)
    OR (`is_client_visible` = 0 AND `shared_at` IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  cols 16  fks 1  uniques 1  checks 1
SELECT t.TABLE_NAME,
       (SELECT COUNT(*) FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME) AS cols,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'FOREIGN KEY') AS fks,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'UNIQUE') AS uniques,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'CHECK') AS checks
  FROM information_schema.TABLES t
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_documents'
