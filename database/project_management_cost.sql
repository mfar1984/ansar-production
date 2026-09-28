-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — rujukan projek atas perbelanjaan, dan satu bajet
--
-- Spec: .kiro/specs/project-management/  (Task 36 — leaf Budget & Cost + Project Procurement)
-- Bergantung pada: database/project_management_schema.sql
--                  database/create_procurement_table.sql   (purchase_requests, purchase_orders)
--                  database/create_expenses_management.sql (expenses)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- INI SATU-SATUNYA MIGRASI DALAM MODUL INI YANG MENYENTUH TABLE MODUL LAIN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Tooltip kedua-dua leaf Commercial menamakan halangan yang sama, dan ia betul:
--
--   "no accounting table in this database carries a project reference, so budget against
--    actual would report zero spend on a signed contract"
--
-- Jadi migrasi ini menambah rujukan itu. Tiga lajur pada tiga table yang BUKAN milik modul
-- ini, dan satu lajur pada `projects` yang memang miliknya.
--
-- ── MENGAPA INI SELAMAT, DIUKUR DAN BUKAN DIANDAIKAN ──
--
--   purchase_requests   0 baris
--   purchase_orders     0 baris
--   expenses            1 baris
--
-- Setiap lajur NULLABLE tanpa default, jadi tiada backfill dan tiada baris sedia ada berubah.
-- Tiada query sedia ada memilih `*` daripada table ini ke dalam satu bentuk yang ketat —
-- disemak — jadi satu lajur tambahan tidak boleh memecahkan satu pembacaan.
--
-- ── DAN PRESEDENNYA SUDAH ADA DALAM PANGKALAN DATA INI ──
--
-- `assets.project_id` SUDAH merujuk `projects` dengan `ON DELETE SET NULL`. Ia satu-satunya
-- table bukan-projek yang berbuat demikian, daripada 14 yang merujuk `projects`. Jadi bentuk
-- "satu table modul lain memegang satu rujukan projek nullable yang menjadi NULL bila projek
-- dipadam" bukan sesuatu yang task ini cipta — ia sudah dipilih dan sudah hidup.
--
-- Tiga lajur baharu meniru `assets.project_id` TEPAT: nullable, INT, FK ke `projects(id)`,
-- `ON DELETE SET NULL`.
--
-- ── MENGAPA `SET NULL` DAN BUKAN `CASCADE` ──
--
-- CASCADE akan memadam satu pesanan belian bila satu projek dipadam. Satu pesanan belian
-- ialah dokumen KEWANGAN: ia ada nombor, ia mungkin sudah diluluskan, dan ia mungkin sudah
-- dipos ke ledger. Memadamnya kerana seseorang membuang satu projek ialah kehilangan rekod
-- perakaunan untuk sebab yang bukan perakaunan.
--
-- `SET NULL` meninggalkan dokumen itu di tempatnya dan hanya kehilangan tagnya. Itu juga
-- pilihan yang `assets` sudah buat: satu aset tidak hilang kerana projeknya hilang.
--
-- ── DAN `RESTRICT` DITOLAK ──
--
-- Ia akan menghalang pemadaman satu projek yang mana-mana pesanan belian namakan — iaitu
-- menjadikan modul perakaunan sebagai penjaga pintu ke atas daftar projek. Satu projek yang
-- dimasukkan dengan silap kemudian tidak boleh dibuang tanpa menyentuh dokumen belian dahulu.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `projects.budget_cost` — DAN MENGAPA `value` BUKAN BAJET
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `projects.value` ialah NILAI KONTRAK: apa yang client bayar. Ia HASIL.
--
-- Satu bajet ialah KOS yang dirancang. Membandingkan kos sebenar terhadap `value` memberi
-- MARGIN, bukan varians bajet — dan melabelkannya "budget vs actual" akan menamakan satu
-- nombor sebagai sesuatu yang bukan dia.
--
-- Jadi satu lajur baharu, dan ia NULLABLE dengan sengaja: satu projek tanpa bajet memaparkan
-- "no budget set" dan bukan satu varians terhadap sifar. Sifar akan menjadikan setiap projek
-- kelihatan 100% terlebih belanja dari hari pertama.
--
-- ── DI MANA IA DISUNTING, DAN MENGAPA BUKAN ATAS SKRIN BUDGET & COST ──
--
-- `project_cost` menyemai SATU tindakan: `view`. Jadi skrin Budget & Cost tidak boleh menulis
-- apa-apa, dan itu bukan kelalaian — ia satu agregat baca-sahaja atas Perakaunan, HR dan
-- daftar vendor, sama seperti `project_resources` dan `project_procurement`.
--
-- Jadi bajet disunting di tempat setiap medan komersial lain projek disunting: borang daftar,
-- di bawah `projects_delivery_edit`, di sebelah `value` dan `retention_percent`. Satu tempat
-- yang menulis nilai kontrak dan satu tempat lain yang menulis bajet akan menjadi dua borang
-- untuk satu perbualan.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT — DAN `ADD COLUMN IF NOT EXISTS` TIDAK BOLEH DIGUNAKAN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- MySQL TIDAK menyokong `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`. MariaDB menyokongnya,
-- tetapi pangkalan data pembangunan ialah MySQL 8.0.45 dan produksi ialah MariaDB 11.4.13 —
-- satu pernyataan yang berjalan atas satu dan gagal atas yang lain ialah tepat kelas kesilapan
-- yang `tests/sql/sql-portability.test.js` wujud untuk menghalang.
--
-- Jadi setiap penambahan dibuat dengan satu blok `information_schema` + `PREPARE`, yang
-- kedua-dua enjin terima. Jalankan dua kali dan larian kedua tidak berbuat apa-apa.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. purchase_requests.project_id
-- ═══════════════════════════════════════════════════════════════════════════════

