-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — kebenaran, DIDAHULUKAN sebelum sidebar menamakannya
--
-- Spec: .kiro/specs/project-management/  (Task 1)
--
-- ── MENGAPA FAIL INI MESTI DIJALANKAN DAHULU ──
--
-- `leafVisible()` dalam AdminSidebar.tsx memanggil `has(leaf.perm)`, dan `has`
-- hanyalah carian dalam senarai kebenaran yang telah diberikan kepada sesi itu.
-- Nama yang TIADA baris dalam `permissions` tidak mungkin pernah diberikan kepada
-- sesiapa — jadi ia menilai false untuk SEMUA orang, termasuk Super Admin.
--
-- Akibatnya bukan ralat. Entri itu langsung tidak render, `visibleNav()` kemudian
-- membuang kumpulan yang anaknya habis, dan seksyen Project Management hilang
-- sepenuhnya seolah-olah keluaran itu tidak masuk. Tiada log, tiada mesej.
--
-- `database/asset_page_permissions.sql` sudah merekod perkara yang sama untuk
-- `asset_models` dan `asset_sites`: kebenaran disemai MENDAHULUI skrinnya, sebab
-- entri `soon` pun mesti menamakan kebenaran yang wujud.
--
-- ── ENAM MODUL, BUKAN DUA PULUH SATU ──
--
-- `ConfigLayout` menerbitkan kebenaran satu tab daripada kuncinya, jadi mengikutnya
-- bulat-bulat bermakna satu modul bagi setiap tab: 14 untuk tab, campur leaf, lebih
-- 80 baris di sini dan 21 baris dalam matriks Roles.
--
-- `database/operations_business_dev.sql` sudah berhujah menentangnya — "three new
-- modules in MODULE_ORDER and MODULE_LABEL for a distinction nobody has asked for"
-- — dan presedennya ialah SATU modul sampai satu role betul-betul memerlukan
-- pecahan.
--
-- Jadi enam, dan setiap pecahan dijustifikasi oleh AUDIENS yang berbeza, bukan oleh
-- skrin yang berbeza:
--
--   projects_delivery   teras penghantaran: register + 6 tab ruang kerja
--   project_cost        kewangan. Penyelia tapak tidak sepatutnya nampak margin
--   project_risk        QA / HSE. Peranan berbeza daripada pengurus projek
--   project_chat        saluran BERHADAPAN CLIENT. Tahap kepercayaan berbeza
--   project_settings    pentadbir sistem, bukan pengurus projek
--   client_projects     sesi client di portal
--
-- ── SET TINDAKAN DIBACA DARI ENDPOINT, BUKAN DITEKA ──
--
-- Satu `_delete` yang diteka ialah kotak semak dalam matriks Roles yang tidak
-- memberi apa-apa, dan tidak dapat dibezakan daripada yang hidup. Jadi:
--
--   projects_delivery  5  GET, POST, PUT, DELETE, campur `approve` untuk tutup gate
--   project_cost       1  agregat BACA-SAHAJA. Tiada entri kewangan dibuat di sini
--   project_risk       4  GET, POST, PUT, DELETE
--   project_chat       4  GET, POST, DELETE, campur `publish` untuk terbit laporan
--   project_settings   2  GET dan PUT. Tiada apa untuk dicipta atau dibuang
--   client_projects    1  client membaca projeknya sendiri
--
-- `category` ialah 'operations', HURUF KECIL. Matriks Roles mengumpulkan mengikut
-- `permissions.category`, dan baris yang hidup dalam pangkalan data ini huruf kecil.
--
-- IDEMPOTENT. `INSERT IGNORE` pada indeks unik `name`.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/project_management_permissions.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Teras penghantaran ──
--
-- Satu modul untuk Register dan untuk ENAM daripada sembilan tab ruang kerja:
-- Overview, Scope, Schedule, Tasks, Resources, Documents. Kesemuanya dibaca dan
-- disunting oleh orang yang sama — pengurus projek dan pasukannya — jadi memecahkan
-- enam tab menjadi enam modul ialah pecahan yang tiada siapa minta.
--
-- `approve` berasingan daripada `edit` sebab ia bukan satu perbuatan yang sama:
-- `edit` membetulkan tarikh, `approve` MENUTUP GATE FASA dan memindahkan projek dari
-- satu fasa ke fasa berikutnya. Melipat approve ke dalam edit bermakna sesiapa yang
-- boleh membetulkan tarikh boleh juga mengisytiharkan projek itu selesai.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('projects_delivery', 'view',    'projects_delivery_view',    'View the project register and project workspace', 'operations'),
  ('projects_delivery', 'create',  'projects_delivery_create',  'Create a project',                               'operations'),
  ('projects_delivery', 'edit',    'projects_delivery_edit',    'Update a project, its scope and its tasks',       'operations'),
  ('projects_delivery', 'delete',  'projects_delivery_delete',  'Delete a project',                               'operations'),
  ('projects_delivery', 'approve', 'projects_delivery_approve', 'Close a project phase gate',                     'operations')

-- >>>
-- ── Kos: satu tindakan, dan itu memang cukup ──
--
-- Tab Cost tidak mencipta apa-apa rekod kewangan. Ia agregat BACA-SAHAJA ke atas
-- invois belian, invois jualan dan jurnal yang sudah dimiliki oleh modul
-- perakaunan. Jadi tiada `create`, `edit` atau `delete` untuk diberikan — dan
-- menyemaikannya akan menjadi tiga kotak semak yang tidak memberi apa-apa.
--
-- Berasingan daripada `projects_delivery` sebab audiensnya berbeza: seorang
-- penyelia tapak perlu melihat tugasan tanpa melihat margin.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_cost', 'view', 'project_cost_view', 'View project budget and actual cost', 'operations')

