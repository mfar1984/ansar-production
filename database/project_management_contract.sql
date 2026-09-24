-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — blok kontrak, kontak tapak, dan pautan ke tender
--
-- Spec: .kiro/specs/project-management/  (Task 20)
-- Bergantung pada: database/project_management_schema.sql
--
-- ── SEBAB FAIL INI WUJUD ──
--
-- Borang Add Project mempunyai TIGA bahagian sementara Add Tender mempunyai TUJUH,
-- dan aduan itu tepat: satu projek penghantaran tidak boleh direkodkan dengan tajuk,
-- nama client dan satu tarikh. Yang hilang ialah kontrak yang mengikat kita, dan
-- orang yang perlu dihubungi di tapak.
--
-- ── SATU PEPIJAT YANG DIUKUR, DAN IA MENGHALANG SETIAP SISIPAN ──
--
-- `sql_mode` pada pelayan ini mengandungi `STRICT_TRANS_TABLES`, dan LIMA lajur pada
-- `projects` ialah NOT NULL: `sector`, `category`, `year`, `location`, `value`.
-- `location` pula NOT NULL dan TIADA default sama sekali.
--
-- Endpoint register menamakan kesemuanya dalam INSERT dan menghantar NULL untuk medan
-- yang kosong, jadi:
--
--   ER_BAD_NULL_ERROR: Column 'sector' cannot be null
--   ER_BAD_NULL_ERROR: Column 'location' cannot be null
--
-- Borang hanya menandakan Title dan Client sebagai wajib. Jadi perkara PERTAMA yang
-- seorang pengguna buat — isi dua medan wajib dan tekan Add — memulangkan 500.
-- Dibuktikan dengan empat sisipan dalam satu transaksi yang di-rollback, bukan
-- disimpulkan.
--
-- Endpoint kini COALESCE lajur-lajur itu, kerana ia yang menamakannya. `location`
-- juga diberi DEFAULT di bawah, supaya pemanggil yang MENINGGALKAN lajur itu turut
-- berfungsi — dua tali pinggang, dan yang kedua tidak berkos apa-apa.
--
-- ── `tenders` SUDAH MENYIMPAN KONTRAK. JADI KITA PAUTKAN, DAN BAWA MERENTAS. ──
--
-- Diukur: `tenders` mempunyai 51 lajur dan blok anugerahnya sudah lengkap —
-- `contract_no`, `actual_value`, `award_date`, `project_start`, `project_end`,
-- `handover_date`, `dlp_months`, ditambah `contact_person`, `contact_designation`,
-- `contact_phone`, `contact_email` dan `agency_address`.
--
-- Jadi satu tender yang DIMENANGI sudah memegang tiga belas nilai yang satu projek
-- penghantaran perlukan. Menaipnya semula ialah tiga belas peluang untuk tersalah satu.
--
-- Corak yang dipilih ialah corak yang codebase ini sudah gunakan: `vendors` mengimport
-- daripada `procurement_applications` melalui `vendors.application_id`, dan komennya
-- berkata "dengan butirannya dibawa merentas dan bukan ditaip semula". PAUT dengan id
-- DAN salin nilainya, kerana dua rekod itu kemudian mempunyai hayat berasingan: satu
-- tender boleh diarkibkan dan projek itu mesti kekal boleh dibaca. Sebab yang sama
-- `project_messages.sender_name` dicache.
--
-- `tender_id` ialah INT UNSIGNED kerana `tenders.id` INT UNSIGNED. `assets.tender_id`
-- sudah INT UNSIGNED dengan FK yang berfungsi, jadi bentuk itu dibuktikan pada table
-- ini. Ini BUKAN kes errno 3780 yang `business_client_id` alami: masalah di sana ialah
-- dua lajur yang tandanya BERBEZA, bukan satu table bertanda merujuk satu yang tidak.
--
-- ON DELETE SET NULL: memadam satu tender tidak sepatutnya memadam projek yang
-- dimenangi daripadanya. Nilai yang dibawa merentas kekal pada baris projek, jadi
-- rekod itu masih lengkap selepas pautan itu hilang.
--
-- ── APA YANG TIDAK DITAMBAH, DAN MENGAPA ──
--
-- TIADA `contract_sum`. `value` sudah DECIMAL(15,2) dan sudah bermaksud nilai kontrak;
-- lajur kedua untuk jumlah yang sama ialah dua nombor yang akan bercanggah.
--
-- TIADA `variation_total`. Itu satu AGREGAT atas `project_changes`, yang Phase 3 bina.
-- Menyimpan jumlah yang diterbitkan sebagai lajur ialah angka yang menjadi stale pada
-- variasi seterusnya.
--
-- TIADA `manager_name`. Pengurus projek ialah satu baris `project_participants` dengan
-- `role` dan `can_message`, yang sudah dibina dan lebih kaya daripada satu string.
-- Borang create menamakan seorang pekerja dan endpoint menyisipkan baris peserta itu
-- dalam transaksi yang sama — jadi tiada lajur baharu, dan model yang sudah ada
-- digunakan.
--
-- IDEMPOTENT. Setiap ALTER melalui PREPARE, dikawal pada KEWUJUDAN lajur, kerana
-- `ALTER TABLE ... ADD COLUMN` yang terdedah gagal pada jalan kedua dan `IF()` yang
-- menamakan lajur tidak membantu — MySQL menyelesaikan KEDUA-DUA cabang apabila ia
-- prepare. Corak yang sama seperti `project_management_schema.sql`.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_contract.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── `location` mendapat DEFAULT, supaya lajur yang ditinggalkan tidak memecahkan sisipan ──
--
-- Ia kekal NOT NULL. Halaman awam membacanya dan `ProjectsClient.tsx` memaparkannya,
-- jadi menjadikannya nullable mengubah kontrak awam untuk tiada faedah — '' dan NULL
-- kedua-duanya render kosong di sana. Yang diperlukan hanyalah satu default, yang
-- lajur itu tidak pernah ada.
ALTER TABLE `projects`
  MODIFY `location` VARCHAR(255) NOT NULL DEFAULT ''
  COMMENT 'NOT NULL dengan default: halaman awam membacanya, jadi kosong ialah "" bukan NULL'

