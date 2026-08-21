"use strict";(()=>{var a={};a.id=1536,a.ids=[1536],a.modules={3498:a=>{a.exports=require("mysql2/promise")},20347:(a,b,c)=>{c.d(b,{I:()=>e});var d=c(88251);async function e(a){let b=function(a){let b=a.cookies?.session_token;if("string"==typeof b&&b)return b;let c=a.query?.hash;return"string"==typeof c&&c?c:""}(a);if(!b)return null;let c=await (0,d.P)(`SELECT s.client_id, c.*
       FROM admin_sessions s
       JOIN client_users c ON s.client_id = c.id
      WHERE s.hash = ? AND s.user_type = 'client' AND s.expires_at > NOW()`,[b]);return c&&c.length>0?c[0]:null}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},96337:(a,b,c)=>{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>q});var d={};c.r(d),c.d(d,{default:()=>k});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(20347);async function k(a,b){b.setHeader("Cache-Control","no-store");let c=await (0,j.I)(a);if(!c)return b.status(401).json({error:"Unauthorized. Please login."});if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({error:"Method not allowed"});try{let d=Number(c.client_id),e=Number(a.query.tender_id),f=Number.isInteger(e)&&e>0?e:null,g=["a.holder = 'external'","a.client_id = ?"],h=[d];f&&(g.push("a.tender_id = ?"),h.push(f)),g.push("a.status NOT IN ('disposed', 'lost')");let j=await (0,i.P)(`SELECT a.id, a.asset_no, a.name, a.serial_no, a.tag_no, a.status,
              COALESCE(st.name, a.site_name) AS site,
              a.tender_id, t.ref_no AS tender_ref,
              -- DATE_FORMAT, never the raw DATE. mysql2 returns a Date and serialising it converts
              -- to UTC, so at UTC+8 a cover date of the 10th is served as the 9th.
              DATE_FORMAT((
                SELECT MAX(x.ends_on) FROM (
                  SELECT o.ends_on
                    FROM asset_obligations o
                   WHERE o.asset_id = a.id
                  UNION ALL
                  -- The DLP inherited from the award. Suppressed where the asset carries its own
                  -- dlp row, which overrides it.
                  SELECT DATE_ADD(t2.handover_date, INTERVAL t2.dlp_months MONTH)
                    FROM tenders t2
                   WHERE t2.id = a.tender_id
                     AND t2.handover_date IS NOT NULL
                     AND t2.dlp_months IS NOT NULL
                     AND NOT EXISTS (
                       SELECT 1 FROM asset_obligations o2
                        WHERE o2.asset_id = a.id AND o2.kind = 'dlp'
                     )
                ) x
              ), '%Y-%m-%d') AS cover_until
         FROM assets a
         LEFT JOIN asset_sites st ON st.id = a.site_id
         LEFT JOIN tenders     t  ON t.id = a.tender_id
        WHERE ${g.join(" AND ")}
        ORDER BY a.asset_no ASC`,h),k=await (0,i.P)(`SELECT DISTINCT t.id, t.ref_no, t.title
         FROM tenders t
         JOIN assets a ON a.tender_id = t.id
        WHERE a.client_id = ? AND a.holder = 'external'
        ORDER BY t.ref_no ASC`,[d]);return b.status(200).json({success:!0,assets:j,tenders:k,reason:0===j.length?f?"No equipment is recorded against that contract on your account.":"No equipment is recorded on your account yet. You can still submit a report — choose a priority other than Urgent and describe the problem.":null})}catch(a){return console.error("Error in client ticket assets API:",a),b.status(500).json({error:"Server error",details:a instanceof Error?a.message:"Unknown error"})}}var l=c(58112),m=c(18766);let n=(0,h.M)(d,"default"),o=(0,h.M)(d,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/client/tickets/assets",pathname:"/api/client/tickets/assets",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function q(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/client/tickets/assets"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,l.getTracer)(),e=d.getActiveScopeSpan(),j=p.instrumentationOnRequestError.bind(p),k=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/client/tickets/assets",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==m.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(m.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:l.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=96337));module.exports=c})();