-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — daftar risiko
--
-- Spec: .kiro/specs/project-management/  (Task 27 — Phase 3, tab Risk)
-- Bergantung pada: database/project_management_schema.sql
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- CHECK CONSTRAINT AKHIRNYA BERFUNGSI, DAN ITU DIUKUR
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Tiga kali codebase ini merekod MySQL menolak satu CHECK:
--
--   project_participants.client_user_id      CHECK ditolak, generated column ditolak
--   project_task_deps.task_id                CHECK ditolak
--   asset_site_documents.tender_document_id  CHECK ditolak
--
-- Ketiga-tiganya ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN, dan ralat
-- itu MENAMAKAN foreign key. Itu satu pernyataan tentang lajur FK, bukan tentang CHECK.
--
-- Jadi satu probe dijalankan pada pangkalan data INI, dengan satu FK bercascade pada
-- `project_id` dan CHECK atas empat lajur yang tiada dalam mana-mana kunci. Keputusan:
--
--   chk_zz_scale   DICIPTA, dan menolak probability = 9  → ER_CHECK_CONSTRAINT_VIOLATED
--   chk_zz_closed  DICIPTA, dan menolak status='closed' dengan closed_on NULL
--                            dan       menolak status='open'   dengan closed_on ditetapkan
--   baris yang sah DITERIMA
--
-- Jadi hadnya memang HANYA lajur FK. `project_risks` di bawah ialah table PERTAMA dalam
-- codebase ini yang memegang invariannya sendiri di dalam pangkalan data dan bukan hanya
-- di dalam satu endpoint. Endpoint masih menyemaknya — untuk memberi mesej yang boleh
-- dibaca — tetapi satu INSERT yang ditulis dengan tangan tidak lagi boleh melepasinya.
--
-- ── SKOR TIDAK DISIMPAN ──
--
-- `probability * impact` ialah aritmetik atas dua lajur dalam BARIS YANG SAMA. Menyimpan
-- hasilnya ialah satu fakta di dua tempat, dan satu salinan menjadi basi — pengajaran
-- `projects.status` lawan `projects.phase` yang sudah pernah diselesaikan sekali.
--
-- Satu generated column STORED memang tersedia di sini (kedua-dua lajur tiada FK, dan
-- probe di atas membuktikan hadnya tentang FK), dan ia DITOLAK atas sebab saiz: satu
-- daftar risiko memegang berpuluh baris satu projek, jadi tiada indeks diperlukan dan
-- `ORDER BY probability * impact DESC` sudah memadai. Satu generated column menjadi
-- berbaloi hanya kalau satu daftar silang-projek menyusun beribu baris.
--
-- ── `status` MEMBAWA KEDUA-DUA PENGAKHIRAN, DAN ITU BUKAN PERCANGGAHAN ──
--
-- `project_tasks` mengecualikan `done` daripada enumnya kerana `completed_on` sudah
-- mengatakannya: satu tarikh boleh membezakan "selesai" daripada "belum".
--
-- Satu risiko mempunyai DUA pengakhiran yang berbeza:
--
--   realised  ia BERLAKU. Ia kini satu isu, dan inilah baris yang paling bernilai dalam
--             pengajaran selepas projek
--   closed    ia tidak lagi satu ancaman. Tiada apa berlaku
--
-- Satu tarikh tidak boleh membezakan kedua-duanya, jadi enum mesti membawanya dan
-- `closed_on` merekod BILA. Alasan yang sama, kesimpulan yang berbeza — dan `chk_pr_closed`
-- di bawah menguatkuasakan pautan antara keduanya, sesuatu yang table tugas tidak dapat.
--
-- ── `owner_employee_id` TIADA FOREIGN KEY ──
--
-- Sebab yang sama seperti `project_tasks.assignee_employee_id` dan
-- `project_participants.employee_id`: seorang pekerja yang keluar tidak sepatutnya memadam
-- rekod bahawa satu risiko pernah dimiliki. Nama diperoleh melalui LEFT JOIN.
--
-- ── KUALITI TIADA DI SINI ──
--
-- `project_quality` ialah modul kebenarannya SENDIRI dan leaf sidebarnya sendiri. Satu
-- risiko ialah apa yang MUNGKIN berlaku dan ia milik pengurus projek; satu
-- non-conformance ialah apa yang SUDAH berlaku dan ia milik QA. Membaca daftar risiko
-- tidak bermakna kuasa untuk menutup satu NCR. Table itu belum dibina.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_risk.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Risiko ──
--
-- `probability` dan `impact` ialah skala 1-5, dikuatkuasakan oleh `chk_pr_scale`. Bukan
-- 1-3 (terlalu tumpul untuk membezakan risiko) dan bukan 1-10 (tiada siapa boleh
-- membezakan 6 daripada 7 secara konsisten). 5x5 ialah matriks yang setiap panduan
-- projek gunakan, dan ia memberi skor 1-25.
--
-- `response` BERASINGAN daripada `mitigation`, dan ia bukan lebihan. Satu risiko yang
-- diputuskan untuk DITERIMA tanpa satu pun tindakan ialah keadaan yang sah dan penting;
-- teks bebas sahaja akan menyembunyikannya sebagai satu medan kosong.
--
-- `review_on` ialah bila risiko itu perlu dilihat semula. Ia satu-satunya sebab satu
-- daftar risiko tidak menjadi satu senarai yang ditulis sekali dan tidak pernah dibuka
-- lagi — dan ia lajur yang satu skrin silang-projek akan menapis atasnya.
CREATE TABLE IF NOT EXISTS `project_risks` (
  `id`                INT NOT NULL AUTO_INCREMENT,
  `project_id`        INT NOT NULL,
  `title`             VARCHAR(255) NOT NULL,
  `description`       TEXT NULL DEFAULT NULL,
  `category`          ENUM('technical','commercial','schedule','resource','external',
                           'safety','quality') NOT NULL DEFAULT 'technical',
  `probability`       TINYINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'skala 1-5, lihat chk_pr_scale',
  `impact`            TINYINT UNSIGNED NOT NULL DEFAULT 3 COMMENT 'skala 1-5, lihat chk_pr_scale',
  `response`          ENUM('avoid','transfer','mitigate','accept') NOT NULL DEFAULT 'mitigate',
  `mitigation`        TEXT NULL DEFAULT NULL,
  `owner_employee_id` INT NULL DEFAULT NULL
                      COMMENT 'tiada FK: pekerja yang keluar tidak memadam rekod pemilikan',
  `status`            ENUM('open','monitoring','realised','closed') NOT NULL DEFAULT 'open'
                      COMMENT 'DUA pengakhiran: realised dan closed. Lihat nota di kepala fail',
  `identified_on`     DATE NOT NULL,
  `review_on`         DATE NULL DEFAULT NULL COMMENT 'bila risiko ini perlu dilihat semula',
  `closed_on`         DATE NULL DEFAULT NULL COMMENT 'dipautkan kepada status oleh chk_pr_closed',
  `closed_note`       VARCHAR(400) NULL DEFAULT NULL
                      COMMENT 'apa yang berlaku, atau mengapa ia tidak lagi satu ancaman',
  `created_by`        VARCHAR(191) NULL DEFAULT NULL,
  `closed_by`         VARCHAR(191) NULL DEFAULT NULL,
  `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  /* Satu projek, yang terbuka dahulu: menjawab tab Risk dalam satu bacaan indeks. */
  KEY `idx_pr_project` (`project_id`, `status`, `id`),
  /* "Apa yang perlu dilihat semula" — penapis utama satu daftar silang-projek. */
  KEY `idx_pr_review` (`review_on`, `status`),
  KEY `idx_pr_owner` (`owner_employee_id`, `status`),
  CONSTRAINT `fk_pr_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  /*
   * Skala 1-5 pada kedua-dua paksi. Diukur sebagai boleh diterima oleh MySQL 8.0.45 pada
   * pangkalan data ini — lihat kepala fail. Tanpanya, satu probability 9 memberi skor 45
   * pada satu skala yang maksimumnya 25, dan setiap band akan salah.
   */
  CONSTRAINT `chk_pr_scale` CHECK (`probability` BETWEEN 1 AND 5 AND `impact` BETWEEN 1 AND 5),
  /*
   * Satu risiko yang tamat MESTI ada tarikh, dan satu risiko yang terbuka MESTI tiada.
   *
   * Tanpa ini, `status='closed'` dengan `closed_on` NULL boleh wujud — satu risiko yang
   * ditutup tanpa siapa pun boleh mengatakan bila, yang merupakan tepat soalan yang satu
   * audit tanya. Dan arah sebaliknya juga: satu `closed_on` yang tertinggal pada satu
   * risiko yang dibuka semula ialah tarikh yang merujuk kepada tiada apa.
   */
  CONSTRAINT `chk_pr_closed` CHECK (
    (`status` IN ('realised','closed') AND `closed_on` IS NOT NULL)
    OR (`status` IN ('open','monitoring') AND `closed_on` IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  cols 19  fks 1  checks 2
--
-- `checks` MESTI 2. Kalau ia 0, MySQL menerima table itu dan MENJATUHKAN constraint —
-- yang bermakna invarian hanya dipegang oleh endpoint, dan nota di kepala fail ini salah
-- untuk pelayan ini.
SELECT t.TABLE_NAME,
       (SELECT COUNT(*) FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME) AS cols,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'FOREIGN KEY') AS fks,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS k
         WHERE k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
           AND k.CONSTRAINT_TYPE = 'CHECK') AS checks
  FROM information_schema.TABLES t
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_risks'
