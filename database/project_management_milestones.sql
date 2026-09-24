-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — milestones, dan apa yang menjadikan `percent_complete` jujur
--
-- Spec: .kiro/specs/project-management/  (Task 24, dari Phase 2)
-- Bergantung pada: database/project_management_schema.sql
--
-- ── SEBAB INI DAHULU DARIPADA SELEBIHNYA PHASE 2 ──
--
-- `projects.percent_complete` dipaparkan di TIGA tempat — register, workspace, dan
-- portal client — dan pada hari ini TIADA apa yang boleh menetapkannya. Ia tiada dalam
-- borang register sama sekali, jadi ia tersekat pada 0.00 selama-lamanya. Skrin projek
-- sebenar yang pertama membacanya "0% Complete" pada projek yang kontraknya sudah
-- ditandatangani.
--
-- Satu portal yang berkata "68%" tanpa apa-apa di belakangnya lebih buruk daripada
-- tidak berkata apa-apa. Milestone ialah yang meletakkan sesuatu di belakangnya.
--
-- ── TIADA LAJUR `status`, DAN ITU KEPUTUSAN YANG SAMA SEPERTI `status` vs `phase` ──
--
-- Satu milestone sudah dicapai atau belum. Itu boleh dibaca terus daripada
-- `completed_on` dan `due_date`:
--
--   completed_on IS NOT NULL          →  done
--   due_date < CURDATE()              →  overdue
--   selainnya                         →  pending
--
-- Satu lajur `status` di sebelah dua tarikh itu ialah fakta yang sama disimpan dua kali,
-- dan salah satunya akan menjadi stale — tepat percanggahan yang `projects.status`
-- lawan `projects.phase` sudah paksa kita selesaikan sekali. `phase` ialah sumber di
-- sana; tarikh ialah sumber di sini.
--
-- `in_progress` SENGAJA tidak boleh diungkapkan, dan itu bukan kekurangan. Satu
-- milestone ialah TITIK PEMERIKSAAN, bukan satu jangka masa. Kemajuan DALAM satu
-- milestone ialah apa yang `project_tasks` untuk, yang Phase 2 bina selepas ini.
--
-- ── `weight` IALAH BERAT RELATIF, BUKAN PERATUSAN YANG MESTI BERJUMLAH 100 ──
--
-- Kontrak pembinaan menulis milestone bayaran sebagai peratusan yang berjumlah 100, dan
-- itu menggoda untuk ditiru. Ia ditolak: menguatkuasakan jumlah 100 bermakna anda TIDAK
-- BOLEH menambah milestone keenam tanpa mengedit lima yang lain dahulu, dan borang itu
-- akan menolak kerja yang sah.
--
-- Berat relatif memberi jawapan yang SAMA tanpa sekatan itu:
--
--   percent = SUM(weight yang selesai) / SUM(semua weight) * 100
--
-- Lima milestone dengan berat 1 setiap satu ialah 20% setiap satu. Satu yang bernilai
-- dua kali lebih mendapat 2. Lalai 1.00, jadi seseorang yang tidak peduli tentang berat
-- mendapat pemberatan sama rata tanpa menaip apa-apa.
--
-- DECIMAL(6,2) dan bukan INT, kerana berat 12.5% muncul dalam kontrak sebenar.
--
-- ── `percent_complete` MENJADI TERBITAN, DAN ENDPOINT YANG MENGIRANYA ──
--
-- Bukan satu VIEW dan bukan satu trigger. Satu view tidak boleh ditulis dan
-- `projects.percent_complete` ialah lajur yang tiga skrin sudah pilih; satu trigger
-- ialah logik dalam pangkalan data yang tiada ujian di sini boleh capai, dan codebase
-- ini tidak mempunyai satu pun.
--
-- Jadi `/api/admin/operations/projects/[id]/milestones` mengira semula dan menulisnya
-- dalam transaksi yang sama, setiap kali satu milestone ditambah, disunting, ditanda
-- selesai atau dipadam. Projek TANPA milestone mengekalkan apa sahaja nilainya — ia
-- tidak dipaksa kepada 0, kerana itu akan memadam satu angka yang seseorang mungkin
-- telah tetapkan dengan tangan.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_milestones.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Milestone ──
--
-- `title` NOT NULL tanpa default: satu milestone tanpa nama tidak boleh dilaporkan dan
-- tiada nilai lalai yang bermakna. Setiap lajur lain boleh kosong, kerana satu milestone
-- dicatat sebaik sahaja ia dinamakan dan tarikhnya tiba kemudian.
--
-- `due_date` NULLABLE dan itu disengajakan. Satu milestone dalam kontrak yang tarikhnya
-- belum dirundingkan masih satu milestone. Ia hanya tidak boleh menjadi OVERDUE — dan
-- query yang mengira kelewatan menapis `due_date IS NOT NULL` atas sebab itu.
--
-- `is_client_visible` ialah pintu ke tab Progress portal client, dan lalainya 1.
-- Sebabnya bertentangan dengan `project_messages.is_internal`, yang lalainya 0: satu
-- mesej adalah peribadi sampai seseorang memutuskan sebaliknya, sementara satu milestone
-- WUJUD untuk dilaporkan. Milestone dalaman — "semak semula margin sebelum tuntutan 2" —
-- ialah kekecualian, jadi ia yang perlu ditandakan.
CREATE TABLE IF NOT EXISTS `project_milestones` (
  `id`                INT NOT NULL AUTO_INCREMENT,
  `project_id`        INT NOT NULL,
  `title`             VARCHAR(255) NOT NULL,
  `description`       TEXT NULL DEFAULT NULL,
  `due_date`          DATE NULL DEFAULT NULL
                      COMMENT 'nullable: satu milestone yang tarikhnya belum dirundingkan masih satu milestone',
  `completed_on`      DATE NULL DEFAULT NULL
                      COMMENT 'ditetapkan = selesai. TIADA lajur status: dua tarikh ini ialah sumbernya',
  `weight`            DECIMAL(6,2) NOT NULL DEFAULT 1.00
                      COMMENT 'RELATIF, bukan peratusan. percent = SUM(selesai)/SUM(semua)*100',
  `is_client_visible` TINYINT(1) NOT NULL DEFAULT 1
                      COMMENT 'lalai 1, bertentangan dengan project_messages.is_internal. Lihat nota di atas',
  `sort_order`        INT NOT NULL DEFAULT 0,
  `completed_by`      VARCHAR(191) NULL DEFAULT NULL
                      COMMENT 'nama pengguna daripada sesi. admin_sessions tiada id admin',
  `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  /* Satu projek, dalam urutan papar. Menjawab tab Scope dalam satu bacaan indeks. */
  KEY `idx_pms_project` (`project_id`, `sort_order`, `id`),
  /* Satu-satunya query silang-projek yang penting: apa yang jatuh tempoh, dan bila. Tarikh
     dahulu, kerana ia ditapis mengikut julat dan diisih mengikut nilai yang sama. */
  KEY `idx_pms_due` (`due_date`, `completed_on`),
  KEY `idx_pms_client` (`project_id`, `is_client_visible`),
  CONSTRAINT `fk_pms_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan: 12 lajur, 1 foreign key ke `projects`, 0 indeks unik, 0 CHECK.
-- Tiada indeks unik atas tujuan: dua milestone boleh berkongsi nama yang sama pada satu
-- projek. "Tuntutan Kemajuan" pada dua peringkat berbeza ialah dua milestone, dan indeks
-- unik atas (project_id, title) akan menolak yang kedua.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_milestones') AS cols,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_milestones'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY') AS fks,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_milestones'
      AND CONSTRAINT_TYPE = 'UNIQUE') AS uniques,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_milestones'
      AND CONSTRAINT_TYPE = 'CHECK') AS checks,
  (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_milestones'
      AND INDEX_NAME <> 'PRIMARY' AND SEQ_IN_INDEX = 1) AS secondary_indexes
