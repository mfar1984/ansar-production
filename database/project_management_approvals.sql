-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — kelulusan client
--
-- Spec: .kiro/specs/project-management/  (Task 32 — leaf Client Approvals)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_chat.sql       (project_participants)
--                  database/project_management_documents.sql  (project_documents)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- DUA TINDAKAN SAHAJA, DAN ITU MENENTUKAN SEGALANYA
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `project_management_permissions.sql` menyemai DUA tindakan untuk
-- `project_client_approvals`: `view` dan `request`. Diprob pada pangkalan data ini dan
-- disahkan.
--
-- Tiada `approve`. Tiada `reject`. Tiada `edit`. Tiada `delete`.
--
-- Itu bukan kelalaian penyemaian — itu SELURUH bentuk ciri ini. Bandingkan:
--
--   project_changes    5 tindakan termasuk `approve`  KITA yang luluskan satu VO
--   project_reports    4 termasuk `publish`           KITA yang terbitkan
--   project_quality    4 CRUD                         KITA yang tutup satu NCR
--   INI                2: view, request                KITA MINTA. CLIENT PUTUSKAN
--
-- Jadi endpoint admin tiada kaedah untuk meluluskan atau menolak apa-apa. Keputusan itu
-- ditulis oleh satu sesi CLIENT, melalui `api/client/projects/[id]/approvals.ts`, dan itulah
-- laluan TULIS pertama yang portal client ada selepas menghantar satu mesej.
--
-- Dan tiada `edit`: satu permintaan yang sudah dihantar kepada client tidak boleh disunting
-- tanpa mengubah apa yang mereka sedang lihat. Tarik balik dan hantar yang baharu — dan
-- `request` ialah kuasa yang sama untuk kedua-duanya, kerana menarik balik permintaan
-- sendiri ialah sebahagian daripada membuat permintaan.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- SATU JENIS SUBJEK SAHAJA: SATU DOKUMEN. DAN IA PILIHAN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Satu model POLIMORFIK — `subject_type ENUM('document','milestone','change','report')`
-- campur `subject_id` — dipertimbangkan dan ditolak. Ia satu FK tanpa integriti rujukan:
-- padam dokumen itu dan baris ini menunjuk kepada tiada apa, tanpa apa-apa dalam skema
-- menangkapnya. Modul ini sudah menolak dua model graf atas sebab yang sama.
--
-- Jadi SATU rujukan nyata: `document_id` kepada `project_documents`.
--
--   satu LUKISAN atau submittal ialah kes kelulusan client yang paling lazim dalam kerja
--     M&E, dan `project_documents` sudah ada failnya, keterlihatan clientnya, gate muat
--     turunnya dan label revisinya
--   satu MILESTONE tidak diletak di sini: client yang mengesahkan satu milestone akan
--     menggerakkan `projects.percent_complete`, dan itu angka terbitan yang Task 24
--     betulkan. Menyerahkannya kepada satu pihak luar ialah menyerahkan lajur itu
--   satu VO tidak diletak di sini: `project_changes` sudah ada kuasa `approve` DALAMAN,
--     dan dua konsep kelulusan untuk satu baris ialah dua tempat ia boleh bercanggah
--
-- `document_id` NULL DIBENARKAN, dan itu bukan kompromi. "Sahkan akses tapak pada dua hari
-- Sabtu di bawah" ialah satu permintaan kelulusan yang sah tanpa satu fail — apa yang
-- diminta ada dalam `description`.
--
-- ── FK ITU `RESTRICT`, DAN ITU MENGUBAH KELAKUAN YANG SUDAH ADA ──
--
-- Sebelum fail ini, TIADA APA merujuk `project_documents`. Menambah satu FK `RESTRICT`
-- bermakna `DELETE FROM project_documents` kini boleh GAGAL.
--
-- Itu disengajakan dan ia betul: satu lukisan yang client sudah luluskan TIDAK BOLEH
-- hilang. Yang salah ialah `SET NULL`, yang akan meninggalkan satu rekod kelulusan yang
-- merujuk kepada satu dokumen yang tiada siapa boleh cari — tepat kegagalan "satu rekod
-- yang tidak menerangkan apa-apa" yang modul ini elak sepanjang masa.
--
-- Tetapi satu ralat FK mentah pada satu skrin ialah pengalaman yang buruk, jadi
-- `api/admin/operations/projects/[id]/documents.ts` MENYEMAK dahulu dan menolak dengan satu
-- ayat. Constraint ini ialah jaring keselamatan, bukan mesej ralat.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- TANDATANGAN ITU SATU SNAPSHOT, BUKAN SATU FOREIGN KEY
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `client_users` mencascade: memadam satu akaun client memadam barisnya dalam
-- `project_participants`. Kalau `decided_by_client_id` membawa satu FK, memadam akaun itu
-- akan MEMADAM ATAU MENGOSONGKAN tandatangan pada satu kelulusan kontraktual.
--
-- Jadi ia satu INT tanpa FK, di sebelah `decided_by_name` — satu snapshot nama orang yang
-- menekan butang itu. Nama itulah tandatangannya dan ia mesti kekal selepas akaun itu
-- tiada. Hujah yang sama seperti `project_ncrs.verified_by` dan
-- `project_risks.owner_employee_id`.
--
-- ── TIADA KEADAAN DRAF ──
--
-- `project_reports` ada `draft` dan `published` kerana satu laporan ditulis berperingkat.
-- Satu permintaan kelulusan tidak: mencipta ia IALAH menghantarnya, dan itu sebabnya
-- tindakan itu dinamakan `request`. Satu keadaan draf di sini akan jadi satu keadaan tanpa
-- keputusan di belakangnya.
--
-- ── SATU HAD YANG DIAKUI, BUKAN DISEMBUNYIKAN ──
--
-- Pintu untuk client MEMUTUSKAN ialah `project_participants.can_message`, iaitu lajur yang
-- sama yang mengawal perbualan. Namanya lebih sempit daripada maknanya, dan itu diakui di
-- sini dengan sengaja.
--
-- Sebabnya: menandatangani sekurang-kurangnya sepenting bercakap. Satu client yang ditahan
-- daripada perbualan semasa satu pertikaian pastinya tidak patut menandatangani satu VO.
-- Satu lajur `can_approve` kedua ialah pintu kedua yang tiada siapa minta, dan mod
-- kegagalannya — boleh tandatangan tetapi tidak boleh berbincang — lebih buruk daripada
-- satu nama lajur yang sempit.
--
-- HAD SEBENARNYA: `uq_pp_client` ialah `(project_id, client_user_id)`, jadi satu projek
-- boleh ada BEBERAPA kontak client. Dalam amalan orang yang berbincang setiap hari BUKAN
-- orang yang diberi kuasa menandatangani — jurutera tapak berbual, pengarah menandatangani.
-- Skema ini TIDAK BOLEH menyatakan perbezaan itu, dan ia memerlukan satu lajur
-- `can_approve` apabila ada sesiapa memintanya. Ia ditulis di sini supaya keputusan itu
-- tidak hidup lebih lama daripada sebabnya secara senyap.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_approvals.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Kelulusan client ──
--
-- Awalan `pca_` untuk setiap constraint. Disemak: skema ini sudah memiliki `chk_pc_*`
-- (changes), `chk_pd_*` (documents), `chk_pq_*` (ncrs), `chk_pr_*` (risks) dan `chk_prp_*`
-- (reports). Nama constraint ialah ruang nama SATU SKEMA dalam MySQL, bukan satu table.
--
-- `approval_no` ialah GLOBAL (`APR-2026-0001`), hujah yang sama seperti empat table
-- sebelumnya: satu urutan per projek memerlukan satu pembilang yang mesti dikunci.
CREATE TABLE IF NOT EXISTS `project_client_approvals` (
  `id`                    INT NOT NULL AUTO_INCREMENT,
  `project_id`            INT NOT NULL,
  `approval_no`           VARCHAR(50) NOT NULL COMMENT 'APR-YYYY-NNNN, global. Lihat nota',
  /*
   * Subjeknya, dan ia PILIHAN. Satu permintaan tanpa fail ialah satu soalan yang jawapannya
   * ada dalam `description` — "sahkan akses tapak pada dua Sabtu di bawah".
   *
   * RESTRICT: satu lukisan yang client sudah luluskan tidak boleh hilang. Lihat nota kepala
   * tentang mengapa ini bukan SET NULL, dan mengapa endpoint dokumen menyemak dahulu.
   */
  `document_id`           INT NULL DEFAULT NULL,
  `title`                 VARCHAR(255) NOT NULL,
  `description`           TEXT NULL DEFAULT NULL COMMENT 'Apa TEPATNYA yang diminta',
  /*
   * Empat keadaan, dan TIGA daripadanya ditulis oleh pihak yang berbeza:
   *
   *   pending    kita hantar. Menunggu client
   *   approved   CLIENT kata ya
   *   rejected   CLIENT kata tidak, dan mesti beri sebab
   *   withdrawn  KITA tarik balik, dan mesti beri sebab
   *
   * Tiada keadaan draf: mencipta satu permintaan IALAH menghantarnya.
   */
  `status`                ENUM('pending','approved','rejected','withdrawn')
                          NOT NULL DEFAULT 'pending',
  `requested_on`          DATE NOT NULL,
  `due_on`                DATE NULL DEFAULT NULL COMMENT 'Bila kita perlukan jawapan',
  `decided_on`            DATE NULL DEFAULT NULL
                          COMMENT 'dipautkan kepada status oleh chk_pca_decided',
  `decision_note`         VARCHAR(400) NULL DEFAULT NULL
                          COMMENT 'WAJIB apabila rejected atau withdrawn',
  /*
   * ── TANDATANGAN. TIADA foreign key, dengan sengaja ──
   *
   * `client_users` mencascade. Satu FK di sini bermakna memadam satu akaun client memadam
   * tandatangan pada satu kelulusan kontraktual. `decided_by_name` ialah snapshot yang
   * kekal selepas akaun itu tiada — hujah yang sama seperti `project_ncrs.verified_by`.
   */
  `decided_by_client_id`  INT NULL DEFAULT NULL COMMENT 'TIADA FK. Lihat nota',
  `decided_by_name`       VARCHAR(191) NULL DEFAULT NULL COMMENT 'Snapshot tandatangan',
  `requested_by`          VARCHAR(191) NULL DEFAULT NULL,
  `created_at`            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                          ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pca_no` (`approval_no`),
  /* Satu projek, yang masih menunggu dahulu. */
  KEY `idx_pca_project` (`project_id`, `status`, `id`),
  /* "Apa yang menunggu satu client, di mana-mana" — soalan utama leaf silang-projek. */
  KEY `idx_pca_status` (`status`, `due_on`),
  /* Untuk semakan "dokumen ini ada kelulusan terhadapnya" sebelum satu DELETE. */
  KEY `idx_pca_document` (`document_id`),
  CONSTRAINT `fk_pca_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pca_document` FOREIGN KEY (`document_id`)
    REFERENCES `project_documents` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  /*
   * Satu permintaan yang TAMAT ada tarikh keputusan; satu yang masih menunggu tiada.
   *
   * Dan penolakan MESTI beri sebab: ia satu-satunya cara kita belajar apa yang perlu diubah,
   * dan satu penolakan tanpa sebab tidak boleh dijawab. Penarikan balik juga — "ditarik,
   * dan tiada siapa boleh mengatakan mengapa" ialah tepat soalan yang satu audit tanya.
   *
   * Satu KELULUSAN tidak memerlukan nota: ya ialah jawapan penuh, dan nota itu tempat satu
   * rujukan arahan client pergi kalau ada.
   */
  CONSTRAINT `chk_pca_decided` CHECK (
    (`status` = 'pending' AND `decided_on` IS NULL)
    OR (`status` = 'approved' AND `decided_on` IS NOT NULL)
    OR (`status` IN ('rejected','withdrawn') AND `decided_on` IS NOT NULL
        AND `decision_note` IS NOT NULL)
  ),
  /*
   * Tarikh dalam susunan yang berlaku.
   *
   * Setiap perbandingan dibalut `IS NULL OR`, kerana satu perbandingan dengan NULL menilai
   * kepada UNKNOWN dan satu CHECK LULUS pada UNKNOWN — jadi tanpa pembalut itu constraint
   * ini akan senyap tidak menyemak apa-apa pada satu permintaan yang masih menunggu.
   *
   * Satu client yang memutuskan pada HARI permintaan itu dihantar adalah sah. Jadi `>=`.
   */
  CONSTRAINT `chk_pca_order` CHECK (
    (`decided_on` IS NULL OR `decided_on` >= `requested_on`)
    AND (`due_on` IS NULL OR `due_on` >= `requested_on`)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  cols 16  fks 2  uniques 1  checks 2
--
-- `fks` MESTI 2. Kalau ia 1, FK dokumen tidak dicipta — dan itu bermakna satu lukisan yang
-- client sudah luluskan boleh dipadam, meninggalkan satu rekod kelulusan yang merujuk
-- kepada tiada apa.
--
-- `checks` MESTI 2. Kalau ia 0, satu penolakan boleh direkod tanpa sebab.
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
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_client_approvals'
