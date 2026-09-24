-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — modul penuh, membetulkan kekurangan pecahan
--
-- Spec: .kiro/specs/project-management/  (Task 1, pembetulan)
-- Susulan kepada: database/project_management_permissions.sql
--
-- ── APA YANG SALAH DENGAN FAIL PERTAMA ──
--
-- Fail pertama menyemai ENAM modul untuk seluruh seksyen, dan hujahnya ialah
-- "satu modul sampai satu role betul-betul perlu pecahan". Hujah itu betul untuk
-- tab SETTINGS satu modul. Ia SALAH untuk skrin yang setiap satunya entiti berbeza.
--
-- Diukur terhadap Asset Management, yang saiznya setanding:
--
--   Asset Management      3 kumpulan   17 leaf   19 modul
--   Project Management    2 kumpulan    3 leaf    6 modul   ← yang dihantar
--   Project Management    5 kumpulan   17 leaf   22 modul   ← fail ini
--
-- Asset Management memberi `asset_checkouts`, `asset_loan_requests`,
-- `asset_maintenance`, `asset_disposals` dan `asset_stocktakes` satu leaf dan satu
-- modul SETIAP SATU, sebab setiap satu entiti berbeza dengan table berbeza. Saya
-- runtuhkan lima entiti Project Management menjadi tab pada satu leaf, dan itu
-- bukan penjimatan — itu menyembunyikan skrin dan memberi satu kebenaran kuasa ke
-- atas lima perkara yang tidak berkaitan.
--
-- Komen pada `asset_maintenance` dalam AdminSidebar.tsx sudah merekod sebabnya:
-- tab dalam satu rekod menjawab "apa yang telah dibuat kepada mesin INI"; ia tidak
-- boleh menjawab "apa yang tertunggak bulan ini merentas keseluruhan register".
-- Dua soalan, dua skrin, dua kebenaran.
--
-- ── PECAHAN TAB SETTINGS ──
--
-- Sembilan modul yang ada sudah mengikut satu-modul-satu-tab-settings:
-- procurement_categories/_approval/_notifications, career, asset_loan,
-- asset_disposal, market_place, tender_categories. `project_settings` tunggal
-- bermakna sesiapa yang boleh menyunting kategori boleh juga menulis semula
-- rantaian kelulusan gate. Itu bukan satu kuasa yang sama.
--
-- ── SATU BARIS DIBUANG, BUKAN DITINGGALKAN ──
--
-- `project_chat_publish` dibuang. Ia disemai untuk "terbitkan laporan kemajuan",
-- dan laporan kemajuan kini ada modulnya sendiri, `project_reports`. Satu tindakan
-- yang tinggal di modul lamanya ialah kotak semak dalam matriks Roles yang tidak
-- mengawal apa-apa. `database/asset_page_permissions.sql` sudah membuat perkara
-- yang sama apabila dua tindakan berpindah bersama halamannya.
--
-- IDEMPOTENT. `INSERT IGNORE` pada indeks unik `name`, dan DELETE yang tidak
-- memerlukan barisnya wujud.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_modules.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Kumpulan: Projects ──
--
-- `projects_delivery` sudah disemai oleh fail pertama dan tidak diulang di sini.
--
-- `project_portfolio` hanya `view`: ia dashboard, tidak mencipta apa-apa. Modul
-- sendiri dan bukan dilipat ke dalam `projects_delivery` sebab audiensnya berbeza —
-- pengurus kanan membaca portfolio tanpa perlu menyunting mana-mana projek. Bentuk
-- yang sama seperti `asset_reports`.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_portfolio', 'view', 'project_portfolio_view', 'View the portfolio dashboard across all projects', 'operations')

-- >>>
-- ── Kumpulan: Projects > Settings, satu modul setiap tab ──
--
-- `project_settings` sudah disemai dan kini memiliki tab Numbering SAHAJA. Lima tab
-- yang lain mendapat modulnya sendiri, mengikut corak yang sembilan modul settings
-- lain sudah pakai.
--
-- `project_approval` berasingan daripada `project_phases` sebab ia dua perkara:
-- `phases` menentukan APA fasa itu, `approval` menentukan SIAPA boleh menutup gate.
-- Satu role boleh dipercayai menamakan fasa tanpa dipercayai memutuskan projek
-- selesai.
--
-- `project_categories` dan `project_templates` mendapat empat tindakan sebab
-- kedua-duanya senarai yang boleh ditambah dan dibuang, bukan satu baris tetapan.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_phases',        'view',   'project_phases_view',        'View the project phase definitions',        'operations'),
  ('project_phases',        'edit',   'project_phases_edit',        'Change the project phase definitions',      'operations'),
  ('project_approval',      'view',   'project_approval_view',      'View the phase gate approval chain',        'operations'),
  ('project_approval',      'edit',   'project_approval_edit',      'Change the phase gate approval chain',      'operations'),
  ('project_categories',    'view',   'project_categories_view',    'View project categories',                   'operations'),
  ('project_categories',    'create', 'project_categories_create',  'Add a project category',                    'operations'),
  ('project_categories',    'edit',   'project_categories_edit',    'Update a project category',                 'operations'),
  ('project_categories',    'delete', 'project_categories_delete',  'Delete a project category',                 'operations'),
  ('project_templates',     'view',   'project_templates_view',     'View WBS templates',                        'operations'),
  ('project_templates',     'create', 'project_templates_create',   'Add a WBS template',                        'operations'),
  ('project_templates',     'edit',   'project_templates_edit',     'Update a WBS template',                     'operations'),
  ('project_templates',     'delete', 'project_templates_delete',   'Delete a WBS template',                     'operations'),
  ('project_notifications', 'view',   'project_notifications_view', 'View project notification settings',        'operations'),
  ('project_notifications', 'edit',   'project_notifications_edit', 'Change project notification settings',      'operations')

