-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — tugas, dan kebergantungan yang menjadikan satu jadual
--
-- Spec: .kiro/specs/project-management/  (Task 26 — Phase 2 dan Phase 5, bersama)
-- Bergantung pada: database/project_management_milestones.sql
--
-- ── MENGAPA TUGAS DAN JADUAL DALAM SATU PERUBAHAN ──
--
-- Spec meletakkan Schedule di Phase 5 dan sebabnya betul: "model kebergantungan tidak
-- boleh dinilai sebelum project_tasks memegang kerja sebenar". Membuat kedua-duanya
-- SERENTAK membatalkan bantahan itu — model kebergantungan direka BERSAMA model tugas
-- dan bukan dipasang kemudian, jadi bentuk tarikh yang CPM perlukan ada dari mula.
--
-- Itu berkesan hanya kerana satu keputusan dibuat di sini dan bukan kemudian: satu tugas
-- membawa `start_date` DAN `due_date`, bukan hanya satu tarikh akhir. Satu bar Gantt
-- memerlukan dua hujung, dan satu critical path memerlukan TEMPOH. Satu jadual yang
-- dipasang pada table yang hanya mempunyai `due_date` akan memaksa satu tempoh yang
-- direka-reka pada setiap tugas.
--
-- ── BASELINE DITANGGUHKAN, DENGAN SEBAB DIREKOD ──
--
-- Phase 5 menamakan empat perkara: Gantt, kebergantungan, critical path, dan baseline.
-- Tiga yang pertama ada di sini. `project_baselines` TIDAK, dan itu bukan kelalaian:
-- satu baseline ialah SNAPSHOT untuk dibandingkan, dan pada hari ini tiada satu tugas
-- pun wujud. Snapshot bagi rancangan kosong ialah salinan bagi tiada apa.
--
-- Ia juga memerlukan satu keputusan yang belum boleh dijawab: baseline diambil BILA —
-- pada setiap gate, atas permintaan, atau pada kelulusan? Menjawabnya sebelum ada
-- rancangan sebenar untuk dibandingkan ialah meneka.
--
-- ── SATU JENIS KEBERGANTUNGAN SAHAJA: FINISH-TO-START ──
--
-- `task_id` tidak boleh MULA sebelum `depends_on_task_id` SELESAI. PMBOK menamakan empat
-- jenis — FS, SS, FF, SF — dan tiga yang lain tidak dibina.
--
-- Bukan kerana ia mudah: setiap satu mengubah lintasan CPM, dan setiap satu memerlukan
-- satu lajur `dep_type` yang setiap query mesti menapis atasnya. Tiada siapa telah minta
-- SS, FF atau SF, dan menambah satu daripadanya kemudian ialah satu lajur dengan lalai
-- 'FS' — bukan satu penulisan semula. Membina ketiga-tiganya sekarang ialah tiga laluan
-- kod yang tidak boleh diuji terhadap kerja sebenar.
--
-- ── CHECK DITOLAK LAGI. KALI KETIGA. ──
--
-- Satu CHECK (task_id <> depends_on_task_id) DICUBA dan MySQL 8.0.45 menolaknya:
--
--   ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN:
--   Column 'task_id' cannot be used in a check constraint 'chk_no_self':
--   needed in a foreign key constraint 'fk_d_task' referential action.
--
-- Sama seperti `project_participants` — satu lajur dalam FK bercascade tidak boleh
-- berada dalam satu CHECK. Jadi rujukan-sendiri dikuatkuasakan oleh endpoint.
--
-- Dan itu tidak penting sebanyak yang ia bunyi, kerana masalah yang LEBIH BESAR tidak
-- boleh menjadi satu constraint walau apa pun: satu KITARAN. A bergantung pada B, B pada
-- C, C pada A. Tiada constraint dalam mana-mana pangkalan data boleh menghalang itu —
-- ia memerlukan satu lintasan graf, yang hanya endpoint boleh lakukan. Jadi endpoint
-- ialah tempat yang betul untuk KEDUA-DUANYA, dan `UNIQUE (task_id, depends_on_task_id)`
-- di bawah menangkap satu-satunya kes yang satu indeks BOLEH tangkap: pendua.
--
-- Tanpa penolakan kitaran, lintasan CPM tidak pernah tamat.
--
-- ── `status` ADA DI SINI, SEMENTARA `project_milestones` TIDAK ADA. INI BUKAN
--    PERCANGGAHAN. ──
--
-- Migrasi milestone menolak satu lajur `status` kerana dua tarikh sudah cukup: satu
-- milestone dicapai atau tidak. Satu TUGAS berbeza — `blocked` dan `in_progress` ialah
-- keadaan yang TIADA tarikh boleh ungkapkan, dan itu tepat perbezaan yang komen milestone
-- itu rekod: "Kemajuan DALAM satu milestone ialah apa yang project_tasks untuk".
--
-- Tetapi `done` TIDAK ada dalam enum, dan itu penting. Ia diterbitkan daripada
-- `completed_on`, seperti pada milestone. Kalau `done` ialah satu nilai status, maka
-- `status='done'` dengan `completed_on` NULL boleh wujud — dan begitu juga
-- `status='todo'` dengan `completed_on` ditetapkan. Satu fakta, satu tempat:
--
--   completed_on IS NOT NULL  →  done, dan `status` ialah sejarah
--   selainnya                 →  `status` ialah keadaan semasa
--
-- Keadaan terbuka terakhir satu tugas yang sudah selesai hilang. Itu diterima: log audit
-- memegangnya, dan tiada siapa bertanya sama ada satu tugas yang sudah siap pernah
-- tersekat.
--
-- IDEMPOTENT. Dua `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_tasks.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Tugas ──
--
-- `milestone_id` ON DELETE SET NULL, BUKAN CASCADE. Memadam satu milestone tidak
-- sepatutnya memadam kerja di bawahnya — kerja itu masih perlu dibuat, ia hanya tidak
-- lagi berkelompok di bawah satu titik pemeriksaan. Bentuk yang sama seperti
-- `projects.tender_id`.
--
-- `assignee_employee_id` TIADA foreign key, atas sebab yang sama seperti
-- `project_participants.employee_id`: seorang pekerja yang keluar dari syarikat tidak
-- sepatutnya memadam rekod kerja yang diberikan kepadanya. Nama diperoleh melalui LEFT
-- JOIN, tidak dicache — `project_messages.sender_name` dicache kerana satu thread mesti
-- kekal boleh dibaca selepas satu akaun dipadam, sementara `employees` tidak dipadam
-- (statusnya bertukar).
--
-- `start_date` dan `due_date` kedua-duanya NULLABLE. Satu tugas dicatat sebaik sahaja ia
-- dinamakan, dan dijadualkan kemudian. Hanya satu tugas dengan KEDUA-DUANYA muncul pada
-- Gantt; selebihnya disenaraikan sebagai belum dijadualkan, yang merupakan satu perkara
-- yang jadual itu sendiri mesti katakan.
--
-- `blocked_reason` wujud kerana `blocked` tanpa sebab ialah jalan mati bagi sesiapa yang
-- membacanya. Ia satu-satunya keadaan yang menuntut penjelasan, jadi ia satu-satunya yang
-- mempunyai medan untuknya.
CREATE TABLE IF NOT EXISTS `project_tasks` (
  `id`                   INT NOT NULL AUTO_INCREMENT,
  `project_id`           INT NOT NULL,
  `milestone_id`         INT NULL DEFAULT NULL
                         COMMENT 'SET NULL bukan CASCADE: kerja kekal selepas milestonenya hilang',
  `title`                VARCHAR(255) NOT NULL,
  `description`          TEXT NULL DEFAULT NULL,
  `assignee_employee_id` INT NULL DEFAULT NULL
                         COMMENT 'tiada FK: pekerja yang keluar tidak memadam rekod kerjanya',
  `status`               ENUM('todo','in_progress','blocked') NOT NULL DEFAULT 'todo'
                         COMMENT "TIADA 'done': itu diterbitkan daripada completed_on. Lihat nota",
  `blocked_reason`       VARCHAR(400) NULL DEFAULT NULL,
  `start_date`           DATE NULL DEFAULT NULL
                         COMMENT 'hujung kiri bar Gantt. Dengan due_date ia memberi tempoh CPM',
  `due_date`             DATE NULL DEFAULT NULL
                         COMMENT 'selesai yang dirancang, hujung kanan bar',
  `completed_on`         DATE NULL DEFAULT NULL
                         COMMENT 'ditetapkan = selesai. Satu fakta, satu tempat',
  `sort_order`           INT NOT NULL DEFAULT 0,
  `created_by`           VARCHAR(191) NULL DEFAULT NULL,
  `completed_by`         VARCHAR(191) NULL DEFAULT NULL,
  `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  /* Satu projek dalam urutan papar: menjawab tab Tasks dalam satu bacaan indeks. */
  KEY `idx_pt_project` (`project_id`, `sort_order`, `id`),
  /* Papan silang-projek: apa yang terbuka, dan bila ia jatuh tempoh. */
  KEY `idx_pt_due` (`due_date`, `completed_on`),
  /* "Apa yang diberikan kepada orang ini" — penapis utama papan itu. */
  KEY `idx_pt_assignee` (`assignee_employee_id`, `completed_on`),
  KEY `idx_pt_milestone` (`milestone_id`),
  CONSTRAINT `fk_pt_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pt_milestone` FOREIGN KEY (`milestone_id`)
    REFERENCES `project_milestones` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Kebergantungan ──
