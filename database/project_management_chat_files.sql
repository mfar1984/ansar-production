-- ══════════════════════════════════════════════════════════════════════════════
-- LAMPIRAN DALAM PERBUALAN PROJEK — site diary, bukan perpustakaan dokumen
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Spec: `.kiro/specs/project-management/` (Task 38)
--
-- SATU table, dan SATU lajur DIBUANG. Tiada kebenaran baharu.
--
-- Apa yang diminta: kakitangan boleh menghantar laporan dalam perbualan projek berupa
-- gambar atau dokumen. Ia BUKAN tab Documents. Tab Documents memegang lukisan as-built,
-- borang serah-terima yang ditandatangani dan kontrak — setiap satunya ada `doc_type`,
-- `revision`, satu tajuk, dan satu bendera keterlihatan client yang diputuskan satu demi
-- satu. Ini memegang gambar tapak yang penting tetapi tidak sepenting itu.
--
-- Perbezaan itu ialah sebab table ini tidak mempunyai satu pun daripada lajur tersebut.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGAPA SATU TABLE, BILA SATU LAJUR `attachments JSON` SUDAH ADA DAN MENUNGGU
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `project_messages.attachments JSON NULL` dicipta bersama table itu, kerana bentuknya
-- diambil daripada `helpdesk_replies` yang MEMANG menyimpan lampirannya sebagai satu array
-- JSON nama fail. Menggunakannya semula ialah pilihan yang paling murah dan ia SALAH,
-- kerana satu perkara yang tiada pada helpdesk: fail helpdesk adalah AWAM.
--
-- `helpdesk_replies.attachments` memegang nama kosong dan enam tapak render membina
-- `/uploads/helpdesk/{nama}` daripadanya. Next melayan laluan itu kepada sesiapa. Tiada
-- siapa perlu mencari satu baris untuk membaca fail itu.
--
-- Fail projek TIDAK boleh awam — `operations-upload.ts` merekodnya: folder `projects`
-- ialah `private` SAHAJA, "there is no public caller and there must not be one", kerana
-- fail itu ialah gambar bangunan seorang client. Satu fail peribadi dibaca melalui
-- `api/admin/operations/files/[...path].ts`, dan semakan KETIGA endpoint itu ialah:
--
--     satu baris dalam pangkalan data mesti merujuk laluan ITU dengan TEPAT
--
-- Tanpa semakan itu endpoint tersebut menjadi pembaca fail am untuk seluruh akar peribadi.
-- Keempat-empat resolver yang ada menjawabnya dengan `WHERE <lajur> = ? LIMIT 1` atas satu
-- lajur berindeks. Satu array JSON tidak boleh: ia memerlukan `JSON_CONTAINS` atau
-- `JSON_SEARCH`, yang tiada indeks boleh melayan, atas satu table yang membesar tanpa had.
--
-- Dan kosnya BUKAN milik chat ini sahaja. Endpoint fail itu dikongsi oleh aset, tapak,
-- dokumen servis dan dokumen projek. Meletakkan satu imbasan table penuh di dalamnya
-- memperlahankan SETIAP muat turun dalam sistem, bukan hanya lampiran chat.
--
-- Itu yang memutuskan. Satu table, dengan `uq_pmf_path`.
--
-- Sebab kedua, lebih kecil: satu array nama kosong tiada tempat untuk `mime_type` atau
-- nama asal. Helpdesk terlepas kerana ia memapar nama yang disimpan sebagai label. Satu
-- site diary gambar memerlukan jenis fail itu untuk memutuskan sama ada ia dipapar sebagai
-- gambar atau sebagai pautan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- JADI `attachments` DIBUANG, DAN BUKAN DIBIARKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- DIUKUR sebelum keputusan ini dibuat, bukan diandaikan:
--
--     SELECT COUNT(*) AS messages,
--            SUM(CASE WHEN attachments IS NOT NULL THEN 1 ELSE 0 END) AS with_attachments
--       FROM project_messages
--     -->  messages 0   with_attachments NULL
--
-- Lajur itu tidak pernah memegang satu nilai. Kedua-dua endpoint SELECT ia dan tiada satu
-- pun menulisnya; jenis `Message` dalam `ProjectChat.tsx` tidak pernah mengisytiharkannya,
-- jadi ia dipilih dan dijatuhkan ke lantai pada setiap bacaan thread.
--
-- Ini orphan KEEMPAT dalam modul ini, selepas `project_chat_publish`, `project_chat_delete`
-- dan `project_schedule_edit`. Tiga yang pertama ialah kebenaran; ini satu LAJUR, dan
-- sebabnya sama: dua tempat untuk satu fakta bermakna satu daripadanya akan menjadi salah.
-- Seorang pembaca yang menjumpai satu lajur bernama `attachments` di sebelah satu table
-- bernama `project_message_files` akan menulis kepada yang salah.
--
-- `project_management_chat.sql` juga disunting supaya `CREATE TABLE` tidak lagi
-- menciptanya. Itu tidak mengubah apa-apa untuk pemasangan yang SUDAH ADA — table itu
-- wujud, jadi `IF NOT EXISTS` ialah no-op — jadi DROP di bawah ialah separuh yang menjaga
-- mereka. Kedua-dua fail kemudian bersetuju pada `cols 8`.
--
-- MySQL tiada `DROP COLUMN IF EXISTS` (MariaDB ada), jadi ia melalui `information_schema`
-- dan `PREPARE`, sama seperti `project_management_cost.sql`.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA KEBENARAN BAHARU, DAN ITU SATU KEPUTUSAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Melampirkan satu fail ialah `project_chat_create` — kebenaran yang SAMA yang menghantar
-- satu mesej. Satu lampiran ialah bahagian satu mesej, bukan satu kuasa kedua.
--
-- Itu penaakulan yang sama yang membiarkan `canMarkInternal` menjadi `project_chat_create`
-- dan bukan satu kebenaran sendiri, dan yang sama yang membiarkan gambar produk atas
-- `market_place_products_edit`. Satu kotak semak `project_chat_attach` akan menjadi satu
-- kebenaran yang tiada siapa akan mencabutnya daripada seseorang yang sudah boleh
-- menghantar mesej.
--
-- `project_chat` kekal pada DUA tindakan: `view`, `create`.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- TIADA LALUAN PADAM, DAN ITU DIWARISI BUKAN DILUPAKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- `project_chat_delete` DIBUANG dalam Task 30 selepas diukur bahawa tiada apa menyemaknya.
-- `project_messages` tiada laluan sunting dan tiada pemadaman lembut, atas sebab yang
-- direkod di kepala fail chat: satu mesej dalam perbualan yang client sudah baca bukan
-- dokumen.
--
-- Satu lampiran mengikut mesejnya. Ia tidak boleh dibuang secara berasingan, kerana
-- membuang satu gambar daripada satu mesej yang berkata "lihat gambar di bawah" ialah
-- menulis semula rekod itu tanpa menyuntingnya.
--
-- Yang MEMBUANGnya ialah memadam projek: `projects` → `project_messages` → baris ini,
-- DUA hop cascade. Itu dibuktikan atas baris sebenar dalam
-- `tests/sql/project-chat-files.test.js` dan bukan diandaikan, kerana cascade dua hop ialah
-- perkara yang paling mudah untuk dipercayai tanpa disemak.
--
-- Fail atas cakera TIDAK dibuang oleh cascade itu. `project_documents` mempunyai sifat yang
-- sama dan sudah lebih lama; ia bukan sesuatu yang perubahan ini memperkenalkan dan bukan
-- sesuatu yang ia sepatutnya membetulkan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. Dijalankan dua kali atas pangkalan data yang sama memberi output yang sama.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── 1. Table ──
--
-- ── `uq_pmf_path`: SATU fail, SATU baris ──
--
-- Sebab yang sama `project_documents` mempunyai `uq_pd_path`, dan ia ditulis di sana:
-- resolver mencari `WHERE file_path = ? LIMIT 1`, jadi kalau dua baris berkongsi satu
-- laluan, memadam satu daripadanya memadam fail yang satu lagi tunjuk — dan muat turun yang
-- kedua kemudian 404 pada semakan FAIL, bukan pada semakan kebenaran, jadi tiada apa akan
-- mengatakan sebabnya.
--
-- Nama yang dijana menjadikan perlanggaran hampir mustahil; indeks ini menjadikannya
-- mustahil. Ia juga sebab fail chat pergi ke folder `project-chat` dan BUKAN ke `projects`
-- bersama dokumen: dua table, dua indeks unik berasingan, dan tiada satu pun daripadanya
-- boleh melihat baris yang satu lagi. Direktori berasingan menjadikan pertembungan
-- antara-table itu mustahil secara struktur dan bukan secara statistik.
--
-- ── TIADA `project_id` DI SINI ──
--
-- Ia boleh didenormalkan untuk mengelak satu join, dan ia tidak. `project_messages.id`
-- ialah kunci utama, jadi join itu ialah satu bacaan indeks. Satu salinan kedua bagi
-- projek mana fail ini milik ialah satu salinan yang boleh menjadi SALAH — dan kalau ia
-- salah, resolver akan menyemak keahlian client projek yang salah. Itu satu pepijat
-- kebenaran, bukan satu pepijat prestasi.
--
-- ── TIADA `uploaded_by` ──
--
-- `project_messages.sender_name` sudah memegangnya, dicache atas baris mesej supaya thread
-- kekal boleh dibaca selepas akaun dipadam. Satu salinan kedua di sini akan menjadi salinan
-- yang basi.
--
-- ── TIADA `is_internal` DI SINI, DAN ITU YANG MENJADIKANNYA SELAMAT ──
--
-- Keterlihatan ialah sifat MESEJ. Satu lampiran atas satu nota dalaman tidak boleh dilihat
-- oleh client, dan cara ia ditegakkan ialah resolver membaca `project_messages.is_internal`
-- MELALUI join — sama seperti `project_documents.is_client_visible` ialah bahagian peraturan
-- akses dan bukan satu penapis papar.
--
-- Satu salinan `is_internal` di sini boleh tidak sepadan dengan mesejnya, dan satu
-- percanggahan dalam arah itu bermakna satu gambar dihantar kepada seorang client yang
-- sepatutnya tidak pernah melihatnya. Itu kegagalan terburuk yang tersedia di sini, jadi
-- lajur itu sengaja tidak wujud.
--
-- ── TIADA CHECK ──
--
-- Satu muat naik sifar-bait sudah ditolak oleh `parseUploads` ("An empty file input, not a
-- file"), dan `project_documents` — table adik-beradik yang paling hampir — tiada CHECK atas
-- `file_size` juga. Menambah satu di sini SAHAJA akan menjadikan dua table dokumen tidak
-- konsisten untuk satu jaminan yang endpoint sudah berikan.
CREATE TABLE IF NOT EXISTS `project_message_files` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `message_id` INT NOT NULL,
  `file_path`  VARCHAR(400) NOT NULL
               COMMENT 'relatif kepada .uploads-private, tanpa garis miring di depan',
  `file_name`  VARCHAR(255) NOT NULL
               COMMENT 'nama yang pengguna kenal. Dipapar, dan menjadi nama muat turun',
  `mime_type`  VARCHAR(120) NULL DEFAULT NULL
               COMMENT 'direkod pada muat naik. Memutuskan gambar dipapar atau dipautkan',
  `file_size`  INT UNSIGNED NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pmf_path` (`file_path`),
  /* Satu mesej dalam urutan papar: menjawab satu thread dalam satu bacaan indeks. */
  KEY `idx_pmf_message` (`message_id`, `id`),
  CONSTRAINT `fk_pmf_message` FOREIGN KEY (`message_id`)
    REFERENCES `project_messages` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── 2. Buang `project_messages.attachments` ──
--
-- MySQL tiada `DROP COLUMN IF EXISTS`, jadi ia melalui `information_schema` dan `PREPARE`.
-- Larian kedua menjumpai 0 lajur dan melaksanakan `DO 0`.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'project_messages'
      AND COLUMN_NAME = 'attachments') = 1,
  'ALTER TABLE `project_messages` DROP COLUMN `attachments`',
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
-- Jangkaan:  pmf_cols 7   pmf_fks 1   pmf_uniques 1   pm_cols 8   attachments 0   chat_actions 2
--
-- `attachments 0` ialah baris yang penting. Kalau ia 1, DROP tidak berjalan dan pembaca
-- seterusnya mempunyai dua tempat bernama untuk lampiran satu mesej.
--
-- `chat_actions 2` membuktikan tiada kebenaran baharu diselit: melampirkan satu fail ialah
-- `project_chat_create`, kebenaran yang sama yang menghantar mesej itu.
SELECT (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_message_files') AS pmf_cols,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_message_files'
           AND CONSTRAINT_TYPE = 'FOREIGN KEY') AS pmf_fks,
       (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_message_files'
           AND CONSTRAINT_TYPE = 'UNIQUE') AS pmf_uniques,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_messages') AS pm_cols,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_messages'
           AND COLUMN_NAME = 'attachments') AS attachments,
       (SELECT COUNT(*) FROM `permissions`
         WHERE module = 'project_chat') AS chat_actions