-- >>>
-- ── Kumpulan: Delivery ──
--
-- Empat entiti, empat modul. Setiap satu menjawab soalan merentas projek yang tab
-- dalam satu projek tidak boleh jawab: milestone mana jatuh bulan ini, apa tugasan
-- saya dari semua projek, projek mana bertindih sumber.
--
-- `project_schedule` tiada `create` atau `delete`: satu jadual tidak dicipta, ia
-- diterbitkan daripada WBS dan tugasan. Yang boleh dilakukan ialah menyunting
-- dependency dan baseline.
--
-- `project_timesheets` mendapat `approve` sebab lembaran masa diluluskan sebelum ia
-- menjadi kos. AMARAN: pemilikan modul ini BELUM SELESAI — keputusan terbuka D5
-- dalam spec merekod bahawa masa terhadap tugasan milik Project Management
-- sementara masa untuk payroll milik HR, dan tiada table lembaran masa dalam
-- kedua-duanya. Kalau ia berpindah ke HR, migration yang memindahkannya membuang
-- baris ini.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_milestones',  'view',    'project_milestones_view',    'View milestones across all projects',   'operations'),
  ('project_milestones',  'create',  'project_milestones_create',  'Add a milestone',                       'operations'),
  ('project_milestones',  'edit',    'project_milestones_edit',    'Update a milestone',                    'operations'),
  ('project_milestones',  'delete',  'project_milestones_delete',  'Delete a milestone',                    'operations'),
  ('project_tasks',       'view',    'project_tasks_view',         'View tasks across all projects',        'operations'),
  ('project_tasks',       'create',  'project_tasks_create',       'Add a task',                            'operations'),
  ('project_tasks',       'edit',    'project_tasks_edit',         'Update or reassign a task',             'operations'),
  ('project_tasks',       'delete',  'project_tasks_delete',       'Delete a task',                         'operations'),
  ('project_schedule',    'view',    'project_schedule_view',      'View the project schedule and Gantt',   'operations'),
  ('project_schedule',    'edit',    'project_schedule_edit',      'Change dependencies and the baseline',  'operations'),
  ('project_timesheets',  'view',    'project_timesheets_view',    'View time booked against projects',     'operations'),
  ('project_timesheets',  'create',  'project_timesheets_create',  'Book time against a task',              'operations'),
  ('project_timesheets',  'edit',    'project_timesheets_edit',    'Correct a time entry',                  'operations'),
  ('project_timesheets',  'delete',  'project_timesheets_delete',  'Delete a time entry',                   'operations'),
  ('project_timesheets',  'approve', 'project_timesheets_approve', 'Approve time before it becomes cost',   'operations')

-- >>>
-- ── Kumpulan: Control ──
--
-- `project_risk` sudah disemai. `project_quality` BERASINGAN daripadanya, dan fail
-- pertama menggabungkan kedua-duanya atas alasan "audiens sama, QA/HSE". Alasan itu
-- terlalu longgar: risiko ialah apa yang MUNGKIN berlaku dan dimiliki oleh pengurus
-- projek; ketidakpatuhan ialah apa yang SUDAH berlaku dan dimiliki oleh QA. Satu
-- role yang boleh membaca daftar risiko tidak semestinya boleh menutup NCR.
--
-- `project_changes` mendapat `approve` sebab permohonan perubahan mengubah kos dan
-- masa yang dipersetujui — itu bukan `edit`.
--
-- `project_reports` mendapat `publish`, dipindahkan daripada `project_chat` di bawah.
-- Mengarang laporan dalaman dan mengeluarkannya kepada client ialah dua keputusan.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_quality',  'view',    'project_quality_view',    'View inspection records and NCRs',              'operations'),
  ('project_quality',  'create',  'project_quality_create',  'Raise an inspection record or an NCR',          'operations'),
  ('project_quality',  'edit',    'project_quality_edit',    'Update an inspection record or close an NCR',   'operations'),
  ('project_quality',  'delete',  'project_quality_delete',  'Delete an inspection record',                   'operations'),
  ('project_changes',  'view',    'project_changes_view',    'View change requests across all projects',      'operations'),
  ('project_changes',  'create',  'project_changes_create',  'Raise a change request',                        'operations'),
  ('project_changes',  'edit',    'project_changes_edit',    'Update a change request',                       'operations'),
  ('project_changes',  'delete',  'project_changes_delete',  'Delete a change request',                       'operations'),
  ('project_changes',  'approve', 'project_changes_approve', 'Approve a change to agreed cost or time',       'operations'),
  ('project_reports',  'view',    'project_reports_view',    'View progress reports',                         'operations'),
  ('project_reports',  'create',  'project_reports_create',  'Write a progress report',                       'operations'),
  ('project_reports',  'edit',    'project_reports_edit',    'Update a progress report',                      'operations'),
  ('project_reports',  'publish', 'project_reports_publish', 'Release a progress report to the client',       'operations')

