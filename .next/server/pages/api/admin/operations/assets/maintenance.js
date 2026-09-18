"use strict";(()=>{var a={};a.id=4643,a.ids=[4643],a.modules={3498:a=>{a.exports=require("mysql2/promise")},11163:(a,b,c)=>{function d(a){let b=Number(a);return Number.isInteger(b)&&b>0?b:null}c.d(b,{Z7:()=>e,kC:()=>d,m6:()=>f});let e="m.batch_id = ?";function f(a,b){return`${b} — ${a}`.slice(0,200)}},57381:(a,b,c)=>{c.r(b),c.d(b,{config:()=>u,default:()=>t,handler:()=>w});var d={};c.r(d),c.d(d,{default:()=>q});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(96543),l=c(95514),m=c(92102),n=c(11163);let o={internal:"assets_internal",external:"assets_external"},p=`a.holder = ?
                AND a.status NOT IN ('disposed', 'lost')`;async function q(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=String(a.query.holder||"internal");if(!l.F7.includes(d))return b.status(400).json({success:!1,error:"Unknown register."});let e=o[d];try{if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if(!(0,j.OD)(c,b,e,"view"))return;if("1"===String(a.query.options||"")){let[a,c]=await Promise.all([(0,i.P)(`SELECT a.id, a.asset_no, a.name, a.category, a.location, a.site_name
             FROM assets a
            WHERE ${p}
            ORDER BY a.asset_no ASC`,[d]),(0,i.P)(`SELECT id, vendor_no, name FROM vendors
            WHERE status = 'active' AND kind = 'company'
            ORDER BY name ASC`)]),e=await (0,m.g)();return b.status(200).json({success:!0,assets:a,vendors:c,repair_categories:e})}let f=["a.holder = ?"],g=[d],h=async a=>(await (0,i.P)("SELECT id FROM asset_repair_categories WHERE name = ? LIMIT 1",[a])).length>0,l=(0,k.gx)(a.query.kind,60);if(l){if(!await h(l))return b.status(400).json({success:!1,error:"Unknown service kind."});f.push("m.kind = ?"),g.push(l)}let o=(0,k.gx)(a.query.state,20);"overdue"===o?f.push("m.next_due IS NOT NULL AND m.next_due < CURDATE()"):"due_30"===o?f.push("m.next_due IS NOT NULL AND m.next_due >= CURDATE() AND m.next_due <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)"):"scheduled"===o?f.push("m.next_due IS NOT NULL"):"unscheduled"===o&&f.push("m.next_due IS NULL");let q=(0,k.gx)(a.query.from,10);q&&(f.push("m.service_date >= ?"),g.push(q));let r=(0,k.gx)(a.query.to,10);r&&(f.push("m.service_date <= ?"),g.push(r));let s=(0,k.gx)(a.query.q,120);if(s){f.push("(a.asset_no LIKE ? OR a.name LIKE ? OR m.summary LIKE ? OR m.performed_by LIKE ? OR v.name LIKE ?)");let a=`%${s}%`;g.push(a,a,a,a,a)}let t=(0,n.kC)(a.query.round);if(void 0!==a.query.round&&null===t)return b.status(400).json({success:!1,error:"That round is not a valid reference."});null!==t&&(f.push(n.Z7),g.push(t));let u=`WHERE ${f.join(" AND ")}`,v=Math.max(1,Number(a.query.page)||1),w=Math.min(100,Math.max(1,Number(a.query.per_page)||100)),x=(v-1)*w,y=async()=>{let a=await (0,i.P)(`SELECT
           (SELECT COUNT(DISTINCT a2.id)
              FROM assets a2
              JOIN asset_maintenance m2 ON m2.asset_id = a2.id
             WHERE a2.holder = ? AND m2.next_due IS NOT NULL
               AND m2.next_due < CURDATE())                                    AS overdue_assets,
           (SELECT COUNT(DISTINCT a3.id)
              FROM assets a3
              JOIN asset_maintenance m3 ON m3.asset_id = a3.id
             WHERE a3.holder = ? AND m3.next_due IS NOT NULL
               AND m3.next_due >= CURDATE()
               AND m3.next_due <= DATE_ADD(CURDATE(), INTERVAL 30 DAY))        AS due_30_assets,
           (SELECT COUNT(*)
              FROM asset_maintenance m4
              JOIN assets a4 ON a4.id = m4.asset_id
             WHERE a4.holder = ? AND YEAR(m4.service_date) = YEAR(CURDATE()))  AS services_ytd,
           (SELECT COALESCE(SUM(m5.cost), 0)
              FROM asset_maintenance m5
              JOIN assets a5 ON a5.id = m5.asset_id
             WHERE a5.holder = ? AND YEAR(m5.service_date) = YEAR(CURDATE()))  AS cost_ytd,
           (SELECT COUNT(*)
              FROM asset_maintenance m6
              JOIN assets a6 ON a6.id = m6.asset_id
             WHERE a6.holder = ?)                                             AS all_records`,[d,d,d,d,d]);return{overdue_assets:Number(a[0]?.overdue_assets||0),due_30_assets:Number(a[0]?.due_30_assets||0),services_ytd:Number(a[0]?.services_ytd||0),cost_ytd:Number(a[0]?.cost_ytd||0),all_records:Number(a[0]?.all_records||0)}};if("1"===String(a.query.ids||"")){let a=await (0,i.P)(`SELECT DISTINCT m.asset_id
           FROM asset_maintenance m
           JOIN assets a       ON a.id = m.asset_id
           LEFT JOIN vendors v ON v.id = m.vendor_id
           ${u}`,g);return b.status(200).json({success:!0,asset_ids:a.map(a=>Number(a.asset_id))})}if("1"===String(a.query.group||"")){let a=await (0,i.P)(`SELECT m.batch_id,
                b.title,
                b.recorded_by                                 AS batch_by,
                DATE_FORMAT(b.created_at, '%Y-%m-%d %H:%i')   AS created_at,
                MIN(m.kind)                                   AS kind,
                COUNT(DISTINCT m.kind)                        AS kinds,
                DATE_FORMAT(MIN(m.service_date), '%Y-%m-%d')  AS service_date,
                DATE_FORMAT(MAX(m.service_date), '%Y-%m-%d')  AS service_date_max,
                COUNT(DISTINCT m.service_date)                AS dates,
                MIN(a.client_id)                              AS client_id,
                COUNT(DISTINCT a.client_id)                   AS clients,
                MAX(cu.company_name)                          AS client_name,
                COUNT(*)                                      AS records,
                COUNT(DISTINCT m.asset_id)                    AS assets,
                COUNT(DISTINCT a.site_id)                     AS sites,
                MIN(a.site_name)                              AS site_name,
                MIN(a.asset_no)                               AS first_asset_no,
                COUNT(DISTINCT m.performed_by)                AS engineers,
                MIN(m.performed_by)                           AS performed_by,
                COUNT(DISTINCT m.vendor_id)                   AS vendor_count,
                MIN(m.vendor_id)                              AS vendor_id,
                MIN(v.name)                                   AS vendor_name,
                SUM(m.cost IS NOT NULL)                       AS costed,
                SUM(m.cost)                                   AS cost_total,
                SUM(m.next_due IS NOT NULL)                   AS scheduled,
                DATE_FORMAT(MIN(m.next_due), '%Y-%m-%d')      AS next_due_min,
                DATE_FORMAT(MAX(m.next_due), '%Y-%m-%d')      AS next_due_max,
                COUNT(DISTINCT m.summary)                     AS summaries,
                MIN(m.summary)                                AS summary,
                COUNT(DISTINCT m.ticket_id)                   AS tickets,
                (SELECT COUNT(*) FROM asset_service_batch_files f
                  WHERE f.batch_id = m.batch_id)              AS files
           FROM asset_maintenance m
           JOIN assets a                 ON a.id = m.asset_id
           JOIN asset_service_batches b  ON b.id = m.batch_id
           LEFT JOIN vendors v           ON v.id = m.vendor_id
           LEFT JOIN client_users cu     ON cu.id = a.client_id
           ${u}
          GROUP BY m.batch_id, b.title, b.recorded_by, b.created_at
          ORDER BY MAX(m.service_date) DESC, m.batch_id DESC
          LIMIT ${w} OFFSET ${x}`,g),c=await (0,i.P)(`SELECT COUNT(*) AS total FROM (
           SELECT 1
             FROM asset_maintenance m
             JOIN assets a                ON a.id = m.asset_id
             JOIN asset_service_batches b ON b.id = m.batch_id
             LEFT JOIN vendors v          ON v.id = m.vendor_id
             ${u}
            GROUP BY m.batch_id
         ) g`,g),d=a.map(a=>({...a,round_key:Number(a.batch_id)}));return b.status(200).json({success:!0,data:d,page:v,per_page:w,total:Number(c[0]?.total||0),summary:await y()})}let z=await (0,i.P)(`SELECT m.id, m.asset_id, m.kind,
              -- DATE_FORMAT on every date. mysql2 returns a Date and serialising it converts to
              -- UTC, which at UTC+8 reports the previous day — a service due today would read as
              -- overdue yesterday.
              DATE_FORMAT(m.service_date, '%Y-%m-%d') AS service_date,
              DATE_FORMAT(m.next_due, '%Y-%m-%d')     AS next_due,
              m.performed_by, m.vendor_id, m.cost, m.ticket_id, m.summary, m.recorded_by,
              a.asset_no, a.name AS asset_name, a.category, a.status AS asset_status,
              a.location, a.site_name,
              v.name AS vendor_name,
              t.ticket_no
         FROM asset_maintenance m
         JOIN assets a           ON a.id = m.asset_id
         LEFT JOIN vendors v     ON v.id = m.vendor_id
         LEFT JOIN helpdesk_tickets t ON t.id = m.ticket_id
         ${u}
        ORDER BY m.service_date DESC, m.id DESC
        LIMIT ${w} OFFSET ${x}`,g),A=await (0,i.P)(`SELECT COUNT(*) AS total
         FROM asset_maintenance m
         JOIN assets a       ON a.id = m.asset_id
         LEFT JOIN vendors v ON v.id = m.vendor_id
         ${u}`,g);return b.status(200).json({success:!0,data:z,page:v,per_page:w,total:Number(A[0]?.total||0),...t?{}:{summary:await y()}})}catch(a){return console.error("Asset maintenance error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load service records"})}}var r=c(58112),s=c(18766);let t=(0,h.M)(d,"default"),u=(0,h.M)(d,"config"),v=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets/maintenance",pathname:"/api/admin/operations/assets/maintenance",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function w(a,b,c){let d=await v.prepare(a,b,{srcPage:"/api/admin/operations/assets/maintenance"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,r.getTracer)(),e=d.getActiveScopeSpan(),j=v.instrumentationOnRequestError.bind(v),k=async e=>v.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:v.isDev,page:"/api/admin/operations/assets/maintenance",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==s.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(s.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:r.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(v.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514,8882],()=>b(b.s=57381));module.exports=c})();