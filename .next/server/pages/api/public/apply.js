"use strict";(()=>{var a={};a.id=8609,a.ids=[8609],a.modules={3498:a=>{a.exports=require("mysql2/promise")},4914:(a,b,c)=>{c.d(b,{Do:()=>j});var d=c(88251);let e=new Map;async function f(a,b){try{let c=await (0,d.P)("SELECT api_allowed_origins, api_cors_allow_all FROM integrations WHERE id = 1 LIMIT 1");if(!Array.isArray(c)||0===c.length)return!1;let e=c[0],f=a.headers.origin||"";if(!f&&a.headers.referer)try{let b=new URL(a.headers.referer);f=`${b.protocol}//${b.host}`}catch(a){f=""}if(b.setHeader("Access-Control-Allow-Methods","GET, POST, PUT, DELETE, OPTIONS"),b.setHeader("Access-Control-Allow-Headers","Content-Type, Authorization, X-API-Token"),b.setHeader("Access-Control-Max-Age","86400"),e.api_cors_allow_all)return b.setHeader("Access-Control-Allow-Origin","*"),!0;let g=[];try{let a=JSON.parse(e.api_allowed_origins||"[]");g=Array.isArray(a)&&1===a.length&&a[0].includes(" ")?a[0].split(/\s+/).filter(a=>a.length>0):a}catch{g=[]}if(0===g.length)return!1;if(!f)return b.setHeader("Access-Control-Allow-Origin","*"),!0;if(g.some(a=>{if(a.includes("*")){let b=a.replace(/\*/g,".*").replace(/\./g,"\\.");return RegExp(`^${b}$`).test(f)}return a===f}))return b.setHeader("Access-Control-Allow-Origin",f),!0;return!1}catch(a){return console.error("CORS error:",a),!1}}async function g(a){try{let b=a.headers["x-api-token"]||a.headers.authorization?.replace("Bearer ","");if(!b)return!1;let c=await (0,d.P)("SELECT api_token FROM integrations WHERE id = 1 LIMIT 1");if(!Array.isArray(c)||0===c.length||!c[0].api_token)return!1;if(b===c[0].api_token)return await (0,d.P)("UPDATE integrations SET api_token_last_used = NOW(), api_token_usage_count = api_token_usage_count + 1 WHERE id = 1"),!0;return!1}catch(a){return console.error("Token verification error:",a),!1}}function h(a){let b=a.headers["x-api-token"]||a.headers.authorization?.replace("Bearer ","");if(b)return`token:${b}`;let c=a.headers["x-forwarded-for"],d=c?Array.isArray(c)?c[0]:c.split(",")[0]:a.socket.remoteAddress;return`ip:${d||"unknown"}`}async function i(a,b,c,d){try{let e=h(a),f=a.headers["x-forwarded-for"]||a.socket.remoteAddress||"unknown",g=a.headers["user-agent"]||"unknown",i=a.headers.origin||a.headers.referer||"unknown";console.log("[API Request]",{timestamp:new Date().toISOString(),endpoint:b,identifier:e,ip:f,origin:i,userAgent:g,success:c,errorMessage:d})}catch(a){console.error("Logging error:",a)}}async function j(a,b,c={requireToken:!0,checkCORS:!0,checkRateLimit:!0,maxRequestsPerHour:1e3}){let d=a.url||"unknown";if("OPTIONS"===a.method)return c.checkCORS&&await f(a,b),b.status(200).end(),{allowed:!1};if(c.checkCORS&&!await f(a,b))return await i(a,d,!1,"CORS: Origin not allowed"),b.status(403).json({error:"Origin not allowed"}),{allowed:!1,error:"CORS violation"};if(c.requireToken&&!await g(a))return await i(a,d,!1,"Invalid or missing API token"),b.status(401).json({error:"Invalid or missing API token"}),{allowed:!1,error:"Invalid token"};if(c.checkRateLimit){let f=function(a,b=100){let c=Date.now(),d=e.get(a);return(!d||c>d.resetTime)&&(d={count:0,resetTime:c+36e5},e.set(a,d)),d.count++,{allowed:d.count<=b,remaining:Math.max(0,b-d.count),resetTime:d.resetTime}}(h(a),c.maxRequestsPerHour||1e3);if(b.setHeader("X-RateLimit-Limit",c.maxRequestsPerHour||1e3),b.setHeader("X-RateLimit-Remaining",f.remaining),b.setHeader("X-RateLimit-Reset",Math.floor(f.resetTime/1e3)),!f.allowed)return await i(a,d,!1,"Rate limit exceeded"),b.status(429).json({error:"Rate limit exceeded",limit:c.maxRequestsPerHour,resetTime:Math.floor(f.resetTime/1e3)}),{allowed:!1,error:"Rate limit exceeded"}}return await i(a,d,!0),{allowed:!0}}setInterval(function(){let a=Date.now();for(let[b,c]of e.entries())a>c.resetTime&&e.delete(b)},36e5)},21572:a=>{a.exports=require("nodemailer")},29021:a=>{a.exports=require("fs")},30704:(a,b,c)=>{c.a(a,async(a,d)=>{try{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>m});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(72095),j=c(58112),k=c(18766),l=a([i]);i=(l.then?(await l)():l)[0];let n=(0,h.M)(i,"default"),o=(0,h.M)(i,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/public/apply",pathname:"/api/public/apply",bundlePath:"",filename:""},userland:i,distDir:".next",relativeProjectDir:""});async function m(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/public/apply"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,j.getTracer)(),e=d.getActiveScopeSpan(),l=p.instrumentationOnRequestError.bind(p),m=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/public/apply",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>l(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==k.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await m(e):await d.withPropagatedContext(a.headers,()=>d.trace(k.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:j.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},m))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}d()}catch(a){d(a)}})},33873:a=>{a.exports=require("path")},55511:a=>{a.exports=require("crypto")},67313:a=>{a.exports=import("formidable")},72095:(a,b,c)=>{c.a(a,async(a,d)=>{try{c.r(b),c.d(b,{config:()=>p,default:()=>o});var e=c(88251),f=c(91823),g=c(13813),h=c(4914),i=c(67313),j=c(29021),k=c.n(j),l=c(33873),m=c.n(l),n=a([i]);i=(n.then?(await n)():n)[0];let p={api:{bodyParser:!1}};async function o(a,b){if((await (0,h.Do)(a,b,{requireToken:!1,checkCORS:!0,checkRateLimit:!0,maxRequestsPerHour:50})).allowed){if("POST"!==a.method)return b.status(405).json({error:"Method not allowed"});try{let c=m().join(process.cwd(),"public","uploads","applicants");k().existsSync(c)||k().mkdirSync(c,{recursive:!0});let d=(0,i.default)({uploadDir:c,keepExtensions:!0,maxFileSize:0xa00000,multiples:!0}),[h,j]=await new Promise((b,c)=>{d.parse(a,(a,d,e)=>{a?c(a):b([d,e])})}),l=a=>{let b=h[a];return Array.isArray(b)?b[0]:b||""},n=new Date().getFullYear(),o=await (0,e.P)(`SELECT application_no FROM career_applicants
        WHERE application_no LIKE ?
        ORDER BY LENGTH(application_no) DESC, application_no DESC
        LIMIT 1`,[`APP-${n}-%`]),p=1;if(o.length>0){let a=String(o[0].application_no).split("-").pop()||"0",b=Number(a);Number.isFinite(b)&&(p=b+1)}let q=`APP-${n}-${String(p).padStart(4,"0")}`,r=a=>{let b=j[a];if(!b)return null;let c=Array.isArray(b)?b[0]:b;return c?m().basename(c.filepath):null},s=r("passport_photo"),t=r("resume_pdf"),u=r("cover_letter_pdf");if(!s||!t)return b.status(400).json({error:"Passport photo and resume are required"});await (0,e.P)(`INSERT INTO career_applicants (
        career_posting_id, application_no, full_name, ic_number, gender, date_of_birth,
        nationality, religion, marital_status, email, phone_number, alt_phone_number,
        ic_address, ic_postcode, ic_city, ic_state, ic_country,
        current_address, current_postcode, current_city, current_state, current_country,
        same_as_ic_address, emergency_name, emergency_relationship, emergency_phone,
        emergency_email, emergency_address, highest_education, field_of_study,
        years_of_experience, current_employer, current_position, expected_salary,
        notice_period, available_start_date, passport_photo, resume_pdf, cover_letter_pdf,
        cover_message, how_did_you_hear, status, submitted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', NOW())`,[l("career_posting_id"),q,l("full_name"),l("ic_number"),l("gender"),l("date_of_birth"),l("nationality")||"Malaysian",l("religion"),l("marital_status")||"Single",l("email"),l("phone_number"),l("alt_phone_number"),l("ic_address"),l("ic_postcode"),l("ic_city"),l("ic_state"),l("ic_country")||"Malaysia","true"===l("same_as_ic_address")?l("ic_address"):l("current_address"),"true"===l("same_as_ic_address")?l("ic_postcode"):l("current_postcode"),"true"===l("same_as_ic_address")?l("ic_city"):l("current_city"),"true"===l("same_as_ic_address")?l("ic_state"):l("current_state"),"true"===l("same_as_ic_address")?l("ic_country")||"Malaysia":l("current_country"),"true"===l("same_as_ic_address"),l("emergency_name"),l("emergency_relationship"),l("emergency_phone"),l("emergency_email"),l("emergency_address"),l("highest_education"),l("field_of_study"),parseInt(l("years_of_experience"))||0,l("current_employer"),l("current_position"),parseFloat(l("expected_salary"))||null,l("notice_period"),l("available_start_date")||null,s,t,u,l("cover_message"),l("how_did_you_hear")]);let v=await (0,e.P)("SELECT title FROM career_postings WHERE id = ?",[l("career_posting_id")]),w=v.length>0?v[0].title:"Position";try{await (0,f.Dw)({application_no:q,full_name:l("full_name"),email:l("email"),phone_number:l("phone_number"),position:w,years_of_experience:parseInt(l("years_of_experience"))||0}),await (0,f.BR)({full_name:l("full_name"),email:l("email"),application_no:q,position:w}),await (0,g.hc)({module:"applicants",reference:q,currentLevel:0,requestedBy:l("full_name"),summary:`Application for ${w}.`,whereToAct:"Application > Job Applicants"})}catch(a){console.error("Email notification error:",a)}b.status(201).json({success:!0,message:"Application submitted successfully!",application_no:q})}catch(a){console.error("Application submission error:",a),b.status(500).json({error:"Failed to submit application"})}}}d()}catch(a){d(a)}})},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},91823:(a,b,c)=>{c.d(b,{BR:()=>k,Dw:()=>g,Hi:()=>j,Mn:()=>h,jo:()=>i});var d=c(2066),e=c(2922);let f={async sendMail(a){let b=await (0,e.it)("applicants"),c=b.email_profile||"hr",f=await (0,d.OT)(c,{to:a.to,subject:a.subject,html:a.html,cc:a.cc||b.cc_email||void 0});if(!f.success)throw Error(f.error||`the "${c}" email profile could not send`);return f}};async function g(a){let b={from:"hr@ansartechnologies.my",to:"hr@ansartechnologies.my",subject:`New Job Application - ${a.application_no}`,html:`
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0;">
        <div style="background-color: #0056b3; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0;">New Job Application Received</h2>
        </div>
        
        <div style="padding: 20px; background-color: #f9f9f9;">
          <h3 style="color: #0056b3; margin-top: 0;">Application Details</h3>
          
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Application No:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.application_no}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Position Applied:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.position}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Applicant Name:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.full_name}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Email:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.email}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Phone:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.phone_number}</td>
            </tr>
            <tr>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;"><strong>Experience:</strong></td>
              <td style="padding: 10px; border-bottom: 1px solid #ddd;">${a.years_of_experience} years</td>
            </tr>
          </table>
          
          <div style="margin-top: 20px; padding: 15px; background-color: #e3f2fd; border-left: 4px solid #0056b3;">
            <p style="margin: 0;"><strong>Action Required:</strong> Please review this application in the admin panel.</p>
          </div>
        </div>
        
        <div style="padding: 20px; text-align: center; background-color: #f0f0f0;">
          <p style="margin: 0; color: #666; font-size: 12px;">
            ANSAR TECHNOLOGIES SDN BHD<br>
            This is an automated notification. Please do not reply to this email.
          </p>
        </div>
      </div>
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending HR notification:",a),{success:!1,error:a}}}async function h(a){let b={from:"hr@ansartechnologies.my",to:a.email,subject:`Interview Invitation - ${a.position}`,html:`
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0;">
        <div style="background-color: #0056b3; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0;">Interview Invitation</h2>
        </div>
        
        <div style="padding: 20px;">
          <p>Dear ${a.full_name},</p>
          
          <p>Thank you for applying for the <strong>${a.position}</strong> position at ANSAR TECHNOLOGIES SDN BHD.</p>
          
          <p>We are pleased to invite you for an interview.</p>
          
          <div style="background-color: #f9f9f9; padding: 20px; border-left: 4px solid #0056b3; margin: 20px 0;">
            <h3 style="color: #0056b3; margin-top: 0;">Interview Details</h3>
            
            <table style="width: 100%;">
              <tr>
                <td style="padding: 8px 0;"><strong>Application No:</strong></td>
                <td style="padding: 8px 0;">${a.application_no}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0;"><strong>Position:</strong></td>
                <td style="padding: 8px 0;">${a.position}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0;"><strong>Date:</strong></td>
                <td style="padding: 8px 0;">${new Date(a.interview_date).toLocaleDateString("en-MY",{weekday:"long",year:"numeric",month:"long",day:"numeric"})}</td>
              </tr>
              ${a.interview_time?`
              <tr>
                <td style="padding: 8px 0;"><strong>Time:</strong></td>
                <td style="padding: 8px 0;">${a.interview_time}</td>
              </tr>
              `:""}
              ${a.interview_location?`
              <tr>
                <td style="padding: 8px 0;"><strong>Location:</strong></td>
                <td style="padding: 8px 0;">${a.interview_location}</td>
              </tr>
              `:""}
            </table>
            
            ${a.interview_notes?`
              <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #ddd;">
                <p style="margin: 0;"><strong>Additional Notes:</strong></p>
                <p style="margin: 5px 0 0 0;">${a.interview_notes}</p>
              </div>
            `:""}
          </div>
          
          <p><strong>What to bring:</strong></p>
          <ul style="line-height: 1.8;">
            <li>Original and photocopies of your IC/Passport</li>
            <li>Original and photocopies of your academic certificates and transcripts</li>
            <li>Certified true copies of all certificates (verified by relevant authorized personnel)</li>
            <li>Updated resume/CV</li>
            <li>Portfolio or work samples (if applicable)</li>
            <li>Any other relevant supporting documents</li>
          </ul>
          
          <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
            <p style="margin: 0; font-size: 13px; color: #856404;">
              <strong>Important:</strong> Please ensure all certificate copies are certified/authenticated by the relevant authorized officer from your institution or a commissioner of oaths.
            </p>
          </div>
          
          <p>If you need to reschedule or have any questions, please contact us immediately at hr@ansartechnologies.my or call +60 11-6344 0530.</p>
          
          <p>We look forward to meeting you!</p>
          
          <p>Best regards,<br>
          <strong>Human Resources Department</strong><br>
          ANSAR TECHNOLOGIES SDN BHD</p>
        </div>
        
        <div style="padding: 20px; text-align: center; background-color: #f0f0f0; border-top: 1px solid #ddd;">
          <p style="margin: 0; color: #666; font-size: 12px;">
            ANSAR TECHNOLOGIES SDN BHD (940482-W)<br>
            Email: hr@ansartechnologies.my | Phone: +60 11-6344 0530
          </p>
        </div>
      </div>
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending interview schedule:",a),{success:!1,error:a}}}async function i(a){let b={from:"hr@ansartechnologies.my",to:a.email,subject:"Good News - Application Shortlisted",html:`
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0;">
        <div style="background-color: #0284c7; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0;">🎉 Congratulations!</h2>
        </div>
        
        <div style="padding: 20px;">
          <p>Dear ${a.full_name},</p>
          
          <p>We are pleased to inform you that your application for the <strong>${a.position}</strong> position has been <strong>shortlisted</strong> for further consideration.</p>
          
          <p>Your qualifications and experience have impressed our hiring team, and we would like to proceed to the next stage of our selection process.</p>
          
          <div style="background-color: #dbeafe; padding: 20px; border-left: 4px solid #0284c7; margin: 20px 0; border-radius: 4px;">
            <h3 style="color: #0284c7; margin-top: 0; font-size: 16px;">Application Summary</h3>
            
            <table style="width: 100%;">
              <tr>
                <td style="padding: 8px 0; width: 40%;"><strong>Application No:</strong></td>
                <td style="padding: 8px 0;">${a.application_no}</td>
              </tr>
              <tr>
                <td style="padding: 8px 0;"><strong>Position:</strong></td>
                <td style="padding: 8px 0;">${a.position}</td>
              </tr>
              ${a.expected_salary?`
              <tr>
                <td style="padding: 8px 0;"><strong>Expected Salary:</strong></td>
                <td style="padding: 8px 0;">RM ${a.expected_salary.toLocaleString()}</td>
              </tr>
              `:""}
              ${a.interview_date?`
              <tr>
                <td style="padding: 8px 0;"><strong>Interview Date:</strong></td>
                <td style="padding: 8px 0;">${new Date(a.interview_date).toLocaleDateString("en-MY",{weekday:"long",year:"numeric",month:"long",day:"numeric"})}</td>
              </tr>
              `:""}
            </table>
          </div>
          
          <p><strong>What happens next?</strong></p>
          <ul style="line-height: 1.8;">
            <li>Our HR team will review your application in detail</li>
            <li>We will conduct further assessments as needed</li>
            <li>You may be contacted for additional interviews or discussions</li>
            <li>Final candidates will be notified of the outcome</li>
          </ul>
          
          <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
            <p style="margin: 0; font-size: 13px; color: #856404;">
              <strong>Please Note:</strong> Being shortlisted does not guarantee a job offer. This is part of our selection process, and we will keep you informed of further developments.
            </p>
          </div>
          
          <p>If you have any questions or need to update any information, please feel free to contact us at hr@ansartechnologies.my or call +60 11-6344 0530.</p>
          
          <p>Thank you for your patience and continued interest in joining ANSAR TECHNOLOGIES SDN BHD. We appreciate your understanding as we work through this process.</p>
          
          <p>Best regards,<br>
          <strong>Human Resources Department</strong><br>
          ANSAR TECHNOLOGIES SDN BHD</p>
        </div>
        
        <div style="padding: 20px; text-align: center; background-color: #f0f0f0; border-top: 1px solid #ddd;">
          <p style="margin: 0; color: #666; font-size: 12px;">
            ANSAR TECHNOLOGIES SDN BHD (940482-W)<br>
            Email: hr@ansartechnologies.my | Phone: +60 11-6344 0530
          </p>
        </div>
      </div>
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending shortlisted email:",a),{success:!1,error:a}}}async function j(a){let b={from:"hr@ansartechnologies.my",to:a.email,subject:`Application Update - ${a.application_no}`,html:`
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0;">
        <div style="background-color: #0056b3; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0;">Application Update</h2>
        </div>
        
        <div style="padding: 20px;">
          <p>Dear ${a.full_name},</p>
          
          <p>Thank you for your interest in the <strong>${a.position}</strong> position and for taking the time to apply with ANSAR TECHNOLOGIES SDN BHD.</p>
          
          <p>We appreciate the effort you put into your application and the opportunity to learn more about your qualifications and experience.</p>
          
          <p>After careful consideration of all applications, we regret to inform you that we will not be moving forward with your application at this time. This decision was not easy, as we received many strong applications from talented candidates.</p>
          
          ${a.rejection_reason?`
          <div style="background-color: #f8f9fa; padding: 15px; border-left: 4px solid #6c757d; margin: 20px 0;">
            <p style="margin: 0; font-size: 13px;">
              <strong>Feedback:</strong><br>
              ${a.rejection_reason}
            </p>
          </div>
          `:""}
          
          <p>We encourage you to apply for future openings that match your skills and experience. Your resume will remain in our database for consideration for other suitable positions that may become available.</p>
          
          <p>We wish you all the best in your job search and future career endeavors. Thank you once again for your interest in joining our team.</p>
          
          <p>Best regards,<br>
          <strong>Human Resources Department</strong><br>
          ANSAR TECHNOLOGIES SDN BHD</p>
          
          <div style="background-color: #e3f2fd; padding: 15px; border-left: 4px solid #0056b3; margin: 20px 0;">
            <p style="margin: 0; font-size: 12px;">
              <strong>Stay Connected:</strong> Follow us on our social media channels to stay updated on new job opportunities and company news.
            </p>
          </div>
        </div>
        
        <div style="padding: 20px; text-align: center; background-color: #f0f0f0; border-top: 1px solid #ddd;">
          <p style="margin: 0; color: #666; font-size: 12px;">
            ANSAR TECHNOLOGIES SDN BHD (940482-W)<br>
            Email: hr@ansartechnologies.my | Phone: +60 11-6344 0530
          </p>
        </div>
      </div>
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending rejection email:",a),{success:!1,error:a}}}async function k(a){let b={from:"hr@ansartechnologies.my",to:a.email,subject:`Application Received - ${a.application_no}`,html:`
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0;">
        <div style="background-color: #0056b3; color: white; padding: 20px; text-align: center;">
          <h2 style="margin: 0;">Application Received</h2>
        </div>
        
        <div style="padding: 20px;">
          <p>Dear ${a.full_name},</p>
          
          <p>Thank you for your interest in joining ANSAR TECHNOLOGIES SDN BHD.</p>
          
          <p>We have successfully received your application for the <strong>${a.position}</strong> position.</p>
          
          <div style="background-color: #e3f2fd; padding: 15px; border-left: 4px solid #0056b3; margin: 20px 0;">
            <p style="margin: 0;"><strong>Application Number:</strong> ${a.application_no}</p>
          </div>
          
          <p>Our HR team will review your application and contact you if your qualifications match our requirements.</p>
          
          <p>Please keep your application number for future reference.</p>
          
          <p>Best regards,<br>
          <strong>Human Resources Department</strong><br>
          ANSAR TECHNOLOGIES SDN BHD</p>
        </div>
        
        <div style="padding: 20px; text-align: center; background-color: #f0f0f0; border-top: 1px solid #ddd;">
          <p style="margin: 0; color: #666; font-size: 12px;">
            ANSAR TECHNOLOGIES SDN BHD (940482-W)<br>
            Email: hr@ansartechnologies.my | Phone: +60 11-6344 0530
          </p>
        </div>
      </div>
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending application confirmation:",a),{success:!1,error:a}}}}};var b=require("../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,2816,3813],()=>b(b.s=30704));module.exports=c})();