"use strict";(()=>{var a={};a.id=4643,a.ids=[4643],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},11163:(a,b,c)=>{function d(a){let b=Number(a);return Number.isInteger(b)&&b>0?b:null}c.d(b,{Z7:()=>e,kC:()=>d,m6:()=>f});let e="m.batch_id = ?";function f(a,b){return`${b} — ${a}`.slice(0,200)}},57381:(a,b,c)=>{c.r(b),c.d(b,{config:()=>u,default:()=>t,handler:()=>w});var d={};c.r(d),c.d(d,{default:()=>q});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(96543),l=c(95514),m=c(92102),n=c(11163);let o={internal:"assets_internal",external:"assets_external"},p=`a.holder = ?
                AND a.status NOT IN ('disposed', 'lost')`;async function q(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=String(a.query.holder||"internal");if(!l.F7.includes(d))return b.status(400).json({success:!1,error:"Unknown register."});let e=o[d];try{if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if(!(0,j.OD)(c,b,e,"view"))return;if("1"===String(a.query.options||"")){let[a,c]=await Promise.all([(0,i.P)(`SELECT a.id, a.asset_no, a.name, a.category, a.location, a.site_name
             FROM assets a
            WHERE ${p}
            ORDER BY a.asset_no ASC`,[d]),(0,i.P)(`SELECT id, vendor_no, name FROM vendors
            WHERE status = 'active' AND kind = 'company'
            ORDER BY name ASC`)]),e=await (0,m.g)();return b.status(200).json({success:!0,assets:a,vendors:c,repair_categories:e})}let f=["a.holder = ?"],g=[d],h=async a=>(await (0,i.P)("SELECT id FROM asset_repair_categories WHERE name = ? LIMIT 1",[a])).length>0,l=(0,k.gx)(a.query.kind,60);if(l){if(!await h(l))return b.status(400).json({success:!1,error:"Unknown service kind."});f.push("m.kind = ?"),g.push(l)}let o=(0,k.gx)(a.query.state,20);"overdue"===o?f.push("m.next_due IS NOT NULL AND m.next_due < CURDATE()"):"due_30"===o?f.push("m.next_due IS NOT NULL AND m.next_due >= CURDATE() AND m.next_due <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)"):"scheduled"===o?f.push("m.next_due IS NOT NULL"):"unscheduled"===o&&f.push("m.next_due IS NULL");let q=(0,k.gx)(a.query.from,10);q&&(f.push("m.service_date >= ?"),g.push(q));let r=(0,k.gx)(a.query.to,10);r&&(f.push("m.service_date <= ?"),g.push(r));let s=(0,k.gx)(a.query.q,120);if(s){f.push("(a.asset_no LIKE ? OR a.name LIKE ? OR m.summary LIKE ? OR m.performed_by LIKE ? OR v.name LIKE ?)");let a=`%${s}%`;g.push(a,a,a,a,a)}let t=(0,n.kC)(a.query.round);if(void 0!==a.query.round&&null===t)return b.status(400).json({success:!1,error:"That round is not a valid reference."});null!==t&&(f.push(n.Z7),g.push(t));let u=`WHERE ${f.join(" AND ")}`,v=Math.max(1,Number(a.query.page)||1),w=Math.min(100,Math.max(1,Number(a.query.per_page)||100)),x=(v-1)*w,y=async()=>{let a=await (0,i.P)(`SELECT
           (SELECT COUNT(DISTINCT a2.id)
              FROM assets a2
              JOIN asset_maintenance m2 ON m2.asset_id = a2.id
             WHERE a2.holder = ? AND m2.next_due IS NOT NULL
               AND m2.next_due < CURDATE())                                    AS overdue_assets,
           (SELECT COUNT(DISTINCT a3.id)
              FROM assets a3
              JOIN asset_maintenance m3 ON m3.asset_id = a3.id
             WHERE a3.holder = ? AND m3.next_due IS NOT NULL
               AND m3.next_due >= CURDATE()
               AND m3.next_due <= DATE_ADD(CURDATE(), INTERVAL 30 DAY))        AS due_30_assets,
           (SELECT COUNT(*)
              FROM asset_maintenance m4
              JOIN assets a4 ON a4.id = m4.asset_id
             WHERE a4.holder = ? AND YEAR(m4.service_date) = YEAR(CURDATE()))  AS services_ytd,
           (SELECT COALESCE(SUM(m5.cost), 0)
              FROM asset_maintenance m5
              JOIN assets a5 ON a5.id = m5.asset_id
             WHERE a5.holder = ? AND YEAR(m5.service_date) = YEAR(CURDATE()))  AS cost_ytd,
           (SELECT COUNT(*)
              FROM asset_maintenance m6
              JOIN assets a6 ON a6.id = m6.asset_id
             WHERE a6.holder = ?)                                             AS all_records`,[d,d,d,d,d]);return{overdue_assets:Number(a[0]?.overdue_assets||0),due_30_assets:Number(a[0]?.due_30_assets||0),services_ytd:Number(a[0]?.services_ytd||0),cost_ytd:Number(a[0]?.cost_ytd||0),all_records:Number(a[0]?.all_records||0)}};if("1"===String(a.query.ids||"")){let a=await (0,i.P)(`SELECT DISTINCT m.asset_id
           FROM asset_maintenance m
           JOIN assets a       ON a.id = m.asset_id
           LEFT JOIN vendors v ON v.id = m.vendor_id
           ${u}`,g);return b.status(200).json({success:!0,asset_ids:a.map(a=>Number(a.asset_id))})}if("1"===String(a.query.group||"")){let a=await (0,i.P)(`SELECT m.batch_id,
                b.title,
                b.recorded_by                                 AS batch_by,
                DATE_FORMAT(b.created_at, '%Y-%m-%d %H:%i')   AS created_at,
                MIN(m.kind)                                   AS kind,
                COUNT(DISTINCT m.kind)                        AS kinds,
                DATE_FORMAT(MIN(m.service_date), '%Y-%m-%d')  AS service_date,
                DATE_FORMAT(MAX(m.service_date), '%Y-%m-%d')  AS service_date_max,
                COUNT(DISTINCT m.service_date)                AS dates,
                MIN(a.client_id)                              AS client_id,
                COUNT(DISTINCT a.client_id)                   AS clients,
                MAX(cu.company_name)                          AS client_name,
                COUNT(*)                                      AS records,
                COUNT(DISTINCT m.asset_id)                    AS assets,
                COUNT(DISTINCT a.site_id)                     AS sites,
                MIN(a.site_name)                              AS site_name,
                MIN(a.asset_no)                               AS first_asset_no,
                -- ── ONLY MEANINGFUL WHEN THE assets COUNT IS 1 ──
                --
                -- A round of one unit is the ordinary shape of a REPAIR, and for that row the
                -- photograph is the unit's, exactly as on every other screen. Across several units
                -- these two are MIN() over a set and can even come from DIFFERENT rows, so the screen
                -- reads them only when that count is 1. Do not use them otherwise.
                --
                -- No backticks anywhere in this comment: the whole statement is a TEMPLATE LITERAL, so
                -- one closes the string and tsc reports "',' expected" on this line.
                MIN(a.id)                                     AS first_asset_id,
                MIN(a.photo_path)                             AS first_photo_path,
                COUNT(DISTINCT m.performed_by)                AS engineers,
                MIN(m.performed_by)                           AS performed_by,
                COUNT(DISTINCT m.vendor_id)                   AS vendor_count,
                MIN(m.vendor_id)                              AS vendor_id,
                MIN(v.name)                                   AS vendor_name,
                SUM(m.cost IS NOT NULL)                       AS costed,
                SUM(m.cost)                                   AS cost_total,
                SUM(m.next_due IS NOT NULL)                   AS scheduled,
                DATE_FORMAT(MIN(m.next_due), '%Y-%m-%d')      AS next_due_min,
                DATE_FORMAT(MAX(m.next_due), '%Y-%m-%d')      AS next_due_max,
                COUNT(DISTINCT m.summary)                     AS summaries,
                MIN(m.summary)                                AS summary,
                COUNT(DISTINCT m.ticket_id)                   AS tickets,
                (SELECT COUNT(*) FROM asset_service_batch_files f
                  WHERE f.batch_id = m.batch_id)              AS files
           FROM asset_maintenance m
           JOIN assets a                 ON a.id = m.asset_id
           JOIN asset_service_batches b  ON b.id = m.batch_id
           LEFT JOIN vendors v           ON v.id = m.vendor_id
           LEFT JOIN client_users cu     ON cu.id = a.client_id
           ${u}
          GROUP BY m.batch_id, b.title, b.recorded_by, b.created_at
          ORDER BY MAX(m.service_date) DESC, m.batch_id DESC
          LIMIT ${w} OFFSET ${x}`,g),c=await (0,i.P)(`SELECT COUNT(*) AS total FROM (
           SELECT 1
             FROM asset_maintenance m
             JOIN assets a                ON a.id = m.asset_id
             JOIN asset_service_batches b ON b.id = m.batch_id
             LEFT JOIN vendors v          ON v.id = m.vendor_id
             ${u}
            GROUP BY m.batch_id
         ) g`,g),d=a.map(a=>({...a,round_key:Number(a.batch_id)}));return b.status(200).json({success:!0,data:d,page:v,per_page:w,total:Number(c[0]?.total||0),summary:await y()})}let z=await (0,i.P)(`SELECT m.id, m.asset_id, m.kind,
              -- DATE_FORMAT on every date. mysql2 returns a Date and serialising it converts to
              -- UTC, which at UTC+8 reports the previous day — a service due today would read as
              -- overdue yesterday.
              DATE_FORMAT(m.service_date, '%Y-%m-%d') AS service_date,
              DATE_FORMAT(m.next_due, '%Y-%m-%d')     AS next_due,
              m.performed_by, m.vendor_id, m.cost, m.ticket_id, m.summary, m.recorded_by,
              a.asset_no, a.name AS asset_name, a.category, a.status AS asset_status,
              -- The cover photograph. One record is one service on one unit, so this is well defined
              -- here in a way it is not on the ROUNDS list above: that one groups by batch and takes
              -- MIN(a.asset_no) across every unit in the round.
              a.photo_path,
              a.location, a.site_name,
              v.name AS vendor_name,
              t.ticket_no
         FROM asset_maintenance m
         JOIN assets a           ON a.id = m.asset_id
         LEFT JOIN vendors v     ON v.id = m.vendor_id
         LEFT JOIN helpdesk_tickets t ON t.id = m.ticket_id
         ${u}
        ORDER BY m.service_date DESC, m.id DESC
        LIMIT ${w} OFFSET ${x}`,g),A=await (0,i.P)(`SELECT COUNT(*) AS total
         FROM asset_maintenance m
         JOIN assets a       ON a.id = m.asset_id
         LEFT JOIN vendors v ON v.id = m.vendor_id
         ${u}`,g);return b.status(200).json({success:!0,data:z,page:v,per_page:w,total:Number(A[0]?.total||0),...t?{}:{summary:await y()}})}catch(a){return console.error("Asset maintenance error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load service records"})}}var r=c(58112),s=c(18766);let t=(0,h.M)(d,"default"),u=(0,h.M)(d,"config"),v=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets/maintenance",pathname:"/api/admin/operations/assets/maintenance",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function w(a,b,c){let d=await v.prepare(a,b,{srcPage:"/api/admin/operations/assets/maintenance"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,r.getTracer)(),e=d.getActiveScopeSpan(),j=v.instrumentationOnRequestError.bind(v),k=async e=>v.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:v.isDev,page:"/api/admin/operations/assets/maintenance",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==s.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(s.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:r.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(v.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},92102:(a,b,c)=>{c.d(b,{HT:()=>m,MD:()=>o,Nr:()=>i,fp:()=>g,g:()=>k,n0:()=>n,v3:()=>h,yU:()=>l,yk:()=>p});var d=c(88251),e=c(96543),f=c(95514);async function g(a,b,c,e=d.P){let f=new Date().getFullYear(),h=`${c}-${f}-%`,i=await e(`SELECT \`${b}\` AS ref FROM \`${a}\`
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
      WHERE asset_id = ?`,[b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,a]):void await (0,d.P)("DELETE FROM asset_vehicles WHERE asset_id = ?",[a])}function p(a){if(a?.code!=="ER_DUP_ENTRY")return null;let b=String(a?.message||"");for(let[a,c]of Object.entries(f.MY))if(b.includes(a))return`Another asset in the register already has that ${c}. Two assets cannot be the same vehicle, so check whether this one is already recorded.`;return"Another asset in the register already has one of those vehicle numbers."}},96543:(a,b,c)=>{function d(a){if(null==a||""===a)return null;let b=Number(String(a).replace(/,/g,"").trim());return Number.isFinite(b)?b:null}function e(a){if(null==a||""===a)return null;let b=String(a).trim().slice(0,10);return/^\d{4}-\d{2}-\d{2}$/.test(b)?b:null}function f(a,b){if(null==a)return null;let c=String(a).trim();return""===c?null:c.slice(0,b)}function g(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>0?b:null}function h(a,b,c){let d=String(a??"").trim().toLowerCase();return b.includes(d)?d:c}function i(a){let b=a.replace(/\\/g,"\\\\").replace(/%/g,"\\%").replace(/_/g,"\\_");return`%${b}%`}c.d(b,{AR:()=>i,Bq:()=>t,Mw:()=>l,N6:()=>o,O1:()=>s,Ov:()=>z,TG:()=>d,Z$:()=>r,_$:()=>e,aI:()=>y,af:()=>u,cM:()=>w,fk:()=>g,gx:()=>f,i9:()=>n,iv:()=>x,jI:()=>v,jT:()=>p,ni:()=>j,qB:()=>q,yH:()=>k,yL:()=>h,zN:()=>m});let j=["draft","in_progress","submitted","evaluation","awarded","unsuccessful","closed"],k=["government","private"],l=["open","selective","quotation","direct"],m=["technical","financial","both"],n=["pending","in_progress","completed"],o=["active","completed"],p=["unsuccessful","cancelled","expired"],q=["active","inactive","blacklisted"],r=["company","marketplace"],s=["registration_no","category","cidb_grade","bumiputera","rating"],t=["prospect","active","inactive"],u=["government","education","healthcare","private","local_government","other"],v=["new","contacted","qualified","proposal","negotiation","won","lost"],w=["referral","cold_call","website","event","tender","other"],x=["draft","sent","accepted","rejected","expired"];function y(a){if(!a)return"open";let b=new Date(a);if(Number.isNaN(b.getTime()))return"open";let c=new Date;c.setHours(0,0,0,0),b.setHours(0,0,0,0);let d=Math.round((b.getTime()-c.getTime())/864e5);return d<0?"closed":d<=7?"closing":"open"}function z(a){return!a||a<=0?"":a<1024?`${a} B`:a<1048576?`${Math.round(a/1024)} KB`:`${(a/1048576).toFixed(1)} MB`}}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514],()=>b(b.s=57381));module.exports=c})();