-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — permintaan perubahan (variation order)
--
-- Spec: .kiro/specs/project-management/  (Task 29 — Phase 3, leaf Change Requests)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_contract.sql  (nilai kontrak)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- INI MEMBETULKAN SATU JURANG INTEGRITI, BUKAN MENAMBAH SATU SKRIN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `projects.value` boleh disunting pada borang register, dan TIADA APA merekod
-- sebabnya. Satu VO bernilai RM 20,000 diluluskan, seseorang menaip nilai baharu, dan
-- enam bulan kemudian tiada siapa boleh mengatakan:
--
--   berapa nilai kontrak ASAL
--   berapa banyak VO telah diluluskan
--   siapa meluluskannya, dan bila
--   sama ada client yang minta (boleh dicaj) atau kesilapan kita (tidak boleh)
--
-- Itu bukan kekurangan ciri. Itu satu lajur wang yang dipapar pada EMPAT skrin —
-- register, kepala ruang kerja, portfolio, dan portal client — dengan tiada jejak di
-- belakangnya. Sama bentuk seperti kegagalan `percent_complete`, kecuali pada WANG.
--
-- ── MELULUSKAN SATU PERUBAHAN MENULIS `projects`, DALAM TRANSAKSI YANG SAMA ──
--
-- Ini keputusan besar fail ini, dan alternatifnya lebih buruk:
--
--   TIDAK menulis     `projects.value` kekal nilai kontrak asal selama-lamanya, dan
--                     empat skrin memapar satu angka yang bukan lagi nilai kontrak.
--                     Senarai VO memapar +RM 20,000 dan tiada siapa menjumlahkannya
--   lajur kedua       satu `varied_value` di sebelah `value` ialah satu fakta di dua
--                     tempat, dan borang register akan membenarkan seseorang menyunting
--                     yang salah
--
-- Jadi kelulusan MEMOHON perubahan itu, dan setiap baris merekod apa yang ia ubah
-- DARIPADA dan KEPADA. Nilai kontrak asal boleh diterbitkan: nilai semasa tolak jumlah
-- setiap `value_change` yang diluluskan. Setiap langkah boleh diaudit.
--
-- Presedennya sudah ada: `[id]/milestones.ts` mengira semula
-- `projects.percent_complete` dalam transaksi yang sama, atas sebab yang sama, dan
-- `tests/sql/tx-leak.test.js` mengawal bentuknya.
--
-- ── SATU PERUBAHAN YANG DILULUSKAN TIDAK BOLEH DISUNTING ──
--
-- Bukan `value_change`, bukan `days_change`. Wang sudah dipohon pada `projects.value`;
-- menukar jumlah itu selepas itu akan meninggalkan lajur projek tidak selari dengan
-- jejaknya, dan tiada apa akan mengatakannya. Peraturan yang sama seperti satu invois
-- pembekal: `editable: ['draft']`.
--
-- Untuk menukar jumlah, batalkan kelulusan dahulu — yang MENOLAK semula wang itu — dan
-- itu direkod dalam log audit.
--
-- ── TIADA LAJUR `kind` ──
--
-- Satu `kind ENUM('addition','omission','substitution','time_only')` DIPERTIMBANGKAN dan
-- ditolak, kerana tiga daripada empat boleh diterbitkan daripada dua nombor yang sudah
-- ada:
--
--   addition    value_change > 0
--   omission    value_change < 0
--   time_only   value_change = 0 DAN days_change <> 0
--
-- Yang keempat, `substitution`, tidak boleh diterbitkan — dan ia juga tidak menentukan
-- apa-apa. Tiada query menapisnya dan tiada keputusan bergantung padanya. Satu enum yang
-- separuhnya pendua dan separuhnya tidak digunakan ialah satu lajur yang setiap INSERT
-- mesti mengisi tanpa sebab.
--
-- `reason` BERBEZA dan ia disimpan, kerana ia menentukan SIAPA BAYAR: satu perubahan yang
-- client minta boleh dicaj, satu kesilapan atau kelalaian kita tidak boleh. Itu satu-satunya
-- klasifikasi pada satu VO yang seseorang akan berhujah tentangnya.
--
-- ── CHECK CONSTRAINT, KALI KEDUA ──
--
-- `database/project_management_risk.sql` merekod probe yang membuktikan had MySQL hanya
-- tentang lajur FK. Dua constraint di sini menggunakan penemuan yang sama:
--
--   chk_pc_decided  satu perubahan yang TAMAT ada tarikh keputusan; yang terbuka tiada
--   chk_pc_applied  status='approved' SELALU membawa applied_at dan angka sebelum/selepas,
--                   dan apa-apa selain 'approved' TIDAK PERNAH membawanya
--
-- Yang kedua ialah yang penting. Tanpanya, satu baris boleh berkata ia diluluskan tanpa
-- merekod apa yang ia ubah — dan jejak itu ialah seluruh sebab table ini wujud.
--
-- `end_date_before` dan `end_date_after` SENGAJA tidak berada dalam CHECK itu: satu projek
-- tanpa `end_date` sah mempunyai kedua-duanya NULL walaupun perubahan itu diluluskan.
--
-- IDEMPOTENT. Satu `CREATE TABLE IF NOT EXISTS` dan satu SELECT verifikasi.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_changes.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Permintaan perubahan ──
--
-- `value_change` dan `days_change` kedua-duanya BERTANDA. Satu kelalaian mengurangkan
-- kontrak, dan satu percepatan mengurangkan tempoh; memaksa kedua-duanya positif akan
-- memerlukan satu lajur arah yang ialah tanda itu sendiri, ditulis dua kali.
--
-- `change_no` ialah GLOBAL (`CHG-2026-0001`), bukan satu urutan per projek. Lapan table
-- lain dalam sistem ini menggunakan `nextReference` dengan bentuk yang sama, dan satu
-- urutan per projek memerlukan satu pembilang per projek yang mesti dikunci — sedangkan
-- "VO kedua projek ini" boleh diterbitkan dengan satu `ROW_NUMBER` bila ada sesiapa
-- memintanya.
CREATE TABLE IF NOT EXISTS `project_changes` (
  `id`              INT NOT NULL AUTO_INCREMENT,
  `project_id`      INT NOT NULL,
  `change_no`       VARCHAR(50) NOT NULL COMMENT 'CHG-YYYY-NNNN, global. Lihat nota',
  `title`           VARCHAR(255) NOT NULL,
  `description`     TEXT NULL DEFAULT NULL,
  /* SIAPA BAYAR. Satu-satunya klasifikasi pada satu VO yang orang berhujah tentangnya. */
  `reason`          ENUM('client_request','site_condition','design_change','statutory',
                         'error_omission','other') NOT NULL DEFAULT 'client_request',
  `value_change`    DECIMAL(15,2) NOT NULL DEFAULT 0.00
                    COMMENT 'BERTANDA. Negatif ialah satu kelalaian',
  `days_change`     SMALLINT NOT NULL DEFAULT 0
                    COMMENT 'BERTANDA. Negatif ialah satu percepatan',
  `status`          ENUM('draft','submitted','approved','rejected','withdrawn')
                    NOT NULL DEFAULT 'draft',
  `raised_on`       DATE NOT NULL,
  `decided_on`      DATE NULL DEFAULT NULL COMMENT 'dipautkan kepada status oleh chk_pc_decided',
  `decision_note`   VARCHAR(400) NULL DEFAULT NULL,
  /* ── Apa yang ia SEBENARNYA lakukan kepada projek, direkod pada saat ia dipohon ──
     Ini jejak audit. Ia BUKAN dakwaan tentang nilai semasa: satu VO kemudian akan
     menggerakkan `projects.value` lagi, dan baris ini kekal seperti yang berlaku. */
  `value_before`    DECIMAL(15,2) NULL DEFAULT NULL,
  `value_after`     DECIMAL(15,2) NULL DEFAULT NULL,
  `end_date_before` DATE NULL DEFAULT NULL,
  `end_date_after`  DATE NULL DEFAULT NULL,
  `applied_at`      TIMESTAMP NULL DEFAULT NULL
                    COMMENT 'ditetapkan hanya apabila diluluskan. Lihat chk_pc_applied',
  `created_by`      VARCHAR(191) NULL DEFAULT NULL,
  `decided_by`      VARCHAR(191) NULL DEFAULT NULL,
  `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pc_no` (`change_no`),
  /* Satu projek, yang belum diputuskan dahulu. */
  KEY `idx_pc_project` (`project_id`, `status`, `id`),
  /* "Apa yang menunggu satu keputusan, di mana-mana" — soalan utama leaf silang-projek. */
  KEY `idx_pc_status` (`status`, `raised_on`),
  CONSTRAINT `fk_pc_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  /*
   * Satu perubahan yang TAMAT ada tarikh keputusan; satu yang masih terbuka tiada.
   *
   * `withdrawn` dikira tamat: ia satu keputusan oleh pihak yang menaikkannya, dan
   * "ditarik, dan tiada siapa boleh mengatakan bila" ialah tepat soalan yang satu audit
   * tanya.
   */
  CONSTRAINT `chk_pc_decided` CHECK (
    (`status` IN ('approved','rejected','withdrawn') AND `decided_on` IS NOT NULL)
    OR (`status` IN ('draft','submitted') AND `decided_on` IS NULL)
  ),
  /*
   * Satu perubahan yang DILULUSKAN selalu merekod apa yang ia ubah, dan apa-apa yang tidak
   * diluluskan tidak pernah merekodnya.
   *
   * Ini constraint yang penting. Tanpanya satu baris boleh berkata ia diluluskan tanpa
   * jejak apa yang ia gerakkan pada `projects.value` — dan jejak itu ialah seluruh sebab
   * table ini wujud. Arah sebaliknya juga: satu `applied_at` yang tertinggal pada satu
   * perubahan yang dibatalkan kelulusannya akan mendakwa wang itu masih dipohon.
   *
   * `end_date_before` dan `end_date_after` BUKAN di sini: satu projek tanpa `end_date` sah
   * mempunyai kedua-duanya NULL walaupun perubahan itu diluluskan.
   */
  CONSTRAINT `chk_pc_applied` CHECK (
    (`status` = 'approved' AND `applied_at` IS NOT NULL
       AND `value_before` IS NOT NULL AND `value_after` IS NOT NULL)
    OR (`status` <> 'approved' AND `applied_at` IS NULL
       AND `value_before` IS NULL AND `value_after` IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan:  cols 21  fks 1  uniques 1  checks 2
--
-- `checks` MESTI 2. Kalau ia 0, MySQL pelayan ini menerima table itu dan MENJATUHKAN
-- constraint — yang bermakna satu baris boleh mendakwa ia diluluskan tanpa jejak apa yang
-- ia gerakkan pada nilai kontrak, dan hanya endpoint yang menghalangnya.
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
 WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'project_changes'
