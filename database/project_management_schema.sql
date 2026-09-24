-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — mengangkat `projects` menjadi table penghantaran
--
-- Spec: .kiro/specs/project-management/  (Task 3)
--
-- ── MENGAPA TABLE INI DIKEMBANGKAN DAN BUKAN TABLE BARU DICIPTA ──
--
-- Keputusan terbuka D1 dijawab dengan UKURAN, bukan pendapat. Pada pangkalan data
-- hidup:
--
--   projects                                    0 baris
--   assets dengan project_id ditetapkan          0 baris
--   projects.client yang padan client_users      0
--   client_users                                 2 baris
--
-- Tiada data untuk dipindah, tiada back-fill, dan halaman awam /resources/projects
-- sedang memapar table kosong. Dua table projek tiada justifikasi apabila yang
-- pertama tidak mempunyai satu baris pun, dan `assets.project_id` kekal bermakna apa
-- yang namanya kata.
--
-- ── `CREATE TABLE` INLINE ITU ROSAK, DAN ITU SEBAB KEDUA ──
--
-- `src/pages/api/admin/projects.ts:36` mencipta table ini dengan
-- `CREATE TABLE IF NOT EXISTS` pada setiap permintaan. Definisi itu TIDAK SAMA
-- dengan table yang hidup: ia tidak mempunyai `sector`, `category` mahupun `year` —
-- tiga lajur yang `SELECT` di bawahnya pada baris 58 memang membaca.
--
-- Pada pangkalan data yang BERSIH, endpoint itu akan mencipta table tanpa tiga lajur
-- itu dan kemudian gagal serta-merta pada query-nya sendiri dengan
-- "Unknown column 'sector'". Ia hanya berfungsi di sini kerana table sudah wujud,
-- dibuat oleh definisi lain yang tiada sesiapa simpan. `IF NOT EXISTS` menyembunyikan
-- percanggahan itu sepenuhnya.
--
-- Itulah sebabnya table ini perlu migration, dan `CREATE TABLE` inline itu dibuang
-- daripada route dalam perubahan yang sama.
--
-- ── DUA KECACATAN YANG PERCUMA DIBETULKAN PADA 0 BARIS ──
--
-- 1. `value VARCHAR(50)` — nilai kontrak sebagai TEKS. Tab Cost akan `SUM()` atasnya.
--    Pada 0 baris ini sekadar tukar jenis lajur. Pada 500 baris ia menjadi penukaran
--    data dengan nilai yang tidak boleh dihurai: "RM 1.2 juta", "TBA", "1,250,000.00".
--    Menangguhkannya bermakna menangguhkan pembetulan sampai ia mahal.
--
-- 2. `status` bertindih dengan `phase` yang ditambah di bawah. Dua lajur kitaran hayat
--    pada satu baris ialah percanggahan dan satu daripadanya akan menjadi stale.
--
--    PENYELESAIANNYA: `phase` ialah SUMBER, dan `status` diterbitkan daripadanya oleh
--    endpoint admin — satu tempat memutuskan. `status` KEKAL dalam schema kerana
--    `src/pages/api/public/projects.ts:37` memilihnya dan `ProjectsClient.tsx`
--    memaparkannya; membuangnya akan memecahkan kontrak awam untuk tiada faedah.
--
-- ── `is_public` LALAI 0, DAN ITU DISENGAJAKAN ──
--
-- Halaman awam kini memulangkan SETIAP baris. Projek penghantaran yang dicipta dalam
-- register baharu tidak sepatutnya muncul di laman web syarikat kerana tiada siapa
-- ingat untuk menyembunyikannya. Jadi lalainya 0 — peribadi sampai seseorang
-- menerbitkannya — dan endpoint awam menapis atasnya.
--
-- Itu selamat KERANA table kosong: tiada satu projek pun hilang daripada halaman
-- awam, sebab tiada satu pun di sana sekarang. Pada table yang berisi lalai ini akan
-- mengosongkan halaman awam, dan itu akan menjadi lalai yang salah.
--
-- ── SETIAP ALTER MELALUI PREPARE ──
--
-- `ALTER TABLE ... ADD COLUMN` yang terdedah gagal pada jalan kedua, dan `IF()` yang
-- menamakan lajur tidak membantu — MySQL menyelesaikan KEDUA-DUA cabang apabila ia
-- prepare. Corak yang sama seperti `market_place_chip_payments.sql`.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_schema.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Table itu sendiri, akhirnya dalam migration ──
--
-- Lajur di bawah ialah bentuk yang HIDUP, dibaca daripada information_schema, bukan
-- bentuk yang `CREATE TABLE` inline dakwa. `value` di sini DECIMAL(15,2) kerana
-- itulah yang sepatutnya dari mula; pernyataan seterusnya membetulkan table yang
-- sudah wujud.
CREATE TABLE IF NOT EXISTS `projects` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `title`       VARCHAR(255) NOT NULL,
  `client`      VARCHAR(255) NOT NULL
                COMMENT 'nama client sebagai teks, warisan. client_user_id di bawah yang boleh login',
  `sector`      ENUM('Government','Private') NOT NULL,
  `category`    VARCHAR(100) NOT NULL,
  `year`        INT NOT NULL,
  `location`    VARCHAR(255) NOT NULL,
  `value`       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  `status`      ENUM('planning','ongoing','completed','on-hold') NOT NULL DEFAULT 'planning'
                COMMENT 'perkataan AWAM, diterbitkan daripada phase oleh endpoint admin',
  `start_date`  DATE NULL DEFAULT NULL,
  `end_date`    DATE NULL DEFAULT NULL,
  `description` TEXT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_projects_year` (`year`),
  KEY `idx_projects_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── `value`: VARCHAR(50) -> DECIMAL(15,2) ──
