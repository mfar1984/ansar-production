-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — timesheet
--
-- Spec: .kiro/specs/project-management/  (Task 34 — leaf Timesheets, keputusan D5)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_tasks.sql  (project_tasks)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- D5 DIJAWAB, DAN JAWAPANNYA MENENTUKAN BENTUK TABLE INI
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Soalan terbuka D5 ialah: masa terhadap satu task milik Project Management, masa untuk
-- gaji milik HR, dan tiada table timesheet dalam kedua-duanya.
--
-- Dijawab oleh pengguna pada 2026-08-21: **Timesheet milik mutlak Project Management dan
-- tiada kaitan dengan HR.**
--
-- ── AKIBAT PERTAMA: JAM SAHAJA. TIADA KADAR, TIADA WANG. ──
--
-- Mengira kos satu jam bermakna membaca `employees.basic_salary`, dan lajur itu milik HR.
-- Jadi table ini merekod TEMPOH dan tiada apa lagi. Tiada `rate`, tiada `amount`, tiada
-- `cost`. Budget & Cost boleh berhujah untuk kos buruh kemudian; itu hujah berasingan
-- dengan jawapan berasingan.
--
-- ── AKIBAT KEDUA: TIADA APA DIBUANG ──
--
-- `project_management_permissions.sql` menyemai LIMA tindakan untuk `project_timesheets`:
-- view, create, edit, delete, approve. Itu set paling kaya yang tinggal dalam modul ini.
-- Kalau jawapannya HR, modul itu kena dipadam dan disemai semula di bawah HR —
-- `asset_page_permissions.sql` ialah presedennya.
--
-- ── AKIBAT KETIGA: TIADA APA BERTINDAN ──
--
-- Diukur pada pangkalan data ini: TIADA table attendance, clock-in atau timesheet di
-- mana-mana. `employees.duty_state` ialah LOKASI — cuti umum negeri mana yang terpakai —
-- bukan jejak masa. `payroll_records` membawa `overtime_amount`, satu jumlah RINGGIT, bukan
-- jam. Tulang belakang payroll tidak pernah meminta jam.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `task_id` NULLABLE, DAN `ON DELETE SET NULL` — BERTENTANGAN DENGAN RESTRICT TASK 32
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Task 32 memberi `project_client_approvals.document_id` satu `ON DELETE RESTRICT`, kerana
-- satu pelan yang client tandatangan ialah BUKTI — kehilangan penunjuknya menjadikan
-- tandatangan itu tidak bermakna.
--
-- Di sini keputusannya bertentangan, dan sebabnya ialah apa yang baris itu rekod. Satu
-- kemasukan jam kekal BENAR dan kekal boleh dikira walaupun task itu disusun semula:
-- projek, orang, tarikh dan tempoh kesemuanya masih ada. Jadi task boleh dipadam dan jam
-- itu jatuh kepada projek.
--
-- Presedennya dalam table jiran: `project_tasks.milestone_id` ialah `ON DELETE SET NULL`
-- atas hujah yang sama — satu task kekal kerja walaupun milestone yang memilikinya hilang.
--
-- Nullable juga kerana kes berguna memang ada tanpa task: mesyuarat tapak, perjalanan,
-- pembetulan yang bukan satu pun task berdaftar. Mewajibkan satu task akan memaksa
-- seseorang mencipta task tiruan untuk merekod dua jam.
--
-- ── DUA LALUAN CASCADE KE SATU TABLE, DAN IA DIBUKTIKAN ──
--
-- `project_id` CASCADE daripada `projects`. `task_id` SET NULL daripada `project_tasks`,
-- yang ITU SENDIRI cascade daripada `projects`. Jadi memadam satu projek mencapai baris
-- timesheet melalui DUA laluan serentak.
--
-- Itu risiko reka bentuk sebenar task ini, jadi ia diprob atas pangkalan data ini sebelum
-- ditulis, bukan diandaikan:
--
--   CREATE dengan CASCADE + SET NULL pada dua laluan   DITERIMA
--   memadam TASK sahaja                                baris kekal, task_id jadi NULL
--   memadam PROJEK dengan task_id hidup                baris hilang
--
-- Kedua-dua tingkah laku betul. Kalau mana-mana satu berbeza atas pelayan, baris
-- pengesahan di bawah tidak akan menangkapnya — jadi ia juga diuji dalam
-- `tests/sql/project-timesheets.test.js` terhadap baris sebenar.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `employee_id` TIADA FOREIGN KEY, DAN TIADA SNAPSHOT NAMA
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Tiada FK, mengikut presedon modul: `project_tasks.assignee_employee_id`,
-- `project_risks.owner_employee_id` dan `project_ncrs.owner_employee_id` kesemuanya tiada
-- FK. Seseorang yang meninggalkan syarikat tidak boleh memadam rekod kerja yang dia buat.
--
-- Tetapi TIADA snapshot nama, dan itu BERBEZA daripada
-- `project_client_approvals.decided_by_name`. Sebabnya diukur: `client_users` CASCADE, jadi
-- satu akaun client yang ditutup akan memadam tandatangannya — itu sebab snapshot itu ada.
-- `employees` pula membawa `status` dan `resign_date`: seorang pekerja yang berhenti
-- DITUKAR STATUS, bukan dipadam. JOIN masih menjumpainya. Satu snapshot di sini akan jadi
-- salinan kedua nama yang boleh bercanggah dengan yang pertama.
--
-- `decided_by` ialah VARCHAR(191) yang memegang username, sama seperti
-- `project_ncrs.verified_by` dan `created_by` di seluruh modul ini.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- TIADA NOMBOR RUJUKAN, DAN INI TABLE PROJEK PERTAMA TANPA SATU
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Lima table dalam modul ini ada satu: `change_no`, `report_no`, `ncr_no`, `approval_no`,
-- dan `project_no` sendiri. Kesemuanya ialah DOKUMEN — sesuatu yang dirujuk dalam surat,
-- disebut dalam mesyuarat, dicari dengan nombornya.
--
-- Satu baris timesheet bukan dokumen. Ia dikenali oleh orang + tarikh + task, dan ketiganya
-- ada dalam baris itu. `TS-2026-0001` untuk tempahan tiga jam ialah birokrasi, dan
-- `nextReference` akan dipanggil pada setiap kemasukan hanya untuk menghasilkan satu rentetan
-- yang tiada siapa akan taip.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- TIADA UNIQUE, DAN ITU KEPUTUSAN — BUKAN KELALAIAN
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- `UNIQUE (employee_id, work_date, task_id)` dipertimbangkan dan DITOLAK. Dua kemasukan
-- atas task yang sama pada hari yang sama adalah sah: pagi dan petang atas aspek berbeza,
-- dengan catatan berbeza. Satu unique akan memaksa kedua-duanya digabung menjadi satu baris
-- dan kehilangan catatan itu — kegagalan yang sama `project_reports` elak dengan tidak
-- meletakkan unique atas tempoh.
--
-- Kos keputusan itu ialah satu kemasukan berganda tidak dihalang oleh pangkalan data. Jadi
-- ia dijadikan KELIHATAN: skrin memaparkan jumlah jam per orang per hari, dan endpoint
-- MENOLAK apa-apa yang akan menjadikan satu hari melebihi 24 jam merentas setiap projek.
-- Peraturan silang-baris itu tidak boleh ditulis sebagai CHECK, jadi ia hidup dalam
-- endpoint dan diuji di sana.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Satu `CREATE TABLE IF NOT EXISTS` dan satu baris pengesahan. Jalankan dua kali dan
-- baris kedua melaporkan nombor yang sama.

