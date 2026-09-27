-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — ketidakakuran (non-conformance report)
--
-- Spec: .kiro/specs/project-management/  (Task 31 — Phase 3, leaf Quality & Inspection)
-- Bergantung pada: database/project_management_schema.sql
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- SATU TABLE, BUKAN DUA — DAN TOOLTIP LEAF DIBETULKAN KERANA ITU
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Tooltip sidebar berkata "Inspection records and non-conformance reports". DUA perkara.
-- Fail ini membina SATU: ketidakakuran. Dan tooltip itu dibetulkan dalam perubahan yang
-- sama, sebab satu janji yang tidak ditunaikan lebih buruk daripada satu skop yang
-- dinyatakan.
--
-- Tiga ukuran memutuskannya:
--
--   1. MODUL INI ADA EMPAT TINDAKAN SAHAJA: view, create, edit, delete. Tiada `approve`,
--      tiada `close`, tiada `verify`. Bandingkan `project_changes`, yang dapat lima kerana
--      ia membawa satu KEPUTUSAN, dan `project_reports`, yang dapat `publish`. Kalau
--      penyemaian mengharapkan dua entiti dengan satu kuasa penutupan, akan ada tindakan
--      kelima. Tiada.
--
--   2. SATU PEMERIKSAAN HAMPIR-HAMPIR `project_tasks`. Table itu sudah ada `title`,
--      `assignee_employee_id`, `start_date`, `due_date`, `completed_on`, `completed_by`
--      dan `status`. Satu pemeriksaan berjadual pada satu hold point IALAH satu tugas;
--      yang tugas tiada ialah satu KEPUTUSAN. Membina `project_inspections` bermakna satu
--      table kedua untuk SATU lajur, pada modul yang sudah ada table tugas dengan
--      kebergantungan dan satu Gantt.
--
--   3. BUKTI SATU PEMERIKSAAN YANG LULUS SUDAH ADA RUMAHNYA. `project_documents.doc_type`
--      membawa `'certificate'` dan `'handover'`. Sijil ujian itulah buktinya, dan ia sudah
--      boleh disimpan, dikongsi dengan client dan disenaraikan dalam daftar pendedahan.
--      Satu daftar pemeriksaan akan jadi metadata untuk fail yang sudah wujud.
--
-- Jadi: satu pemeriksaan yang LULUS ialah satu sijil dalam `project_documents`. Satu
-- pemeriksaan yang GAGAL ialah satu baris di sini. Satu pemeriksaan yang AKAN DATANG ialah
-- satu `project_tasks`. Ketiga-tiganya sudah ada tempat, dan tiada satu pun memerlukan
-- table keempat.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- DUA TARIKH PENUTUPAN, BUKAN SATU — PRESEDEN `project_risks`
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Kontraktor MEMBETULKAN kecacatan itu (satu tarikh). Pemeriksa MENERIMA pembetulan itu
-- (tarikh lain). Itu dua fakta berbeza dan satu tarikh tidak boleh menyatakan kedua-duanya
-- — sama bentuk dengan `project_risks`, yang perlu `realised` dan `closed` sebagai dua
-- pengakhiran kerana tiada satu tarikh boleh membezakannya.
--
-- Jadi kitaran hayatnya EMPAT keadaan:
--
--   open       dijumpai, belum dibetulkan
--   corrected  kerja sudah dibuat semula, menunggu pemeriksaan semula
--   verified   diperiksa semula dan diterima. INI penutupan sebenar
--   void       dinaikkan secara silap. Rekod kekal, dan ia MESTI beri sebab
--
-- `verified` bukan satu KUASA berasingan, kerana modul ini tiada tindakan untuk itu — ia
-- satu KEADAAN, dan satu keadaan bukan satu kebenaran. Perbezaan itu penting: siapa boleh
-- mengesahkan ditadbir oleh `edit`, dan itu jujur dengan apa yang disemai.
--
-- ── SEVERITY MENENTUKAN SAMA ADA IA MENGHALANG PENYERAHAN ──
--
-- Tiga nilai, dan setiap satu memutuskan sesuatu:
--
--   observation  dicatat, tidak menghalang apa-apa
--   minor        mesti dibetulkan SEBELUM penyerahan
--   major        kerja berhenti sampai ia dibetulkan
--
-- TIADA skala 1-5 seperti risiko. Satu risiko diskor kerana kebarangkalian DARAB impak
-- ialah aritmetik yang berguna; satu kecacatan yang sudah BERLAKU tiada kebarangkalian
-- untuk didarab. Skala lima titik di sini akan jadi tiga nilai dengan dua yang tiada siapa
-- pilih.
--
-- ── DAN TIADA BENDERA "KERJA DIHENTIKAN" ──
--
-- `severity = 'major'` sudah menyatakannya, dan `project_tasks.blocked_reason` sudah
-- merekod kerja yang tersekat. Satu lajur ketiga untuk fakta yang sama ialah tempat ketiga
-- ia boleh bercanggah.
--
-- ── `owner_employee_id` TIADA FOREIGN KEY ──
--
-- Sengaja, dan atas sebab yang sama seperti `project_risks.owner_employee_id` dan
-- `project_tasks.assignee_employee_id`: seseorang yang meninggalkan syarikat tidak boleh
-- memadam rekod bahawa dia pernah bertanggungjawab membetulkan sesuatu.
--
-- ── SATU PAUTAN KE `project_documents` DIPERTIMBANGKAN DAN DITOLAK ──
--
-- Satu `document_id` untuk gambar kecacatan itu kelihatan berguna. Ia ditolak: menambah
-- satu FK di sini bermakna memutuskan apa berlaku bila dokumen itu dipadam, dan tajuk
-- dokumen boleh menamakan NCR itu tanpa satu lajur pun. Tiada siapa memintanya.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_quality.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Ketidakakuran ──
--
-- Awalan `pq_` untuk setiap constraint. Disemak: skema ini sudah memiliki `chk_pc_*`
-- (changes), `chk_pd_*` (documents), `chk_pr_*` (risks) dan `chk_prp_*` (reports), dan nama
-- constraint ialah ruang nama SATU SKEMA dalam MySQL — bukan satu table. `pq_` bebas.
--
-- `ncr_no` ialah GLOBAL (`NCR-2026-0001`), hujah yang sama seperti `change_no` dan
-- `report_no`: satu urutan per projek memerlukan satu pembilang yang mesti dikunci, dan
-- "NCR ketiga projek ini" boleh diterbitkan dengan satu `ROW_NUMBER`.
CREATE TABLE IF NOT EXISTS `project_ncrs` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `project_id`         INT NOT NULL,
  `ncr_no`             VARCHAR(50) NOT NULL COMMENT 'NCR-YYYY-NNNN, global. Lihat nota',
  `title`              VARCHAR(255) NOT NULL,
  `description`        TEXT NULL DEFAULT NULL,
  /* SIAPA BETULKAN. Sejajar dengan `project_risks.category`, yang menentukan siapa dipanggil. */
  `category`           ENUM('workmanship','material','documentation','safety','testing',
                            'design','other') NOT NULL DEFAULT 'workmanship',
  /* Menentukan sama ada ia menghalang penyerahan. Tiga nilai, bukan satu skala. */
  `severity`           ENUM('observation','minor','major') NOT NULL DEFAULT 'minor',
  /*
   * DI MANA pada tapak. Ini yang menjadikan satu NCR boleh ditindak: "Level 3 riser
   * cupboard" ialah perbezaan antara satu laporan dan satu arahan. Bukan satu FK kepada
   * `asset_locations` — itu lokasi ASET, dan satu kecacatan boleh berada di mana-mana
   * termasuk tempat yang tiada aset didaftarkan.
   */
  `location`           VARCHAR(200) NULL DEFAULT NULL,
  `status`             ENUM('open','corrected','verified','void') NOT NULL DEFAULT 'open',
  /* TIADA foreign key. Seorang yang keluar tidak boleh memadam rekod tanggungjawabnya. */
  `owner_employee_id`  INT NULL DEFAULT NULL,
  `found_on`           DATE NOT NULL,
  `due_on`             DATE NULL DEFAULT NULL COMMENT 'Bila ia mesti dibetulkan',
  /* ── DUA tarikh penutupan, kerana membetulkan dan menerima ialah dua fakta ── */
  `corrected_on`       DATE NULL DEFAULT NULL COMMENT 'dipautkan kepada status oleh chk_pq_lifecycle',
  `verified_on`        DATE NULL DEFAULT NULL COMMENT 'dipautkan kepada status oleh chk_pq_lifecycle',
  `corrective_action`  TEXT NULL DEFAULT NULL COMMENT 'Apa yang dibuat untuk membetulkannya',
  `closed_note`        VARCHAR(400) NULL DEFAULT NULL
                       COMMENT 'WAJIB apabila void. Juga catatan pengesahan',
  `found_by`           VARCHAR(191) NULL DEFAULT NULL,
  `verified_by`        VARCHAR(191) NULL DEFAULT NULL,
  `created_by`         VARCHAR(191) NULL DEFAULT NULL,
  `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pq_no` (`ncr_no`),
  /* Satu projek, yang masih terbuka dahulu. */
  KEY `idx_pq_project` (`project_id`, `status`, `id`),
  /* "Apa yang lewat, di mana-mana" — soalan utama leaf silang-projek. */
  KEY `idx_pq_status` (`status`, `due_on`),
  CONSTRAINT `fk_pq_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  /*
   * SELURUH kitaran hayat dalam satu constraint.
   *
   *   open       tiada tarikh pembetulan, tiada tarikh pengesahan
   *   corrected  ADA tarikh pembetulan, BELUM disahkan
   *   verified   ADA kedua-duanya
   *   void       tiada kedua-duanya, DAN mesti beri sebab
   *
   * Arah sebaliknya penting sama: satu `corrected_on` yang tertinggal pada satu NCR yang
   * dibuka semula akan mendakwa kerja itu sudah dibuat semula. Itu kelas kesilapan yang
   * sama yang `chk_pc_applied` dan `chk_prp_published` halang.
   *
   * `void` menuntut `closed_note` kerana "dinaikkan secara silap, dan tiada siapa boleh
   * mengatakan mengapa" ialah tepat soalan yang satu audit kualiti tanya.
   */
  CONSTRAINT `chk_pq_lifecycle` CHECK (
    (`status` = 'open'      AND `corrected_on` IS NULL     AND `verified_on` IS NULL)
    OR (`status` = 'corrected' AND `corrected_on` IS NOT NULL AND `verified_on` IS NULL)
    OR (`status` = 'verified'  AND `corrected_on` IS NOT NULL AND `verified_on` IS NOT NULL)
    OR (`status` = 'void'      AND `corrected_on` IS NULL     AND `verified_on` IS NULL
                               AND `closed_note` IS NOT NULL)
  ),
  /*
   * Tarikh dalam susunan yang berlaku.
   *
   * Setiap perbandingan dibalut dengan `IS NULL OR`, kerana satu perbandingan dengan NULL
   * menilai kepada UNKNOWN dan satu CHECK LULUS pada UNKNOWN — jadi tanpa pembalut itu
   * constraint ini akan senyap tidak menyemak apa-apa pada satu NCR yang masih terbuka.
   *
   * Satu NCR yang dibetulkan dan disahkan pada HARI YANG SAMA adalah sah: pemeriksa berada
   * di tapak. Jadi `>=`, bukan `>`.
   */
  CONSTRAINT `chk_pq_order` CHECK (
    (`corrected_on` IS NULL OR `corrected_on` >= `found_on`)
    AND (`verified_on` IS NULL OR `corrected_on` IS NULL OR `verified_on` >= `corrected_on`)
    AND (`due_on` IS NULL OR `due_on` >= `found_on`)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  cols 21  fks 1  uniques 1  checks 2
--
-- `checks` MESTI 2. Kalau ia 0, MySQL pelayan ini menerima table itu dan MENJATUHKAN
-- constraint — yang bermakna satu NCR boleh mendakwa ia disahkan tanpa tarikh pembetulan,
-- dan hanya endpoint yang menghalangnya.
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
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_ncrs'
