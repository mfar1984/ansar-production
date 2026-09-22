"use strict";(()=>{var a={};a.id=4479,a.ids=[4479],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},19275:(a,b,c)=>{c.d(b,{At:()=>j,Mx:()=>g});var d=c(88251),e=c(63415);async function f(a){let b=function(a){let b=(0,e.T1)(a);return"unknown"===b?null:b}(a),c={userId:null,username:"system",role:null,ip:b,portal:"admin"};try{let e="string"==typeof a.query?.hash?a.query.hash:"",f=a.headers.authorization||"",g=f.startsWith("Bearer ")?f.slice(7).trim():"",h=e||g;if(!h)return c;let i=await (0,d.P)("SELECT username, user_type FROM admin_sessions WHERE hash = ? LIMIT 1",[h]);if(!i.length)return c;let{username:j,user_type:k}=i[0],l=await (0,d.P)("SELECT id FROM admins WHERE username = ? LIMIT 1",[j]),m=l.length?l[0].id:null,n=null;if(null!==m){let a=await (0,d.P)(`SELECT r.name FROM roles r
         INNER JOIN admin_roles ar ON ar.role_id = r.id
         WHERE ar.admin_id = ? ORDER BY r.id LIMIT 1`,[m]);a.length&&(n=a[0].name)}return{userId:m,username:j,role:n,ip:b,portal:"client"===k?"client":"employee"===k?"employee":"admin"}}catch{return c}}async function g(a,b){try{let c=b.actor||(a?await f(a):null);await (0,d.P)(`INSERT INTO activity_logs
         (level, category, \`user\`, user_id, ip, \`path\`, portal, message, details)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,[b.level||"INFO",b.category||"System",c?.username||"system",c?.userId??null,c?.ip??null,b.path??null,c?.portal??null,b.message,b.details??null])}catch{}}let h=/password|passwd|token|secret|api_key|hash|receipt|payment_proof|doc_data|file_data|^doc_|_data$/i;function i(a){if(null==a)return null;try{return JSON.stringify(function(a){if(!a||"object"!=typeof a)return a;let b={};for(let[c,d]of Object.entries(a))if(!h.test(c)){if("string"==typeof d&&d.length>300){b[c]=d.slice(0,300)+"…";continue}b[c]=d}return b}(a))}catch{return null}}async function j(a,b){try{let c=b.actor||(a?await f(a):null);await (0,d.P)(`INSERT INTO audit_logs
         (action, module, \`user\`, user_id, user_role, ip, target, description, before_data, after_data)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[b.action,b.module,c?.username||"system",c?.userId??null,c?.role??null,c?.ip??null,b.target,b.description,i(b.before),i(b.after)]),await g(null,{level:["DELETE","REJECT","SUSPEND"].includes(b.action)?"WARN":"INFO",category:b.module,message:b.description,details:b.target,actor:c||void 0})}catch{}}},21674:(a,b,c)=>{c.d(b,{k:()=>e});let d=`
  SELECT o.asset_id, o.ends_on
    FROM asset_obligations o
  UNION ALL
  SELECT ai.id AS asset_id,
         DATE_ADD(ti.handover_date, INTERVAL ti.dlp_months MONTH) AS ends_on
    FROM assets ai
    JOIN tenders ti ON ti.id = ai.tender_id
   WHERE ti.handover_date IS NOT NULL
     AND ti.dlp_months IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM asset_obligations od
                      WHERE od.asset_id = ai.id AND od.kind = 'dlp')`;function e(a,b){return`(SELECT MAX(${b}.ends_on) FROM (${d}) ${b}
            WHERE ${b}.asset_id = ${a}.id)`}},51906:(a,b,c)=>{c.d(b,{Hy:()=>g,Pi:()=>f,kl:()=>e});var d=c(77598);let e="0123456789ABCDEFGHJKLMNPQRSTUVWXYZ";function f(){let a=256-256%e.length,b="",c=(0,d.randomBytes)(24),f=0;for(;b.length<12;){f>=c.length&&(c=(0,d.randomBytes)(24),f=0);let g=c[f];f+=1,g>=a||(b+=e[g%e.length])}return b}function g(a){return a.trim().toUpperCase().replace(/O/g,"0").replace(/I/g,"1")}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},77598:a=>{a.exports=require("node:crypto")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},92102:(a,b,c)=>{c.d(b,{HT:()=>m,MD:()=>o,Nr:()=>i,fp:()=>g,g:()=>k,n0:()=>n,v3:()=>h,yU:()=>l,yk:()=>p});var d=c(88251),e=c(96543),f=c(95514);async function g(a,b,c,e=d.P){let f=new Date().getFullYear(),h=`${c}-${f}-%`,i=await e(`SELECT \`${b}\` AS ref FROM \`${a}\`
      WHERE \`${b}\` LIKE ?
      ORDER BY LENGTH(\`${b}\`) DESC, \`${b}\` DESC
      LIMIT 1`,[h]),j=1;if(i.length>0){let a=Number(String(i[0].ref).split("-").pop()||"0");Number.isFinite(a)&&(j=a+1)}return`${c}-${f}-${String(j).padStart(4,"0")}`}async function h(){return await (0,d.P)(`SELECT a.id, a.application_no, a.company_name, a.ssm_number, a.services,
            a.email, a.office_phone, a.mobile_phone, a.director_name,
            a.business_address, a.city, a.state, a.cidb_grade, a.bumiputera_status,
            DATE_FORMAT(a.approval_date, '%Y-%m-%d') AS approval_date
       FROM procurement_applications a
      WHERE a.status = 'approved'
        AND NOT EXISTS (SELECT 1 FROM vendors v WHERE v.application_id = a.id)
      ORDER BY a.company_name ASC`)}async function i(){return await (0,d.P)(`SELECT p.id, p.reference_no, p.company, p.ssm, p.industry, p.state, p.country,
            p.contact_name, p.position, p.email, p.phone, p.website, p.expected_revenue,
            DATE_FORMAT(p.reviewed_at, '%Y-%m-%d') AS reviewed_at
       FROM partner_applications p
      WHERE p.status = 'approved'
        AND NOT EXISTS (SELECT 1 FROM business_clients c WHERE c.application_id = p.id)
      ORDER BY p.company ASC`)}async function j(){return(await (0,d.P)(`SELECT name FROM asset_repair_categories
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)).map(a=>a.name)}async function k(){return await (0,d.P)(`SELECT name, icon, expects_next_due FROM asset_repair_categories
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)}async function l(a){let b=String(a??"").trim(),c=await j(),d=c.find(a=>a===b);if(d)return d;let e=c.find(a=>a.toLowerCase()===b.toLowerCase());return e||c.find(a=>"Corrective"===a)||c[0]||"Corrective"}function m(a){let b=(0,e.gx)(a.plate_no,20),c=(0,e.gx)(a.chassis_no,40),d=(0,e.gx)(a.engine_no,40),g=String(a.fuel_type??"").trim().toLowerCase();return{plate_no:b?b.toUpperCase().replace(/\s+/g," "):null,chassis_no:c?c.toUpperCase().replace(/\s+/g,""):null,engine_no:d?d.toUpperCase().replace(/\s+/g,""):null,fuel_type:f.Q.includes(g)?g:null,colour:(0,e.gx)(a.colour,40),registered_on:(0,e._$)(a.registered_on),road_tax_until:(0,e._$)(a.road_tax_until)}}function n(a){return f.Dx.some(b=>null!==a[b])}async function o(a,b,c){return n(b)?0===(await (0,d.P)("SELECT asset_id FROM asset_vehicles WHERE asset_id = ? LIMIT 1",[a])).length?void await (0,d.P)(`INSERT INTO asset_vehicles
         (asset_id, plate_no, chassis_no, engine_no, fuel_type, colour, registered_on,
          road_tax_until, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,[a,b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,c]):void await (0,d.P)(`UPDATE asset_vehicles
        SET plate_no = ?, chassis_no = ?, engine_no = ?, fuel_type = ?, colour = ?,
            registered_on = ?, road_tax_until = ?
      WHERE asset_id = ?`,[b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,a]):void await (0,d.P)("DELETE FROM asset_vehicles WHERE asset_id = ?",[a])}function p(a){if(a?.code!=="ER_DUP_ENTRY")return null;let b=String(a?.message||"");for(let[a,c]of Object.entries(f.MY))if(b.includes(a))return`Another asset in the register already has that ${c}. Two assets cannot be the same vehicle, so check whether this one is already recorded.`;return"Another asset in the register already has one of those vehicle numbers."}},96543:(a,b,c)=>{function d(a){if(null==a||""===a)return null;let b=Number(String(a).replace(/,/g,"").trim());return Number.isFinite(b)?b:null}function e(a){if(null==a||""===a)return null;let b=String(a).trim().slice(0,10);return/^\d{4}-\d{2}-\d{2}$/.test(b)?b:null}function f(a,b){if(null==a)return null;let c=String(a).trim();return""===c?null:c.slice(0,b)}function g(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>0?b:null}function h(a,b,c){let d=String(a??"").trim().toLowerCase();return b.includes(d)?d:c}function i(a){let b=a.replace(/\\/g,"\\\\").replace(/%/g,"\\%").replace(/_/g,"\\_");return`%${b}%`}c.d(b,{AR:()=>i,Bq:()=>t,Mw:()=>l,N6:()=>o,O1:()=>s,Ov:()=>z,TG:()=>d,Z$:()=>r,_$:()=>e,aI:()=>y,af:()=>u,cM:()=>w,fk:()=>g,gx:()=>f,i9:()=>n,iv:()=>x,jI:()=>v,jT:()=>p,ni:()=>j,qB:()=>q,yH:()=>k,yL:()=>h,zN:()=>m});let j=["draft","in_progress","submitted","evaluation","awarded","unsuccessful","closed"],k=["government","private"],l=["open","selective","quotation","direct"],m=["technical","financial","both"],n=["pending","in_progress","completed"],o=["active","completed"],p=["unsuccessful","cancelled","expired"],q=["active","inactive","blacklisted"],r=["company","marketplace"],s=["registration_no","category","cidb_grade","bumiputera","rating"],t=["prospect","active","inactive"],u=["government","education","healthcare","private","local_government","other"],v=["new","contacted","qualified","proposal","negotiation","won","lost"],w=["referral","cold_call","website","event","tender","other"],x=["draft","sent","accepted","rejected","expired"];function y(a){if(!a)return"open";let b=new Date(a);if(Number.isNaN(b.getTime()))return"open";let c=new Date;c.setHours(0,0,0,0),b.setHours(0,0,0,0);let d=Math.round((b.getTime()-c.getTime())/864e5);return d<0?"closed":d<=7?"closing":"open"}function z(a){return!a||a<=0?"":a<1024?`${a} B`:a<1048576?`${Math.round(a/1024)} KB`:`${(a/1048576).toFixed(1)} MB`}},99558:(a,b,c)=>{c.r(b),c.d(b,{config:()=>x,default:()=>w,handler:()=>z});var d={};c.r(d),c.d(d,{default:()=>r});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19275),l=c(96543),m=c(92102),n=c(51906),o=c(21674),p=c(95514);let q={internal:"assets_internal",external:"assets_external"};async function r(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=String(a.query.holder||"").trim();if(!p.F7.includes(d))return b.status(400).json({success:!1,error:"A register must be named: holder=internal or holder=external."});let e=q[d];try{if("GET"===a.method){if(!(0,j.OD)(c,b,e,"view"))return;if("1"===String(a.query.options||"")){let[a,c,d,e,f,g,h,j,k,l,n]=await Promise.all([(0,i.P)(`SELECT c.id, c.name, c.parent_id, p.name AS parent_name,
                    c.asset_class, c.icon, c.default_loanable,
                    COALESCE(c.useful_life_years, p.useful_life_years)        AS useful_life_years,
                    COALESCE(NULLIF(c.detail_form, 'none'), p.detail_form, 'none') AS detail_form
               FROM asset_categories c
               LEFT JOIN asset_categories p ON p.id = c.parent_id
              WHERE c.is_active = 1
              ORDER BY COALESCE(p.sort_order, c.sort_order) ASC,
                       COALESCE(p.name, c.name) ASC,
                       c.parent_id IS NOT NULL ASC,
                       c.name ASC`),(0,i.P)(`SELECT id, employee_id, full_name, department_id FROM employees
              WHERE status = 'active' ORDER BY full_name ASC`),(0,i.P)("SELECT id, name FROM departments ORDER BY name ASC"),(0,i.P)(`SELECT id, company_name, contact_person FROM client_users
              WHERE status = 'active' ORDER BY company_name ASC`),(0,i.P)(`SELECT id, title, client, year FROM projects
              ORDER BY year DESC, title ASC LIMIT 300`),(0,i.P)(`SELECT id, vendor_no, name, kind, platform FROM vendors
              WHERE status = 'active' ORDER BY name ASC`),(0,i.P)(`SELECT id, ref_no, title, contract_no,
                    DATE_FORMAT(handover_date, '%Y-%m-%d') AS handover_date, dlp_months
               FROM tenders
              WHERE stage IN ('awarded', 'closed')
              ORDER BY award_date DESC, id DESC LIMIT 300`),(0,i.P)(`SELECT id, client_id, name FROM asset_sites
              WHERE is_active = 1 ORDER BY name ASC`),(0,i.P)(`SELECT id, brand, model_name, category,
                    default_useful_life_years, default_warranty_months
               FROM asset_models
              WHERE is_active = 1 ORDER BY brand ASC, model_name ASC`),(0,i.P)(`SELECT id, name FROM asset_locations
              WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`),(0,m.g)()]);return b.status(200).json({success:!0,categories:a,employees:c,departments:d,clients:e,projects:f,vendors:g,tenders:h,sites:j,models:k,locations:l,repair_categories:n})}let f=["a.holder = ?"],g=[d],h=String(a.query.status||"").trim();if(h&&"all"!==h){if(!p.aN.includes(h))return b.status(400).json({success:!1,error:"Unknown status filter."});f.push("a.status = ?"),g.push(h)}let k=(0,l.gx)(a.query.category,80);k&&(f.push(`(a.category = ? OR a.category IN (
              SELECT c.name FROM asset_categories c
                JOIN asset_categories p ON p.id = c.parent_id
               WHERE p.name = ?))`),g.push(k,k));let n=(0,l.gx)(a.query.asset_class,20);if(n){if(!p.Aj.includes(n))return b.status(400).json({success:!1,error:"Unknown kind filter."});f.push("a.asset_class = ?"),g.push(n)}"1"===String(a.query.needs_label||"")&&f.push("(a.serial_no IS NULL OR a.serial_no = '') AND (a.tag_no IS NULL OR a.tag_no = '') AND a.label_printed_at IS NULL");let q="1"===String(a.query.all||"");if(q&&!(0,j.OD)(c,b,e,"export"))return;let r=Number(a.query.per_page),s=q?5e3:Number.isFinite(r)?Math.min(100,Math.max(1,Math.trunc(r))):100,t=Number(a.query.page),u=q||!Number.isFinite(t)?1:Math.max(1,Math.trunc(t)),v=(u-1)*s,w=String(a.query.q||"").trim();if(w){let a=(0,l.AR)(w);f.push("(a.asset_no LIKE ? ESCAPE '\\\\' OR a.name LIKE ? ESCAPE '\\\\' OR a.serial_no LIKE ? ESCAPE '\\\\' OR a.tag_no LIKE ? ESCAPE '\\\\' OR a.brand LIKE ? ESCAPE '\\\\' OR a.model LIKE ? ESCAPE '\\\\' OR e.full_name LIKE ? ESCAPE '\\\\' OR c.company_name LIKE ? ESCAPE '\\\\' OR EXISTS (SELECT 1 FROM asset_uid_map m WHERE m.asset_id = a.id AND m.old_asset_no LIKE ? ESCAPE '\\\\'))"),g.push(a,a,a,a,a,a,a,a,a)}let x=await (0,i.P)(`SELECT a.id, a.asset_no, a.holder, a.name, a.category, a.brand, a.model,
                a.serial_no, a.tag_no, a.status, a.condition_note, a.photo_path,
                -- DATE_FORMAT for the same reason every other date on this row carries it: mysql2
                -- hands back a DATETIME as a JS Date, and JSON serialises that as UTC, which is the
                -- previous day east of Greenwich for anything before 08:00.
                DATE_FORMAT(a.label_printed_at, '%Y-%m-%d %H:%i')                   AS label_printed_at,
                a.purchase_cost, a.useful_life_years,
                DATE_FORMAT(a.purchase_date, '%Y-%m-%d')  AS purchase_date,
                DATE_FORMAT(a.installed_on, '%Y-%m-%d')   AS installed_on,
                -- On the LIST and not only on the detail payload, and this is load-bearing rather
                -- than convenience. openEdit(row, source?) in the register reads "source || row",
                -- so the edit form can be opened straight from a list row with no detail fetch.
                -- Its text('pic_name') would then read undefined, render blank, and the next save
                -- would write NULL over a PIC nobody had touched -- no error, nothing to notice.
                -- The detail payload selects a.* and already carries both, which is exactly why
                -- this gap would not have shown up in testing through the popup.
                --
                -- SQL comments, not a JS block comment: this is inside a template literal, and a
                -- backtick in prose terminates the string. That mistake was made here once and tsc
                -- reported it as seven unrelated syntax errors on the following lines.
                a.pic_name, a.pic_position,
                a.ownership,
                -- Cover, derived. warranty_until and contract_until were columns holding one
                -- date each; a unit can sit inside a manufacturer warranty AND a DLP AND a
                -- service contract at once, so cover is the LATEST end date across all of them.
                -- Reporting the earliest would have somebody quote a client for work that is
                -- already covered.
                --
                -- The expression, including the DLP inherited from the tender and the override
                -- rule that suppresses it, lives in @/lib/asset-cover-sql. It is written there as
                -- an UNCORRELATED derived table filtered from the outside, because MariaDB
                -- refuses a derived table that reaches outward for the alias a, and production
                -- runs MariaDB. Read that file before changing the shape of this.
                --
                -- DATE_FORMAT, not the bare column. mysql2 returns a DATE as a JS Date at LOCAL
                -- midnight, which JSON serialises as a UTC timestamp -- east of UTC that is 16:00
                -- the PREVIOUS day. Without this the cell printed
                -- "2026-08-09T16:00:00.000Z" for a date of 2026-08-10.
                DATE_FORMAT(${(0,o.k)("a","cu")}, '%Y-%m-%d')              AS cover_until,
                (SELECT COUNT(*) FROM asset_obligations o WHERE o.asset_id = a.id) AS obligation_count,
                -- The MANUFACTURER WARRANTY end date on its own, which cover_until above is NOT:
                -- that one is MAX across every kind, so a unit on a service contract to December
                -- reports December there. The BULK EDIT grid pre-fills a Warranty Until cell from
                -- this, and pre-filling it from cover_until would show a service contract date in a
                -- warranty field and then save it back as the warranty.
                --
                -- MAX here too, because nothing stops a unit holding two warranty rows and the
                -- cover resolver takes the longer of them. This has to agree with what it shows.
                --
                -- NO BACKTICKS ANYWHERE IN THIS COMMENT. The whole statement is a template literal,
                -- because assetCoverUntil is interpolated into it a few lines up. A backtick used to
                -- quote a column name in prose CLOSES the template, and tsc then reports three
                -- unrelated "',' expected" errors on the following lines.
                DATE_FORMAT((SELECT MAX(w.ends_on) FROM asset_obligations w
                              WHERE w.asset_id = a.id AND w.kind = 'warranty'),
                            '%Y-%m-%d')                                        AS warranty_until,
                a.asset_class,
                -- On the LIST because the BULK EDIT grid pre-fills every cell from the list row.
                -- A column the grid renders but cannot pre-fill would show blank, and blank means
                -- "clear it" in that payload -- so saving would wipe the invoice number on every
                -- row in the selection. Reading it here is what makes the cell safe.
                a.invoice_no,
                a.location, a.location_id, a.site_name, a.site_id, a.tender_id,
                -- The SITE the unit is installed at, as master data. The site_name column above
                -- is the old free-text field and stays for the room or rack within a site.
                st.name AS site_label,
                t.ref_no      AS tender_ref,
                t.contract_no AS tender_contract_no,
                a.employee_id, a.department_id, a.client_id, a.project_id, a.vendor_id,
                e.full_name   AS employee_name,
                e.employee_id AS employee_code,
                d.name        AS department_name,
                c.company_name AS client_company,
                p.title       AS project_title,
                v.name        AS vendor_name,
                -- The platform travels with the name, because a marketplace seller's name alone
                -- does not say where the purchase was made.
                v.kind        AS vendor_kind,
                v.platform    AS vendor_platform,
                (SELECT COUNT(*) FROM asset_maintenance m WHERE m.asset_id = a.id) AS service_count,
                (SELECT DATE_FORMAT(MIN(m.next_due), '%Y-%m-%d') FROM asset_maintenance m
                  WHERE m.asset_id = a.id AND m.next_due IS NOT NULL
                    AND m.next_due >= CURDATE())                                   AS next_service,
                (SELECT COUNT(*) FROM helpdesk_tickets t WHERE t.asset_id = a.id)  AS ticket_count
           FROM assets a
           LEFT JOIN employees    e ON e.id = a.employee_id
           LEFT JOIN departments  d ON d.id = a.department_id
           LEFT JOIN client_users c ON c.id = a.client_id
           LEFT JOIN projects     p ON p.id = a.project_id
           LEFT JOIN vendors      v ON v.id = a.vendor_id
           LEFT JOIN tenders      t ON t.id = a.tender_id
           LEFT JOIN asset_sites st ON st.id = a.site_id
          WHERE ${f.join(" AND ")}
          ORDER BY a.id DESC
          LIMIT ${s} OFFSET ${v}`,g),y=await (0,i.P)(`SELECT COUNT(*) AS n
           FROM assets a
           LEFT JOIN employees    e ON e.id = a.employee_id
           LEFT JOIN client_users c ON c.id = a.client_id
          WHERE ${f.join(" AND ")}`,g),z=Number(y[0]?.n||0),A=await (0,i.P)("SELECT status, COUNT(*) AS n FROM assets WHERE holder = ? GROUP BY status",[d]),B={};for(let a of p.aN)B[a]=0;let C=0;for(let a of A)B[a.status]=Number(a.n),C+=Number(a.n);let D=p.jS.map(()=>"?").join(", "),E=await (0,i.P)(`SELECT COALESCE(SUM(purchase_cost), 0) AS cost, COUNT(*) AS n
           FROM assets
          WHERE holder = ? AND ownership = 'ansar'
            AND status NOT IN (${D}) AND purchase_cost IS NOT NULL`,[d,...p.jS]),F=await (0,i.P)(`SELECT COUNT(*) AS n FROM assets
          WHERE holder = ? AND ownership = 'client' AND status NOT IN (${D})`,[d,...p.jS]),G=await (0,i.P)(`SELECT
           SUM(c.cover_until IS NOT NULL AND c.cover_until < CURDATE())              AS expired,
           SUM(c.cover_until IS NOT NULL AND c.cover_until >= CURDATE()
               AND c.cover_until <= DATE_ADD(CURDATE(), INTERVAL 30 DAY))            AS expiring,
           SUM(c.cover_until IS NULL)                                               AS uncovered
         FROM (
           SELECT a.id,
                  ${(0,o.k)("a","cs")}                                     AS cover_until
             FROM assets a
            WHERE a.holder = ? AND a.status NOT IN (${D})
         ) c`,[d,...p.jS]),H=await (0,i.P)(`SELECT COUNT(DISTINCT a.id) AS n
           FROM assets a
           JOIN asset_maintenance m ON m.asset_id = a.id
          WHERE a.holder = ? AND m.next_due IS NOT NULL AND m.next_due < CURDATE()`,[d]),I=await (0,i.P)(`SELECT COUNT(*) AS n FROM assets
          WHERE holder = ? AND status NOT IN (${D})
            AND (serial_no IS NULL OR serial_no = '')
            AND (tag_no IS NULL OR tag_no = '')
            AND label_printed_at IS NULL`,[d,...p.jS]);return b.status(200).json({success:!0,data:x,page:u,per_page:s,total:z,summary:{...B,total:C,in_register:Number(E[0]?.n||0),total_cost:Number(E[0]?.cost||0),client_owned:Number(F[0]?.n||0),cover_expired:Number(G[0]?.expired||0),cover_expiring:Number(G[0]?.expiring||0),uncovered:Number(G[0]?.uncovered||0),service_overdue:Number(H[0]?.n||0),needs_label:Number(I[0]?.n||0)}})}if("POST"===a.method){if(!(0,j.OD)(c,b,e,"create"))return;let f=(0,j.J9)(a),g=(0,l.gx)(f.name,200);if(!g)return b.status(400).json({success:!1,error:"An asset name is required."});let h=(0,l.yL)(f.status,p.aN,"in_store");if(p.W9.includes(h)&&!(0,j.OD)(c,b,e,"dispose"))return;let o="ansar";if("external"===d){let a=String(f.ownership||"").trim();if(!p.v9.includes(a))return b.status(400).json({success:!1,error:"Ownership is required on an installed asset: `ansar` if ANSAR still owns it (rented, or not yet handed over), `client` if it was sold to the client."});o=a}let q="internal"===d?(0,l.fk)(f.employee_id):null,r="external"===d?(0,l.fk)(f.client_id):null;if((q||r)&&!(0,j.OD)(c,b,e,"assign"))return;let u="external"===d?(0,l.fk)(f.site_id):null;if(u){let a=await (0,i.P)(`SELECT s.id, s.name, s.client_id, s.is_active, c.company_name
             FROM asset_sites s
             JOIN client_users c ON c.id = s.client_id
            WHERE s.id = ? LIMIT 1`,[u]);if(0===a.length)return b.status(400).json({success:!1,error:"That site no longer exists."});let c=a[0];if(!r||Number(c.client_id)!==r)return b.status(400).json({success:!1,error:`"${c.name}" belongs to ${c.company_name}. Choose a site belonging to this asset's client, or set the client first.`});if(1!==c.is_active)return b.status(400).json({success:!1,error:`"${c.name}" is inactive and cannot take new equipment. Reactivate it, or choose another site.`})}let v=(0,l.fk)(f.model_id),w=null;if(v){let a=await (0,i.P)(`SELECT brand, model_name, category, default_useful_life_years, default_warranty_months
             FROM asset_models WHERE id = ? LIMIT 1`,[v]);if(0===a.length)return b.status(400).json({success:!1,error:"That model no longer exists."});w=a[0]}for(let[a,c,e]of[[q,"employees","That employee no longer exists."],["internal"===d?(0,l.fk)(f.department_id):null,"departments","That department no longer exists."],[r,"client_users","That client no longer exists."],["external"===d?(0,l.fk)(f.project_id):null,"projects","That project no longer exists."],[(0,l.fk)(f.vendor_id),"vendors","That vendor no longer exists."],["external"===d?(0,l.fk)(f.tender_id):null,"tenders","That tender no longer exists."]]){if(!a)continue;let d=await (0,i.P)(`SELECT id FROM \`${c}\` WHERE id = ? LIMIT 1`,[a]);if(0===d.length)return b.status(400).json({success:!1,error:e})}let x=(0,l.gx)(f.category,80)||w?.category||null,y="internal"===d?(0,l.fk)(f.location_id):null,z=null;if(y){let a=await (0,i.P)("SELECT name FROM asset_locations WHERE id = ? LIMIT 1",[y]);if(0===a.length)return b.status(400).json({success:!1,error:"That location no longer exists."});z=a[0].name}let A=null;x&&(A=(await (0,i.P)("SELECT default_loanable, asset_class FROM asset_categories WHERE name = ? LIMIT 1",[x]))[0]??null);let B=0;"internal"===d&&(B=void 0!==f.is_loanable?+!!f.is_loanable:+(1===Number(A?.default_loanable)));let C=p.Aj.includes(String(f.asset_class??""))?String(f.asset_class):A?.asset_class??"movable",D={name:g,category:x,asset_class:C,brand:(0,l.gx)(f.brand,120)||w?.brand||null,model:(0,l.gx)(f.model,120)||w?.model_name||null,serial_no:(0,l.gx)(f.serial_no,120),tag_no:(0,l.gx)(f.tag_no,60),description:(0,l.gx)(f.description,65535),purchase_date:(0,l._$)(f.purchase_date),purchase_cost:(0,l.TG)(f.purchase_cost),useful_life_years:s(f.useful_life_years)??s(w?.default_useful_life_years),vendor_id:(0,l.fk)(f.vendor_id),tender_id:"external"===d?(0,l.fk)(f.tender_id):null,invoice_no:(0,l.gx)(f.invoice_no,80),employee_id:q,department_id:"internal"===d?(0,l.fk)(f.department_id):null,location:"internal"===d?z??(0,l.gx)(f.location,200):null,location_id:y,client_id:r,project_id:"external"===d?(0,l.fk)(f.project_id):null,site_id:u,site_name:"external"===d?(0,l.gx)(f.site_name,200):null,site_address:"external"===d?(0,l.gx)(f.site_address,400):null,installed_on:"external"===d?(0,l._$)(f.installed_on):null,pic_name:"external"===d?(0,l.gx)(f.pic_name,150):null,pic_position:"external"===d?(0,l.gx)(f.pic_position,150):null,status:h,condition_note:(0,l.gx)(f.condition_note,400),notes:(0,l.gx)(f.notes,65535)},E=0,F="";for(let a=0;a<5;a++){F=(0,n.Pi)();try{E=(await (0,i.P)(`INSERT INTO assets
               (asset_no, holder, ownership, name, category, asset_class, brand, model, serial_no,
                tag_no,
                description, purchase_date, purchase_cost, useful_life_years, vendor_id,
                tender_id, invoice_no, employee_id, department_id, location, location_id,
                client_id, site_id, project_id, site_name, site_address, installed_on,
                pic_name, pic_position,
                status, condition_note, notes, is_loanable, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                     ?, ?, ?, ?, ?, ?, ?, ?)`,[F,d,o,D.name,D.category,D.asset_class,D.brand,D.model,D.serial_no,D.tag_no,D.description,D.purchase_date,D.purchase_cost,D.useful_life_years,D.vendor_id,D.tender_id,D.invoice_no,D.employee_id,D.department_id,D.location,D.location_id,D.client_id,D.site_id,D.project_id,D.site_name,D.site_address,D.installed_on,D.pic_name,D.pic_position,D.status,D.condition_note,D.notes,B,c.username])).insertId;break}catch(a){if("ER_DUP_ENTRY"===a.code)continue;throw a}}if(!E)return b.status(503).json({success:!1,error:"Could not allocate an asset number. Please try again."});let G=(0,m.HT)(f);if((0,m.n0)(G))try{await (0,m.MD)(E,G,c.username)}catch(c){let a=(0,m.yk)(c);if(!a)throw c;return await (0,i.P)("DELETE FROM assets WHERE id = ?",[E]),b.status(400).json({success:!1,error:a})}await (0,i.P)(`INSERT INTO asset_movements
           (asset_id, movement, moved_on, from_holder, to_holder, remarks, recorded_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,[E,q?"assigned":r?"deployed":"transferred",D.purchase_date||(0,p.r9)(),D.vendor_id?"Vendor":"Recorded into the register",await t(d,q,r,D.location,D.site_name),"Opening entry.",c.username]);let H="";if(w?.default_warranty_months){let a=D.installed_on||D.purchase_date,b=(0,p.wd)(a,w.default_warranty_months);b&&(await (0,i.P)(`INSERT INTO asset_obligations
               (asset_id, kind, starts_on, ends_on, reference, notes, created_by)
             VALUES (?, 'warranty', ?, ?, ?, ?, ?)`,[E,a,b,null,`${w.default_warranty_months}-month default for ${w.brand} ${w.model_name}.`,c.username]),H=` Warranty recorded to ${b} from the model default.`)}return await (0,k.At)(a,{action:"CREATE",module:"internal"===d?"Assets: Internal":"Assets: External",target:`Asset: ${F}`,description:`Asset "${g}" recorded as ${h}`,after:{asset_no:F,name:g,holder:d,status:h}}),b.status(201).json({success:!0,id:E,asset_no:F,message:`${g} recorded as ${F}.${H}`})}return b.setHeader("Allow","GET, POST"),b.status(405).json({success:!1,error:"Method not allowed"})}catch(a){return console.error("Assets error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the asset register"})}}function s(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>=1&&b<=50?b:null}async function t(a,b,c,d,e){if(b){let a=await (0,i.P)("SELECT full_name FROM employees WHERE id = ? LIMIT 1",[b]);return a[0]?.full_name||"An employee"}if(c){let a=await (0,i.P)("SELECT company_name FROM client_users WHERE id = ? LIMIT 1",[c]),b=a[0]?.company_name||"A client";return e?`${b} — ${e}`:b}return d||("internal"===a?"Store":"Not yet deployed")}var u=c(58112),v=c(18766);let w=(0,h.M)(d,"default"),x=(0,h.M)(d,"config"),y=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets",pathname:"/api/admin/operations/assets",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function z(a,b,c){let d=await y.prepare(a,b,{srcPage:"/api/admin/operations/assets"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,u.getTracer)(),e=d.getActiveScopeSpan(),j=y.instrumentationOnRequestError.bind(y),k=async e=>y.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:y.isDev,page:"/api/admin/operations/assets",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==v.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(v.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:u.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(y.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514],()=>b(b.s=99558));module.exports=c})();