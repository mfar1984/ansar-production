-- ══════════════════════════════════════════════════════════════════════════════
-- PEMBALIKAN GATE FASA — SATU FASA YANG SUDAH DITUTUP BOLEH DIBUKA SEMULA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Diminta pengguna: "ko buat ni dulu supaya aku boleh back balik yang aku dah
-- close", di dalam Project Workspace > Phase & Gates.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `phase.ts` SUDAH MEREKA BENTUK INI, DAN FAIL INI MENGIKUT HUJAHNYA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Di bawah tajuk `ONE STEP FORWARD, AND NOT BACKWARD`, endpoint itu menulis:
--
--   "Going BACKWARD is not offered. It is a real thing — a project that has to
--    re-plan — but it is a reversal rather than a gate closing, and it needs its
--    own record and its own authority to mean anything. Built as the same button,
--    one permission could undo a signed-off gate."
--
-- Jadi tiga perkara TIDAK boleh dirunding, dan ketiga-tiganya datang daripada
-- ayat itu sendiri:
--
--   1. Pembalikan ialah TINDAKAN SENDIRI — nilai ENUM ketiga, `revert`. Bukan
--      `advance` yang dilebarkan untuk menerima pasangan ke belakang.
--   2. Ia ada KEBENARAN SENDIRI — `projects_delivery_reopen`. Bukan
--      `projects_delivery_edit`, yang menjaga gate ke hadapan.
--   3. Ia ada REKOD SENDIRI — satu baris `project_phase_log` yang boleh dibaca
--      sebagai pembalikan dan bukan sebagai gate yang ditutup. Lihat bahagian 3.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- APA YANG MENGHALANGNYA SEBELUM INI, DIUKUR PADA SKEMA HIDUP
-- ══════════════════════════════════════════════════════════════════════════════
--
--   project_phase_requests.action   enum('advance','complete')   — tiada nilai ketiga
--   chk_ppr_forward                 menyenaraikan 5 pasangan ke hadapan sahaja
--   projects.phase                  enum lima Process Group
--   projects.status                 enum('planning','ongoing','completed','on-hold')
--   project_phase_log               from/to enum yang sama, SIFAR kekangan CHECK
--
-- `project_phase_log` tiada CHECK, jadi satu baris ke belakang memang boleh
-- disimpan di situ hari ini. DISAHKAN pada pangkalan data dan bukan diandaikan:
-- `information_schema.CHECK_CONSTRAINTS` memulangkan 0 baris untuk jadual itu, dan
-- `tests/sql/project-management.test.js` sudah MENUNTUT ia kekal 0 — MySQL menolak
-- satu CHECK atas jadual yang memegang lajur FK CASCADE. Jadi lajur `action` di
-- bahagian 3 ialah lajur biasa tanpa CHECK, dengan sengaja.
--
-- Data hidup ketika fail ini ditulis: 148 baris log (42/37/24/23/22 merentas lima
-- pasangan), SIFAR ke belakang. 46 projek — 22 di closing+completed, 13
-- executing+ongoing, 5 planning, 4 initiation, 1 closing+on-hold, 1 monitoring.
-- `project_phase_requests` memegang 1 pending dan 12 approved.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- SATU LANGKAU KE BELAKANG SAHAJA, DAN LIMA PASANGAN YANG DIBENARKAN
-- ══════════════════════════════════════════════════════════════════════════════
--
--   planning   -> initiation
--   executing  -> planning
--   monitoring -> executing
--   closing    -> monitoring
--   closing    -> closing      (membuka semula PENUTUPAN — hanya `status` bergerak)
--
-- `closing -> initiation` MESTI mustahil. `advance` menyasarkan `nextPhase()` dan
-- tiada yang lain supaya tiada siapa mendarat tiga gate jauh di belakang satu baris
-- log; hujah yang sama dipakai dalam arah bertentangan. Badan permintaan TIDAK
-- menerima fasa sasaran sama sekali — `phaseReversal()` dalam `src/lib/projects.ts`
-- menerbitkannya daripada tempat projek itu berada.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- `closing -> closing` ADA DUA MAKNA SEKARANG, DAN ITU SEBAB LAJUR BAHARU
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Pasangan padan pada `action = 'complete'` bermaksud "gate Closing ditandatangani,
-- projek selesai". Pasangan padan yang SAMA pada `action = 'revert'` bermaksud
-- sebaliknya sepenuhnya: "penutupan dibuka semula".
--
-- `project_phase_log` tiada lajur `action` sebelum ini kerana ia tidak perlu satu:
-- satu pasangan padan hanya boleh bermakna satu perkara. Sekarang ia boleh bermakna
-- dua yang bertentangan, dan skrin Phase & Gates menerbitkan ayatnya daripada
-- pasangan itu — jadi tanpa lajur ini satu pembalikan akan dipaparkan sebagai
-- "Closing signed off — project completed", iaitu bertentangan dengan apa yang
-- berlaku. Satu rekod yang membaca sebagai lawannya sendiri bukan satu rekod.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGGUGURKAN DAN MENAMBAH SEMULA SATU CHECK IALAH LANGKAH BERISIKO
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Satu jadual yang tertinggal tanpa `chk_ppr_forward` akan membenarkan SEBARANG
-- pasangan lalu — lebih buruk daripada ciri ini tidak wujud.
--
-- ── VERSI PERTAMA FAIL INI GAGAL DI PRODUKSI, DAN INILAH SEBABNYA ──
--
-- Ia melakukan kedua-dua belah dalam SATU pernyataan ALTER, dengan sintaks
-- `DROP CHECK`. Produksi menjawab:
--
--   ER_PARSE_ERROR: ... check the manual that corresponds to your MariaDB server
--   version for the right syntax to use near 'CHECK `chk_ppr_forward`, ADD ...'
--
-- `ALTER TABLE ... DROP CHECK <nama>` ialah sintaks MySQL SAHAJA. Produksi ialah
-- MariaDB 11.4.13 — direkodkan dalam `tests/sql/sql-portability.test.js` — dan
-- MariaDB tidak mengenal `DROP CHECK` sama sekali. Yang diterima oleh KEDUA-DUA
-- enjin ialah `DROP CONSTRAINT`:
--
--   MySQL     8.0.19+   ALTER TABLE menerima `DROP CONSTRAINT <simbol>` untuk
--                       sebarang jenis kekangan, termasuk CHECK (WL#12798).
--   MariaDB   10.2+     `DROP CONSTRAINT <nama>` ialah satu-satunya bentuk.
--
-- `IF EXISTS` TIDAK dipakai selepas `DROP CONSTRAINT`: MariaDB menerimanya, MySQL
-- tidak. Pengawal `information_schema` di bawah melakukan kerja yang sama dan
-- berjalan pada kedua-dua enjin.
--
-- Kegagalan itu meninggalkan keadaan yang LEBIH BURUK daripada migrasi yang tidak
-- pernah dijalankan: ENUM `action` SUDAH mendapat ''revert'' (pernyataan #5 berjaya)
-- tetapi klausa CHECK TIDAK (pernyataan #9 gagal). Jadi aplikasi menghantar
-- `action = 'revert'` dan pangkalan data menolaknya. Dua belah tidak bersetuju.
--
-- ── EMPAT ALTER BERPENGAWAL, DAN JADUAL TIDAK PERNAH TANPA KEKANGAN ──
--
-- Satu ALTER yang membawa `DROP CONSTRAINT x, ADD CONSTRAINT x` TIDAK dipakai,
-- kerana kelakuan itu tidak dapat disahkan pada MariaDB daripada dokumentasi dan
-- mesin ini menjalankan MySQL 8.0.45 — jadi ia tidak boleh diuji sampai gagal di
-- sini. Mengandaikan ia berfungsi ialah kesilapan yang sama yang menyebabkan
-- kecacatan ini.
--
-- Jadi nama ditukar melalui satu kekangan JAMBATAN yang memegang peraturan LEBAR
-- semasa nama itu bertukar tangan. Pada setiap saat sekurang-kurangnya SATU
-- kekangan sedang menguatkuasakan, dan tiada satu pun daripada empat langkah
-- bergantung pada langkah sebelumnya BERJAYA — setiap satu membaca
-- `information_schema` semula:
--
--   mula    chk_ppr_forward (sempit)
--   2a      + chk_ppr_forward_bridge (lebar)     sempit AND lebar = sempit
--   2b      - chk_ppr_forward                    lebar, melalui jambatan
--   2c      + chk_ppr_forward (lebar)            lebar AND lebar = lebar
--   2d      - chk_ppr_forward_bridge             lebar, melalui namanya sendiri
--
-- Kegagalan di mana-mana titik meninggalkan jadual BERKEKANGAN, dan larian semula
-- menyelesaikan apa yang tinggal. Itu termasuk keadaan separuh-terpakai di
-- produksi: 2a menambah jambatan, 2b menggugurkan klausa sempit, 2c menambah
-- klausa lebar di bawah nama asal, 2d mengemas. Tiada satu pun pengawal bertanya
-- "adakah ENUM sudah lebar" atau "adakah kekangan itu ADA" — soalan yang betul
-- ialah "adakah KLAUSA itu menyebut revert", dan itulah yang ditanya.
--
-- Klausa itu hidup dalam SATU pemboleh ubah, `@ppr_rule`, kerana 2a dan 2c
-- memerlukan teks yang sama. Dua salinan bermakna dua tempat untuk satu pasangan
-- tercicir.
--
-- ── MENAMBAH CHECK PADA JADUAL YANG SUDAH ADA BARIS ──
--
-- Klausa lebar ialah SUPERSET klausa sempit: ia menambah cabang ''revert'' dan
-- tidak mengubah apa-apa dalam cabang ''advance'' atau ''complete''. Jadi setiap
-- baris yang memenuhi klausa sempit memenuhi klausa lebar, dan 2a tidak boleh
-- gagal atas baris yang sudah ada. Produksi memegang 2 baris pending; pembangunan
-- 13 baris merentas 5 pasangan ke hadapan. Kalau satu baris PERNAH gagal di sini,
-- ALTER itu ditolak dengan ER_CHECK_CONSTRAINT_VIOLATED dan jadual kekal dengan
-- klausa sempitnya — migrasi berhenti, tiada apa yang rosak, dan baris yang
-- menyalahi itu mesti diperiksa dengan tangan sebelum mencuba lagi.
--
-- ── NAMANYA KEKAL `chk_ppr_forward`, DAN ITU BUKAN KEMALASAN ──
--
-- `project_phase_approval.sql` mengawal ALTER-nya dengan
-- `CONSTRAINT_NAME = 'chk_ppr_forward'`. Memberi kekangan baharu ini satu nama lain
-- bermakna larian semula migrasi LAMA itu akan mendapati nama lama hilang dan
-- MENCIPTANYA SEMULA dengan klausa sempit — dan dua kekangan mesti KEDUA-DUANYA
-- lulus, jadi setiap baris `revert` akan ditolak oleh kekangan yang baru dihidupkan
-- semula itu. Produksi menjalankan migrasi dengan tangan dan tangan menjalankan
-- benda dua kali, jadi nama itu dikekalkan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- MENGANGKAT DAN MEMUTUSKAN IALAH DUA KEBENARAN BERBEZA
-- ══════════════════════════════════════════════════════════════════════════════
--
--   angkat   (PUT)   `projects_delivery_reopen`   — "fasa ini perlu dibuka semula"
--   putus    (POST)  `projects_delivery_approve`  — "setuju, dan ia ditandatangani"
--
-- `approve` TIDAK berubah. Satu pembalikan membatalkan gate yang SUDAH
-- ditandatangani, jadi ia mesti sekurang-kurangnya sesukar tandatangan itu — dan
-- tandatangan itu ialah `approve`. Yang baharu ialah hak untuk BERTANYA, dan itu
-- sengaja bukan `projects_delivery_edit`: menjaga daftar tepat bukan kuasa untuk
-- membatalkan satu gate yang diluluskan.
--
-- ══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT. Dijalankan dua kali memberi output yang sama.
-- Setiap ALTER dikawal melalui `information_schema` dan `PREPARE`, kerana MySQL
-- MELERAIKAN KEDUA-DUA CABANG satu `IF()` pada masa prepare — jadi satu `IF()`
-- yang menamakan lajur yang belum ada gagal sebelum pengawalnya dibaca.
-- ══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── 1. `action` mendapat nilai ketiga ──
--
-- Dikawal pada COLUMN_TYPE dan bukan pada kewujudan lajur: satu pengawal atas
-- kewujudan dipenuhi pada larian 1 dan tidak akan melebarkan apa-apa selepas itu.
-- Corak yang sama `market_place_collection.sql` guna untuk menambah `pending`.
--
-- Pelebaran ini DAHULU, sebelum kekangan di bahagian 2, kerana klausa baharu itu
-- membandingkan `action` dengan ''revert'' dan nilai itu perlu ada dalam ENUM
-- sebelum perbandingan bermakna apa-apa.
SET @ppr_action_wide := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND COLUMN_NAME = 'action' AND COLUMN_TYPE LIKE '%revert%'
)

-- >>>
SET @sql := IF(@ppr_action_wide = 0,
  'ALTER TABLE `project_phase_requests`
     MODIFY COLUMN `action` ENUM(''advance'',''complete'',''revert'')
       NOT NULL DEFAULT ''advance''',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 2. `chk_ppr_forward` DILEBARKAN MELALUI SATU KEKANGAN JAMBATAN
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Kesepuluh pasangan DISENARAIKAN dan bukan dikira dengan `FIELD()`, atas sebab
-- `project_phase_approval.sql` sendiri rekodkan: aritmetik atas kedudukan ENUM
-- memaksa pembaca mempercayai urutan pengisytiharan, dan menyusun semula ENUM itu
-- suatu hari akan menukar makna kekangan ini tanpa menyentuh fail ini.
--
-- `closing -> initiation` tiada dalam senarai ini, dan ketiadaannya ialah
-- peraturannya. `tests/sql/project-phase-approval.test.js` MENCUBA pasangan itu dan
-- mengesahkan ia masih ditolak — satu klausa yang dibaca bukan satu klausa yang
-- diuji.
--
-- SATU salinan teks, dipakai oleh 2a dan 2c. Lihat tajuk: dua salinan ialah dua
-- tempat untuk satu pasangan tercicir.
SET @ppr_rule := '(
       (`action` = ''advance'' AND (
            (`from_phase` = ''initiation'' AND `to_phase` = ''planning'')
         OR (`from_phase` = ''planning''   AND `to_phase` = ''executing'')
         OR (`from_phase` = ''executing''  AND `to_phase` = ''monitoring'')
         OR (`from_phase` = ''monitoring'' AND `to_phase` = ''closing'')
       ))
       OR (`action` = ''complete'' AND `from_phase` = ''closing'' AND `to_phase` = ''closing'')
       OR (`action` = ''revert'' AND (
            (`from_phase` = ''planning''   AND `to_phase` = ''initiation'')
         OR (`from_phase` = ''executing''  AND `to_phase` = ''planning'')
         OR (`from_phase` = ''monitoring'' AND `to_phase` = ''executing'')
         OR (`from_phase` = ''closing''    AND `to_phase` = ''monitoring'')
         OR (`from_phase` = ''closing''    AND `to_phase` = ''closing'')
       ))
     )'

-- >>>
-- ── 2a. Jambatan dinaikkan, memegang peraturan LEBAR ──
--
-- Pengawalnya ialah KLAUSA dan bukan kewujudan: `@ppr_fwd_wide` bertanya sama ada
-- `chk_ppr_forward` sudah menyebut ''revert''. Satu pengawal atas kewujudan sahaja
-- akan dipenuhi oleh klausa SEMPIT yang masih terpasang di produksi, dan memutuskan
-- tiada apa perlu dibuat — meninggalkan pelayan rosak selama-lamanya. Itulah
-- soalan yang salah, dan ia soalan yang mudah ditanya tanpa sengaja.
SET @ppr_fwd_wide := (
  SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_ppr_forward'
     AND CHECK_CLAUSE LIKE '%revert%'
)

-- >>>
-- `TABLE_CONSTRAINTS` dan bukan `CHECK_CONSTRAINTS` untuk soalan kewujudan: versi
-- MySQL bagi `CHECK_CONSTRAINTS` tiada lajur `TABLE_NAME`, jadi menapis atas nama
-- jadual di situ ialah ralat pada satu enjin daripada dua. `CHECK_CONSTRAINTS`
-- dipakai HANYA untuk `CHECK_CLAUSE`, yang hanya ada di situ, dan ditapis atas
-- skema + nama kekangan sahaja.
SET @ppr_bridge := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward_bridge'
)

-- >>>
SET @sql := IF(@ppr_fwd_wide = 0 AND @ppr_bridge = 0,
  CONCAT('ALTER TABLE `project_phase_requests` ',
         'ADD CONSTRAINT `chk_ppr_forward_bridge` CHECK ', @ppr_rule),
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2b. Klausa sempit digugurkan, dengan jambatan memegang peraturan ──
--
-- Setiap pengawal DIBACA SEMULA di sini. Ia tidak boleh diwarisi daripada 2a:
-- kalau 2a tidak berjaya, jambatan tidak ada, dan menggugurkan `chk_ppr_forward`
-- ketika itu meninggalkan jadual TANPA kekangan — perkara tunggal yang keseluruhan
-- fail ini wujud untuk mengelak. Jadi `@ppr_bridge = 1` ialah syarat pertama.
SET @ppr_bridge := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward_bridge'
)

-- >>>
SET @ppr_fwd_any := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward'
)

-- >>>
SET @ppr_fwd_wide := (
  SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_ppr_forward'
     AND CHECK_CLAUSE LIKE '%revert%'
)

-- >>>
-- `DROP CONSTRAINT`, bukan `DROP CHECK`. Lihat tajuk — `DROP CHECK` ialah sebab
-- fail ini gagal di produksi, dan `tests/sql/sql-portability.test.js` kini
-- mengimbas setiap fail dalam `database/` untuknya.
SET @sql := IF(@ppr_bridge = 1 AND @ppr_fwd_any = 1 AND @ppr_fwd_wide = 0,
  'ALTER TABLE `project_phase_requests` DROP CONSTRAINT `chk_ppr_forward`',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2c. Nama asal dikembalikan, membawa klausa lebar ──
--
-- Namanya kekal `chk_ppr_forward` dan itu bukan kemalasan — lihat bahagian di bawah.
-- Pengawal: jambatan ada (peraturan sedang dikuatkuasakan) DAN nama asal tiada.
SET @ppr_bridge := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward_bridge'
)

-- >>>
SET @ppr_fwd_any := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward'
)

-- >>>
SET @sql := IF(@ppr_bridge = 1 AND @ppr_fwd_any = 0,
  CONCAT('ALTER TABLE `project_phase_requests` ',
         'ADD CONSTRAINT `chk_ppr_forward` CHECK ', @ppr_rule),
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 2d. Jambatan dibongkar ──
--
-- HANYA selepas `chk_ppr_forward` disahkan ADA dan LEBAR. Kalau 2c tidak berjaya,
-- jambatan kekal dan peraturan kekal dikuatkuasakan di bawah nama lain — keadaan
-- yang pelik untuk dibaca tetapi SELAMAT, dan larian semula membetulkannya.
-- `bridge_left` dalam SELECT verifikasi melaporkannya supaya ia tidak senyap.
SET @ppr_bridge := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward_bridge'
)

-- >>>
SET @ppr_fwd_wide := (
  SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_ppr_forward'
     AND CHECK_CLAUSE LIKE '%revert%'
)

-- >>>
SET @sql := IF(@ppr_bridge = 1 AND @ppr_fwd_wide = 1,
  'ALTER TABLE `project_phase_requests` DROP CONSTRAINT `chk_ppr_forward_bridge`',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ══════════════════════════════════════════════════════════════════════════════
-- 3. `project_phase_log.action` — SUPAYA SATU PEMBALIKAN BOLEH DIBACA
-- ══════════════════════════════════════════════════════════════════════════════
--
-- TIADA CHECK dan TIADA lajur terjana atas jadual ini, dengan sengaja dan bukan
-- kerana terlupa. `tests/sql/project-management.test.js` menuntut sifar bagi
-- kedua-duanya atas empat jadual chat, kerana MySQL menolak satu CHECK atas satu
-- jadual yang memegang lajur asas FK CASCADE dengan
-- `ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN`. Peraturan pasangan
-- fasa hidup pada `project_phase_requests`, iaitu satu-satunya tempat satu baris
-- log boleh datang.
--
-- DEFAULT ''advance'' supaya 148 baris yang ada mendapat satu nilai yang sah tanpa
-- penulisan semula, dan supaya satu INSERT lama yang tidak menamakan lajur ini
-- masih berfungsi.
SET @ppl_action := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_log'
     AND COLUMN_NAME = 'action'
)

-- >>>
SET @sql := IF(@ppl_action = 0,
  'ALTER TABLE `project_phase_log`
     ADD COLUMN `action` ENUM(''advance'',''complete'',''revert'')
       NOT NULL DEFAULT ''advance'' AFTER `to_phase`',
  'DO 0')

-- >>>
PREPARE s FROM @sql

-- >>>
EXECUTE s

-- >>>
DEALLOCATE PREPARE s

-- >>>
-- ── 3a. Menamakan semula 22 penutupan yang sudah ada ──
--
-- DEFAULT memberi kesemua 148 baris yang ada nilai ''advance'', dan 22 daripadanya
-- sebenarnya penutupan akhir. Nilai betul itu BOLEH diterbitkan, dan
-- penerbitan itu tepat kerana sebelum fail ini satu pasangan `closing -> closing`
-- hanya boleh bermakna satu perkara: `chk_ppr_forward` membenarkannya hanya pada
-- `action = 'complete'`, dan SIFAR baris ke belakang pernah disimpan.
--
-- IDEMPOTENT dua kali: selepas larian pertama baris itu memegang ''complete'', jadi
-- `action = 'advance'` tidak lagi padan. Satu baris ''revert'' masa depan tidak
-- boleh ditangkap di sini atas sebab yang sama — endpoint menamakan ''revert''
-- secara eksplisit.
UPDATE `project_phase_log`
   SET `action` = 'complete'
 WHERE `from_phase` = 'closing' AND `to_phase` = 'closing' AND `action` = 'advance'

-- >>>
-- ── 4. Kebenaran keenam ──
--
-- `projects_delivery` ada lima: view, create, edit, delete, approve. Ini keenam.
-- Bentuk INSERT yang sama seperti `project_management_permissions.sql`: lajur
-- `module, action, name, description, category`.
--
-- `reopen` BUKAN salah satu daripada lapan tindakan utama matriks (tambah, lihat,
-- kemaskini, padam, tolak, terima, gantung, aktifkan), jadi ia dipaparkan sebagai
-- cip dalam lajur "Other" pada skrin Roles. `ACTION_LABEL` dalam
-- `PermissionMatrix.tsx` mendapat kekunci `reopen` dalam perubahan yang sama —
-- tanpanya cip itu memaparkan kekunci mentah, iaitu kecacatan yang peta itu sendiri
-- sudah rekodkan untuk `dispose`.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('projects_delivery', 'reopen', 'projects_delivery_reopen',
   'Ask to reopen a closed project phase gate', 'operations')

-- >>>
-- ── 4a. Berikannya kepada Super Admin ──
--
-- PELAYAN ada pintasan Super Admin; KLIEN tiada. `usePermissions` menyertai melalui
-- `role_permissions`, jadi satu kebenaran yang tidak diberi menjadikan kawalan itu
-- TIDAK KELIHATAN dan bukan ditolak — yang dibaca sebagai skrin rosak.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.`id`, p.`id`
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(TRIM(r.`name`)) = 'super admin'
   AND p.`name` = 'projects_delivery_reopen'

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan pada pangkalan data pembangunan ketika fail ini ditulis:
--
--   action_enum 1   fwd_chk 1   revert_clause 1   bridge_left 0   log_action 1
--   log_complete 22   log_revert 0   reopen_perm 1   reopen_granted 1
--   pending_now 1
--
-- `fwd_chk 1` ialah baris yang MESTI dibaca setiap kali. Satu SIFAR di situ bermakna
-- nama asal tiada. Dengan reka bentuk jambatan, `bridge_left 1` pada masa yang sama
-- bermakna peraturan MASIH dikuatkuasakan di bawah nama lain dan larian semula akan
-- membetulkannya. `fwd_chk 0` DAN `bridge_left 0` bersama ialah satu-satunya
-- bacaan yang bermakna jadual itu TANPA kekangan — setiap pasangan, termasuk
-- `closing -> initiation`, akan lalu. Itu lebih buruk daripada ciri ini tidak wujud.
--
-- `revert_clause 1` ialah baris yang membuktikan pembaikan. Produksi melaporkan
-- `action_enum 1  fwd_chk 1  revert_clause 0` — ENUM lebar, klausa sempit, dua belah
-- tidak bersetuju. Selepas fail ini dijalankan semula ia mesti membaca 1.
--
-- `log_complete 22` ialah penamaan semula di bahagian 3a. Pada larian kedua ia kekal
-- 22, yang membuktikan UPDATE itu idempotent.
--
-- ── APA YANG SELECT INI TIDAK BOLEH BUKTIKAN, DAN SIAPA YANG MEMBUKTIKANNYA ──
--
-- `revert_clause 1` hanya mengatakan perkataan `revert` ada dalam klausa itu. Ia
-- TIDAK mengatakan pasangan mana yang dibenarkan, dan ia TIDAK boleh mengatakan
-- `closing -> initiation` ditolak — membaca satu klausa bukan menguji satu klausa,
-- dan itu kelas semakan yang sudah dua kali memberi lulus palsu dalam repositori ini.
--
-- Pembuktiannya ialah PERCUBAAN, dan ia hidup dalam
-- `tests/sql/project-phase-approval.test.js`: ia menyisipkan `closing -> initiation`
-- sebagai `revert`, `initiation -> planning` sebagai `revert`, dan satu pasangan ke
-- hadapan dengan tindakan yang salah, mengesahkan ketiga-tiganya ditolak, kemudian
-- membatalkan setiap probe. Jalankan `node tests/run-all.js` selepas fail ini.
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
      AND COLUMN_NAME = 'action' AND COLUMN_TYPE LIKE '%revert%')              AS action_enum,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
      AND CONSTRAINT_NAME = 'chk_ppr_forward')                                 AS fwd_chk,
  (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_ppr_forward'
      AND CHECK_CLAUSE LIKE '%revert%')                                        AS revert_clause,
  (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
      AND CONSTRAINT_NAME = 'chk_ppr_forward_bridge')                          AS bridge_left,
  (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_log'
      AND COLUMN_NAME = 'action' AND COLUMN_TYPE LIKE '%revert%')              AS log_action,
  (SELECT COUNT(*) FROM `project_phase_log` WHERE `action` = 'complete')       AS log_complete,
  (SELECT COUNT(*) FROM `project_phase_log` WHERE `action` = 'revert')         AS log_revert,
  (SELECT COUNT(*) FROM `permissions` WHERE `name` = 'projects_delivery_reopen')
                                                                               AS reopen_perm,
  (SELECT COUNT(*) FROM `role_permissions` rp
     JOIN `permissions` p ON p.`id` = rp.`permission_id`
     JOIN `roles` r       ON r.`id` = rp.`role_id`
    WHERE LOWER(TRIM(r.`name`)) = 'super admin'
      AND p.`name` = 'projects_delivery_reopen')                               AS reopen_granted,
  (SELECT COUNT(*) FROM `project_phase_requests` WHERE `status` = 'pending')   AS pending_now
