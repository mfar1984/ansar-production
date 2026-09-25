"use strict";(()=>{var a={};a.id=8039,a.ids=[8039],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},21061:(a,b,c)=>{c.r(b),c.d(b,{config:()=>q,default:()=>p,handler:()=>s});var d={};c.r(d),c.d(d,{default:()=>m});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557);let k="(r.probability * r.impact)",l=["live","critical","review","unowned","realised","all"];async function m(a,b){let c=await (0,j.OC)(a,b);if(c){if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if((0,j.OD)(c,b,"project_risk","view"))try{let c=String(a.query.view||"").trim().toLowerCase(),d=l.includes(c)?c:"live",e=String(a.query.owner||"").trim().toLowerCase(),f=Number(a.query.owner),g="unowned"===e,h=!g&&Number.isInteger(f)&&f>0?f:null,j=Number(a.query.project),m=Number.isInteger(j)&&j>0?j:null,n=[],o=[];"realised"!==d&&"all"!==d&&n.push("p.status <> 'completed'"),"realised"===d?n.push("r.status = 'realised'"):"all"!==d&&(n.push("r.status IN ('open','monitoring')"),"critical"===d&&n.push(`${k} >= 10`),"review"===d&&n.push("r.review_on IS NOT NULL AND r.review_on < CURDATE()"),"unowned"===d&&n.push("r.owner_employee_id IS NULL")),g?n.push("r.owner_employee_id IS NULL"):null!==h&&(n.push("r.owner_employee_id = ?"),o.push(h)),null!==m&&(n.push("r.project_id = ?"),o.push(m));let p="realised"===d?"r.closed_on DESC, r.id DESC":`${k} DESC, COALESCE(r.review_on, '9999-12-31') ASC, p.project_no ASC`,q=await (0,i.P)(`SELECT r.id, r.title, r.category, r.probability, r.impact, r.response, r.status,
              r.mitigation, r.owner_employee_id, r.closed_note,
              ${k} AS score,
              DATE_FORMAT(r.identified_on, '%Y-%m-%d') AS identified_on,
              DATE_FORMAT(r.review_on, '%Y-%m-%d')     AS review_on,
              DATE_FORMAT(r.closed_on, '%Y-%m-%d')     AS closed_on,
              CASE WHEN r.status IN ('open','monitoring') AND r.review_on IS NOT NULL
                   THEN DATEDIFF(r.review_on, CURDATE()) END AS days_to_review,
              DATEDIFF(CURDATE(), r.identified_on) AS age_days,
              e.full_name AS owner_name, e.employee_id AS owner_no,
              p.id AS project_id, p.project_no, p.title AS project_title, p.client, p.phase,
              p.health, p.status AS project_status
         FROM project_risks r
         JOIN projects p ON p.id = r.project_id
         LEFT JOIN employees e ON e.id = r.owner_employee_id
        WHERE ${n.join(" AND ")}
        ORDER BY ${p}
        LIMIT 300`,o),[r]=await (0,i.P)(`SELECT COUNT(*) AS total,
              SUM(CASE WHEN r.status IN ('open','monitoring') THEN 1 ELSE 0 END) AS live,
              SUM(CASE WHEN r.status IN ('open','monitoring') AND ${k} >= 15 THEN 1 ELSE 0 END)
                AS critical,
              SUM(CASE WHEN r.status IN ('open','monitoring')
                        AND ${k} BETWEEN 10 AND 14 THEN 1 ELSE 0 END) AS high,
              SUM(CASE WHEN r.status IN ('open','monitoring')
                        AND r.owner_employee_id IS NULL THEN 1 ELSE 0 END) AS unowned,
              SUM(CASE WHEN r.status IN ('open','monitoring') AND r.review_on IS NOT NULL
                        AND r.review_on < CURDATE() THEN 1 ELSE 0 END) AS review_overdue,
              SUM(CASE WHEN r.status IN ('open','monitoring') AND r.review_on IS NULL
                       THEN 1 ELSE 0 END) AS no_review_date,
              COUNT(DISTINCT r.project_id) AS projects
         FROM project_risks r
         JOIN projects p ON p.id = r.project_id
        WHERE p.status <> 'completed'`),[s]=await (0,i.P)(`SELECT COUNT(*) AS total,
              SUM(CASE WHEN r.closed_on >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 ELSE 0 END)
                AS last_90_days,
              COUNT(DISTINCT r.project_id) AS projects
         FROM project_risks r WHERE r.status = 'realised'`),t=await (0,i.P)(`SELECT r.owner_employee_id, e.full_name AS owner_name,
              COUNT(*) AS live_count,
              MAX(${k}) AS worst_score,
              SUM(CASE WHEN ${k} >= 15 THEN 1 ELSE 0 END) AS critical_count,
              SUM(CASE WHEN r.review_on IS NOT NULL AND r.review_on < CURDATE() THEN 1 ELSE 0 END)
                AS review_overdue,
              COUNT(DISTINCT r.project_id) AS project_count
         FROM project_risks r
         JOIN projects p ON p.id = r.project_id
         LEFT JOIN employees e ON e.id = r.owner_employee_id
        WHERE r.status IN ('open','monitoring') AND p.status <> 'completed'
        GROUP BY r.owner_employee_id, e.full_name
        ORDER BY critical_count DESC, worst_score DESC, live_count DESC, e.full_name ASC
        LIMIT 50`),u=await (0,i.P)(`SELECT p.id, p.project_no, p.title, p.client, p.phase, p.health, p.percent_complete,
              DATE_FORMAT(p.end_date, '%Y-%m-%d') AS end_date
         FROM projects p
        WHERE p.status <> 'completed'
          AND NOT EXISTS (SELECT 1 FROM project_risks r WHERE r.project_id = p.id)
        ORDER BY FIELD(p.phase, 'monitoring', 'executing', 'closing', 'planning', 'initiation'),
                 p.created_at DESC
        LIMIT 50`),v=await (0,i.P)(`SELECT e.id, e.full_name, e.employee_id AS employee_no, e.status
         FROM employees e
        WHERE e.status = 'active'
           OR EXISTS (SELECT 1 FROM project_risks r
                       WHERE r.owner_employee_id = e.id
                         AND r.status IN ('open','monitoring'))
        ORDER BY e.full_name ASC`),w=await (0,i.P)(`SELECT p.id, p.project_no, p.title
         FROM projects p
        WHERE EXISTS (SELECT 1 FROM project_risks r WHERE r.project_id = p.id)
        ORDER BY p.project_no ASC`);return b.status(200).json({success:!0,data:q,summary:r,realised:s,by_owner:t,no_register:u,employees:v,projects:w,view:d,filters:{owner:g?"unowned":h,project:m}})}catch(a){return console.error("Risk register board error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the risk register"})}}}var n=c(58112),o=c(18766);let p=(0,h.M)(d,"default"),q=(0,h.M)(d,"config"),r=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/risks",pathname:"/api/admin/operations/projects/risks",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function s(a,b,c){let d=await r.prepare(a,b,{srcPage:"/api/admin/operations/projects/risks"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,n.getTracer)(),e=d.getActiveScopeSpan(),j=r.instrumentationOnRequestError.bind(r),k=async e=>r.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:r.isDev,page:"/api/admin/operations/projects/risks",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==o.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(o.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:n.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(r.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=21061));module.exports=c})();