-- ══════════════════════════════════════════════════════════════════════════════
-- SATU PROJEK BOLEH MENAMAKAN SATU CUSTOMER PERAKAUNAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec: `.kiro/specs/project-management/` (Task 39)
--
-- SATU lajur. Tiada table baharu, tiada kebenaran baharu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA, DAN IA DATANG DARIPADA SATU UKURAN YANG MENGEJUTKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Dilaporkan daripada skrin: "senarai client kena masukkan dropdown, bukan key in
-- manual." Borang daftar projek MEMANG sudah ada satu dropdown — `client_user_id`,
-- dilabel "No portal access" — jadi jawapan mudahnya ialah "label semula sahaja".
--
-- Ukuran menunjukkan itu tidak cukup:
--
--   client_users        2 baris    log masuk portal
--   business_clients    0 baris    rekod CRM
--   customers          18 baris    master PERAKAUNAN
--
-- Dan 18 customer itu ialah: "Alam Maritim (M) Sdn Bhd", "Bahagian Teknologi
-- Maklumat dan Telekomunikasi...", "Bahagian Perkhidmatan Farmasi, Jabatan
-- Kesihatan...". Itu BENTUK YANG SAMA dengan client dalam daftar projek —
-- "AMANAH SAHAM NASIONAL BERHAD", "JABATAN KEMAJUAN MASYARAKAT(KEMAS) NEGERI
-- PAHANG", "UNIVERSITI PUTRA MALAYSIA".
--
-- Jadi dropdown yang ada membaca table yang SALAH untuk hampir setiap projek. Ia
-- menawarkan 2 pilihan daripada satu daftar log masuk, apabila 18 rekod yang
-- sepadan hidup dalam daftar perakaunan — dan `projects` tiada tempat untuk
-- menyimpan satu daripadanya.
--
-- Itu sebab lajur ini wujud. Tanpanya, "guna dropdown" hanya kosmetik.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA `customers` BOLEH ADA FK DAN `business_clients` TIDAK
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Diukur, kerana ini pernah gagal dalam modul ini sebelum ini:
--
--   projects.id           int              SIGNED
--   customers.id          int              SIGNED      -> FK boleh
--   client_users.id       int              SIGNED      -> FK boleh (sudah ada)
--   business_clients.id   int unsigned     UNSIGNED    -> FK MUSTAHIL, errno 3780
--
-- `project_management_schema.sql` sudah merekod kegagalan itu: `business_client_id`
-- sengaja tiada foreign key kerana satu kunci melintasi sempadan signed/unsigned
-- ditolak oleh MySQL. Lajur ini tiada masalah itu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `ON DELETE SET NULL`, DAN BUKAN CASCADE DAN BUKAN RESTRICT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Bentuk yang SAMA dengan tiga lajur dalam `project_management_cost.sql` dan dengan
-- `assets.project_id` yang mendahului kesemuanya, atas sebab yang sama:
--
--   CASCADE   akan memadam satu PROJEK kerana seseorang mengemas kini daftar
--             customer. Satu projek ialah rekod kontrak; ia tidak dimiliki oleh
--             satu baris dalam ledger
--   RESTRICT  akan menjadikan Project Management penjaga pintu ke atas Perakaunan —
--             satu customer tidak boleh dibuang sampai seseorang mencari dan
--             melepaskan setiap projek
--
-- SET NULL: projek kekal, pautannya hilang, dan `projects.client` — teks warisan —
-- masih memegang nama. Itu sebab lajur teks itu TIDAK dibuang; lihat di bawah.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `projects.client` KEKAL, DAN ITU KEPUTUSAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Ia `VARCHAR(255) NOT NULL` dengan komen 'nama client sebagai teks, warisan', dan
-- 37 projek mengisinya dengan teks bebas hari ini (dilihat pada skrin pengguna;
-- pangkalan data pembangunan ini ada 0 projek, jadi bilangan itu TIDAK dapat saya
-- ukur sendiri dan saya tidak berpura-pura).
--
-- Ia tidak dibuang dan tidak dijadikan nullable, kerana:
--
--   1. Projek yang ada TIDAK terpaut kepada apa-apa. Menjadikan pautan itu wajib
--      akan menjadikan setiap satu daripada mereka tidak sah, dan borang tidak
--      boleh disimpan sampai seseorang memadankan 37 baris dengan tangan.
--   2. Satu projek boleh sah tidak mempunyai rekod: satu tender yang belum
--      dimenangi, satu kerja untuk pihak yang belum pernah diinvois.
--   3. SET NULL di atas memerlukan sesuatu untuk kekal boleh dibaca selepas satu
--      customer dibuang.
--
-- Yang BERUBAH ialah tingkah laku borang: apabila satu rekod dipilih, medan teks
-- itu DITERBITKAN daripadanya dan menjadi baca-sahaja. Menaip nama menjadi
-- pengecualian yang dinyatakan, bukan lalai yang senyap.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA UNIQUE
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Satu customer mempunyai banyak projek — itu keseluruhan maksudnya. Satu unique di
-- sini akan menghadkan setiap agensi kepada satu projek sepanjang hayat.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. Dijalankan dua kali memberi output yang sama.
-- MySQL tiada `ADD COLUMN IF NOT EXISTS` (MariaDB ada), jadi ia melalui
-- `information_schema` dan `PREPARE` — sama seperti `project_management_cost.sql`.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── 1. Lajur ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'projects'
      AND COLUMN_NAME = 'customer_id') = 0,
  'ALTER TABLE `projects`
     ADD COLUMN `customer_id` INT NULL DEFAULT NULL AFTER `business_client_id`,
     ADD KEY `idx_projects_customer` (`customer_id`)',
  'DO 0'
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── 2. Foreign key, berasingan daripada lajur ──
--
-- Dua pernyataan dan bukan satu, kerana larian pertama boleh menambah lajur dan
-- kemudian gagal pada kunci — dan larian kedua mesti masih boleh menambah kunci itu
-- tanpa mencuba menambah lajur lagi. `project_management_cost.sql` belajar ini
-- dengan cara yang susah: ia gagal `ER_FK_DUP_NAME` selepas menambah 2 daripada 3
-- lajur, dan hanya kerana setiap bahagian berasingan ia boleh disambung semula.
--
-- Nama `fk_projects_customer` diperiksa terhadap seluruh skema, bukan hanya table
-- ini: nama FK dalam MySQL ialah ruang nama SATU PANGKALAN DATA. Itu tepat cara
-- `fk_pr_project` bertembung dengan `project_risks`.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'fk_projects_customer') = 0,
  'ALTER TABLE `projects`
     ADD CONSTRAINT `fk_projects_customer` FOREIGN KEY (`customer_id`)
     REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0'
)

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  customer_col 1   customer_fk 1   set_null 1   cascades 0   client_not_null 1
--
-- `set_null 1` ialah baris yang penting. Satu CASCADE di sini akan memadam satu
-- PROJEK kerana seseorang mengemas kini daftar customer.
--
-- `client_not_null 1` membuktikan lajur teks warisan itu masih wajib, jadi 37 projek
-- yang tidak terpaut kekal sah dan borang mereka masih boleh disimpan.
SELECT (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
           AND COLUMN_NAME = 'customer_id') AS customer_col,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE()
           AND CONSTRAINT_NAME = 'fk_projects_customer') AS customer_fk,
       (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE()
           AND CONSTRAINT_NAME = 'fk_projects_customer'
           AND DELETE_RULE = 'SET NULL') AS set_null,
       (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS r
          JOIN information_schema.KEY_COLUMN_USAGE k
            ON k.CONSTRAINT_SCHEMA = r.CONSTRAINT_SCHEMA
           AND k.CONSTRAINT_NAME = r.CONSTRAINT_NAME
         WHERE r.CONSTRAINT_SCHEMA = DATABASE()
           AND k.TABLE_NAME = 'projects'
           AND k.REFERENCED_TABLE_NAME IN ('customers', 'client_users')
           AND r.DELETE_RULE = 'CASCADE') AS cascades,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
           AND COLUMN_NAME = 'client' AND IS_NULLABLE = 'NO') AS client_not_null
