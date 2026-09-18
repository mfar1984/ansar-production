"use strict";(()=>{var a={};a.id=4643,a.ids=[4643],a.modules={3498:a=>{a.exports=require("mysql2/promise")},57381:(a,b,c)=>{c.r(b),c.d(b,{config:()=>t,default:()=>s,handler:()=>v});var d={};c.r(d),c.d(d,{default:()=>p});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(96543),l=c(95514),m=c(92102);let n={internal:"assets_internal",external:"assets_external"},o=`a.holder = ?
                AND a.status NOT IN ('disposed', 'lost')`;async function p(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=String(a.query.holder||"internal");if(!l.F7.includes(d))return b.status(400).json({success:!1,error:"Unknown register."});let e=n[d];try{if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});if(!(0,j.OD)(c,b,e,"view"))return;if("1"===String(a.query.options||"")){let[a,c]=await Promise.all([(0,i.P)(`SELECT a.id, a.asset_no, a.name, a.category, a.location, a.site_name
             FROM assets a
            WHERE ${o}
            ORDER BY a.asset_no ASC`,[d]),(0,i.P)(`SELECT id, vendor_no, name FROM vendors
            WHERE status = 'active' AND kind = 'company'
            ORDER BY name ASC`)]),e=await (0,m.g)();return b.status(200).json({success:!0,assets:a,vendors:c,repair_categories:e})}let f=["a.holder = ?"],g=[d],h=(0,k.gx)(a.query.kind,60);if(h){let a=await (0,i.P)("SELECT id FROM asset_repair_categories WHERE name = ? LIMIT 1",[h]);if(0===a.length)return b.status(400).json({success:!1,error:"Unknown service kind."});f.push("m.kind = ?"),g.push(h)}let l=(0,k.gx)(a.query.state,20);"overdue"===l?f.push("m.next_due IS NOT NULL AND m.next_due < CURDATE()"):"due_30"===l?f.push("m.next_due IS NOT NULL AND m.next_due >= CURDATE() AND m.next_due <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)"):"scheduled"===l?f.push("m.next_due IS NOT NULL"):"unscheduled"===l&&f.push("m.next_due IS NULL");let n=(0,k.gx)(a.query.from,10);n&&(f.push("m.service_date >= ?"),g.push(n));let p=(0,k.gx)(a.query.to,10);p&&(f.push("m.service_date <= ?"),g.push(p));let q=(0,k.gx)(a.query.q,120);if(q){f.push("(a.asset_no LIKE ? OR a.name LIKE ? OR m.summary LIKE ? OR m.performed_by LIKE ? OR v.name LIKE ?)");let a=`%${q}%`;g.push(a,a,a,a,a)}let r=`WHERE ${f.join(" AND ")}`,s=Math.max(1,Number(a.query.page)||1),t=Math.min(100,Math.max(1,Number(a.query.per_page)||100)),u=(s-1)*t,v=await (0,i.P)(`SELECT m.id, m.asset_id, m.kind,
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
         ${r}
        ORDER BY m.service_date DESC, m.id DESC
        LIMIT ${t} OFFSET ${u}`,g),w=await (0,i.P)(`SELECT COUNT(*) AS total
         FROM asset_maintenance m
         JOIN assets a       ON a.id = m.asset_id
         LEFT JOIN vendors v ON v.id = m.vendor_id
         ${r}`,g),x=await (0,i.P)(`SELECT
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
           WHERE a6.holder = ?)                                             AS all_records`,[d,d,d,d,d]);return b.status(200).json({success:!0,data:v,page:s,per_page:t,total:Number(w[0]?.total||0),summary:{overdue_assets:Number(x[0]?.overdue_assets||0),due_30_assets:Number(x[0]?.due_30_assets||0),services_ytd:Number(x[0]?.services_ytd||0),cost_ytd:Number(x[0]?.cost_ytd||0),all_records:Number(x[0]?.all_records||0)}})}catch(a){return console.error("Asset maintenance error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load service records"})}}var q=c(58112),r=c(18766);let s=(0,h.M)(d,"default"),t=(0,h.M)(d,"config"),u=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets/maintenance",pathname:"/api/admin/operations/assets/maintenance",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function v(a,b,c){let d=await u.prepare(a,b,{srcPage:"/api/admin/operations/assets/maintenance"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,q.getTracer)(),e=d.getActiveScopeSpan(),j=u.instrumentationOnRequestError.bind(u),k=async e=>u.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:u.isDev,page:"/api/admin/operations/assets/maintenance",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==r.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(r.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:q.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(u.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514,5208],()=>b(b.s=57381));module.exports=c})();