-- `preq_`, NOT `pr_`. Nama foreign key ialah ruang nama SATU SKEMA dalam MySQL, sama seperti
-- nama CHECK — dan `fk_pr_project` SUDAH dimiliki oleh `project_risks`. Larian pertama gagal
-- dengan `ER_FK_DUP_NAME` dan meninggalkan lajur ini tidak ditambah sementara dua yang lain
-- berjaya, yang mana adalah tepat sebab baris pengesahan di bawah mengira keempat-empat lajur
-- secara berasingan dan bukan melaporkan satu "berjaya".
--
-- `chk_prp_*` (project_reports) sudah merekod kesilapan yang sama untuk CHECK. Awalan dua huruf
-- atas satu skema dengan 130 table akan bertembung; ini yang kedua.

SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'purchase_requests'
      AND column_name = 'project_id') = 0,
  'ALTER TABLE `purchase_requests`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL AFTER `department`,
     ADD KEY `idx_preq_project` (`project_id`),
     ADD CONSTRAINT `fk_preq_project` FOREIGN KEY (`project_id`)
       REFERENCES `projects` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0');

-- >>>

PREPARE stmt FROM @sql;

-- >>>

EXECUTE stmt;

-- >>>

DEALLOCATE PREPARE stmt;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. purchase_orders.project_id
-- ═══════════════════════════════════════════════════════════════════════════════

SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'purchase_orders'
      AND column_name = 'project_id') = 0,
  'ALTER TABLE `purchase_orders`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL AFTER `department`,
     ADD KEY `idx_po_project` (`project_id`),
     ADD CONSTRAINT `fk_po_project` FOREIGN KEY (`project_id`)
       REFERENCES `projects` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0');

-- >>>

PREPARE stmt FROM @sql;

-- >>>

EXECUTE stmt;

-- >>>

DEALLOCATE PREPARE stmt;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. expenses.project_id
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Satu tuntutan perbelanjaan pekerja ialah perbelanjaan projek sebenar: perjalanan ke tapak,
-- bahan yang dibeli tunai, penginapan semasa pemasangan. Ia dibayar oleh syarikat sama seperti
-- satu pesanan belian, hanya melalui laluan yang berbeza.
--
-- `AFTER category_id`, kerana di situlah pengelasan tuntutan itu sudah duduk.

SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'expenses'
      AND column_name = 'project_id') = 0,
  'ALTER TABLE `expenses`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL AFTER `category_id`,
     ADD KEY `idx_exp_project` (`project_id`),
     ADD CONSTRAINT `fk_exp_project` FOREIGN KEY (`project_id`)
       REFERENCES `projects` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0');

-- >>>

PREPARE stmt FROM @sql;

-- >>>

EXECUTE stmt;

-- >>>

DEALLOCATE PREPARE stmt;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. projects.budget_cost
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- DECIMAL(15,2), sama seperti `projects.value`, supaya kedua-duanya boleh ditolak tanpa
-- penukaran jenis. NULLABLE: lihat nota di atas — sifar akan menjadikan setiap projek
-- kelihatan 100% terlebih belanja.
--
-- TIADA CHECK bahawa bajet lebih kecil daripada nilai kontrak. Ia BOLEH lebih besar, dan
-- bila ia lebih besar itu satu penemuan yang skrin patut laporkan — bukan satu baris yang
-- pangkalan data patut tolak. Satu kontrak yang dianggarkan pada kerugian kadangkala ditandatangan
-- dengan sengaja.

SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'projects'
      AND column_name = 'budget_cost') = 0,
  'ALTER TABLE `projects`
     ADD COLUMN `budget_cost` DECIMAL(15,2) NULL DEFAULT NULL AFTER `value`',
  'DO 0');

-- >>>

PREPARE stmt FROM @sql;

-- >>>

EXECUTE stmt;

-- >>>

DEALLOCATE PREPARE stmt;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- PENGESAHAN — apa yang operator baca atas pelayan
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Jangkaan:  pr_col 1   po_col 1   exp_col 1   budget_col 1   project_fks 4   cascades 0
--
-- `project_fks 4` ialah TIGA yang baharu campur `assets.project_id` yang sudah ada. Kalau ia
-- 1, tiada satu pun ALTER berjalan dan kedua-dua leaf Commercial akan melaporkan sifar
-- perbelanjaan atas setiap projek.
--
-- `cascades 0` ialah semakan paling penting di sini. Ia mengira berapa banyak table BUKAN
-- projek yang merujuk `projects` dengan CASCADE, dan jawapannya mesti SIFAR. Satu CASCADE
-- akan memadam pesanan belian bila satu projek dipadam — kehilangan rekod perakaunan untuk
-- sebab yang bukan perakaunan.

SELECT (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'purchase_requests'
           AND column_name = 'project_id') AS pr_col,
       (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'purchase_orders'
           AND column_name = 'project_id') AS po_col,
       (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'expenses'
           AND column_name = 'project_id') AS exp_col,
       (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'projects'
           AND column_name = 'budget_cost') AS budget_col,
       (SELECT COUNT(*) FROM information_schema.key_column_usage kcu
         WHERE kcu.table_schema = DATABASE() AND kcu.referenced_table_name = 'projects'
           AND kcu.table_name NOT LIKE 'project%') AS project_fks,
       (SELECT COUNT(*) FROM information_schema.referential_constraints rc
          JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = rc.constraint_name
           AND kcu.constraint_schema = rc.constraint_schema
         WHERE rc.constraint_schema = DATABASE()
           AND kcu.referenced_table_name = 'projects'
           AND kcu.table_name NOT LIKE 'project%'
           AND rc.delete_rule = 'CASCADE') AS cascades;
