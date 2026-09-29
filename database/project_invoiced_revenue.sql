-- ══════════════════════════════════════════════════════════════════════════════
-- SATU INVOIS JUALAN BOLEH DITANDAKAN KEPADA SATU PROJEK
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec: `.kiro/specs/project-management/` (Task 43)
--
-- SATU lajur: `sales_invoices.project_id`. Tiada table baharu, tiada kebenaran baharu.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA — DAN BUKAN ATAS SEBAB YANG DICATAT DALAM SPEC
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec menyenaraikan ini selama ini sebagai "hasil yang diinvois ialah separuh lagi
-- bagi untung". Itu benar dan ia BUKAN hujah yang paling kuat. Hujah yang lebih kuat
-- datang daripada mengukur apa yang tab Cost sebenarnya boleh laporkan hari ini:
--
--   `earned` = value × percent_complete / 100, dan ia NULL melainkan projek itu ada
--   milestone. Diukur atas data produksi: hanya 2 daripada 37 projek ada milestone.
--   Jadi angka hasil pada tab itu adalah NULL untuk 35 projek.
--
-- Dan `percent_complete` sendiri bukan ukuran kemajuan pada data ini — ia 0 atau 100
-- sahaja, ditetapkan oleh penutupan fasa dalam `[id]/phase.ts`, bukan diterbitkan
-- daripada berat milestone seperti yang komen endpoint itu andaikan.
--
-- Hasil yang DIINVOIS tidak bergantung pada mana-mana itu. Ia fakta keras: satu
-- dokumen wujud, ia diluluskan, ia ada jumlah. Jadi lajur ini memberi tab Cost angka
-- hasil PERTAMA yang tidak memerlukan seorang pun memasukkan milestone.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IA TIDAK AKAN MELAPORKAN APA-APA HARI INI, DAN ITU DINYATAKAN BUKAN DISEMBUNYIKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Diukur atas salinan produksi sebelum menulis fail ini:
--
--   sales_invoices      0 baris
--   delivery_orders     0 baris
--   ar_receipts         0 baris
--   journal_entries     0 baris
--   sales_orders        1 baris
--
-- Jadi lajur ini ialah PAIP, bukan laporan. Ia akan melaporkan sifar sampai seseorang
-- mula mengeluarkan invois. Itu direkod di sini supaya tiada siapa kemudian membaca
-- "invoiced 0" sebagai pepijat.
--
-- Sebab ia dibuat sekarang dan bukan nanti: `sales_invoices` ada 40 lajur dengan
-- integrasi e-invois terpasang padanya, dan menambah satu lajur pada table itu lebih
-- murah dilakukan sekali sekarang daripada bersama satu perubahan lain kemudian.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `ON DELETE SET NULL`, DAN DI SINI HUJAHNYA LEBIH KERAS DARIPADA YANG LAIN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Bentuk yang sama seperti tiga lajur dalam `project_management_cost.sql`, tetapi
-- alasan menolak CASCADE lebih kuat di sini daripada mana-mana:
--
--   CASCADE   akan memadam satu INVOIS CUKAI yang mungkin sudah difailkan kepada
--             LHDN, kerana seseorang membuang satu projek. Itu bukan kehilangan
--             rekod perakaunan sahaja — ia kehilangan dokumen berkanun.
--   RESTRICT  akan menjadikan Perakaunan penjaga pintu ke atas daftar projek: satu
--             projek tidak boleh dibuang sampai seseorang mencari setiap invois.
--
-- SET NULL: invois kekal, pautannya hilang, dan laporan kos berhenti mengira hasil
-- itu kepada projek yang sudah tiada.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- NAMA: `sinv`, BUKAN `si` — DAN ITU PELAJARAN YANG DIBAYAR
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `project_management_cost.sql` merekod kegagalan sebenar: awalan `pr_` dipilih untuk
-- `purchase_requests`, dan `fk_pr_project` SUDAH dimiliki oleh `project_risks`.
-- Larian pertama gagal `ER_FK_DUP_NAME` dan meninggalkan satu lajur tidak ditambah
-- sementara dua yang lain berjaya. Nama FK dalam MySQL ialah ruang nama SATU
-- PANGKALAN DATA, bukan satu table.
--
-- Kedua-dua `fk_si_project` dan `fk_sinv_project` disemak terhadap seluruh skema dan
-- kedua-duanya bebas. `sinv` dipilih kerana komen fail itu sendiri berkata awalan dua
-- huruf atas skema 130 table akan bertembung — ini kali kedua nasihat itu diikut.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `AFTER location`
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `location` ialah tapak; projek ialah kerja di tapak itu. Diukur: `location` pada
-- kedudukan 15, jadi lajur ini mendarat pada 16.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA SNAPSHOT, DAN ITU KEPUTUSAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Hanya id. Tiada `project_no` atau `title` disalin ke atas invois, tidak seperti
-- `deposit_to_account_code`/`_name` pada jualan tunai.
--
-- Sebabnya dicatat dalam `purchase-document-kinds.ts` dan ia terpakai sama: satu kod
-- akaun DICETAK pada dokumen yang orang failkan, jadi ia dibekukan. Satu rujukan
-- projek DIIKUT pada masa baca oleh laporan kos, dan satu projek yang dinamakan semula
-- tahun depan patut muncul di bawah nama barunya di situ.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. MySQL tiada `ADD COLUMN IF NOT EXISTS` (MariaDB ada), jadi ia melalui
-- `information_schema` dan `PREPARE` — bentuk yang sama seperti
-- `project_management_cost.sql`, dan sebab `tests/sql/sql-portability.test.js` wujud.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'sales_invoices'
      AND column_name = 'project_id') = 0,
  'ALTER TABLE `sales_invoices`
     ADD COLUMN `project_id` INT NULL DEFAULT NULL AFTER `location`,
     ADD KEY `idx_sinv_project` (`project_id`),
     ADD CONSTRAINT `fk_sinv_project` FOREIGN KEY (`project_id`)
       REFERENCES `projects` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
  'DO 0')

