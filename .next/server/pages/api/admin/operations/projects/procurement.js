"use strict";(()=>{var a={};a.id=1833,a.ids=[1833],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},17231:(a,b,c)=>{c.r(b),c.d(b,{config:()=>q,default:()=>p,handler:()=>s});var d={};c.r(d),c.d(d,{default:()=>m});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557);let k="'approved', 'completed'",l="'draft', 'approved'";async function m(a,b){let c=await (0,j.OC)(a,b);if(c){if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if((0,j.OD)(c,b,"project_procurement","view"))try{let a=(await (0,i.P)(`SELECT p.id, p.project_no, p.title, p.client, p.phase, p.status,
              (SELECT COUNT(*) FROM purchase_orders po
                WHERE po.project_id = p.id AND po.status IN (${k})) AS orders,
              (SELECT COALESCE(SUM(po.total_amount), 0) FROM purchase_orders po
                WHERE po.project_id = p.id AND po.status IN (${k})) AS order_value,
              (SELECT COUNT(*) FROM purchase_requests pr
                WHERE pr.project_id = p.id AND pr.status IN (${l})) AS open_requests,
              (SELECT COALESCE(SUM(pr.total_amount), 0) FROM purchase_requests pr
                WHERE pr.project_id = p.id AND pr.status IN (${l})) AS request_value,
              (SELECT COUNT(DISTINCT po.supplier_id) FROM purchase_orders po
                WHERE po.project_id = p.id AND po.status IN (${k})
                  AND po.supplier_id IS NOT NULL) AS suppliers,
              (SELECT COUNT(*) FROM assets a WHERE a.project_id = p.id) AS equipment,
              (SELECT COALESCE(SUM(a.purchase_cost), 0) FROM assets a
                WHERE a.project_id = p.id) AS equipment_value,
              /* Still ours, so a recovery job at the end of the contract and a balance-sheet item until
                 then. projects/resources.ts reports the same figure for the same reason.
                 NOTE: no backticks in here. This is inside a template literal and one would end the
                 string - the fifth time in this module that exact line has had to be written. */
              (SELECT COUNT(*) FROM assets a
                WHERE a.project_id = p.id AND a.ownership = 'ansar'
                  AND a.handed_over_on IS NULL) AS to_recover,
              DATE_FORMAT((SELECT MAX(po.order_date) FROM purchase_orders po
                WHERE po.project_id = p.id AND po.status IN (${k})), '%Y-%m-%d') AS last_order
         FROM projects p
        WHERE p.status <> 'completed'
        ORDER BY p.project_no ASC
        LIMIT 200`)).map(a=>({...a,project_no:String(a.project_no??""),orders:Number(a.orders||0),order_value:Number(a.order_value||0),open_requests:Number(a.open_requests||0),request_value:Number(a.request_value||0),suppliers:Number(a.suppliers||0),equipment:Number(a.equipment||0),equipment_value:Number(a.equipment_value||0),to_recover:Number(a.to_recover||0),untagged:0===Number(a.orders||0)&&0===Number(a.open_requests||0)&&0===Number(a.equipment||0)}));a.sort((a,b)=>b.order_value-a.order_value||b.orders-a.orders||String(a.project_no).localeCompare(String(b.project_no)));let c=await (0,i.P)(`SELECT po.supplier_id, po.supplier_name, po.supplier_code,
              COUNT(*) AS orders,
              COALESCE(SUM(po.total_amount), 0) AS total,
              COUNT(DISTINCT po.project_id) AS projects,
              DATE_FORMAT(MAX(po.order_date), '%Y-%m-%d') AS last_order
         FROM purchase_orders po
        WHERE po.project_id IS NOT NULL AND po.status IN (${k})
        GROUP BY po.supplier_id, po.supplier_name, po.supplier_code
        ORDER BY total DESC
        LIMIT 100`),d=await (0,i.P)(`SELECT 'order' AS kind, po.id, po.order_no AS ref_no, po.total_amount, po.status,
              po.supplier_name, po.project_id,
              DATE_FORMAT(po.order_date, '%Y-%m-%d') AS doc_date,
              p.project_no, p.title AS project_title
         FROM purchase_orders po
         JOIN projects p ON p.id = po.project_id
        WHERE po.status IN (${k})
        UNION ALL
       SELECT 'request' AS kind, pr.id, pr.request_no AS ref_no, pr.total_amount, pr.status,
              pr.supplier_name, pr.project_id,
              DATE_FORMAT(pr.request_date, '%Y-%m-%d') AS doc_date,
              p.project_no, p.title AS project_title
         FROM purchase_requests pr
         JOIN projects p ON p.id = pr.project_id
        WHERE pr.status IN (${l})
        ORDER BY doc_date DESC, ref_no DESC
        LIMIT 300`),e=b=>a.reduce((a,c)=>a+b(c),0),[f]=await (0,i.P)(`SELECT (SELECT COUNT(*) FROM purchase_orders
                WHERE project_id IS NULL AND status IN (${k})) AS orders,
              (SELECT COALESCE(SUM(total_amount), 0) FROM purchase_orders
                WHERE project_id IS NULL AND status IN (${k})) AS order_value,
              (SELECT COUNT(*) FROM purchase_requests
                WHERE project_id IS NULL AND status IN (${l})) AS requests,
              (SELECT COUNT(*) FROM assets WHERE project_id IS NULL) AS equipment`);return b.status(200).json({success:!0,data:a,suppliers:c,documents:d,summary:{live_projects:a.length,untagged_projects:a.filter(a=>a.untagged).length,orders:e(a=>a.orders),order_value:e(a=>a.order_value),open_requests:e(a=>a.open_requests),request_value:e(a=>a.request_value),equipment:e(a=>a.equipment),equipment_value:e(a=>a.equipment_value),to_recover:e(a=>a.to_recover),suppliers:c.length},untagged:{orders:Number(f?.orders||0),order_value:Number(f?.order_value||0),requests:Number(f?.requests||0),equipment:Number(f?.equipment||0)},limit:200})}catch(a){return console.error("Project procurement board error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the procurement position"})}}}var n=c(58112),o=c(18766);let p=(0,h.M)(d,"default"),q=(0,h.M)(d,"config"),r=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/procurement",pathname:"/api/admin/operations/projects/procurement",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function s(a,b,c){let d=await r.prepare(a,b,{srcPage:"/api/admin/operations/projects/procurement"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,n.getTracer)(),e=d.getActiveScopeSpan(),j=r.instrumentationOnRequestError.bind(r),k=async e=>r.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:r.isDev,page:"/api/admin/operations/projects/procurement",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==o.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(o.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:n.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(r.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=17231));module.exports=c})();