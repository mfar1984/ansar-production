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
-- pasangan lalu — lebih buruk daripada ciri ini tidak wujud. Jadi kedua-dua belah
-- dilakukan dalam SATU pernyataan ALTER:
--
--   ALTER TABLE ... DROP CHECK `chk_ppr_forward`, ADD CONSTRAINT `chk_ppr_forward` CHECK (...)
--
-- DIUJI pada MySQL 8.0.45 atas satu jadual ujian sebelum ditulis di sini: satu ALTER
-- menerima gugur-dan-tambah nama yang SAMA, dan DDL InnoDB 8.0 bersifat atomik — jadi
-- tiada tetingkap di mana jadual itu tidak berkekangan. Dua pernyataan berasingan ADA
-- tetingkap itu, dan separuh kedua yang gagal meninggalkan jadual terbuka.
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
-- 2. `chk_ppr_forward` DIGANTIKAN DALAM SATU ALTER
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Dua pengawal dibaca, bukan satu:
--
--   @ppr_chk_wide     klausa sudah menyebut ''revert''  -> tiada apa dibuat
--   @ppr_chk_present  nama itu ada                      -> GUGUR dahulu, dalam ALTER yang sama
--
-- Pengawal kedua itu penting. Tanpa ia, satu pangkalan data yang entah bagaimana
-- kehilangan kekangan itu akan dapat `ER_CANT_DROP_FIELD_OR_KEY` dan ALTER penuh
-- gagal — jadi lajur `action` dilebarkan dan TIADA kekangan dicipta. Itu keadaan
-- paling buruk yang fail ini wujud untuk mengelak.
SET @ppr_chk_present := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'project_phase_requests'
     AND CONSTRAINT_NAME = 'chk_ppr_forward'
)

-- >>>
SET @ppr_chk_wide := (
  SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
   WHERE CONSTRAINT_SCHEMA = DATABASE() AND CONSTRAINT_NAME = 'chk_ppr_forward'
     AND CHECK_CLAUSE LIKE '%revert%'
)

-- >>>
-- Kesepuluh pasangan DISENARAIKAN dan bukan dikira dengan `FIELD()`, atas sebab
-- `project_phase_approval.sql` sendiri rekodkan: aritmetik atas kedudukan ENUM
-- memaksa pembaca mempercayai urutan pengisytiharan, dan menyusun semula ENUM itu
-- suatu hari akan menukar makna kekangan ini tanpa menyentuh fail ini.
--
-- `closing -> initiation` tiada dalam senarai ini, dan ketiadaannya ialah
-- peraturannya. `tests/sql/project-phase-approval.test.js` MENCUBA pasangan itu dan
-- mengesahkan ia masih ditolak — satu klausa yang dibaca bukan satu klausa yang
-- diuji.
SET @sql := IF(@ppr_chk_wide = 1, 'DO 0',
  CONCAT(
    IF(@ppr_chk_present = 1,
      'ALTER TABLE `project_phase_requests` DROP CHECK `chk_ppr_forward`, ADD CONSTRAINT ',
      'ALTER TABLE `project_phase_requests` ADD CONSTRAINT '),
    '`chk_ppr_forward` CHECK (
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
     )'))

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
--   action_enum 1   fwd_chk 1   revert_clause 1   log_action 1
--   log_complete 22   log_revert 0   reopen_perm 1   reopen_granted 1
--   pending_now 1
--
-- `fwd_chk 1` ialah baris yang MESTI dibaca setiap kali. Satu SIFAR di situ bermakna
-- gugur-dan-tambah tidak berjaya dan jadual itu kini TANPA kekangan — setiap
-- pasangan, termasuk `closing -> initiation`, akan lalu. Itu lebih buruk daripada
-- ciri ini tidak wujud.
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