-- >>>
PREPARE stmt FROM @sql

-- >>>
EXECUTE stmt

-- >>>
DEALLOCATE PREPARE stmt

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- PENGESAHAN — apa yang operator baca atas pelayan
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Jangkaan:  sinv_col 1   sinv_fk 1   set_null 1   cascades 0   project_fks 5
--            invoices_now 0   tagged_now 0
--
-- `cascades 0` ialah semakan paling penting, dan ia semakan yang SAMA seperti dalam
-- `project_management_cost.sql`: ia mengira berapa banyak table BUKAN projek merujuk
-- `projects` dengan CASCADE, dan jawapannya mesti SIFAR. Satu CASCADE di sini akan
-- memadam satu invois cukai.
--
-- `project_fks 5` ialah empat yang sudah ada (`purchase_requests`, `purchase_orders`,
-- `expenses`, `assets`) campur yang ini. Komen dalam `project_management_cost.sql`
-- menjangka 4 dan itu betul pada masa ia ditulis — ia dikemas kini dalam perubahan ini
-- supaya larian semula tidak melaporkan penggera palsu.
--
-- `invoices_now 0` dan `tagged_now 0` BUKAN kegagalan. Ia direkod supaya pembaca tahu
-- angka hasil akan sifar sampai seseorang mengeluarkan invois.
SELECT (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'sales_invoices'
           AND column_name = 'project_id') AS sinv_col,
       (SELECT COUNT(*) FROM information_schema.table_constraints
         WHERE constraint_schema = DATABASE()
           AND constraint_name = 'fk_sinv_project') AS sinv_fk,
       (SELECT COUNT(*) FROM information_schema.referential_constraints
         WHERE constraint_schema = DATABASE()
           AND constraint_name = 'fk_sinv_project'
           AND delete_rule = 'SET NULL') AS set_null,
       (SELECT COUNT(*) FROM information_schema.referential_constraints rc
          JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = rc.constraint_name
           AND kcu.constraint_schema = rc.constraint_schema
         WHERE rc.constraint_schema = DATABASE()
           AND kcu.referenced_table_name = 'projects'
           AND kcu.table_name NOT LIKE 'project%'
           AND rc.delete_rule = 'CASCADE') AS cascades,
       (SELECT COUNT(*) FROM information_schema.key_column_usage kcu
         WHERE kcu.table_schema = DATABASE() AND kcu.referenced_table_name = 'projects'
           AND kcu.table_name NOT LIKE 'project%') AS project_fks,
       (SELECT COUNT(*) FROM `sales_invoices`) AS invoices_now,
       (SELECT COUNT(*) FROM `sales_invoices` WHERE `project_id` IS NOT NULL) AS tagged_now