-- >>>
-- ── Kumpulan: Commercial — tiga modul, satu tindakan setiap satu ──
--
-- Ketiga-tiganya agregat BACA-SAHAJA ke atas modul yang sudah memiliki datanya:
-- perakaunan, HR, dan register vendor campur Purchases. Tiada rekod dicipta di sini,
-- jadi tiada `create`, `edit` atau `delete` untuk diberikan — dan menyemaikannya
-- akan menjadi kotak semak yang tidak memberi apa-apa.
--
-- `project_cost` sudah disemai. Dua lagi ditambah di sini dengan alasan yang sama:
-- audiens berbeza. Seorang perancang sumber perlu melihat siapa over-allocated tanpa
-- melihat margin projek.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_resources',   'view', 'project_resources_view',   'View staff and equipment allocation across projects', 'operations'),
  ('project_procurement', 'view', 'project_procurement_view', 'View vendors and purchase orders by project',         'operations')

-- >>>
-- ── Kumpulan: Client Workspace ──
--
-- `project_chat` sudah disemai. Dua leaf lagi mendapat modulnya sendiri sebab
-- kedua-duanya entiti berbeza: satu fail yang dikongsi bukan satu mesej, dan satu
-- kelulusan client bukan salah satu daripadanya.
--
-- `project_documents_share` berasingan daripada `_create`: memuat naik lukisan ke
-- dalam projek dan MENANDAKANNYA kelihatan kepada pihak luar ialah dua keputusan.
-- Itu penanda yang sama yang menentukan apa portal client papar.
--
-- `project_client_approvals` tiada `create`: yang mencipta kelulusan ialah CLIENT,
-- dari portalnya. Pihak admin meminta satu (`request`) dan membacanya.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_documents',        'view',    'project_documents_view',        'View project documents',                     'operations'),
  ('project_documents',        'create',  'project_documents_create',      'Upload a project document',                  'operations'),
  ('project_documents',        'edit',    'project_documents_edit',        'Replace or version a project document',      'operations'),
  ('project_documents',        'delete',  'project_documents_delete',      'Delete a project document',                  'operations'),
  ('project_documents',        'share',   'project_documents_share',       'Mark a document visible to the client',      'operations'),
  ('project_client_approvals', 'view',    'project_client_approvals_view', 'View what is waiting on a client decision',  'operations'),
  ('project_client_approvals', 'request', 'project_client_approvals_request', 'Ask a client to approve something',       'operations')

-- >>>
-- ── Satu baris dibuang: `project_chat_publish` ──
--
-- Ia disemai untuk menerbitkan laporan kemajuan. Laporan kemajuan kini ada modulnya
-- sendiri, dan `project_reports_publish` di atas ialah tindakan yang sama di tempat
-- yang betul. Membiarkan yang lama bermakna dua kotak semak untuk satu perbuatan,
-- dan hanya satu daripadanya yang disemak oleh endpoint.
--
-- `role_permissions` dibersihkan dahulu: FK ke `permissions` akan menghalang DELETE
-- kalau baris pemberian masih ada.
DELETE rp FROM `role_permissions` rp
  JOIN `permissions` p ON p.id = rp.permission_id
 WHERE p.name = 'project_chat_publish'

-- >>>
DELETE FROM `permissions` WHERE `name` = 'project_chat_publish'

-- >>>
-- ── Berikan setiap modul admin kepada super-admin ──
--
-- `client_projects` dan `client_helpdesk` SENGAJA dikecualikan: sesi client yang
-- memegangnya, bukan role admin.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.id, p.id
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(REPLACE(TRIM(r.name), ' ', '-')) = 'super-admin'
   AND p.module IN ('project_portfolio', 'project_phases', 'project_approval',
                    'project_categories', 'project_templates', 'project_notifications',
                    'project_milestones', 'project_tasks', 'project_schedule',
                    'project_timesheets', 'project_quality', 'project_changes',
                    'project_reports', 'project_resources', 'project_procurement',
                    'project_documents', 'project_client_approvals')

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan: 22 modul admin campur 2 modul client = 24 baris.
-- Setiap modul admin mesti ada grants = actions. `project_chat` mesti menunjukkan
-- actions = 3 sekarang, bukan 4 — `publish` sudah berpindah.
-- `client_projects` dan `client_helpdesk` mesti grants = 0.
SELECT p.module, COUNT(*) AS actions,
       SUM((SELECT COUNT(*) FROM `role_permissions` rp WHERE rp.permission_id = p.id)) AS grants
  FROM `permissions` p
 WHERE p.module LIKE 'project%' OR p.module LIKE 'client_%'
 GROUP BY p.module
 ORDER BY p.module