--
-- `task_id` tidak boleh mula sebelum `depends_on_task_id` selesai. Satu jenis sahaja;
-- lihat nota di kepala fail.
--
-- `UNIQUE (task_id, depends_on_task_id)` ialah satu-satunya invarian yang satu indeks
-- BOLEH kuatkuasakan di sini, dan ia berfungsi kerana KEDUA-DUA lajur NOT NULL — tidak
-- seperti `project_participants`, di mana NULL yang dianggap berbeza bermakna satu indeks
-- empat-lajur menolak apa-apa pun.
--
-- Dua perkara yang ia TIDAK boleh halang, dan kedua-duanya milik endpoint:
--   rujukan-sendiri  MySQL menolak CHECK atas lajur FK bercascade. Diukur, kali ketiga
--   KITARAN          tiada constraint boleh; ia memerlukan satu lintasan graf
--
-- Kedua-dua FK CASCADE: memadam satu tugas mesti membuang setiap kebergantungan yang
-- menyebutnya, atau lintasan CPM mengikut satu tepi kepada satu nod yang tiada.
CREATE TABLE IF NOT EXISTS `project_task_deps` (
  `id`                 INT NOT NULL AUTO_INCREMENT,
  `task_id`            INT NOT NULL COMMENT 'pengganti — tidak boleh mula sebelum...',
  `depends_on_task_id` INT NOT NULL COMMENT '...yang ini selesai',
  `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ptd_pair` (`task_id`, `depends_on_task_id`),
  KEY `idx_ptd_dep` (`depends_on_task_id`),
  CONSTRAINT `fk_ptd_task` FOREIGN KEY (`task_id`)
    REFERENCES `project_tasks` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ptd_dep` FOREIGN KEY (`depends_on_task_id`)
    REFERENCES `project_tasks` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:
--   project_tasks       cols 16  fks 2  uniques 0  checks 0
--   project_task_deps   cols  4  fks 2  uniques 1  checks 0
--
-- `checks` MESTI 0 pada kedua-duanya. Satu CHECK di sini akan bermakna MySQL menerima
-- sesuatu yang ia menolak pada pangkalan data ini — lihat kepala fail.
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
 WHERE t.TABLE_SCHEMA = DATABASE()
   AND t.TABLE_NAME IN ('project_tasks', 'project_task_deps')
 ORDER BY t.TABLE_NAME