-- >>>
-- ── Blok kontrak dan kontak tapak ──
--
-- Lebar disalin TEPAT daripada `tenders`, supaya satu nilai yang dibawa merentas
-- daripada tender tidak boleh terpotong. `contact_designation` 120,
-- `contact_person` 150, `contact_phone` 40, `contact_email` 150, dan `site_address`
-- 400 seperti `tenders.agency_address`.
SET @sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND COLUMN_NAME = 'contract_no') = 0,
    'ALTER TABLE `projects`
       ADD COLUMN `tender_id` INT UNSIGNED NULL DEFAULT NULL AFTER `business_client_id`,
       ADD COLUMN `contract_no` VARCHAR(80) NULL DEFAULT NULL AFTER `tender_id`,
       ADD COLUMN `contract_date` DATE NULL DEFAULT NULL AFTER `contract_no`,
       ADD COLUMN `retention_percent` DECIMAL(5,2) NULL DEFAULT NULL AFTER `value`,
       ADD COLUMN `handover_date` DATE NULL DEFAULT NULL AFTER `end_date`,
       ADD COLUMN `dlp_months` SMALLINT UNSIGNED NULL DEFAULT NULL AFTER `handover_date`,
       ADD COLUMN `contact_person` VARCHAR(150) NULL DEFAULT NULL AFTER `dlp_months`,
       ADD COLUMN `contact_designation` VARCHAR(120) NULL DEFAULT NULL AFTER `contact_person`,
       ADD COLUMN `contact_phone` VARCHAR(40) NULL DEFAULT NULL AFTER `contact_designation`,
       ADD COLUMN `contact_email` VARCHAR(150) NULL DEFAULT NULL AFTER `contact_phone`,
       ADD COLUMN `site_address` VARCHAR(400) NULL DEFAULT NULL AFTER `contact_email`,
       ADD KEY `idx_projects_tender` (`tender_id`),
       ADD KEY `idx_projects_contract` (`contract_no`)',
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
-- ── Foreign key ke tenders, berasingan ──
--
-- Berasingan daripada blok ADD COLUMN di atas supaya satu kegagalan di sini tidak
-- menghalang sebelas lajur itu daripada wujud. `assets.tender_id` membuktikan bentuk
-- ini berfungsi pada pangkalan data ini, jadi ia tidak dijangka gagal — tetapi
-- `project_management_chat.sql` merekod apa yang berlaku apabila satu ALTER gabungan
-- gagal separuh jalan.
SET @sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
        AND CONSTRAINT_NAME = 'fk_projects_tender') = 0,
    'ALTER TABLE `projects`
       ADD CONSTRAINT `fk_projects_tender` FOREIGN KEY (`tender_id`)
       REFERENCES `tenders` (`id`) ON DELETE SET NULL ON UPDATE CASCADE',
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
-- ── Verifikasi ──
--
-- Jangkaan: sebelas lajur baharu, dan `location` kini mempunyai default ''.
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects'
   AND COLUMN_NAME IN ('tender_id','contract_no','contract_date','retention_percent',
                       'handover_date','dlp_months','contact_person','contact_designation',
                       'contact_phone','contact_email','site_address','location')
 ORDER BY ORDINAL_POSITION
