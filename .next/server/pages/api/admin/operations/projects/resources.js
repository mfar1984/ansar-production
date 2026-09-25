"use strict";(()=>{var a={};a.id=7588,a.ids=[7588],a.modules={850:(a,b,c)=>{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>q});var d={};c.r(d),c.d(d,{default:()=>k});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557);async function k(a,b){let c=await (0,j.OC)(a,b);if(c){if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if((0,j.OD)(c,b,"project_resources","view"))try{let c=Number(a.query.days),d=Number.isFinite(c)?Math.min(180,Math.max(7,Math.round(c))):28,e=await (0,i.P)(`SELECT e.id AS employee_id, e.full_name, e.employee_id AS employee_no, e.position, e.status,
              dep.name AS department,
              (SELECT COUNT(*) FROM project_tasks t
                 JOIN projects p ON p.id = t.project_id
                WHERE t.assignee_employee_id = e.id AND t.completed_on IS NULL
                  AND p.status <> 'completed') AS open_tasks,
              (SELECT COUNT(*) FROM project_tasks t
                 JOIN projects p ON p.id = t.project_id
                WHERE t.assignee_employee_id = e.id AND t.completed_on IS NULL
                  AND p.status <> 'completed'
                  AND t.due_date IS NOT NULL AND t.due_date < CURDATE()) AS overdue_tasks,
              (SELECT COUNT(*) FROM project_tasks t
                 JOIN projects p ON p.id = t.project_id
                WHERE t.assignee_employee_id = e.id AND t.completed_on IS NULL
                  AND p.status <> 'completed' AND t.status = 'blocked') AS blocked_tasks,
              (SELECT COUNT(DISTINCT t.project_id) FROM project_tasks t
                 JOIN projects p ON p.id = t.project_id
                WHERE t.assignee_employee_id = e.id AND t.completed_on IS NULL
                  AND p.status <> 'completed') AS task_projects,
              (SELECT COUNT(DISTINCT pp.project_id) FROM project_participants pp
                 JOIN projects p ON p.id = pp.project_id
                WHERE pp.party_type = 'employee' AND pp.employee_id = e.id
                  AND p.status <> 'completed') AS member_projects,
              (SELECT COUNT(*) FROM project_risks r
                 JOIN projects p ON p.id = r.project_id
                WHERE r.owner_employee_id = e.id AND r.status IN ('open','monitoring')
                  AND p.status <> 'completed') AS risks_owned,
              /* The absence side. total_days is what the application itself recorded, so a half-day
                 policy is honoured without this query re-deriving it: leave_types.allow_half_days
                 exists and this endpoint has no business interpreting it.
                 NOTE: no backticks in here. This is inside a template literal, and one would end the
                 string — which is exactly how this file first failed to compile. */
              (SELECT COALESCE(SUM(la.total_days), 0) FROM leave_applications la
                WHERE la.employee_id = e.id AND la.status = 'approved'
                  AND la.start_date <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
                  AND la.end_date >= CURDATE()) AS leave_days,
              (SELECT COUNT(*) FROM leave_applications la
                WHERE la.employee_id = e.id AND la.status = 'approved'
                  AND la.start_date <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
                  AND la.end_date >= CURDATE()) AS leave_spells,
              (SELECT DATE_FORMAT(MIN(la.start_date), '%Y-%m-%d') FROM leave_applications la
                WHERE la.employee_id = e.id AND la.status = 'approved'
                  AND la.start_date <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
                  AND la.end_date >= CURDATE()) AS leave_from
         FROM employees e
         LEFT JOIN departments dep ON dep.id = e.department_id
        WHERE EXISTS (SELECT 1 FROM project_tasks t
                        JOIN projects p ON p.id = t.project_id
                       WHERE t.assignee_employee_id = e.id AND t.completed_on IS NULL
                         AND p.status <> 'completed')
           OR EXISTS (SELECT 1 FROM project_participants pp
                        JOIN projects p ON p.id = pp.project_id
                       WHERE pp.party_type = 'employee' AND pp.employee_id = e.id
                         AND p.status <> 'completed')
        ORDER BY overdue_tasks DESC, open_tasks DESC, e.full_name ASC
        LIMIT 200`,[d,d,d]),f=e.filter(a=>Number(a.leave_days)>0&&Number(a.open_tasks)>0),g=f.filter(a=>Number(a.overdue_tasks)>0),h=e.filter(a=>Number(a.member_projects)>0&&0===Number(a.open_tasks)),[j]=await (0,i.P)(`SELECT (SELECT COUNT(*) FROM projects WHERE status <> 'completed') AS live_projects,
              (SELECT COUNT(DISTINCT pp.employee_id) FROM project_participants pp
                 JOIN projects p ON p.id = pp.project_id
                WHERE pp.party_type = 'employee' AND p.status <> 'completed') AS people_on_projects,
              (SELECT COUNT(*) FROM project_tasks t JOIN projects p ON p.id = t.project_id
                WHERE t.completed_on IS NULL AND p.status <> 'completed') AS open_tasks,
              (SELECT COUNT(*) FROM project_tasks t JOIN projects p ON p.id = t.project_id
                WHERE t.completed_on IS NULL AND p.status <> 'completed'
                  AND t.assignee_employee_id IS NULL) AS unassigned_tasks,
              (SELECT COUNT(*) FROM assets a JOIN projects p ON p.id = a.project_id
                WHERE p.status <> 'completed') AS equipment,
              (SELECT COALESCE(SUM(a.purchase_cost), 0) FROM assets a
                 JOIN projects p ON p.id = a.project_id
                WHERE p.status <> 'completed') AS equipment_cost`),k=await (0,i.P)(`SELECT p.id AS project_id, p.project_no, p.title AS project_title, p.client, p.phase,
              COUNT(*) AS total,
              COALESCE(SUM(a.purchase_cost), 0) AS cost,
              COALESCE(SUM(CASE WHEN a.ownership = 'ansar' THEN 1 ELSE 0 END), 0) AS still_ours,
              COALESCE(SUM(CASE WHEN a.status = 'under_repair' THEN 1 ELSE 0 END), 0) AS under_repair,
              COALESCE(SUM(CASE WHEN a.handed_over_on IS NULL THEN 1 ELSE 0 END), 0) AS not_handed_over
         FROM assets a
         JOIN projects p ON p.id = a.project_id
        WHERE p.status <> 'completed'
        GROUP BY p.id, p.project_no, p.title, p.client, p.phase
        ORDER BY cost DESC, p.project_no ASC
        LIMIT 100`);return b.status(200).json({success:!0,data:e,summary:j,clashes:f.length,sharp_clashes:g.length,idle:h.length,equipment_by_project:k,days:d})}catch(a){return console.error("Resource allocation board error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the resource allocation"})}}}var l=c(58112),m=c(18766);let n=(0,h.M)(d,"default"),o=(0,h.M)(d,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/resources",pathname:"/api/admin/operations/projects/resources",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function q(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/admin/operations/projects/resources"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,l.getTracer)(),e=d.getActiveScopeSpan(),j=p.instrumentationOnRequestError.bind(p),k=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/admin/operations/projects/resources",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==m.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(m.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:l.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=850));module.exports=c})();