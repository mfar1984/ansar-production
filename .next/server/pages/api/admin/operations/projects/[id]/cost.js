"use strict";(()=>{var a={};a.id=4592,a.ids=[4592],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},47412:(a,b,c)=>{c.r(b),c.d(b,{config:()=>t,default:()=>s,handler:()=>v});var d={};c.r(d),c.d(d,{default:()=>p});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557);let k="'approved', 'completed'",l="'approved', 'paid'",m="'pending'",n="'approved', 'paid'",o="'draft', 'approved'";async function p(a,b){let c=await (0,j.OC)(a,b);if(!c)return;if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid project id."});if((0,j.OD)(c,b,"project_cost","view"))try{let a=await (0,i.P)(`SELECT id, project_no, title, client, phase, status, health, percent_complete,
              value, budget_cost,
              DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
              DATE_FORMAT(end_date, '%Y-%m-%d')   AS end_date
         FROM projects WHERE id = ? LIMIT 1`,[d]);if(0===a.length)return b.status(404).json({success:!1,error:"Project not found."});let c=a[0],[e]=await (0,i.P)(`SELECT (SELECT COALESCE(SUM(po.total_amount), 0) FROM purchase_orders po
                WHERE po.project_id = ? AND po.status IN (${k})) AS committed,
              (SELECT COUNT(*) FROM purchase_orders po
                WHERE po.project_id = ? AND po.status IN (${k})) AS order_count,

              (SELECT COALESCE(SUM(pr.total_amount), 0) FROM purchase_requests pr
                WHERE pr.project_id = ? AND pr.status IN (${o})) AS requested,
              (SELECT COUNT(*) FROM purchase_requests pr
                WHERE pr.project_id = ? AND pr.status IN (${o})) AS request_count,

              (SELECT COALESCE(SUM(e.total_amount), 0) FROM expenses e
                WHERE e.project_id = ? AND e.status IN (${l})) AS claimed,
              (SELECT COUNT(*) FROM expenses e
                WHERE e.project_id = ? AND e.status IN (${l})) AS claim_count,
              (SELECT COALESCE(SUM(e.total_amount), 0) FROM expenses e
                WHERE e.project_id = ? AND e.status IN (${m})) AS claims_pending,
              (SELECT COUNT(*) FROM expenses e
                WHERE e.project_id = ? AND e.status IN (${m})) AS claims_pending_count,

              (SELECT COALESCE(SUM(a.purchase_cost), 0) FROM assets a
                WHERE a.project_id = ?) AS equipment,
              (SELECT COUNT(*) FROM assets a WHERE a.project_id = ?) AS equipment_count,

              /* INVOICED REVENUE - see database/project_invoiced_revenue.sql. The other side of the
                 ledger, kept out of the spend total. Unlike the milestone count below, this figure
                 needs no scope to have been entered: an invoice either exists and is issued, or it
                 does not.
                 NO BACKTICKS in here. This is inside a template literal and one would end the string -
                 which is exactly how this comment first failed to compile. */
              (SELECT COALESCE(SUM(si.total_amount), 0) FROM sales_invoices si
                WHERE si.project_id = ? AND si.status IN (${n})) AS invoiced,
              (SELECT COUNT(*) FROM sales_invoices si
                WHERE si.project_id = ? AND si.status IN (${n})) AS invoice_count,

              /*
               * HOW MANY MILESTONES EXIST, AND IT IS NOT DECORATION.
               *
               * percent_complete is DERIVED from milestone weights, so a project with no milestones
               * reads 0% - and 0% is the difference between two completely different statements:
               *
               *   "we have spent RM 200,000 and delivered nothing"     a real, alarming loss
               *   "nobody has entered the scope yet"                   a data-entry gap
               *
               * Without this count the screen cannot tell them apart, and it would report every
               * unplanned project as a total loss. Measured on this database: project_milestones holds
               * ZERO rows, so today EVERY project is the second case.
               */
              (SELECT COUNT(*) FROM project_milestones m
                WHERE m.project_id = ?) AS milestone_count`,[d,d,d,d,d,d,d,d,d,d,d,d,d]),f=Number(e?.committed||0),g=Number(e?.claimed||0),h=Number(e?.equipment||0),j=Number(e?.requested||0),p=f+g+h,q=Number(e?.invoiced||0),r=null===c.budget_cost?null:Number(c.budget_cost),s=Number(c.value||0),t=null!==r&&r>0?Math.round(p/r*1e3)/10:null,u=s>0?Math.round(p/s*1e3)/10:null,v=Number(e?.milestone_count||0),w=Number(c.percent_complete||0),x=v>0,y=s>0&&x?Math.round(s*w)/100:null,z=null===y?null:Math.round((y-p)*100)/100,A=null!==y&&y>0?Math.round(z/y*1e3)/10:null,B=await (0,i.P)(`SELECT po.id, po.order_no, po.supplier_name, po.total_amount, po.status, po.currency,
              po.requester, po.department, po.remark,
              DATE_FORMAT(po.order_date, '%Y-%m-%d')    AS order_date,
              DATE_FORMAT(po.delivery_date, '%Y-%m-%d') AS delivery_date
         FROM purchase_orders po
        WHERE po.project_id = ? AND po.status IN (${k})
        ORDER BY po.total_amount DESC, po.id DESC
        LIMIT 100`,[d]),C=await (0,i.P)(`SELECT pr.id, pr.request_no, pr.supplier_name, pr.total_amount, pr.status, pr.currency,
              pr.requester, pr.department,
              DATE_FORMAT(pr.request_date, '%Y-%m-%d')  AS request_date,
              DATE_FORMAT(pr.required_date, '%Y-%m-%d') AS required_date
         FROM purchase_requests pr
        WHERE pr.project_id = ? AND pr.status IN (${o})
        ORDER BY pr.total_amount DESC, pr.id DESC
        LIMIT 100`,[d]),D=await (0,i.P)(`SELECT e.id, e.expense_number, e.total_amount, e.status, e.vendor_name, e.description,
              DATE_FORMAT(e.expense_date, '%Y-%m-%d') AS expense_date,
              /* employees.employee_id is the STAFF NUMBER, a varchar, not a foreign key. Eleven
                 other endpoints alias it the same way; the name is confusing and it is not this
                 file's to fix. NO BACKTICKS IN HERE: this comment is inside a template literal, and
                 one would end the string and report TS1005 on a line of prose. */
              emp.full_name AS claimant, emp.employee_id AS employee_no,
              cat.name AS category
         FROM expenses e
         LEFT JOIN employees emp ON emp.id = e.employee_id
         LEFT JOIN expense_categories cat ON cat.id = e.category_id
        WHERE e.project_id = ?
          AND e.status IN (${l}, ${m})
        ORDER BY e.total_amount DESC, e.id DESC
        LIMIT 100`,[d]),E=await (0,i.P)(`SELECT a.id, a.asset_no, a.name, a.brand, a.model, a.serial_no, a.status, a.holder,
              a.ownership, a.purchase_cost, a.category,
              DATE_FORMAT(a.purchase_date, '%Y-%m-%d') AS purchase_date
         FROM assets a
        WHERE a.project_id = ?
        ORDER BY a.purchase_cost DESC, a.id DESC
        LIMIT 100`,[d]),F=await (0,i.P)(`SELECT si.id, si.invoice_no, si.customer_name, si.status, si.total_amount, si.currency,
              DATE_FORMAT(si.invoice_date, '%Y-%m-%d') AS invoice_date,
              DATE_FORMAT(si.due_date, '%Y-%m-%d') AS due_date
         FROM sales_invoices si
        WHERE si.project_id = ?
          AND si.status IN (${n})
        ORDER BY si.total_amount DESC, si.id DESC
        LIMIT 100`,[d]);return b.status(200).json({success:!0,project:{...c,value:s,budget_cost:r,percent_complete:Number(c.percent_complete||0)},summary:{committed:f,claimed:g,equipment:h,requested:j,spent:p,claims_pending:Number(e?.claims_pending||0),order_count:Number(e?.order_count||0),request_count:Number(e?.request_count||0),claim_count:Number(e?.claim_count||0),claims_pending_count:Number(e?.claims_pending_count||0),equipment_count:Number(e?.equipment_count||0),budget:r,value:s,remaining:null===r?null:Math.round((r-p)*100)/100,of_budget:t,of_value:u,over_budget:null!==r&&p>r,percent_complete:w,milestone_count:v,progress_known:x,earned:y,profit:z,margin_pct:A,invoiced:q,invoice_count:Number(e?.invoice_count||0),billed_pct:s>0?Math.round(q/s*1e3)/10:null,unbilled:null===y?null:Math.round((y-q)*100)/100,at_a_loss:null!==z&&z<0,untagged:0===f&&0===g&&0===h&&0===j},orders:B,requests:C,claims:D,equipment:E,invoices:F,limit:100})}catch(a){return console.error("Project cost tab error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the cost position"})}}var q=c(58112),r=c(18766);let s=(0,h.M)(d,"default"),t=(0,h.M)(d,"config"),u=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/[id]/cost",pathname:"/api/admin/operations/projects/[id]/cost",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function v(a,b,c){let d=await u.prepare(a,b,{srcPage:"/api/admin/operations/projects/[id]/cost"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,q.getTracer)(),e=d.getActiveScopeSpan(),j=u.instrumentationOnRequestError.bind(u),k=async e=>u.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:u.isDev,page:"/api/admin/operations/projects/[id]/cost",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==r.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(r.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:q.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(u.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=47412));module.exports=c})();