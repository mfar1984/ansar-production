"use strict";(()=>{var a={};a.id=1099,a.ids=[1099],a.modules={3498:a=>{a.exports=require("mysql2/promise")},55511:a=>{a.exports=require("crypto")},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},96811:(a,b,c)=>{c.r(b),c.d(b,{config:()=>t,default:()=>s,handler:()=>v});var d={};c.r(d),c.d(d,{default:()=>p});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(55511),j=c.n(i),k=c(88251),l=c(18692);function m(a){return a.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function n(a,b,c){return`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>EasyParcel</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center;
         justify-content: center; background: #f9fafb;
         font-family: 'Inter','Segoe UI',system-ui,sans-serif; color: #1f2937; }
  .card { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px;
          padding: 28px 32px; max-width: 460px; box-shadow: 0 1px 2px rgba(0,0,0,.04); }
  .mark { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center;
          justify-content: center; color: #fff; font-size: 20px; background: ${a?"#059669":"#dc2626"};
          margin-bottom: 16px; }
  h1 { font-size: 15px; margin: 0 0 8px; }
  p  { font-size: 13px; line-height: 1.55; margin: 0 0 10px; color: #6b7280; }
  .hint { font-size: 11.5px; color: #9ca3af; }
</style>
</head>
<body>
  <div class="card">
    <div class="mark">${a?"&#10003;":"&#33;"}</div>
    <h1>${m(b)}</h1>
    <p>${m(c)}</p>
    <p class="hint" id="hint">You can close this window.</p>
  </div>
<script>
  (function () {
    /* Same origin as the settings tab, because the redirect URI is on this host. The tab
       listens for this and reloads its own state, so the operator never leaves the screen. */
    try {
      if (window.opener && !window.opener.closed) {
        window.opener.postMessage(
          { source: 'ansar-easyparcel', ok: ${a?"true":"false"} },
          window.location.origin
        );
        setTimeout(function () { window.close(); }, ${a?"1200":"4000"});
        return;
      }
    } catch (e) { /* a closed or cross-origin opener is not an error worth showing */ }
    document.getElementById('hint').textContent =
      'Return to Settings \\u203A Integration \\u203A EasyParcel and reload the page.';
  }());
</script>
</body>
</html>`}function o(a,b,c){a.setHeader("Content-Type","text/html; charset=utf-8"),a.setHeader("Cache-Control","no-store"),a.setHeader("Content-Security-Policy","default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'"),a.setHeader("X-Frame-Options","DENY"),a.status(b).send(c)}async function p(a,b){if("GET"!==a.method)return b.setHeader("Allow","GET"),o(b,405,n(!1,"Not allowed","This address is only reached by a redirect from EasyParcel."));let c=String(a.query.code??"").trim(),d=String(a.query.state??"").trim();try{let e=await (0,l.Xg)();if(!e)return o(b,503,n(!1,"Not configured","The EasyParcel configuration row does not exist on this server, so there is nothing to connect. Apply database/easyparcel_integration.sql."));let f=String(e.oauth_state??""),g=e.oauth_state_at?new Date(e.oauth_state_at).getTime():0;if(await (0,k.P)("UPDATE easyparcel_integration SET oauth_state = NULL, oauth_state_at = NULL WHERE id = 1"),!f)return o(b,400,n(!1,"Nothing was waiting for this","No authorization was in progress — this link has already been used, or it was opened without pressing Connect first. Open Settings, Integration, EasyParcel and press Connect."));if(!Number.isFinite(g)||Date.now()-g>l.Ak)return o(b,400,n(!1,"This took too long",`The authorization attempt expired after ${l.Ak/6e4} minutes. Press Connect again — nothing has changed.`));if(!function(a,b){if(!a||!b||a.length!==b.length)return!1;try{return j().timingSafeEqual(Buffer.from(a),Buffer.from(b))}catch{return!1}}(d,f))return console.warn("[integration/easyparcel/callback] state mismatch — request rejected"),o(b,400,n(!1,"This request could not be verified","The security token did not match the one this server issued. Go back to Settings, Integration, EasyParcel and press Connect again."));if(!c){let c=String(a.query.error_description??a.query.error??"").trim();return o(b,400,n(!1,"EasyParcel did not return an authorization",c||"The approval was cancelled or refused, so nothing has been connected."))}let h=String(e.updated_by??"").trim()||"an administrator";await (0,l.rW)(e,c,h);let i=await (0,l.Xg)(),m=i?.account_label?` as ${i.account_label}`:"";return o(b,200,n(!0,"EasyParcel connected",`This system can now price and book parcels through EasyParcel${m}. Check the account name on the settings screen — it is what tells you whether a demo or a live account was linked.`))}catch(c){let a=c instanceof Error?c.message:"Unknown error";return console.error("[integration/easyparcel/callback]",a),o(b,500,n(!1,"The connection could not be completed",a))}}var q=c(58112),r=c(18766);let s=(0,h.M)(d,"default"),t=(0,h.M)(d,"config"),u=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/integration/easyparcel/callback",pathname:"/api/admin/integration/easyparcel/callback",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function v(a,b,c){let d=await u.prepare(a,b,{srcPage:"/api/admin/integration/easyparcel/callback"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,q.getTracer)(),e=d.getActiveScopeSpan(),j=u.instrumentationOnRequestError.bind(u),k=async e=>u.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:u.isDev,page:"/api/admin/integration/easyparcel/callback",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==r.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(r.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:q.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(u.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,8692],()=>b(b.s=96811));module.exports=c})();