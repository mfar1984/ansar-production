"use strict";(()=>{var a={};a.id=3559,a.ids=[3559],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},45487:(a,b,c)=>{c.r(b),c.d(b,{config:()=>s,default:()=>r,handler:()=>u});var d={};c.r(d),c.d(d,{default:()=>o});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(96543),l=c(95514);let m={internal:"assets_internal",external:"assets_external"},n="Management figures. Depreciation is straight-line over the useful life recorded on each asset and is not the audited fixed-asset register.";async function o(a,b){let c=await (0,j.OC)(a,b);if(!c)return;if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let d=String(a.query.holder||"").trim();if(!l.F7.includes(d))return b.status(400).json({success:!1,error:"A register must be named: holder=internal or holder=external."});let e=m[d];if(!(0,j.OD)(c,b,e,"view")||"1"===String(a.query.export||"")&&!(0,j.OD)(c,b,e,"export"))return;let f=String(a.query.report||"").trim(),g=(0,k._$)(a.query.from)||"2000-01-01",h=(0,k._$)(a.query.to)||"2100-01-01";try{if("internal"===d&&"holdings"===f){let a=await (0,i.P)(`SELECT e.id AS employee_id, e.employee_id AS employee_code, e.full_name,
                d.name AS department_name,
                COUNT(a.id)                                    AS assigned_count,
                COALESCE(SUM(a.purchase_cost), 0)              AS assigned_cost,
                (SELECT COUNT(*) FROM asset_checkouts ck
                  WHERE ck.employee_id = e.id AND ck.returned_on IS NULL) AS open_loans,
                (SELECT COUNT(*) FROM asset_checkouts ck
                  WHERE ck.employee_id = e.id AND ck.returned_on IS NULL
                    AND ck.due_on < CURDATE())                            AS overdue_loans
           FROM employees e
           LEFT JOIN departments d ON d.id = e.department_id
           LEFT JOIN assets a ON a.employee_id = e.id AND a.holder = 'internal'
                             AND a.status NOT IN ('disposed', 'lost')
          WHERE e.status = 'active'
          GROUP BY e.id, e.employee_id, e.full_name, d.name
         HAVING assigned_count > 0 OR open_loans > 0
          ORDER BY assigned_count DESC, e.full_name ASC`);return b.status(200).json({success:!0,report:f,data:a,note:"Assigned equipment is held indefinitely; a loan has a due date. An employee can appear here for either."})}if("depreciation"===f){let a=await (0,i.P)(`SELECT a.id, a.asset_no, a.name, a.category, a.ownership,
                DATE_FORMAT(a.purchase_date, '%Y-%m-%d') AS purchase_date,
                a.purchase_cost, a.useful_life_years, a.status,
                -- Age in whole months, so a part year is not counted as none.
                TIMESTAMPDIFF(MONTH, a.purchase_date, CURDATE()) AS age_months,
                -- Straight line, floored at zero. An asset past its life is worth nothing on this
                -- schedule, never a negative figure.
                CASE
                  WHEN a.purchase_cost IS NULL OR a.useful_life_years IS NULL
                    OR a.purchase_date IS NULL THEN NULL
                  ELSE GREATEST(0, ROUND(a.purchase_cost -
                    (a.purchase_cost / (a.useful_life_years * 12))
                      * LEAST(TIMESTAMPDIFF(MONTH, a.purchase_date, CURDATE()),
                              a.useful_life_years * 12), 2))
                END AS book_value
           FROM assets a
          WHERE a.holder = ?
            AND a.ownership = 'ansar'
            AND a.status NOT IN ('disposed', 'lost')
          ORDER BY a.purchase_date ASC, a.asset_no ASC`,[d]);return b.status(200).json({success:!0,report:f,data:a,note:"external"===d?`${n} Client-owned equipment is excluded: it is not ANSAR property, so depreciating it would report a book value for something ANSAR does not own.`:n})}if("service"===f){if("internal"===d){let a=await (0,i.P)(`SELECT m.id, m.asset_id, a.asset_no, a.name AS asset_name, a.category,
                  m.kind, m.performed_by, v.name AS vendor_name, m.cost,
                  DATE_FORMAT(m.service_date, '%Y-%m-%d') AS service_date,
                  m.summary
             FROM asset_maintenance m
             JOIN assets a       ON a.id = m.asset_id
             LEFT JOIN vendors v ON v.id = m.vendor_id
            WHERE a.holder = 'internal'
              AND m.service_date BETWEEN ? AND ?
            ORDER BY m.service_date DESC, m.id DESC`,[g,h]);return b.status(200).json({success:!0,report:f,data:a,from:g,to:h})}let a=await (0,i.P)(`SELECT m.id, m.asset_id, a.asset_no, a.name AS asset_name,
                c.company_name AS client_company,
                COALESCE(st.name, a.site_name) AS site,
                t.ref_no AS tender_ref,
                m.kind, m.performed_by, v.name AS vendor_name, m.cost,
                DATE_FORMAT(m.service_date, '%Y-%m-%d') AS service_date,
                m.summary,
                DATE_FORMAT((
                  SELECT MAX(x.ends_on) FROM (
                    SELECT o.ends_on FROM asset_obligations o WHERE o.asset_id = a.id
                    UNION ALL
                    SELECT DATE_ADD(t2.handover_date, INTERVAL t2.dlp_months MONTH)
                      FROM tenders t2
                     WHERE t2.id = a.tender_id
                       AND t2.handover_date IS NOT NULL AND t2.dlp_months IS NOT NULL
                       AND NOT EXISTS (
                         SELECT 1 FROM asset_obligations o2
                          WHERE o2.asset_id = a.id AND o2.kind = 'dlp')
                  ) x
                ), '%Y-%m-%d') AS cover_until,
                -- 1 when cover was still running on the day of the visit. This is the split that
                -- decides whether a support contract is priced correctly.
                CASE WHEN (
                  SELECT MAX(x.ends_on) FROM (
                    SELECT o.ends_on FROM asset_obligations o WHERE o.asset_id = a.id
                    UNION ALL
                    SELECT DATE_ADD(t2.handover_date, INTERVAL t2.dlp_months MONTH)
                      FROM tenders t2
                     WHERE t2.id = a.tender_id
                       AND t2.handover_date IS NOT NULL AND t2.dlp_months IS NOT NULL
                       AND NOT EXISTS (
                         SELECT 1 FROM asset_obligations o2
                          WHERE o2.asset_id = a.id AND o2.kind = 'dlp')
                  ) x
                ) >= m.service_date THEN 1 ELSE 0 END AS was_covered
           FROM asset_maintenance m
           JOIN assets a           ON a.id = m.asset_id
           LEFT JOIN vendors v      ON v.id = m.vendor_id
           LEFT JOIN client_users c ON c.id = a.client_id
           LEFT JOIN asset_sites st ON st.id = a.site_id
           LEFT JOIN tenders t      ON t.id = a.tender_id
          WHERE a.holder = 'external'
            AND m.service_date BETWEEN ? AND ?
          ORDER BY m.service_date DESC, m.id DESC`,[g,h]);return b.status(200).json({success:!0,report:f,data:a,from:g,to:h,note:"Cost is split by whether an obligation was still running on the day of the visit. Work done after every obligation expired should have been billed — if it was not, that is the leak this report exists to show."})}if("internal"===d&&"movements"===f){let c=String(a.query.kind||"").trim(),d=["a.holder = 'internal'","mv.moved_on BETWEEN ? AND ?"],e=[g,h];c&&(d.push("mv.movement = ?"),e.push(c));let j=await (0,i.P)(`SELECT mv.id, mv.asset_id, a.asset_no, a.name AS asset_name, a.category,
                mv.movement, DATE_FORMAT(mv.moved_on, '%Y-%m-%d') AS moved_on,
                mv.from_holder, mv.to_holder, mv.remarks, mv.recorded_by
           FROM asset_movements mv
           JOIN assets a ON a.id = mv.asset_id
          WHERE ${d.join(" AND ")}
          ORDER BY mv.moved_on DESC, mv.id DESC
          LIMIT 2000`,e);return b.status(200).json({success:!0,report:f,data:j,from:g,to:h})}if("external"===d&&"installed"===f){let a=await (0,i.P)(`SELECT a.id, a.asset_no, a.name, a.category, a.brand, a.model, a.serial_no, a.tag_no,
                a.status, a.ownership,
                c.company_name AS client_company,
                COALESCE(st.name, a.site_name) AS site,
                t.ref_no AS tender_ref,
                DATE_FORMAT(a.installed_on, '%Y-%m-%d') AS installed_on,
                DATE_FORMAT((
                  SELECT MAX(x.ends_on) FROM (
                    SELECT o.ends_on FROM asset_obligations o WHERE o.asset_id = a.id
                    UNION ALL
                    SELECT DATE_ADD(t2.handover_date, INTERVAL t2.dlp_months MONTH)
                      FROM tenders t2
                     WHERE t2.id = a.tender_id
                       AND t2.handover_date IS NOT NULL AND t2.dlp_months IS NOT NULL
                       AND NOT EXISTS (
                         SELECT 1 FROM asset_obligations o2
                          WHERE o2.asset_id = a.id AND o2.kind = 'dlp')
                  ) x
                ), '%Y-%m-%d') AS cover_until,
                (SELECT COUNT(*) FROM helpdesk_tickets tk WHERE tk.asset_id = a.id) AS ticket_count
           FROM assets a
           LEFT JOIN client_users c ON c.id = a.client_id
           LEFT JOIN asset_sites st ON st.id = a.site_id
           LEFT JOIN tenders t      ON t.id = a.tender_id
          WHERE a.holder = 'external'
            AND a.status NOT IN ('disposed', 'lost')
          ORDER BY c.company_name ASC, site ASC, a.asset_no ASC`);return b.status(200).json({success:!0,report:f,data:a,note:"Ownership is shown per unit. Client-owned equipment is still ANSAR's responsibility while an obligation runs, which is what the cover date says."})}if("external"===d&&"deployment"===f){let a=await (0,i.P)(`SELECT t.id AS tender_id, t.ref_no AS tender_ref, t.title AS tender_title,
                p.id AS project_id, p.title AS project_title,
                c.company_name AS client_company,
                COUNT(a.id) AS asset_count,
                -- ANSAR-owned only. Summing client-owned purchase costs here would report a value
                -- for equipment ANSAR does not own.
                COALESCE(SUM(CASE WHEN a.ownership = 'ansar' THEN a.purchase_cost ELSE 0 END), 0)
                  AS owned_cost,
                SUM(a.ownership = 'client') AS client_owned_count,
                COUNT(DISTINCT COALESCE(st.name, a.site_name)) AS site_count
           FROM assets a
           LEFT JOIN tenders t      ON t.id = a.tender_id
           LEFT JOIN projects p     ON p.id = a.project_id
           LEFT JOIN client_users c ON c.id = a.client_id
           LEFT JOIN asset_sites st ON st.id = a.site_id
          WHERE a.holder = 'external'
            AND a.status NOT IN ('disposed', 'lost')
          GROUP BY t.id, t.ref_no, t.title, p.id, p.title, c.company_name
          ORDER BY asset_count DESC, t.ref_no ASC`);return b.status(200).json({success:!0,report:f,data:a,note:"Cost covers ANSAR-owned equipment only. Client-owned units are counted but carry no value on ANSAR's books."})}return b.status(400).json({success:!1,error:"internal"===d?"Unknown report. Use report=holdings, depreciation, service or movements.":"Unknown report. Use report=installed, deployment, depreciation or service."})}catch(a){return console.error("Asset reports error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to build the report"})}}var p=c(58112),q=c(18766);let r=(0,h.M)(d,"default"),s=(0,h.M)(d,"config"),t=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets/reports",pathname:"/api/admin/operations/assets/reports",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function u(a,b,c){let d=await t.prepare(a,b,{srcPage:"/api/admin/operations/assets/reports"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,p.getTracer)(),e=d.getActiveScopeSpan(),j=t.instrumentationOnRequestError.bind(t),k=async e=>t.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:t.isDev,page:"/api/admin/operations/assets/reports",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==q.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(q.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:p.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(t.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},96543:(a,b,c)=>{function d(a){if(null==a||""===a)return null;let b=Number(String(a).replace(/,/g,"").trim());return Number.isFinite(b)?b:null}function e(a){if(null==a||""===a)return null;let b=String(a).trim().slice(0,10);return/^\d{4}-\d{2}-\d{2}$/.test(b)?b:null}function f(a,b){if(null==a)return null;let c=String(a).trim();return""===c?null:c.slice(0,b)}function g(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>0?b:null}function h(a,b,c){let d=String(a??"").trim().toLowerCase();return b.includes(d)?d:c}function i(a){let b=a.replace(/\\/g,"\\\\").replace(/%/g,"\\%").replace(/_/g,"\\_");return`%${b}%`}c.d(b,{AR:()=>i,Bq:()=>r,Mw:()=>l,N6:()=>o,Ov:()=>x,TG:()=>d,_$:()=>e,aI:()=>w,af:()=>s,cM:()=>u,fk:()=>g,gx:()=>f,i9:()=>n,iv:()=>v,jI:()=>t,jT:()=>p,ni:()=>j,qB:()=>q,yH:()=>k,yL:()=>h,zN:()=>m});let j=["draft","in_progress","submitted","evaluation","awarded","unsuccessful","closed"],k=["government","private"],l=["open","selective","quotation","direct"],m=["technical","financial","both"],n=["pending","in_progress","completed"],o=["active","completed"],p=["unsuccessful","cancelled","expired"],q=["active","inactive","blacklisted"],r=["prospect","active","inactive"],s=["government","education","healthcare","private","local_government","other"],t=["new","contacted","qualified","proposal","negotiation","won","lost"],u=["referral","cold_call","website","event","tender","other"],v=["draft","sent","accepted","rejected","expired"];function w(a){if(!a)return"open";let b=new Date(a);if(Number.isNaN(b.getTime()))return"open";let c=new Date;c.setHours(0,0,0,0),b.setHours(0,0,0,0);let d=Math.round((b.getTime()-c.getTime())/864e5);return d<0?"closed":d<=7?"closing":"open"}function x(a){return!a||a<=0?"":a<1024?`${a} B`:a<1048576?`${Math.round(a/1024)} KB`:`${(a/1048576).toFixed(1)} MB`}}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514],()=>b(b.s=45487));module.exports=c})();