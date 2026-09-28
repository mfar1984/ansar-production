-- ═══════════════════════════════════════════════════════════════════════════════
-- PROJECT MANAGEMENT — leaf Schedule merentas daftar
--
-- Spec: .kiro/specs/project-management/  (Task 33 — leaf Schedule)
-- Bergantung pada: database/project_management_schema.sql
--                  database/project_management_tasks.sql  (project_tasks, project_task_deps)
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRASI INI TIDAK MENCIPTA TABLE. IA MEMBUANG SATU KEBENARAN.
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Leaf Schedule ialah satu skrin ANALITIK atas table yang sudah ada — `projects`,
-- `project_tasks` dan `project_task_deps`. Tiada baris baharu ditulis di sana, jadi tiada
-- table baharu diperlukan. Itu menjadikannya leaf termurah yang tinggal dalam modul ini.
--
-- Apa yang ia PERLU selesaikan ialah satu kebenaran yatim.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- `project_schedule_edit` DIBUANG — kotak semak ketiga yang tidak memberi apa-apa
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Diukur pada 2026-08-21, dengan mengimbas setiap tindakan `project_*` terhadap seluruh
-- `src/` (komen dibuang dahulu, kerana satu semakan yang membaca komen bukan semakan):
--
--   modul                  tindakan disemai   tindakan disemak dalam src/
--   project_schedule       view, edit         view SAHAJA
--
-- `project_schedule_edit` tidak muncul walau sekali dalam sumber. Ia DIBERI kepada satu role.
--
-- ── DAN INILAH SEBAB IA BERBEZA DARIPADA 14 TINDAKAN YATIM YANG LAIN ──
--
-- Empat belas tindakan lain juga tidak disemak — milik `project_phases`, `project_categories`,
-- `project_templates`, `project_settings`, `project_notifications`, `project_approval` dan
-- `project_timesheets`. Kesemuanya tidak apa-apa: skrin mereka memang belum wujud, jadi memang
-- belum ada kawalan untuk menyemaknya. Itu keadaan jujur.
--
-- `project_schedule` BERBEZA. Skrinnya sudah HIDUP sejak Task 26 — tab Schedule dalam workspace
-- projek, `built: true`. Jadi ini satu tindakan yang tidak disemak atas modul yang sudah ada
-- skrin, dan itu tepat pola yang modul ini sudah betulkan DUA kali:
--
--   project_chat_publish   dibuang dalam Task 1
--   project_chat_delete    dibuang dalam Task 30
--
-- ── MENGAPA IA TIDAK DIISI DENGAN KAWALAN, DAN BUKAN DIBUANG ──
--
-- Saya pertimbangkan membina sesuatu untuk ia menggate, dan menolaknya atas ukuran:
--
--   1. `api/admin/operations/projects/[id]/schedule.ts` ialah GET SAHAJA. Ia tidak mempunyai
--      POST, PUT atau DELETE untuk digate.
--   2. Tab Schedule dalam workspace ialah satu carta. Ia menempatkan segi empat; ia tidak
--      menulis apa-apa.
--   3. Tarikh task DISUNTING melalui `project_tasks_edit`, dan kebergantungan melalui
--      `api/.../[id]/task-deps.ts` yang juga menyemak `project_tasks_edit`. Satu kebenaran
--      KEDUA atas tarikh yang sama bermakna dua jawapan kepada "bolehkah orang ini
--      mengalihkan task ini", dan dua jawapan boleh bercanggah.
--   4. Leaf merentas daftar yang ditambah oleh task ini juga baca-sahaja. Setiap baris yang
--      dipaparkannya dimiliki oleh skrin lain.
--
-- Jadi tiada apa untuk ia gate, hari ini atau dalam reka bentuk yang dirancang. Satu kebenaran
-- yang menunggu satu kawalan yang tidak akan datang ialah satu kotak semak yang seorang
-- pentadbir beri dengan niat dan tidak dapat apa-apa.
--
-- Kalau seseorang kemudian mahu menyunting jadual DARI carta — mengheret satu bar untuk
-- menukar tarikh — itu satu kaedah PUT pada endpoint schedule, dan ia menyemak
-- `project_tasks_edit`, kerana ia menulis `project_tasks`. Bukan kebenaran ini.
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Dua DELETE, yang secara semula jadi idempotent, dan satu baris pengesahan. Jalankan dua kali
-- dan baris kedua melaporkan nombor yang sama.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. Buang grant DAHULU, kemudian kebenaran itu
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Susunan itu penting. `role_permissions.permission_id` ialah foreign key kepada
-- `permissions.id`; membuang kebenaran itu dahulu akan ditolak oleh constraint, atau lebih
-- buruk, meninggalkan satu grant yang menunjuk kepada baris yang tidak wujud kalau constraint
-- itu tiada.

DELETE rp FROM `role_permissions` rp
JOIN `permissions` p ON p.id = rp.permission_id
WHERE p.name = 'project_schedule_edit';

-- >>>

DELETE FROM `permissions` WHERE `name` = 'project_schedule_edit';

-- >>>

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. PENGESAHAN — apa yang operator baca atas pelayan
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Jangkaan:  schedule_actions 1   schedule_edit 0   tasks_actions 4
--
-- Kalau `schedule_edit` bukan 0, DELETE di atas tidak berjalan dan matriks Roles masih
-- memaparkan satu kotak semak yang tidak memberi apa-apa.
--
-- Kalau `schedule_actions` bukan 1, sesuatu selain `edit` juga hilang — dan `view` ialah
-- kebenaran yang membuka leaf itu, jadi tanpanya skrin baharu tidak boleh dicapai oleh
-- sesiapa.
--
-- `tasks_actions` ada di sini sebagai kawalan: ia MESTI kekal 4. Tarikh task dimiliki oleh
-- `project_tasks_edit`, dan kalau DELETE di atas tersilap sasaran ia akan kelihatan di sini.

SELECT (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_schedule') AS schedule_actions,
       (SELECT COUNT(*) FROM `permissions` WHERE `name` = 'project_schedule_edit') AS schedule_edit,
       (SELECT COUNT(*) FROM `permissions` WHERE `module` = 'project_tasks') AS tasks_actions;