CREATE TABLE IF NOT EXISTS `project_timesheets` (
  `id` INT NOT NULL AUTO_INCREMENT,

  `project_id` INT NOT NULL,

  -- Nullable: mesyuarat tapak, perjalanan, kerja yang bukan satu pun task berdaftar.
  `task_id` INT NULL DEFAULT NULL,

  -- TIADA foreign key. Lihat nota di atas.
  `employee_id` INT NOT NULL,

  `work_date` DATE NOT NULL,

  -- DECIMAL(4,2) memberi 99.99; `chk_pts_hours` mengehadkannya kepada 24. Separuh jam dan
  -- suku jam kedua-duanya boleh dinyatakan, yang mana cukup untuk satu buku masa.
  `hours` DECIMAL(4,2) NOT NULL,

  -- Apa yang dibuat. VARCHAR, bukan TEXT: ini satu baris, bukan satu laporan.
  `activity` VARCHAR(400) NULL DEFAULT NULL,

  -- TIGA keadaan, dan tiada `draft`. Mencipta satu kemasukan ITULAH menghantarnya — satu
  -- baris tiga jam tidak ditulis berperingkat merentas beberapa hari seperti satu laporan.
  `status` ENUM('submitted','approved','rejected') NOT NULL DEFAULT 'submitted',

  `decided_on` DATE NULL DEFAULT NULL,
  `decided_by` VARCHAR(191) NULL DEFAULT NULL,

  -- Wajib untuk `rejected`, pilihan untuk `approved`. Ketidakseimbangan yang sama seperti
  -- `chk_pca_decided`: ya ialah jawapan lengkap, penolakan ialah satu-satunya cara pemilik
  -- jam itu tahu apa perlu dibetulkan.
  `decision_note` VARCHAR(400) NULL DEFAULT NULL,

  `created_by` VARCHAR(191) NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  -- Daftar per projek, ditapis mengikut status, disusun mengikut tarikh kerja.
  KEY `idx_pts_project` (`project_id`, `status`, `work_date`),
  -- Jumlah harian seorang pekerja — pembacaan yang peraturan 24 jam endpoint bergantung
  -- padanya, jadi ia mesti satu bacaan indeks.
  KEY `idx_pts_employee` (`employee_id`, `work_date`),
  KEY `idx_pts_task` (`task_id`),
  -- Barisan kelulusan merentas setiap projek.
  KEY `idx_pts_status` (`status`, `work_date`),

  CONSTRAINT `fk_pts_project` FOREIGN KEY (`project_id`)
    REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,

  -- SET NULL, bukan RESTRICT. Lihat nota di atas: jam yang dikerjakan kekal benar walaupun
  -- task itu hilang.
  CONSTRAINT `fk_pts_task` FOREIGN KEY (`task_id`)
    REFERENCES `project_tasks` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,

  -- Satu hari tidak boleh mengandungi lebih daripada 24 jam, dan sifar jam bukan satu
  -- kemasukan. Nilai negatif ditolak oleh had bawah yang sama.
  CONSTRAINT `chk_pts_hours` CHECK (`hours` > 0 AND `hours` <= 24),

  -- Satu baris yang diputuskan mesti membawa SIAPA dan BILA. Satu baris `submitted` mesti
  -- tidak membawa apa-apa daripadanya — itu separuh yang menjadikan penyuntingan semula
  -- selepas penolakan perlu MEMBERSIHKAN jejaknya, dan endpoint berbuat demikian.
  --
  -- Setiap perbandingan yang menyentuh lajur nullable dibalut, kerana satu CHECK LULUS pada
  -- UNKNOWN. Tanpa balutan itu constraint akan menyemak apa-apa pun pada baris yang belum
  -- diputuskan.
  CONSTRAINT `chk_pts_decided` CHECK (
    (`status` = 'submitted'
      AND `decided_on` IS NULL AND `decided_by` IS NULL AND `decision_note` IS NULL)
    OR (`status` = 'approved'
      AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL)
    OR (`status` = 'rejected'
      AND `decided_on` IS NOT NULL AND `decided_by` IS NOT NULL
      AND `decision_note` IS NOT NULL)
  ),

  -- Jam tidak boleh diluluskan sebelum ia dikerjakan. Hari yang sama dibenarkan: seorang
  -- penyelia atas tapak boleh menyemak buku masa petang itu.
  CONSTRAINT `chk_pts_order` CHECK (`decided_on` IS NULL OR `decided_on` >= `work_date`)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- PENGESAHAN — apa yang operator baca atas pelayan
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Jangkaan:  cols 14   fks 2   uniques 0   checks 3   actions 5
--
-- (14: id, project_id, task_id, employee_id, work_date, hours, activity, status, decided_on,
--  decided_by, decision_note, created_by, created_at, updated_at. Dikira semula terhadap
--  pangkalan data selepas saya menulis 15 di sini — operator membaca baris ini atas pelayan
--  dan satu jangkaan yang salah lebih buruk daripada tiada jangkaan.)
--
-- `uniques 0` ialah SATU JANGKAAN, bukan satu kelalaian. Lihat nota di atas: dua kemasukan
-- atas task yang sama pada hari yang sama adalah sah, dan peraturan 24 jam hidup dalam
-- endpoint kerana ia silang-baris.
--
-- Kalau `checks` bukan 3, satu kemasukan boleh merekod 100 jam sehari, atau satu penolakan
-- boleh direkod tanpa sebab, atau jam boleh diluluskan sebelum ia dikerjakan.
--
-- Kalau `fks` bukan 2, `task_id` tidak akan jadi NULL bila satu task dipadam — ia akan
-- menunjuk kepada baris yang tidak wujud, dan setiap JOIN atasnya akan menjatuhkan baris
-- itu secara senyap.
--
-- Kalau `actions` bukan 5, penyemaian kebenaran tidak lengkap dan skrin ini tidak akan
-- menawarkan kelulusan.
--
-- `PRIMARY KEY` dikecualikan daripada kiraan unique dengan sengaja: ia sentiasa ada, dan
-- memasukkannya akan menjadikan jangkaan `1` yang tidak boleh gagal.

SELECT (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = 'project_timesheets') AS cols,
       (SELECT COUNT(*) FROM information_schema.table_constraints
         WHERE table_schema = DATABASE() AND table_name = 'project_timesheets'
           AND constraint_type = 'FOREIGN KEY') AS fks,
       (SELECT COUNT(*) FROM information_schema.table_constraints
         WHERE table_schema = DATABASE() AND table_name = 'project_timesheets'
           AND constraint_type = 'UNIQUE') AS uniques,
       (SELECT COUNT(*) FROM information_schema.table_constraints
         WHERE table_schema = DATABASE() AND table_name = 'project_timesheets'
           AND constraint_type = 'CHECK') AS checks,
       (SELECT COUNT(*) FROM `permissions`
         WHERE `module` = 'project_timesheets') AS actions;
