"use strict";(()=>{var a={};a.id=9868,a.ids=[9868],a.modules={3498:a=>{a.exports=require("mysql2/promise")},17526:(a,b,c)=>{c.r(b),c.d(b,{config:()=>p,default:()=>o,handler:()=>r});var d={};c.r(d),c.d(d,{default:()=>l});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19890);async function l(a,b){let c=await (0,j.OC)(a,b);if(!c)return;if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid project id."});if((0,j.OD)(c,b,"project_schedule","view"))try{let a=await (0,i.P)(`SELECT id, project_no, title, phase, status, percent_complete,
              DATE_FORMAT(start_date, '%Y-%m-%d')    AS start_date,
              DATE_FORMAT(end_date, '%Y-%m-%d')      AS end_date,
              DATE_FORMAT(handover_date, '%Y-%m-%d') AS handover_date
         FROM projects WHERE id = ? LIMIT 1`,[d]);if(0===a.length)return b.status(404).json({success:!1,error:"Project not found."});let c=a[0],e=await (0,i.P)(`SELECT t.id, t.title, t.status, t.milestone_id, t.blocked_reason, t.sort_order,
              DATE_FORMAT(t.start_date, '%Y-%m-%d')   AS start_date,
              DATE_FORMAT(t.due_date, '%Y-%m-%d')     AS due_date,
              DATE_FORMAT(t.completed_on, '%Y-%m-%d') AS completed_on,
              CASE
                WHEN t.completed_on IS NOT NULL THEN 'done'
                WHEN t.due_date IS NOT NULL AND t.due_date < CURDATE() THEN 'overdue'
                ELSE t.status
              END AS derived_status,
              e.full_name AS assignee_name,
              m.title AS milestone_title
         FROM project_tasks t
         LEFT JOIN employees e ON e.id = t.assignee_employee_id
         LEFT JOIN project_milestones m ON m.id = t.milestone_id
        WHERE t.project_id = ?
        ORDER BY t.sort_order ASC, t.id ASC`,[d]),f=await (0,i.P)(`SELECT d.task_id, d.depends_on_task_id
         FROM project_task_deps d
         JOIN project_tasks s ON s.id = d.task_id            AND s.project_id = ?
         JOIN project_tasks p ON p.id = d.depends_on_task_id  AND p.project_id = ?
        ORDER BY d.task_id ASC, d.depends_on_task_id ASC`,[d,d]),g=await (0,i.P)(`SELECT id, title, is_client_visible,
              DATE_FORMAT(due_date, '%Y-%m-%d')     AS due_date,
              DATE_FORMAT(completed_on, '%Y-%m-%d') AS completed_on
         FROM project_milestones
        WHERE project_id = ? AND due_date IS NOT NULL
        ORDER BY due_date ASC, id ASC`,[d]),h=(0,k.Bd)(e,f),j=c.start_date,l=c.end_date,m=(0,k.ZW)(e,j,l),n=null===m?null:{...m,from_date:(0,k.cb)(m.from),to_date:(0,k.cb)(m.to)},o=e.filter(a=>!a.start_date||!a.due_date).map(a=>({id:a.id,title:a.title,start_date:a.start_date,due_date:a.due_date})),p=null;if(l&&null!==m){let a=Date.parse(`${l}T00:00:00Z`),b=Math.max(...e.filter(a=>a.start_date&&a.due_date).map(a=>Date.parse(`${a.due_date}T00:00:00Z`)));Number.isFinite(a)&&Number.isFinite(b)&&(p=Math.round((b-a)/864e5))}return b.status(200).json({success:!0,project:c,data:e,deps:f,milestones:g,schedule:h,window:n,unscheduled:o,overrun_days:p})}catch(a){return console.error("Project schedule error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the schedule"})}}var m=c(58112),n=c(18766);let o=(0,h.M)(d,"default"),p=(0,h.M)(d,"config"),q=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/[id]/schedule",pathname:"/api/admin/operations/projects/[id]/schedule",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function r(a,b,c){let d=await q.prepare(a,b,{srcPage:"/api/admin/operations/projects/[id]/schedule"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,m.getTracer)(),e=d.getActiveScopeSpan(),j=q.instrumentationOnRequestError.bind(q),k=async e=>q.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:q.isDev,page:"/api/admin/operations/projects/[id]/schedule",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==n.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(n.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:m.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(q.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,8854],()=>b(b.s=17526));module.exports=c})();