"use strict";(()=>{var a={};a.id=1005,a.ids=[1005],a.modules={3498:a=>{a.exports=require("mysql2/promise")},5267:(a,b,c)=>{c.r(b),c.d(b,{config:()=>q,default:()=>p,handler:()=>s});var d={};c.r(d),c.d(d,{default:()=>m});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(60379);async function k(a){if(!a)return null;let[b]=await i.Ay.query("SELECT username, expires_at FROM admin_sessions WHERE hash = ?",[a]);if(!b||0===b.length)return null;let c=b[0];return new Date(c.expires_at)<new Date?null:c}async function l(a){let b=await i.Ay.getConnection();try{let[c]=await b.query("SELECT id FROM admins WHERE username = ? LIMIT 1",[a]);if(!c||0===c.length)return[];let d=c[0].id,[e]=await b.query(`
      SELECT DISTINCT p.module, p.action
      FROM permissions p
      INNER JOIN role_permissions rp ON p.id = rp.permission_id
      INNER JOIN admin_roles ar ON rp.role_id = ar.role_id
      WHERE ar.admin_id = ?
      ORDER BY p.module, p.action
    `,[d]);return e.map(a=>`${a.module}_${a.action}`)}finally{b.release()}}async function m(a,b){let{hash:c,id:d}=a.query,e=await k(c);if(!e)return b.status(401).json({error:"Unauthorized"});let f=await l(e.username);if("GET"===a.method){if(!(0,j._m)(f,"payroll_view"))return b.status(403).json({error:"Forbidden"});try{let[a]=await i.Ay.query(`SELECT 
          pr.*,
          e.employee_id as employee_number,
          e.full_name as employee_name,
          e.ic_number,
          e.epf_number,
          e.socso_number,
          e.tax_number,
          e.bank_name,
          e.bank_account_number,
          d.name as department_name,
          pp.period_name,
          pp.period_month,
          pp.period_year,
          DATE_FORMAT(pp.start_date, '%Y-%m-%d')   AS start_date,
          DATE_FORMAT(pp.end_date, '%Y-%m-%d')     AS end_date,
          DATE_FORMAT(pp.payment_date, '%Y-%m-%d') AS payment_date
        FROM payroll_records pr
        INNER JOIN employees e ON pr.employee_id = e.id
        LEFT JOIN departments d ON e.department_id = d.id
        INNER JOIN payroll_periods pp ON pr.payroll_period_id = pp.id
        WHERE pr.id = ?`,[d]);if(!a||0===a.length)return b.status(404).json({error:"Payroll record not found"});return b.status(200).json({record:a[0]})}catch(a){return console.error("Payroll record fetch error:",a),b.status(500).json({error:"Failed to fetch payroll record"})}}if("DELETE"===a.method){if(!(0,j._m)(f,"payroll_delete"))return b.status(403).json({error:"Forbidden"});try{let[a]=await i.Ay.query("SELECT id, status, payroll_period_id FROM payroll_records WHERE id = ?",[d]);if(!a||0===a.length)return b.status(404).json({error:"Payroll record not found"});let c=a[0].payroll_period_id;if("draft"!==a[0].status&&"cancelled"!==a[0].status)return b.status(400).json({error:"Only draft or cancelled payslips can be deleted"});await i.Ay.query("DELETE FROM payroll_records WHERE id = ?",[d]);let[e]=await i.Ay.query("SELECT COUNT(*) as count FROM payroll_records WHERE payroll_period_id = ?",[c]);if(0===e[0].count)return await i.Ay.query(`UPDATE payroll_periods 
           SET status = 'draft', 
               total_employees = 0,
               total_gross_salary = 0,
               total_deductions = 0,
               total_net_salary = 0,
               processed_date = NULL,
               processed_by = NULL
           WHERE id = ?`,[c]),b.status(200).json({message:"Payroll record deleted successfully. Period status reverted to draft (no payslips remaining).",periodReverted:!0});return b.status(200).json({message:"Payroll record deleted successfully"})}catch(a){return console.error("Payroll record deletion error:",a),b.status(500).json({error:"Failed to delete payroll record"})}}return b.status(405).json({error:"Method not allowed"})}var n=c(58112),o=c(18766);let p=(0,h.M)(d,"default"),q=(0,h.M)(d,"config"),r=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/payroll/records/[id]",pathname:"/api/admin/payroll/records/[id]",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function s(a,b,c){let d=await r.prepare(a,b,{srcPage:"/api/admin/payroll/records/[id]"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,n.getTracer)(),e=d.getActiveScopeSpan(),j=r.instrumentationOnRequestError.bind(r),k=async e=>r.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:r.isDev,page:"/api/admin/payroll/records/[id]",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==o.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(o.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:n.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(r.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},60379:(a,b,c)=>{function d(a,b){return a.includes(b)}function e(a,b){return[`${b}_edit`,`${b}_update`].some(b=>a.includes(b))}c.d(b,{_m:()=>d,zi:()=>e})},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=5267));module.exports=c})();