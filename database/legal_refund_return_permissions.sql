-- ═══════════════════════════════════════════════════════════════════════════════
-- WEB TOOLS > LEGAL — two new pages: Refund Policy and Return Policy
--
-- Kedua-dua halaman ini datang bersama kedai. Sebelum kedai ada, tiada apa untuk
-- dipulangkan wangnya dan tiada apa untuk dihantar balik, jadi kedua-dua dokumen
-- tidak mempunyai subjek. Sekarang laman awam menerima bayaran kad melalui CHIP
-- dan menghantar melalui EasyParcel, jadi pembeli berhak membaca terma kedua-duanya
-- SEBELUM membayar.
--
-- Satu modul untuk setiap halaman, mengikut cara empat halaman Legal yang sedia ada
-- sudah dibuat: supaya satu role boleh menyunting Refund Policy tanpa menyunting
-- Privacy Policy.
--
-- `category` MESTI 'web_tools'. Matriks Roles mengumpulkan mengikut
-- `permissions.category`, bukan mengikut sidebar — kategori yang salah bermakna
-- halaman muncul di bawah tajuk yang salah dalam matriks, jauh daripada empat
-- halaman Legal yang lain.
--
-- IDEMPOTENT. `INSERT IGNORE` pada indeks unik `name`, jadi jalankan seberapa kali
-- pun tanpa kesan sampingan.
--
-- Jalankan di pelayan:  node scripts/run-sql.js database/legal_refund_return_permissions.sql
-- ═══════════════════════════════════════════════════════════════════════════════

-- >>>
-- ── Empat kebenaran baharu: view dan edit untuk setiap satu daripada dua halaman ──
--
-- Tanpa baris ini, entri sidebar TIDAK AKAN muncul untuk sesiapa, termasuk Super
-- Admin. `leafVisible()` dalam AdminSidebar.tsx memanggil `has(leaf.perm)`, dan
-- `has` ialah carian dalam senarai yang telah diberikan; nama yang tiada baris
-- dalam `permissions` tidak boleh diberikan kepada sesiapa, jadi ia sentiasa false.
-- Itulah sebabnya migrasi ini didahulukan sebelum sidebar dipercayai.
INSERT IGNORE INTO `permissions` (`module`, `action`, `name`, `description`, `category`) VALUES
  ('legal-refund', 'view', 'legal-refund_view', 'View the refund policy page', 'web_tools'),
  ('legal-refund', 'edit', 'legal-refund_edit', 'Edit the refund policy page', 'web_tools'),
  ('legal-return', 'view', 'legal-return_view', 'View the return policy page', 'web_tools'),
  ('legal-return', 'edit', 'legal-return_edit', 'Edit the return policy page', 'web_tools')

-- >>>
-- ── Berikan kepada super-admin, dan kepada tiada role lain ──
--
-- Bentuk yang sama seperti `operations_application_modules.sql`: padankan role
-- mengikut nama yang dinormalkan, supaya 'Super Admin' dan 'super-admin' kedua-duanya
-- dijumpai.
INSERT IGNORE INTO `role_permissions` (`role_id`, `permission_id`)
SELECT r.id, p.id
  FROM `roles` r
  CROSS JOIN `permissions` p
 WHERE LOWER(REPLACE(r.name, ' ', '-')) = 'super-admin'
   AND p.module IN ('legal-refund', 'legal-return')

-- >>>
-- ── Verifikasi ──
--
-- Jangkaan: DUA baris, setiap satu `actions` = 2. Lajur `grants` mesti 2 juga; jika
-- 0, role super-admin tidak dijumpai dan sidebar akan kelihatan kosong walaupun
-- kebenaran itu wujud.
SELECT p.category, p.module, COUNT(*) AS actions,
       SUM((SELECT COUNT(*) FROM `role_permissions` rp WHERE rp.permission_id = p.id)) AS grants
  FROM `permissions` p
 WHERE p.module IN ('legal-refund', 'legal-return')
 GROUP BY p.category, p.module
 ORDER BY p.module
