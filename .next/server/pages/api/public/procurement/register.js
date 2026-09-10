"use strict";(()=>{var a={};a.id=4501,a.ids=[4501],a.modules={3498:a=>{a.exports=require("mysql2/promise")},21572:a=>{a.exports=require("nodemailer")},29021:a=>{a.exports=require("fs")},33873:a=>{a.exports=require("path")},40880:(a,b,c)=>{c.a(a,async(a,d)=>{try{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>m});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(68771),j=c(58112),k=c(18766),l=a([i]);i=(l.then?(await l)():l)[0];let n=(0,h.M)(i,"default"),o=(0,h.M)(i,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/public/procurement/register",pathname:"/api/public/procurement/register",bundlePath:"",filename:""},userland:i,distDir:".next",relativeProjectDir:""});async function m(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/public/procurement/register"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,j.getTracer)(),e=d.getActiveScopeSpan(),l=p.instrumentationOnRequestError.bind(p),m=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/public/procurement/register",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>l(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==k.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await m(e):await d.withPropagatedContext(a.headers,()=>d.trace(k.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:j.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},m))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}d()}catch(a){d(a)}})},46898:(a,b,c)=>{c.d(b,{Bu:()=>h,JQ:()=>j,S6:()=>f,VN:()=>g,yY:()=>i});var d=c(88251);let e=["service_civil","service_mne","service_ict","service_pmc","service_trading","service_others"];async function f(){return await (0,d.P)(`SELECT id, name, legacy_key, sort_order, is_active
       FROM procurement_categories
      ORDER BY sort_order ASC, name ASC`)}async function g(){return await (0,d.P)(`SELECT id, name, legacy_key, sort_order, is_active
       FROM procurement_categories
      WHERE is_active = 1
      ORDER BY sort_order ASC, name ASC`)}function h(a,b){let c=new Map(b.map(a=>[a.name.toLowerCase(),a.name])),d=Array.isArray(a)?a:"string"==typeof a?a.split(","):[],e=[];for(let a of d){let b=c.get(String(a??"").trim().toLowerCase());b&&!e.includes(b)&&e.push(b)}return e}function i(a,b){let c=Object.fromEntries(e.map(a=>[a,"No"])),d=new Map(b.map(a=>[a.name,a.legacy_key]));for(let b of a){let a=d.get(b);a&&e.includes(a)&&(c[a]="Yes")}return c}function j(a){let b="string"==typeof a.services?a.services.trim():"";if(b)return b.split(",").map(a=>a.trim()).filter(Boolean);let c={service_civil:"Civil Engineering",service_mne:"Mechanical & Electrical Engineering",service_ict:"ICT Engineering",service_pmc:"Project Management & Consultancy",service_trading:"General Trading",service_others:"Others"};return e.filter(b=>"Yes"===a[b]).map(a=>c[a])}},55511:a=>{a.exports=require("crypto")},67313:a=>{a.exports=import("formidable")},68771:(a,b,c)=>{c.a(a,async(a,d)=>{try{c.r(b),c.d(b,{config:()=>p,default:()=>o});var e=c(67313),f=c(88251),g=c(79748),h=c(33873),i=c(29021),j=c(2066),k=c(2922),l=c(13813),m=c(46898),n=a([e]);e=(n.then?(await n)():n)[0];let p={api:{bodyParser:!1}};async function o(a,b){if("POST"!==a.method)return b.status(405).json({success:!1,message:"Method not allowed"});try{let c=(0,h.join)(process.cwd(),"public","uploads","procurement");(0,i.existsSync)(c)||await (0,g.mkdir)(c,{recursive:!0});let d=(0,e.default)({uploadDir:c,keepExtensions:!0,maxFileSize:0xa00000,multiples:!0}),[n,o]=await new Promise((b,c)=>{d.parse(a,(a,d,e)=>{a?c(a):b([d,e])})}),p=a=>{let b=n[a];return Array.isArray(b)?b[0]||null:b||null},q=function(){let a=Date.now().toString().slice(-8),b=Math.floor(1e3*Math.random()).toString().padStart(3,"0");return`PROC-${a}-${b}`}(),r=a=>{let b=o[a];if(!b)return null;let c=Array.isArray(b)?b[0]:b;return c&&c.size>0?(0,h.basename)(c.filepath):null},s={doc_ssm:r("doc_ssm"),doc_profile:r("doc_profile"),doc_mof:r("doc_mof"),doc_cidb:r("doc_cidb"),doc_financial:r("doc_financial"),doc_bank:r("doc_bank")},t=o.doc_others;t&&(s.doc_others=(Array.isArray(t)?t:[t]).filter(a=>a&&a.size>0).map(a=>(0,h.basename)(a.filepath)));let u=await (0,m.VN)(),v=void 0!==n.services?Array.isArray(n.services)?n.services:[n.services]:u.filter(a=>a.legacy_key&&"on"===p(a.legacy_key)).map(a=>a.name),w=(0,m.Bu)(v,u),x=(0,m.yY)(w,u);await (0,f.P)(`INSERT INTO procurement_applications (
        application_no, company_name, ssm_number, company_type, incorporation_date,
        business_address, city, state, postcode, office_phone, mobile_phone, email, website,
        mof_number, cidb_number, cidb_grade, bumiputera_status, paid_up_capital,
        num_employees, annual_turnover, years_in_business,
        bank_name, bank_account_number, bank_account_name,
        service_civil, service_mne, service_ict, service_pmc, service_trading, service_others,
        services,
        nature_of_business, products_services,
        director_name, director_ic, director_position, director_contact,
        attachments, status, submitted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,[q,p("company_name"),p("ssm_number"),p("company_type"),p("incorporation_date"),p("business_address"),p("city"),p("state"),p("postcode"),p("office_phone"),p("mobile_phone"),p("email"),p("website"),p("mof_number"),p("cidb_number"),p("cidb_grade"),p("bumiputera_status"),p("paid_up_capital"),p("num_employees"),p("annual_turnover"),p("years_in_business"),p("bank_name"),p("bank_account_number"),p("bank_account_name"),x.service_civil,x.service_mne,x.service_ict,x.service_pmc,x.service_trading,x.service_others,w.join(", "),p("nature_of_business"),p("products_services"),p("director_name"),p("director_ic"),p("director_position"),p("director_contact"),JSON.stringify(s),"pending"]);let y=await (0,k.it)("procurement"),z=y.email_profile||"hr",A=(y.cc_email||"").trim()||"hr@ansartechnologies.my",B=`
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 800px; margin: 0 auto; padding: 20px; }
    .header { background-color: #007bff; color: white; padding: 20px; text-align: center; }
    .section { margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-left: 4px solid #007bff; }
    .section h2 { margin-top: 0; color: #007bff; font-size: 18px; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 8px; border-bottom: 1px solid #ddd; }
    td:first-child { font-weight: bold; width: 40%; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>New Supplier Registration</h1>
      <p>Application No: ${q}</p>
    </div>

    <div class="section">
      <h2>📋 Company Information</h2>
      <table>
        <tr><td>Company Name</td><td>${p("company_name")}</td></tr>
        <tr><td>SSM Number</td><td>${p("ssm_number")}</td></tr>
        <tr><td>Email</td><td>${p("email")}</td></tr>
        <tr><td>Phone</td><td>${p("office_phone")}</td></tr>
        <tr><td>City, State</td><td>${p("city")}, ${p("state")}</td></tr>
      </table>
    </div>

    <div class="section">
      <h2>🔧 Services Interested</h2>
      <ul>
        ${w.length>0?w.map(a=>`<li>${a}</li>`).join(""):"<li>None selected</li>"}
      </ul>
    </div>

    <div style="margin-top: 30px; padding: 15px; background-color: #d1ecf1; border-left: 4px solid #0dcaf0;">
      <p><strong>📝 Action Required:</strong> Please review this application in the Procurement Management system.</p>
      <p>Documents have been uploaded and stored in the system.</p>
    </div>

    <div style="margin-top: 20px; text-align: center; color: #666; font-size: 12px;">
      <p>Submitted on: ${new Date().toLocaleString("en-MY",{timeZone:"Asia/Kuala_Lumpur"})}</p>
    </div>
  </div>
</body>
</html>
    `;try{await (0,j.OT)(z,{to:A,subject:`New Supplier Registration: ${p("company_name")} (${q})`,html:B})}catch(a){console.error("Email notification error:",a)}let C=`
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #007bff 0%, #0056b3 100%); color: white; padding: 40px 20px; text-align: center; }
    .content { padding: 30px 20px; background-color: #ffffff; }
    .success-icon { text-align: center; margin: 20px 0; }
    h2 { color: #007bff; text-align: center; }
    .info-box { background-color: #f8f9fa; border-left: 4px solid #007bff; padding: 15px; margin: 20px 0; }
    .footer { background-color: #343a40; color: #ffffff; padding: 20px; text-align: center; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>ANSAR TECHNOLOGIES SDN. BHD.</h1>
      <p>Procurement Portal</p>
    </div>

    <div class="content">
      <h2>✓ Registration Received Successfully!</h2>
      
      <p>Dear <strong>${p("company_name")}</strong>,</p>
      
      <p>Thank you for your interest in becoming a registered supplier with ANSAR TECHNOLOGIES SDN. BHD.</p>
      
      <div class="info-box">
        <p><strong>Application No:</strong> ${q}</p>
        <p><strong>Submitted:</strong> ${new Date().toLocaleString("en-MY",{timeZone:"Asia/Kuala_Lumpur"})}</p>
      </div>

      <p>Our procurement team will review your application within 5-7 working days. You will be notified via email once the review is complete.</p>

      <p style="color: #666; font-size: 13px; margin-top: 30px;">
        <strong>Need assistance?</strong> Contact us at hr@ansartechnologies.my or call 03-8959 0530.
      </p>
    </div>

    <div class="footer">
      <p><strong>ANSAR TECHNOLOGIES SDN. BHD.</strong></p>
      <p style="font-size: 11px;">( 940482-W / 201101012342 )</p>
      <p>\xa9 ${new Date().getFullYear()} ANSAR TECHNOLOGIES. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    `;try{await (0,j.OT)(z,{to:p("email"),subject:"Registration Confirmed - ANSAR TECHNOLOGIES Supplier Portal",html:C})}catch(a){console.error("Client email error:",a)}return await (0,l.hc)({module:"procurement",reference:q,currentLevel:0,requestedBy:String(p("company_name")||""),summary:`Supplier registration from ${p("company_name")}.`,whereToAct:"Application > Procurement"}),b.status(200).json({success:!0,message:"Registration submitted successfully",application_no:q})}catch(a){return console.error("Procurement registration error:",a),b.status(500).json({success:!1,message:a instanceof Error?a.message:"Failed to process registration"})}}d()}catch(a){d(a)}})},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},79748:a=>{a.exports=require("fs/promises")}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,2816,3813],()=>b(b.s=40880));module.exports=c})();