-- >>>
-- ── Risiko dan kualiti ──
--
-- Satu modul untuk tab Risk & Quality dan untuk tab Risk Log merentas projek. QA
-- dan HSE ialah peranan yang berbeza daripada pengurus projek, dan ia sebab yang
-- sah untuk memecahkan.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_risk', 'view',   'project_risk_view',   'View the project risk register and quality records', 'operations'),
  ('project_risk', 'create', 'project_risk_create', 'Raise a risk or a quality record',                   'operations'),
  ('project_risk', 'edit',   'project_risk_edit',   'Update a risk, its mitigation or a quality record',  'operations'),
  ('project_risk', 'delete', 'project_risk_delete', 'Delete a risk or a quality record',                  'operations')

-- >>>
-- ── Chat: berasingan sebab ia BERHADAPAN CLIENT ──
--
-- Ini satu-satunya modul yang menulis teks yang dibaca oleh orang di luar syarikat.
-- Itu tahap kepercayaan yang berbeza daripada menyunting tarikh dalam satu register,
-- dan sebab itu ia modulnya sendiri.
--
-- `delete` berasingan sebab membuang mesej daripada satu perbualan yang client sudah
-- baca bukan pembetulan, ia penulisan semula rekod.
--
-- `publish` ialah menerbitkan laporan kemajuan supaya client nampak. Ia BUKAN
-- `create`: mengarang laporan dalaman dan mengeluarkannya kepada pihak luar ialah
-- dua keputusan.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_chat', 'view',    'project_chat_view',    'Read project conversations with a client',  'operations'),
  ('project_chat', 'create',  'project_chat_create',  'Post a message into a project conversation','operations'),
  ('project_chat', 'delete',  'project_chat_delete',  'Delete a message from a conversation',      'operations'),
  ('project_chat', 'publish', 'project_chat_publish', 'Publish a progress report to the client',   'operations')

-- >>>
-- ── Settings: dua tindakan untuk lima tab ──
--
-- Kelima-lima tab Settings — Phases & Gates, Categories, WBS Templates, Numbering,
-- Notifications — dikongsi satu modul. Kesemuanya data induk yang disunting oleh
-- pentadbir sistem, bukan oleh pengurus projek, dan tiada seorang pun akan diberi
-- satu tab tanpa yang lain.
--
-- Tiada `create` atau `delete`: satu tab settings menulis baris yang migration sudah
-- INSERT, jadi tiada apa untuk dicipta dan tiada apa untuk dibuang.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('project_settings', 'view', 'project_settings_view', 'View project management settings',   'operations'),
  ('project_settings', 'edit', 'project_settings_edit', 'Change project management settings', 'operations')

-- >>>
-- ── Portal client ──
--
-- Ini membetulkan kecacatan yang ada, bukan sekadar menambah satu baris.
--
-- `src/app/(auth)/auth/[hash]/page.tsx` menetapkan kebenaran sesi client sebagai
-- array yang DITULIS KERAS — `['client_helpdesk_view']` — dengan komen yang berkata
-- client tiada kebenaran admin tradisional. Itu bertahan selagi client ada satu
-- skrin sahaja. Dengan skrin kedua ia tidak lagi bertahan: dua string keras ialah
-- dua tempat untuk terlupa.
--
-- Jadi kedua-dua nama disemai sebagai baris sebenar, dan shell membacanya daripada
-- pangkalan data seperti sesi admin. `client_helpdesk` disemai di sini kerana tiada
-- migration lain pernah menyemainya — nama itu hanya wujud dalam JavaScript sampai
-- sekarang.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('client_projects', 'view', 'client_projects_view', 'A client reads their own projects',      'operations'),
  ('client_helpdesk', 'view', 'client_helpdesk_view', 'A client reads their own support tickets','operations')

-- >>>
-- ── Berikan kepada super-admin, dan kepada tiada role lain ──
--
-- `client_projects` dan `client_helpdesk` SENGAJA tidak termasuk. Kedua-duanya
-- dipegang oleh sesi client, bukan oleh role admin, dan memberikannya kepada Super
-- Admin akan meletakkan dua kotak semak dalam matriks Roles yang tidak mengawal
-- apa-apa skrin admin.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.id, p.id
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(REPLACE(TRIM(r.name), ' ', '-')) = 'super-admin'
   AND p.module IN ('projects_delivery', 'project_cost', 'project_risk',
                    'project_chat', 'project_settings')

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan: TUJUH baris.
--   projects_delivery  actions=5  grants=5
--   project_cost       actions=1  grants=1
--   project_risk       actions=4  grants=4
--   project_chat       actions=4  grants=4
--   project_settings   actions=2  grants=2
--   client_projects    actions=1  grants=0   ← 0 memang betul, lihat nota di atas
--   client_helpdesk    actions=1  grants=0   ← 0 memang betul
--
-- Kalau lima yang pertama menunjukkan grants=0, role super-admin tidak dijumpai dan
-- sidebar akan kelihatan kosong walaupun kebenaran itu wujud.
SELECT p.category, p.module, COUNT(*) AS actions,
       SUM((SELECT COUNT(*) FROM `role_permissions` rp WHERE rp.permission_id = p.id)) AS grants
  FROM `permissions` p
 WHERE p.module IN ('projects_delivery', 'project_cost', 'project_risk',
                    'project_chat', 'project_settings',
                    'client_projects', 'client_helpdesk')
 GROUP BY p.category, p.module
 ORDER BY FIELD(p.module, 'projects_delivery', 'project_cost', 'project_risk',
                'project_chat', 'project_settings',
                'client_projects', 'client_helpdesk')
