"use strict";(()=>{var a={};a.id=6997,a.ids=[6997],a.modules={3498:a=>{a.exports=require("mysql2/promise")},20444:(a,b,c)=>{c.d(b,{K5:()=>f,OC:()=>g,Ow:()=>h,Z8:()=>e,uq:()=>i});let d=["low","medium","high","urgent"];function e(a){let b=String(a??"").trim().toLowerCase();return d.includes(b)?b:"medium"}function f(a,b){return"urgent"!==a||b&&Number.isInteger(b)&&b>0?{ok:!0}:{ok:!1,error:"An Urgent report must name the equipment involved, because answering it means going to a specific unit and knowing whether the visit is covered. Identify the equipment, or choose High if you cannot."}}let g="Raised to Urgent with no equipment identified. A technician cannot be dispatched, and whether the visit is chargeable cannot be decided, until the unit is named.";function h(a,b){return"urgent"===String(a||"").toLowerCase()&&!b}function i(a){let b=String(a??"").trim();return b?b.slice(-4):null}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},90437:(a,b,c)=>{c.r(b),c.d(b,{config:()=>p,default:()=>o,handler:()=>r});var d={};c.r(d),c.d(d,{default:()=>l});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(20444);async function k(a){if(!a)return null;let b=await (0,i.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[a]);if(!b||0===b.length)return null;let{username:c,expires_at:d}=b[0];if(new Date(d)<=new Date)return null;let e=await (0,i.P)("SELECT id FROM admins WHERE username = ? LIMIT 1",[c]);if(!e||0===e.length)return null;let f=e[0].id,g=(await (0,i.P)(`
      SELECT DISTINCT p.module, p.action
      FROM permissions p
      INNER JOIN role_permissions rp ON p.id = rp.permission_id
      INNER JOIN admin_roles ar ON rp.role_id = ar.role_id
      WHERE ar.admin_id = ?
      ORDER BY p.module, p.action
    `,[f])).map(a=>`${a.module}_${a.action}`);return{adminId:f,username:c,permissionNames:g}}async function l(a,b){try{let{hash:c}=a.query,d=await k(c||"");if(!d)return b.status(401).json({error:"Unauthorized"});if(!d.permissionNames.includes("helpdesk_view"))return b.status(403).json({error:"Access denied. Insufficient permissions."});if("GET"===a.method){let a=(await (0,i.P)(`SELECT 
          t.*,
          c.company_name,
          c.contact_person,
          c.email as client_email,
          c.phone as client_phone,
          u.full_name as assigned_user_name,
          -- The equipment the fault is about, when one was identified. An Urgent ticket without
          -- it cannot be dispatched, and whether the visit is chargeable cannot be decided.
          a.asset_no,
          a.name AS asset_name,
          a.serial_no AS asset_serial,
          COALESCE(st.name, a.site_name) AS asset_site,
          te.ref_no AS asset_tender_ref
        FROM helpdesk_tickets t
        JOIN client_users c ON t.client_id = c.id
        LEFT JOIN users u ON t.assigned_to = u.id
        LEFT JOIN assets a ON a.id = t.asset_id
        LEFT JOIN asset_sites st ON st.id = a.site_id
        LEFT JOIN tenders te ON te.id = a.tender_id
        ORDER BY 
          CASE t.priority
            WHEN 'Urgent' THEN 1
            WHEN 'High' THEN 2
            WHEN 'Medium' THEN 3
            WHEN 'Low' THEN 4
          END,
          t.created_at DESC`)).map(a=>{let b=a.attachments,c=[];if(null!=b&&""!==b){if(Array.isArray(b))c=b;else if("object"==typeof b)c=b;else if("string"==typeof b){let a=b.trim();if(a.startsWith("[")&&a.endsWith("]")||a.startsWith("{")&&a.endsWith("}"))try{c=JSON.parse(a)}catch{c=[a]}else c=[a]}}return{...a,attachments:c,urgent_asset_outstanding:(0,j.Ow)(a.priority,a.asset_id),urgent_asset_note:j.OC}});return b.status(200).json({tickets:a})}return b.status(405).json({error:"Method not allowed"})}catch(a){return console.error("Error in admin helpdesk API:",a),b.status(500).json({error:"Server error",details:a instanceof Error?a.message:"Unknown error"})}}var m=c(58112),n=c(18766);let o=(0,h.M)(d,"default"),p=(0,h.M)(d,"config"),q=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/helpdesk",pathname:"/api/admin/helpdesk",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function r(a,b,c){let d=await q.prepare(a,b,{srcPage:"/api/admin/helpdesk"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,m.getTracer)(),e=d.getActiveScopeSpan(),j=q.instrumentationOnRequestError.bind(q),k=async e=>q.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:q.isDev,page:"/api/admin/helpdesk",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==n.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(n.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:m.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(q.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=90437));module.exports=c})();