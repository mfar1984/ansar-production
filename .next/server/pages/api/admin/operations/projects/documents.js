"use strict";(()=>{var a={};a.id=5637,a.ids=[5637],a.modules={3498:a=>{a.exports=require("mysql2/promise")},52912:(a,b,c)=>{c.r(b),c.d(b,{config:()=>r,default:()=>q,handler:()=>t});var d={};c.r(d),c.d(d,{default:()=>n});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(96543),l=c(26279);let m=["shared","internal","orphan","all"];async function n(a,b){let c=await (0,j.OC)(a,b);if(c){if(b.setHeader("Cache-Control","no-store"),"GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if((0,j.OD)(c,b,"project_documents","view"))try{let c=String(a.query.view||"").trim().toLowerCase(),d=m.includes(c)?c:"shared",e=String(a.query.type||"").trim().toLowerCase(),f=l.PJ.includes(e)?(0,k.yL)(e,l.PJ,"general"):null,g=Number(a.query.project),h=Number.isInteger(g)&&g>0?g:null,j=`(SELECT COUNT(*) FROM project_participants pp
                            WHERE pp.project_id = d.project_id AND pp.party_type = 'client'
                              AND pp.can_message = 1 AND pp.client_user_id IS NOT NULL)`,n=[],o=[];"shared"===d&&n.push("d.is_client_visible = 1"),"internal"===d&&n.push("d.is_client_visible = 0"),"orphan"===d&&n.push(`d.is_client_visible = 1 AND ${j} = 0`),null!==f&&(n.push("d.doc_type = ?"),o.push(f)),null!==h&&(n.push("d.project_id = ?"),o.push(h)),0===n.length&&n.push("1 = 1");let p="internal"===d?"d.uploaded_at DESC, d.id DESC":"d.shared_at DESC, d.uploaded_at DESC, d.id DESC",q=(await (0,i.P)(`SELECT d.id, d.doc_type, d.title, d.revision, d.notes, d.file_path, d.file_name,
              d.mime_type, d.file_size, d.is_client_visible, d.shared_by, d.uploaded_by,
              DATE_FORMAT(d.shared_at, '%Y-%m-%d %H:%i')   AS shared_at,
              DATE_FORMAT(d.uploaded_at, '%Y-%m-%d %H:%i') AS uploaded_at,
              ${j} AS client_accounts,
              p.id AS project_id, p.project_no, p.title AS project_title, p.client, p.phase,
              p.status AS project_status
         FROM project_documents d
         JOIN projects p ON p.id = d.project_id
        WHERE ${n.join(" AND ")}
        ORDER BY ${p}
        LIMIT 300`,o)).map(a=>({...a,download_url:`/api/admin/operations/files/${a.file_path}`})),[r]=await (0,i.P)(`SELECT COUNT(*) AS total,
              SUM(CASE WHEN d.is_client_visible = 1 THEN 1 ELSE 0 END) AS shared,
              SUM(CASE WHEN d.is_client_visible = 0 THEN 1 ELSE 0 END) AS internal,
              COALESCE(SUM(d.file_size), 0) AS bytes,
              COUNT(DISTINCT d.project_id) AS projects,
              SUM(CASE WHEN d.is_client_visible = 1
                        AND d.shared_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
                       THEN 1 ELSE 0 END) AS shared_last_30_days
         FROM project_documents d`),[s]=await (0,i.P)(`SELECT COUNT(*) AS n, COUNT(DISTINCT d.project_id) AS projects
         FROM project_documents d
        WHERE d.is_client_visible = 1
          AND (SELECT COUNT(*) FROM project_participants pp
                WHERE pp.project_id = d.project_id AND pp.party_type = 'client'
                  AND pp.can_message = 1 AND pp.client_user_id IS NOT NULL) = 0`),t=await (0,i.P)(`SELECT cu.id AS client_user_id, cu.company_name, cu.email,
              COUNT(DISTINCT d.id) AS shared_count,
              COUNT(DISTINCT d.project_id) AS project_count,
              DATE_FORMAT(MAX(d.shared_at), '%Y-%m-%d') AS last_shared
         FROM project_participants pp
         JOIN client_users cu ON cu.id = pp.client_user_id
         JOIN project_documents d ON d.project_id = pp.project_id AND d.is_client_visible = 1
        WHERE pp.party_type = 'client' AND pp.can_message = 1 AND pp.client_user_id IS NOT NULL
        GROUP BY cu.id, cu.company_name, cu.email
        ORDER BY shared_count DESC, cu.company_name ASC
        LIMIT 50`),u=await (0,i.P)(`SELECT p.id, p.project_no, p.title, p.client, p.phase, p.percent_complete,
              DATE_FORMAT(p.end_date, '%Y-%m-%d') AS end_date,
              (SELECT COUNT(*) FROM project_participants pp
                WHERE pp.project_id = p.id AND pp.party_type = 'client'
                  AND pp.can_message = 1 AND pp.client_user_id IS NOT NULL) AS client_accounts
         FROM projects p
        WHERE p.status <> 'completed'
          AND NOT EXISTS (SELECT 1 FROM project_documents d WHERE d.project_id = p.id)
        ORDER BY FIELD(p.phase, 'closing', 'monitoring', 'executing', 'planning', 'initiation'),
                 p.created_at DESC
        LIMIT 50`),v=await (0,i.P)(`SELECT p.id, p.project_no, p.title
         FROM projects p
        WHERE EXISTS (SELECT 1 FROM project_documents d WHERE d.project_id = p.id)
        ORDER BY p.project_no ASC`);return b.status(200).json({success:!0,data:q,summary:r,orphans:{count:Number(s?.n||0),projects:Number(s?.projects||0)},by_client:t,no_documents:u,projects:v,view:d,filters:{type:f,project:h}})}catch(a){return console.error("Shared documents board error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the documents"})}}}var o=c(58112),p=c(18766);let q=(0,h.M)(d,"default"),r=(0,h.M)(d,"config"),s=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/projects/documents",pathname:"/api/admin/operations/projects/documents",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function t(a,b,c){let d=await s.prepare(a,b,{srcPage:"/api/admin/operations/projects/documents"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,o.getTracer)(),e=d.getActiveScopeSpan(),j=s.instrumentationOnRequestError.bind(s),k=async e=>s.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:s.isDev,page:"/api/admin/operations/projects/documents",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==p.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(p.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:o.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(s.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,1129],()=>b(b.s=52912));module.exports=c})();