--
-- Dikawal pada DATA_TYPE dan bukan pada kewujudan lajur: lajur itu sentiasa ada, jadi
-- pengawal kewujudan akan dipenuhi pada jalan pertama dan tidak pernah menukar apa-apa.
SET @sql := (
  SELECT IF(
    (SELECT DATA_TYPE FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND COLUMN_NAME = 'value') <> 'decimal',
    'ALTER TABLE `projects` MODIFY `value` DECIMAL(15,2) NOT NULL DEFAULT 0.00',
    'DO 0'
  )
)

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── `project_no` — rujukan PRJ-YYYY-NNNN ──
--
-- UNIQUE, jadi dua projek tidak boleh berkongsi satu nombor walaupun dua permintaan
-- mengira maksimum yang sama. `nextReference()` mencuba lima kali; indeks unik inilah
-- jaminan sebenarnya.
--
-- NULL dibenarkan supaya baris lama, kalau ada, tidak menghalang ALTER. Tiada baris
-- lama di sini, tetapi migration tidak boleh mengandaikan pangkalan data yang ia
-- dijalankan ke atasnya kosong.
SET @sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND COLUMN_NAME = 'project_no') = 0,
    'ALTER TABLE `projects`
       ADD COLUMN `project_no` VARCHAR(50) NULL DEFAULT NULL AFTER `id`,
       ADD UNIQUE KEY `uq_projects_no` (`project_no`)',
    'DO 0'
  )
)

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── Lajur penghantaran ──
--
-- `client_user_id` ialah SATU-SATUNYA identiti client yang mempunyai login, jadi ia
-- yang menentukan siapa boleh melihat projek ini di portal. FK dengan ON DELETE SET
-- NULL: memadam akaun client tidak sepatutnya memadam rekod projek.
--
-- `business_client_id` TIADA foreign key, dan itu bukan kelalaian. `client_users.id`,
-- `employees.id` dan `projects.id` semuanya SIGNED, sementara `business_clients.id`
-- ialah INT UNSIGNED. Kunci melintasi sempadan itu gagal dengan errno 3780 — sudah
-- direkod pada `database/operations_assets.sql:25`. Jadi lajur ini INT UNSIGNED untuk
-- memadankan jenis yang ia rujuk, dan integriti dikuatkuasakan oleh endpoint.
--
-- `phase` ialah lima Process Group PMBOK sebagai SATU MEDAN, bukan lima modul. Bentuk
-- yang sama seperti `business_leads.stage`.
--
-- `health` berasingan daripada `phase` kerana ia menjawab soalan berbeza: `phase`
-- ialah DI MANA projek itu, `health` ialah SAMA ADA ia bermasalah. Satu projek dalam
-- fasa executing boleh on_track atau delayed, dan melipat kedua-duanya menjadi satu
-- enum akan menghasilkan sepuluh nilai yang tiada siapa boleh tapis dengan betul.
SET @sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND COLUMN_NAME = 'phase') = 0,
    'ALTER TABLE `projects`
       ADD COLUMN `client_user_id` INT NULL DEFAULT NULL AFTER `client`,
       ADD COLUMN `business_client_id` INT UNSIGNED NULL DEFAULT NULL AFTER `client_user_id`,
       ADD COLUMN `phase` ENUM(''initiation'',''planning'',''executing'',''monitoring'',''closing'')
                  NOT NULL DEFAULT ''initiation'' AFTER `status`,
       ADD COLUMN `health` ENUM(''on_track'',''at_risk'',''delayed'') NOT NULL DEFAULT ''on_track''
                  AFTER `phase`,
       ADD COLUMN `percent_complete` DECIMAL(5,2) NOT NULL DEFAULT 0.00 AFTER `health`,
       ADD COLUMN `is_public` TINYINT(1) NOT NULL DEFAULT 0 AFTER `percent_complete`,
       ADD KEY `idx_projects_client_user` (`client_user_id`),
       ADD KEY `idx_projects_phase` (`phase`),
       ADD KEY `idx_projects_public` (`is_public`)',
    'DO 0'
  )
)

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── Foreign key ke client_users, berasingan supaya ia boleh dilangkau ──
--
-- Ditambah dalam pernyataan sendiri kerana ia boleh gagal secara sah pada pangkalan
-- data di mana `client_users` menggunakan enjin atau kolasi lain, dan kegagalan itu
-- tidak sepatutnya menghalang lajur di atas daripada wujud.
SET @sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND CONSTRAINT_NAME = 'fk_projects_client_user') = 0,
    'ALTER TABLE `projects`
       ADD CONSTRAINT `fk_projects_client_user` FOREIGN KEY (`client_user_id`)
       REFERENCES `client_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
    'DO 0'
  )
)

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── `status` lalai `completed` ialah perangkap, dan ia sudah ada di sana ──
--
-- Table yang hidup dibuat oleh definisi yang tiada sesiapa simpan, dan lalainya ialah
-- `completed`. Jadi satu projek yang dimasukkan tanpa `status` yang eksplisit lahir
-- sebagai SIAP. Tiada apa akan melaporkannya; ia hanya akan muncul di laman awam
-- sebagai kerja yang telah disempurnakan pada hari ia dicipta.
--
-- Endpoint admin memang sentiasa memberikan `status`, jadi ini tidak pernah menyala
-- hari ini. Itu bukan sebab untuk membiarkannya: lalai ialah apa yang berlaku apabila
-- pemanggil SETERUSNYA terlupa, dan pemanggil seterusnya ialah register penghantaran
-- yang menerbitkan `status` daripada `phase`.
--
-- `planning` memadankan `phase` lalai `initiation`, yang merupakan hubungan yang
-- endpoint akan kekalkan.
ALTER TABLE `projects`
  MODIFY `status` ENUM('planning','ongoing','completed','on-hold') NOT NULL DEFAULT 'planning'
  COMMENT 'perkataan AWAM, diterbitkan daripada phase oleh endpoint admin'

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan: `value` = decimal, `status` lalai = planning, dan tujuh lajur baharu wujud.
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
   AND COLUMN_NAME IN ('project_no','client_user_id','business_client_id','phase',
                       'health','percent_complete','is_public','value','status')
 ORDER BY ORDINAL_POSITION
