-- ══════════════════════════════════════════════════════════════════════════════
-- SATU LOG MASUK PORTAL BOLEH MENAMAKAN CUSTOMER PERAKAUNAN YANG DIMILIKINYA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec: `.kiro/specs/project-management/` (Task 41)
--
-- SATU lajur. Tiada table baharu, tiada kebenaran baharu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA — DAN SOALAN PENGGUNA YANG MENYEBABKANNYA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Dilaporkan daripada skrin: "kenapa data client x ambil je data dari CLIENT LOGIN.
-- kan sama je tu."
--
-- Jawapannya tidak, dan `project_management_customer.sql` sudah merekod sebabnya:
-- CLIENT LOGIN ada 2 baris, daftar perakaunan ada 18, dan register projek ada 37
-- projek. Satu borang yang membaca CLIENT LOGIN sahaja tidak dapat menamakan client
-- bagi 35 daripada 37.
--
-- Tetapi bahagian KEDUA soalan itu betul, dan lajur ini ialah jawapannya: mereka
-- bukan benda yang sama, tetapi mereka PATUT BERSAMBUNG. Diukur, dan inilah keadaan
-- sebenar sebelum lajur ini:
--
--   customers        18 baris    has_login = 0 bagi KESEMUA 18
--   client_users      2 baris    same_name_in_customers = 0 bagi KEDUA-DUANYA
--
-- Sifar sambungan, dua arah. Jadi borang daftar projek mempunyai dua dropdown yang
-- kedua-duanya berbunyi "Client" dan tiada apa-apa yang mengaitkan mereka — itu
-- sebab pengguna keliru, dan kekeliruan itu ialah laporannya.
--
-- Dengan lajur ini, "Portal access" pada borang projek DITAPIS oleh rekod client
-- yang dipilih: log masuk yang dimiliki oleh customer LAIN tidak lagi ditawarkan.
-- Itu perubahan tingkah laku sebenar, bukan label baharu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- SATU CUSTOMER, BANYAK LOG MASUK. JADI TIADA UNIQUE.
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Arah pautan ini bukan simetri, dan ia penting:
--
--   satu log masuk    -> tepat satu customer    (satu akaun tergolong kepada satu
--                                                syarikat; itu sebab lajur ini
--                                                duduk di `client_users`)
--   satu customer     -> banyak log masuk       (satu jabatan besar boleh ada
--                                                beberapa pegawai, masing-masing
--                                                dengan akaun sendiri)
--
-- Satu UNIQUE di sini akan menghadkan setiap agensi kepada SATU akaun portal
-- sepanjang hayat, dan tiada siapa meminta had itu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `ON DELETE SET NULL`, DAN BUKAN CASCADE DAN BUKAN RESTRICT
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Bentuk yang sama dengan `projects.customer_id`, tetapi sebab CASCADE ditolak di
-- sini adalah LEBIH KUAT:
--
--   CASCADE   akan memadam satu AKAUN LOG MASUK kerana seseorang mengemas kini
--             daftar customer. Itu kelayakan seseorang, sejarah mesej mereka dalam
--             `project_messages`, dan sesi mereka. Satu baris ledger tidak memiliki
--             identiti seseorang
--   RESTRICT  akan menjadikan portal client penjaga pintu ke atas Perakaunan — satu
--             customer tidak boleh dibuang sampai seseorang mencari dan memadam
--             akaun portal mereka dahulu
--
-- SET NULL: akaun itu kekal dan masih boleh log masuk. Ia cuma tidak lagi mendakwa
-- tergolong kepada satu rekod perakaunan yang sudah tiada.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- FK BOLEH DI SINI, DAN IA DIUKUR
-- ══════════════════════════════════════════════════════════════════════════════
--
--   client_users.id       int              SIGNED      -> FK boleh
--   customers.id          int              SIGNED      -> FK boleh
--   business_clients.id   int unsigned     UNSIGNED    -> FK MUSTAHIL, errno 3780
--
-- Itu sebab tiada `business_client_id` pada table ini. Halangan yang sama yang
-- direkod dalam `project_management_schema.sql`, bukan satu kelalaian.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA PADANAN AUTOMATIK. INI KEPUTUSAN, BUKAN KELALAIAN.
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Menggoda untuk memadankan 2 baris itu di sini mengikut nama. Ia juga akan BERJAYA,
-- dan itulah bahayanya. Diukur:
--
--   client_users : JABATAN KEMAJUAN MASYARAKAT(KEMAS) NEGERI PAHANG
--   customers    : Jabatan Kemajuan Masyarakat (KEMAS) Negeri Pahang
--
-- Tiada ruang sebelum `(`, huruf besar/kecil berbeza. Satu padanan tepat memberi
-- SIFAR; satu padanan ternormal (buang bukan-alfanumerik, huruf kecil) memberi
-- padanan — kedua-dua rentetan menjadi
-- `jabatankemajuanmasyarakatkemasnegeripahang`.
--
-- Ia tidak dibuat, kerana akibat satu padanan yang SALAH bukan kosmetik: satu akaun
-- portal yang terpaut kepada syarikat yang salah akan ditawarkan sebagai pilihan
-- pada projek syarikat itu, dan seseorang boleh memberi akses kepada pihak yang
-- salah. Itu bukan risiko yang patut diambil oleh satu heuristik nama untuk
-- menjimatkan dua klik.
--
-- `KF Legacy Resources` pula tiada dalam `customers` sama sekali — ia akaun ujian —
-- jadi satu padanan automatik akan meninggalkannya NULL walau apa pun.
--
-- Skrin Settings > Users > Client menunjukkan "Not linked to a client record" pada
-- setiap baris yang belum terpaut, jadi kerja yang tinggal itu KELIHATAN dan bukan
-- tersembunyi dalam table.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- NULL DIBENARKAN SELAMANYA, BUKAN SEMENTARA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Satu akaun portal yang sah boleh tiada rekod perakaunan: satu pihak yang belum
-- pernah diinvois, satu akaun ujian, satu prospek yang diberi akses awal. Jadi
-- lajur ini kekal NULL-boleh dan pelayan MEMBENARKAN satu log masuk yang tidak
-- terpaut dipilih pada mana-mana projek. Yang ia TOLAK hanyalah log masuk yang
-- terpaut kepada customer yang BERBEZA daripada yang dinamakan projek itu.
--
-- Menjadikannya wajib akan mematikan kedua-dua akaun yang ada serta-merta.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. Dijalankan dua kali memberi output yang sama.
-- MySQL tiada `ADD COLUMN IF NOT EXISTS` (MariaDB ada), jadi ia melalui
-- `information_schema` dan `PREPARE` — sama seperti `project_management_customer.sql`.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── 1. Lajur ──
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'client_users'
      AND COLUMN_NAME = 'customer_id') = 0,
  'ALTER TABLE `client_users`
     ADD COLUMN `customer_id` INT NULL DEFAULT NULL
       COMMENT ''rekod perakaunan yang dimiliki akaun ini; NULL bermaksud belum terpaut''
       AFTER `address`,
     ADD KEY `idx_client_users_customer` (`customer_id`)',
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
-- Dua pernyataan dan bukan satu, atas sebab yang `project_management_cost.sql`
-- belajar dengan cara susah: larian pertama boleh menambah lajur dan kemudian gagal
-- pada kunci, dan larian kedua mesti masih boleh menambah kunci itu tanpa mencuba
-- menambah lajur lagi.
--
-- Nama `fk_client_users_customer` diperiksa terhadap seluruh skema, bukan hanya
-- table ini: nama FK dalam MySQL ialah ruang nama SATU PANGKALAN DATA.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND CONSTRAINT_NAME = 'fk_client_users_customer') = 0,
  'ALTER TABLE `client_users`
     ADD CONSTRAINT `fk_client_users_customer` FOREIGN KEY (`customer_id`)
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
-- Jangkaan:  cu_col 1   cu_fk 1   set_null 1   cascades 0   nullable 1   no_unique 0
--
-- `set_null 1` ialah baris yang penting. Satu CASCADE di sini akan memadam satu
-- AKAUN LOG MASUK kerana seseorang mengemas kini daftar customer.
--
-- `nullable 1` membuktikan satu akaun portal masih boleh wujud tanpa rekod
-- perakaunan — kedua-dua akaun yang ada hari ini berada dalam keadaan itu.
--
-- `no_unique 0` membuktikan satu customer masih boleh memegang beberapa log masuk.
SELECT (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'client_users'
           AND COLUMN_NAME = 'customer_id') AS cu_col,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE()
           AND CONSTRAINT_NAME = 'fk_client_users_customer') AS cu_fk,
       (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
         WHERE CONSTRAINT_SCHEMA = DATABASE()
           AND CONSTRAINT_NAME = 'fk_client_users_customer'
           AND DELETE_RULE = 'SET NULL') AS set_null,
       (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS r
          JOIN information_schema.KEY_COLUMN_USAGE k
            ON k.CONSTRAINT_SCHEMA = r.CONSTRAINT_SCHEMA
           AND k.CONSTRAINT_NAME = r.CONSTRAINT_NAME
         WHERE r.CONSTRAINT_SCHEMA = DATABASE()
           AND k.TABLE_NAME = 'client_users'
           AND k.REFERENCED_TABLE_NAME = 'customers'
           AND r.DELETE_RULE = 'CASCADE') AS cascades,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'client_users'
           AND COLUMN_NAME = 'customer_id' AND IS_NULLABLE = 'YES') AS nullable,
       (SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'client_users'
           AND COLUMN_NAME = 'customer_id' AND NON_UNIQUE = 0) AS no_unique
