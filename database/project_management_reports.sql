-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — laporan kemajuan (progress reports)
--
-- Spec: .kiro/specs/project-management/  (Task 30 — Phase 3, leaf Progress Reports)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_milestones.sql  (percent_complete)
--                  database/project_management_permissions.sql  (modul project_reports)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- SATU TABLE, DUA SKRIN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Itu sebabnya leaf ini dipilih sebelum Quality & Inspection, yang juga hanya perlu
-- satu table:
--
--   1. `Control › Progress Reports` — client mana masih terhutang satu laporan
--   2. Tab `Progress` dalam PORTAL CLIENT, yang sebelum ini `built: false` dan
--      dirender DILUMPUHKAN dengan tooltip "coming soon"
--
-- Yang kedua ialah satu-satunya tab mati yang tinggal dalam portal client. Portal itu
-- ialah bahagian modul yang sebenarnya diminta dalam Phase 1, dan satu tab kelabu di
-- dalamnya ialah tepi yang belum siap yang paling kelihatan.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- INI BUKAN TEMPAT KEDUA UNTUK MEREKOD PERATUS
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `projects.percent_complete` dikira semula daripada `project_milestones` oleh
-- `[id]/milestones.ts`, secara atomik, dan itulah yang Task 24 betulkan. Satu lajur
-- peratus di sini yang boleh DITAIP akan menjadi kegagalan yang sama dicipta semula:
-- dua angka untuk satu fakta, dan tiada apa mengatakan yang mana betul.
--
-- Tetapi satu laporan kemajuan MEMANG satu rekod titik-masa. "Pada 30 September projek
-- ini 45% siap" ialah satu fakta tentang masa lalu yang angka terbitan itu TIDAK BOLEH
-- jawab kemudian, kerana milestone bergerak. Jadi snapshot itu sah.
--
-- Penyelesaiannya ialah pola yang sama dengan `project_documents.is_client_visible`:
--
--   `percent_snapshot` DITULIS OLEH ENDPOINT daripada `projects.percent_complete`,
--   pada saat laporan itu DITERBITKAN, dan TIDAK PERNAH dibaca daripada permintaan.
--
-- Jadi ia tidak boleh bercanggah dengan milestone pada masa penerbitan, ia kekal benar
-- selepas itu, dan tiada siapa boleh menaip satu angka lain. `chk_prp_published`
-- menegakkan bahawa satu laporan yang diterbitkan SELALU membawanya.
--
-- Pada saat DITERBITKAN, bukan pada saat dicipta: satu draf yang duduk seminggu akan
-- membawa angka yang sudah lapuk, dan apa yang client lihat mesti sama dengan apa yang
-- benar bila kami menghantarnya.
--
-- ── DUA STATUS, BUKAN LIMA ──
--
-- `draft` dan `published`. Satu laporan kemajuan BUKAN satu keputusan — ia satu
-- komunikasi. Tiada barisan menunggu, tiada kelulusan, tiada penolakan. Bandingkan
-- `project_changes`, yang ada lima status kerana setiap satu ialah satu keputusan
-- kontraktual dengan kuasa berbeza.
--
-- ── TIADA TINDAKAN `delete` PADA MODUL INI, DAN ITU BUKAN KELALAIAN ──
--
-- `project_management_permissions.sql` menyemai EMPAT tindakan untuk `project_reports`:
-- view, create, edit, publish. Tiada `delete`.
--
-- Jadi endpoint tidak mempunyai kaedah DELETE. Satu laporan yang sudah dihantar kepada
-- client tidak boleh dibuat seolah-olah tidak pernah wujud. Yang BOLEH dilakukan ialah
-- menarik balik penerbitannya — `publish` meliputi kedua-dua arah, sama seperti
-- `project_changes_approve` meliputi masuk dan keluar daripada `approved` — kemudian
-- membetulkan dan menerbitkan semula.
--
-- ── TIADA UNIQUE PADA TEMPOH, DAN ITU DIPERTIMBANGKAN ──
--
-- Satu `UNIQUE (project_id, period_start, period_end)` kelihatan betul: dua laporan
-- untuk projek yang sama dan tempoh yang sama ialah satu kesilapan.
--
-- Ia ditolak. Satu laporan TAMBAHAN atau laporan PEMBETULAN yang diterbitkan di sebelah
-- yang asal ialah cara yang jujur untuk membetulkan satu dokumen yang sudah dihantar —
-- memaksa pembetulan itu MENIMPA yang asal memadam apa yang client sebenarnya terima.
-- Satu constraint yang menghalang laluan yang betul lebih buruk daripada satu skrin yang
-- memberi amaran, jadi skrin itu memberi amaran apabila tempoh bertindih.
--
-- ── `summary` NOT NULL, TETAPI RENTETAN KOSONG DIBENARKAN ──
--
-- Satu draf yang ditulis secara berperingkat sah mempunyai ringkasan kosong. Apa yang
-- TIDAK sah ialah satu laporan DITERBITKAN tanpa ringkasan, dan itu ditegakkan oleh
-- endpoint, bukan oleh table — sama seperti `closed_note` pada satu risiko diperlukan
-- hanya apabila risiko itu tamat.
--
-- NOT NULL masih berbayar: bug `parseFields` yang dihantar dalam Task 27 menulis NULL ke
-- atas satu lajur `description` secara SENYAP. Pada lajur ini kelas bug yang sama gagal
-- dengan KUAT, di pangkalan data, bukan senyap.
--
-- ── SEMUA LIMA BAHAGIAN PROSA DILIHAT OLEH CLIENT, TERMASUK `issues` ──
--
-- `projects.health` sengaja DITAHAN daripada portal: `at_risk` ialah satu penilaian
-- dalaman, dan satu client yang membacanya sebelum kami memberitahunya ialah cara satu
-- perbualan penghantaran bermula dengan buruk.
--
-- `issues` BERBEZA, dan perbezaan itu penting. Ia PROSA YANG KAMI TULIS UNTUK client,
-- dalam satu laporan yang kami PILIH untuk terbitkan. Penulis mengawal perkataannya.
-- Kalau sesuatu tidak patut dilihat client, ia tidak ditulis di sini — ia satu mesej
-- dengan `is_internal = 1`, yang sudah wujud.
--
-- Itu sebabnya tiada bendera keterlihatan per bahagian. Lima lajur lagi dan satu borang
-- yang tiada siapa mengisi dengan betul, untuk menyelesaikan satu masalah yang satu
-- kotak teks kosong sudah selesaikan.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- DAN SATU BARIS KEBENARAN DIBUANG: `project_chat_delete`
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Ia disemai, ia DIBERI kepada satu role, dan `grep` seluruh `src/` untuknya kembali
-- KOSONG. Tiada satu butang. Itu satu kotak semak dalam matriks Roles yang tidak memberi
-- apa-apa, iaitu TEPAT sebab `project_chat_publish` dibuang oleh
-- `project_management_modules.sql`. Presedennya dalam modul yang sama.
--
-- Pilihannya ialah membina kawalan itu atau membuang kebenarannya, dan tiga ukuran
-- memutuskannya:
--
--   1. `project_messages` TIADA lajur soft-delete. Sembilan lajur, tiada `deleted_at`.
--      Satu pemadaman adalah kekal.
--
--   2. `project_message_reads.last_read_message_id` ialah INT NOT NULL dengan TIADA
--      foreign key kepada `project_messages` — satu-satunya FK-nya ialah `project_id`
--      kepada `projects`. Jadi memadam satu mesej meninggalkan setiap penanda-baca
--      menunjuk kepada satu baris yang tidak lagi wujud, dan TIADA APA dalam skema
--      menangkapnya. Kiraan belum-baca dikira daripadanya, jadi kiraan itu akan salah
--      tanpa ralat di mana-mana.
--
--   3. Socket sudah menyiarkan mesej itu. Salinan yang sudah dirender dalam pelayar
--      client akan bercanggah dengan pelayan, dan `project_message_reads` sudah merekod
--      bahawa mereka membacanya.
--
-- Satu perbualan ialah satu REKOD. `project_documents` ada revisi; `project_changes` ada
-- jejak status. Satu mesej tiada kedua-duanya, dengan sengaja — ia satu pusingan dalam
-- satu perbualan, dan memadam satu membuat baki thread itu BERBOHONG.
--
-- Kalau ia dikehendaki kemudian, ia memerlukan satu `deleted_at`, satu penapis dalam
-- empat query, satu keputusan tentang apa client lihat dalam lubang itu, dan satu
-- siaran socket. Itu satu ciri. Ini satu pembetulan.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS`, dua DELETE (yang secara semula jadi
-- idempotent), dan dua SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_reports.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Laporan kemajuan ──
--
-- Awalan `prp_` untuk setiap constraint, BUKAN `pr_`. `project_risks` sudah memiliki
-- `chk_pr_scale` dan `chk_pr_closed`, dan nama constraint ialah ruang nama SATU SKEMA
-- dalam MySQL — bukan satu table. `chk_pr_period` akan gagal dengan satu ralat nama
-- pendua yang tidak menyebut table mana yang sudah memilikinya.
--
-- `report_no` ialah GLOBAL (`RPT-2026-0001`), hujah yang sama seperti `change_no`: satu
-- urutan per projek memerlukan satu pembilang yang mesti dikunci, dan "laporan ketiga
-- projek ini" boleh diterbitkan dengan satu `ROW_NUMBER`.
CREATE TABLE IF NOT EXISTS `project_reports` (
  `id`               INT NOT NULL AUTO_INCREMENT,
  `project_id`       INT NOT NULL,
  `report_no`        VARCHAR(50) NOT NULL COMMENT 'RPT-YYYY-NNNN, global. Lihat nota',
  `title`            VARCHAR(200) NOT NULL,
  /* Tempoh yang laporan ini LIPUTI. Dua tarikh, bukan satu bulan: laporan dua minggu
     dan laporan berasaskan milestone kedua-duanya nyata, dan `YYYY-MM` akan menolaknya
     tanpa menjimatkan apa-apa. */
  `period_start`     DATE NOT NULL,
  `period_end`       DATE NOT NULL,
  /* Dua status. Satu laporan ialah satu KOMUNIKASI, bukan satu keputusan. */
  `status`           ENUM('draft','published') NOT NULL DEFAULT 'draft',
  /* ── Lima bahagian prosa, kesemuanya dilihat client apabila diterbitkan ──
     `summary` ialah laporan itu. Empat yang lain memecahkannya supaya penulis tidak
     menghadapi satu kotak teks kosong, dan supaya `client_actions` — satu-satunya
     bahagian yang client perlu BERTINDAK atasnya — mempunyai tempatnya sendiri dan
     tidak hilang dalam perenggan ketiga. */
  `summary`          TEXT NOT NULL COMMENT 'Kosong dibenarkan pada draf; endpoint menuntutnya pada penerbitan',
  `work_done`        TEXT NULL DEFAULT NULL COMMENT 'Siap dalam tempoh ini',
  `work_next`        TEXT NULL DEFAULT NULL COMMENT 'Dirancang untuk tempoh seterusnya',
  `issues`           TEXT NULL DEFAULT NULL COMMENT 'Apa yang menghalang. DILIHAT client — lihat nota',
  `client_actions`   TEXT NULL DEFAULT NULL COMMENT 'Apa yang kami perlukan DARIPADA client',
  /*
   * DITULIS OLEH ENDPOINT daripada `projects.percent_complete` pada saat penerbitan, dan
   * TIDAK PERNAH dibaca daripada permintaan. Lihat nota kepala: satu lajur peratus yang
   * boleh ditaip di sini ialah kegagalan `percent_complete` dicipta semula.
   */
  `percent_snapshot` DECIMAL(5,2) NULL DEFAULT NULL
                     COMMENT 'Dicop daripada projects.percent_complete pada penerbitan. Lihat chk_prp_published',
  `published_at`     TIMESTAMP NULL DEFAULT NULL,
  `published_by`     VARCHAR(191) NULL DEFAULT NULL,
  `created_by`       VARCHAR(191) NULL DEFAULT NULL,
  `created_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_prp_no` (`report_no`),
  /* Satu projek, tempoh terbaharu dahulu — apa yang portal client baca, dan apa yang
     "bila kali terakhir kami melaporkan" bergantung padanya. */
  KEY `idx_prp_project` (`project_id`, `period_end`),
  /* "Siapa masih terhutang satu laporan" — soalan utama leaf silang-projek. */
  KEY `idx_prp_status` (`status`, `published_at`),
  CONSTRAINT `fk_prp_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  /*
   * Satu tempoh berakhir pada atau selepas ia bermula.
   *
   * Satu tempoh terbalik akan membuat "bila kali terakhir kami melaporkan" mengembalikan
   * satu tarikh sebelum laporan itu bermula, dan senarai yang disusun mengikut
   * `period_end` akan meletakkannya di tempat yang salah tanpa apa-apa kelihatan pelik
   * pada baris itu sendiri.
   *
   * Satu tempoh SEHARI sah: satu laporan untuk satu hari tapak tertentu.
   */
  CONSTRAINT `chk_prp_period` CHECK (`period_end` >= `period_start`),
  /*
   * Satu laporan yang DITERBITKAN selalu membawa bila ia diterbitkan DAN peratus pada
   * masa itu; satu draf tidak pernah membawa kedua-duanya.
   *
   * Kedua-dua arah, atas sebab yang sama seperti `chk_pc_applied`: satu `published_at`
   * yang tertinggal pada satu laporan yang ditarik balik akan mendakwa client masih
   * boleh melihatnya, dan satu `percent_snapshot` yang tertinggal ialah satu angka
   * sejarah yang tiada laporan diterbitkan pernah menyokongnya.
   *
   * `published_by` BUKAN di sini: `created_by` dan `published_by` kedua-duanya boleh
   * NULL pada satu baris yang sah kalau sesi yang menulisnya tiada nama pengguna, dan
   * satu constraint atas identiti akan menolak satu laporan yang sah sebaliknya.
   */
  CONSTRAINT `chk_prp_published` CHECK (
    (`status` = 'published' AND `published_at` IS NOT NULL AND `percent_snapshot` IS NOT NULL)
    OR (`status` = 'draft' AND `published_at` IS NULL AND `percent_snapshot` IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Satu baris dibuang: `project_chat_delete` ──
--
-- Grant dahulu, kemudian kebenaran itu. Susunan itu penting: `role_permissions.permission_id`
-- membawa satu foreign key, jadi memadam kebenaran itu dahulu akan sama ada gagal atau
-- mencascade bergantung pada bagaimana FK itu diisytiharkan — dan bergantung padanya
-- ialah bergantung pada sesuatu yang fail ini tidak mengisytiharkan.
--
-- Hujah penuh ada dalam nota kepala. Ringkasnya: tiada kawalan wujud untuknya, tiada
-- lajur soft-delete untuk ia menulis kepada, dan `project_message_reads` akan
-- ditinggalkan menunjuk kepada satu mesej yang tidak wujud tanpa FK menangkapnya.
DELETE rp FROM `role_permissions` rp
  JOIN `permissions` p ON p.id = rp.permission_id
 WHERE p.name = 'project_chat_delete'

-- >>>
DELETE FROM `permissions` WHERE `name` = 'project_chat_delete'

-- >>>
-- ── Verifikasi 1: table ──
--
-- Jangkaan:  cols 18  fks 1  uniques 1  checks 2
--
-- `checks` MESTI 2. Kalau ia 0, MySQL pelayan ini menerima table itu dan MENJATUHKAN
-- constraint — yang bermakna satu laporan boleh mendakwa ia diterbitkan tanpa peratus
-- yang client sebenarnya lihat, dan hanya endpoint yang menghalangnya.
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
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_reports'

-- >>>
-- ── Verifikasi 2: kebenaran chat ──
--
-- Jangkaan:  chat_actions 2  (view, create)  dan  chat_delete 0
--
-- Kalau `chat_delete` ialah 1, DELETE di atas tidak berjalan dan matriks Roles masih
-- memaparkan satu kotak semak yang tidak memberi apa-apa.
SELECT (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_chat') AS chat_actions,
       (SELECT COUNT(*) FROM `permissions` WHERE `name` = 'project_chat_delete') AS chat_delete,
       (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_reports') AS report_actions
