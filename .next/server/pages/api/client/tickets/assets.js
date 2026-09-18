"use strict";(()=>{var a={};a.id=1536,a.ids=[1536],a.modules={3498:a=>{a.exports=require("mysql2/promise")},20347:(a,b,c)=>{c.d(b,{I:()=>e});var d=c(88251);async function e(a){let b=function(a){let b=a.cookies?.session_token;if("string"==typeof b&&b)return b;let c=a.query?.hash;return"string"==typeof c&&c?c:""}(a);if(!b)return null;let c=await (0,d.P)(`SELECT s.client_id, c.*
       FROM admin_sessions s
       JOIN client_users c ON s.client_id = c.id
      WHERE s.hash = ? AND s.user_type = 'client' AND s.expires_at > NOW()`,[b]);return c&&c.length>0?c[0]:null}},21674:(a,b,c)=>{c.d(b,{k:()=>e});let d=`
  SELECT o.asset_id, o.ends_on
    FROM asset_obligations o
  UNION ALL
  SELECT ai.id AS asset_id,
         DATE_ADD(ti.handover_date, INTERVAL ti.dlp_months MONTH) AS ends_on
    FROM assets ai
    JOIN tenders ti ON ti.id = ai.tender_id
   WHERE ti.handover_date IS NOT NULL
     AND ti.dlp_months IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM asset_obligations od
                      WHERE od.asset_id = ai.id AND od.kind = 'dlp')`;function e(a,b){return`(SELECT MAX(${b}.ends_on) FROM (${d}) ${b}
            WHERE ${b}.asset_id = ${a}.id)`}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},96337:(a,b,c)=>{c.r(b),c.d(b,{config:()=>p,default:()=>o,handler:()=>r});var d={};c.r(d),c.d(d,{default:()=>l});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(20347),k=c(21674);async function l(a,b){b.setHeader("Cache-Control","no-store");let c=await (0,j.I)(a);if(!c)return b.status(401).json({error:"Unauthorized. Please login."});if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({error:"Method not allowed"});try{let d=Number(c.client_id),e=Number(a.query.tender_id),f=Number.isInteger(e)&&e>0?e:null,g=["a.holder = 'external'","a.client_id = ?"],h=[d];f&&(g.push("a.tender_id = ?"),h.push(f)),g.push("a.status NOT IN ('disposed', 'lost')");let j=await (0,i.P)(`SELECT a.id, a.asset_no, a.name, a.serial_no, a.tag_no, a.status,
              COALESCE(st.name, a.site_name) AS site,
              a.tender_id, t.ref_no AS tender_ref,
              -- Cover: the latest obligation on the unit, and the DLP inherited from the award
              -- where the unit carries no dlp row of its own. One definition, in
              -- @/lib/asset-cover-sql, shared with the admin register.
              --
              -- DATE_FORMAT, never the raw DATE. mysql2 returns a Date and serialising it converts
              -- to UTC, so at UTC+8 a cover date of the 10th is served as the 9th.
              DATE_FORMAT(${(0,k.k)("a","cu")}, '%Y-%m-%d') AS cover_until
         FROM assets a
         LEFT JOIN asset_sites st ON st.id = a.site_id
         LEFT JOIN tenders     t  ON t.id = a.tender_id
        WHERE ${g.join(" AND ")}
        -- By NAME, not by asset_no. The identifier is a 12-character random ID now, so alphabetical
        -- order over it is meaningless; a client picking their own equipment out of a list reads the
        -- name. a.id behind it keeps the order stable when two units share a name.
        -- NO BACKTICKS ANYWHERE IN THIS COMMENT: the statement is a template literal.
        ORDER BY a.name ASC, a.id ASC`,h),l=await (0,i.P)(`SELECT DISTINCT t.id, t.ref_no, t.title
         FROM tenders t
         JOIN assets a ON a.tender_id = t.id
        WHERE a.client_id = ? AND a.holder = 'external'
        ORDER BY t.ref_no ASC`,[d]);return b.status(200).json({success:!0,assets:j,tenders:l,reason:0===j.length?f?"No equipment is recorded against that contract on your account.":"No equipment is recorded on your account yet. You can still submit a report — choose a priority other than Urgent and describe the problem.":null})}catch(a){return console.error("Error in client ticket assets API:",a),b.status(500).json({error:"Server error",details:a instanceof Error?a.message:"Unknown error"})}}var m=c(58112),n=c(18766);let o=(0,h.M)(d,"default"),p=(0,h.M)(d,"config"),q=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/client/tickets/assets",pathname:"/api/client/tickets/assets",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function r(a,b,c){let d=await q.prepare(a,b,{srcPage:"/api/client/tickets/assets"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,m.getTracer)(),e=d.getActiveScopeSpan(),j=q.instrumentationOnRequestError.bind(q),k=async e=>q.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:q.isDev,page:"/api/client/tickets/assets",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==n.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(n.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:m.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(q.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=96337));module.exports=c})();