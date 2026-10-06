"use strict";(()=>{var a={};a.id=9471,a.ids=[9471],a.modules={3498:a=>{a.exports=require("mysql2/promise")},36989:(a,b,c)=>{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>q});var d={};c.r(d),c.d(d,{default:()=>k});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(63415);async function k(a,b){if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let c=await (0,j.PS)(a,b,"payroll","view");if(!c)return;if(!(0,j.$3)(c,"claims","view"))return b.status(403).json({success:!1,error:"You can open a payroll run, but reading claim detail needs claims_view. The outstanding-claims panel is hidden."});let d=Number(a.query.period_id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Name the payroll period."});try{let a=await (0,i.P)(`SELECT 'claim' AS kind,
              c.id,
              c.claim_number,
              c.submission_ref,
              c.employee_id,
              e.full_name AS employee_name,
              e.employee_id AS employee_number,
              ct.name AS claim_type,
              ct.color AS claim_type_color,
              DATE_FORMAT(c.period_from, '%Y-%m-%d') AS period_from,
              DATE_FORMAT(c.period_to, '%Y-%m-%d')   AS period_to,
              DATE_FORMAT(c.reviewed_date, '%Y-%m-%d') AS approved_on,
              c.total_amount,
              (SELECT COUNT(*) FROM claim_items ci WHERE ci.claim_id = c.id) AS items_count
         FROM claims c
         INNER JOIN employees e   ON e.id = c.employee_id
         INNER JOIN claim_types ct ON ct.id = c.claim_type_id
         INNER JOIN payroll_records pr
                 ON pr.employee_id = c.employee_id
                AND pr.payroll_period_id = ?
        WHERE c.status = 'approved'

        UNION ALL

       SELECT 'mileage' AS kind,
              m.id,
              m.claim_number,
              /* No submission grouping here: one mileage submission is one row, always. */
              m.claim_number AS submission_ref,
              m.employee_id,
              e2.full_name AS employee_name,
              e2.employee_id AS employee_number,
              CONCAT('Mileage \xb7 ', m.total_km, ' km') AS claim_type,
              NULL AS claim_type_color,
              DATE_FORMAT(m.period_from, '%Y-%m-%d') AS period_from,
              DATE_FORMAT(m.period_to, '%Y-%m-%d')   AS period_to,
              DATE_FORMAT(m.reviewed_date, '%Y-%m-%d') AS approved_on,
              m.total_amount,
              m.trip_count AS items_count
         FROM (SELECT mc.*,
                      (SELECT COUNT(*) FROM mileage_trips t WHERE t.mileage_claim_id = mc.id)
                        AS trip_count
                 FROM mileage_claims mc) m
         INNER JOIN employees e2  ON e2.id = m.employee_id
         INNER JOIN payroll_records pr2
                 ON pr2.employee_id = m.employee_id
                AND pr2.payroll_period_id = ?
        WHERE m.status = 'approved'

        ORDER BY employee_name ASC, kind ASC, claim_number ASC`,[d,d]),c=a.reduce((a,b)=>a+Math.round(100*Number(b.total_amount||0)),0);return b.status(200).json({success:!0,period_id:d,claims:a,count:a.length,total_amount:(c/100).toFixed(2),note:"Approved and not yet paid. These are NOT part of this payroll run — a reimbursement is not wages, and each is paid from its own expense account: expense claims through Human Resource > Claim Management, mileage through Human Resource > Mileage Claims, which posts to Motor vehicle expenses rather than Salaries."})}catch(c){let a=c instanceof Error?c.message:"Unknown error";return console.error("Payroll outstanding claims error:",c),b.status(500).json({success:!1,error:`Failed to load outstanding claims: ${a}`})}}var l=c(58112),m=c(18766);let n=(0,h.M)(d,"default"),o=(0,h.M)(d,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/payroll/outstanding-claims",pathname:"/api/admin/payroll/outstanding-claims",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function q(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/admin/payroll/outstanding-claims"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,l.getTracer)(),e=d.getActiveScopeSpan(),j=p.instrumentationOnRequestError.bind(p),k=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/admin/payroll/outstanding-claims",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==m.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(m.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:l.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=36989));module.exports=c})();