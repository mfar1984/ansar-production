"use strict";(()=>{var a={};a.id=3249,a.ids=[3249],a.modules={3498:a=>{a.exports=require("mysql2/promise")},24677:(a,b,c)=>{c.r(b),c.d(b,{config:()=>p,default:()=>o,handler:()=>r});var d={};c.r(d),c.d(d,{default:()=>l});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(69486),k=c(64487);async function l(a,b){if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let c=await (0,j.UD)(a,b);if(!c||!(0,j.Tw)(c,b,a.query.employee_id))return;let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid id."});try{let a=await (0,i.P)(`SELECT w.id, w.work_order_no, w.type_name, w.title, w.description, w.materials_note,
              w.status, w.priority,
              DATE_FORMAT(w.scheduled_date, '%Y-%m-%d') AS scheduled_date,
              DATE_FORMAT(w.started_on,     '%Y-%m-%d') AS started_on,
              DATE_FORMAT(w.completed_on,   '%Y-%m-%d') AS completed_on,
              w.assignee_employee_id,
              IF(w.assignee_employee_id = ?, 'lead', 'crew') AS my_role,
              e.full_name AS lead_name,
              a.asset_no, a.name AS asset_name, a.holder AS asset_holder,
              k.ticket_no, k.subject AS ticket_subject,
              p.project_no, p.title AS project_title,
              s.order_no, s.customer_name,
              v.name AS vendor_name
         FROM work_orders w
         LEFT JOIN employees e        ON e.id = w.assignee_employee_id
         LEFT JOIN vendors v          ON v.id = w.vendor_id
         LEFT JOIN assets a           ON a.id = w.asset_id
         LEFT JOIN helpdesk_tickets k ON k.id = w.ticket_id
         LEFT JOIN projects p         ON p.id = w.project_id
         LEFT JOIN sales_orders s     ON s.id = w.sales_order_id
        WHERE w.id = ?
          AND ${k.Zk}
        LIMIT 1`,[c.employeeId,d,...(0,k.Nm)(c.employeeId)]);if(0===a.length)return b.status(404).json({success:!1,error:"That work order is not one of yours."});let[e,f]=await Promise.all([(0,i.P)(`SELECT id, title, notes, is_required, sort_order, state, skip_reason,
                DATE_FORMAT(decided_on, '%Y-%m-%d') AS decided_on, decided_by
           FROM work_order_items
          WHERE work_order_id = ? ORDER BY sort_order ASC, id ASC`,[d]),(0,i.P)(`SELECT c.employee_id, e.full_name, e.position
           FROM work_order_crew c
           LEFT JOIN employees e ON e.id = c.employee_id
          WHERE c.work_order_id = ?
          ORDER BY e.full_name ASC, c.employee_id ASC`,[d])]);return b.status(200).json({success:!0,data:a[0],items:e,crew:f})}catch(c){let a=c instanceof Error?c.message:"Unknown error";return console.error("ESS work order detail error:",c),b.status(500).json({success:!1,error:`Failed to load the work order: ${a}`})}}var m=c(58112),n=c(18766);let o=(0,h.M)(d,"default"),p=(0,h.M)(d,"config"),q=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/employee/work-orders/[id]",pathname:"/api/employee/work-orders/[id]",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function r(a,b,c){let d=await q.prepare(a,b,{srcPage:"/api/employee/work-orders/[id]"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,m.getTracer)(),e=d.getActiveScopeSpan(),j=q.instrumentationOnRequestError.bind(q),k=async e=>q.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:q.isDev,page:"/api/employee/work-orders/[id]",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==n.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(n.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:m.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(q.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},69486:(a,b,c)=>{c.d(b,{Tw:()=>i,UD:()=>h,k_:()=>f,lD:()=>g});var d=c(88251);let e=["active","on_leave"],f="Your employee access has ended. Please contact HR if you believe this is incorrect.";function g(a){return e.includes(String(a))}async function h(a,b){let c="string"==typeof a.query.hash?a.query.hash:"";if(!c)return b.status(400).json({success:!1,error:"Session hash is required."}),null;let e=(await (0,d.P)(`SELECT s.username, s.user_type, s.employee_id, s.expires_at, e.status AS employment_status
       FROM admin_sessions s
       LEFT JOIN employees e ON e.id = s.employee_id
      WHERE s.hash = ? LIMIT 1`,[c]))[0];return e?new Date(e.expires_at)<=new Date?(b.status(401).json({success:!1,error:"Your session has expired. Sign in again."}),null):"employee"===e.user_type&&e.employee_id?g(e.employment_status)?{employeeId:e.employee_id,username:e.username}:(b.status(403).json({success:!1,error:f}),null):(b.status(403).json({success:!1,error:"This endpoint is for employee accounts."}),null):(b.status(401).json({success:!1,error:"Invalid or expired session."}),null)}function i(a,b,c){return null==c||""===c||Number(c)===a.employeeId||(b.status(403).json({success:!1,error:"You can only access your own records."}),!1)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,3133,2102,3565],()=>b(b.s=24677));module.exports=c})();