"use strict";(()=>{var a={};a.id=3684,a.ids=[3684],a.modules={3498:a=>{a.exports=require("mysql2/promise")},3557:(a,b,c)=>{c.d(b,{$3:()=>g,J9:()=>j,O4:()=>l,OC:()=>f,OD:()=>h,QU:()=>m,Sj:()=>k,ah:()=>n,oS:()=>i});var d=c(88251),e=c(63415);async function f(a,b){let c=await (0,e.iT)(a);return c||(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}function g(a,b,c){return(0,e.$3)(a,b,c)}function h(a,b,c,d){return!!g(a,c,d)||(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),!1)}function i(a,b){let c=[],d=[];for(let[e,f]of Object.entries(b))e in a&&(c.push(`\`${e}\` = ?`),d.push(function(a,b){if(void 0===b)return null;if("bool"===a)return+(!0===b||1===b||"1"===b||"true"===b);if("number"===a){if(null===b||""===b)return null;let a=Number(b);return Number.isFinite(a)?a:null}if("json"===a){if(null===b||""===b)return null;if("string"==typeof b)return b;try{return JSON.stringify(b)}catch{return null}}if(null===b)return null;let c=String(b);return""===c?null:c}(f,a[e])));return 0===c.length?null:{clause:c.join(", "),values:d}}function j(a){let b=a.body;if(!b)return{};if("string"==typeof b)try{return JSON.parse(b)}catch{return{}}return"object"==typeof b?b:{}}async function k(){let a=await (0,d.P)("SELECT * FROM system_settings WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO system_settings (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM system_settings WHERE id = 1"))[0]||{})}async function l(){let a=await (0,d.P)("SELECT * FROM integrations WHERE id = 1");return a.length>0?a[0]:(await (0,d.P)("INSERT INTO integrations (id) VALUES (1)"),(await (0,d.P)("SELECT * FROM integrations WHERE id = 1"))[0]||{})}function m(a,b){let c={...a};for(let a of b){let b=c[a];c[`${a}_set`]="string"==typeof b&&b.length>0,c[a]=""}return c}function n(a,b){let c={...a};for(let a of b)a in c&&(""===c[a]||null===c[a]||void 0===c[a])&&delete c[a];return c}},8493:(a,b,c)=>{c.r(b),c.d(b,{config:()=>D,default:()=>C,handler:()=>F});var d={};c.r(d),c.d(d,{default:()=>z});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19275),l=c(34461),m=c(95514),n=c(45680);let o=a=>null==a?"":String(a),p=a=>{let b="number"==typeof a?a:parseFloat(String(a??""));return Number.isFinite(b)?b:0},q=a=>{if(a instanceof Date){if(Number.isNaN(a.getTime()))return null;let b=a=>String(a).padStart(2,"0");return`${a.getFullYear()}-${b(a.getMonth()+1)}-${b(a.getDate())}`}let b=o(a).trim();return b?b.slice(0,10):null},r=(...a)=>{for(let b of a){let a=o(b).trim();if(a)return a}return""},s=(...a)=>r(...a)||null;async function t(a,b){let c=await (0,i.P)(`SELECT a.*, c.title AS job_title, c.department
       FROM career_applicants a
       LEFT JOIN career_postings c ON c.id = a.career_posting_id
      WHERE a.id = ? LIMIT 1`,[a]);if(0===c.length)return{created:!1,reason:"applicant-missing"};let d=c[0];if((await (0,i.P)("SELECT id FROM employees WHERE ic_number = ? OR email = ? LIMIT 1",[o(d.ic_number),o(d.email)])).length>0)return{created:!1,reason:"already-exists"};let e=9,f=`%${o(d.department).toLowerCase()}%`,g=await (0,i.P)("SELECT id FROM departments WHERE LOWER(name) LIKE ? OR LOWER(code) LIKE ? LIMIT 1",[f,f]);g.length>0&&(e=p(g[0].id));let h=new Date().getFullYear(),j=await (0,i.P)("SELECT code FROM departments WHERE id = ?",[e]),k=j.length>0?o(j[0].code):"GEN",l=await (0,i.P)("SELECT employee_id FROM employees WHERE employee_id LIKE ? ORDER BY employee_id DESC LIMIT 1",[`ANSR-${h}-${k}-%`]),t=1;if(l.length>0){let a=o(l[0].employee_id).match(/-(\d+)$/);a&&(t=parseInt(a[1],10)+1)}let u=`ANSR-${h}-${k}-${String(t).padStart(3,"0")}`,v=`EMP-${Date.now()}-${Math.random().toString(36).substring(7)}`,w=[u,o(d.full_name),o(d.email),o(d.phone_number),o(d.ic_number),q(d.date_of_birth),r(d.gender)||"Male",r(d.nationality)||"Malaysian",(r(d.marital_status)||"single").toLowerCase(),r(d.ic_address,d.current_address),r(d.ic_postcode,d.current_postcode),r(d.ic_city,d.current_city),r(d.ic_state,d.current_state),r(d.ic_country,d.current_country)||"Malaysia",o(d.emergency_name),o(d.emergency_phone),o(d.emergency_relationship),r(d.job_title)||"Employee",e,"Permanent",q(d.available_start_date)||(0,m.r9)(),p(d.expected_salary),"active",s(d.resume_pdf),s(d.cover_letter_pdf),null,s(d.highest_education),s(d.field_of_study),null,null,p(d.years_of_experience),b,v,`Auto-created from application ${o(d.application_no)} — includes resume, education and all applicant details`],x=(await (0,i.P)(`INSERT INTO employees (
      employee_id, full_name, email, phone, ic_number, date_of_birth,
      gender, nationality, marital_status,
      address, postcode, city, state, country,
      emergency_contact_name, emergency_contact_phone, emergency_contact_relationship,
      position, department_id, employment_type, join_date, basic_salary, status,
      resume_path, cover_letter_path, certificates_path,
      highest_education, field_of_study, institution, graduation_year, years_of_experience,
      created_by, qr_code, notes
    )
    -- 34 columns, 34 placeholders. It shipped with 33, so MySQL answered
    -- ER_WRONG_VALUE_COUNT_ON_ROW and hiring an applicant failed EVERY time, for as long as this
    -- code had existed. The values array has always had 34 entries in the same order; only the
    -- placeholder list was short. Count them before editing either side.
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,w)).insertId,y=0;try{y=(await (0,n.gq)(x,(0,n.kq)(new Date))).total}catch(a){console.error("Leave balance initialization error:",a)}return{created:!0,employeeId:u,id:x,leaveTypes:y}}var u=c(96543),v=c(80283),w=c(91823);let x={pending:"offered",approved:"hired",rejected:"rejected"},y="applicants";async function z(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid applicant id."});try{if("GET"===a.method){if(!(0,j.OD)(c,b,y,"view"))return;let a=await (0,i.P)(`SELECT a.*,
                -- Every date and datetime through DATE_FORMAT. mysql2 returns a Date and
                -- serialising it converts to UTC: at UTC+8 a 09:00 interview reports as 01:00 and a
                -- birthday moves back a day.
                DATE_FORMAT(a.date_of_birth, '%Y-%m-%d')          AS date_of_birth,
                DATE_FORMAT(a.available_start_date, '%Y-%m-%d')   AS available_start_date,
                DATE_FORMAT(a.submitted_at, '%Y-%m-%d %H:%i')     AS submitted_at,
                DATE_FORMAT(a.reviewed_at, '%Y-%m-%d %H:%i')      AS reviewed_at,
                DATE_FORMAT(a.archived_at, '%Y-%m-%d %H:%i')      AS archived_at,
                DATE_FORMAT(a.interview_date, '%Y-%m-%d\\T%H:%i') AS interview_date,
                c.title AS job_title, c.department AS job_department
           FROM career_applicants a
           LEFT JOIN career_postings c ON c.id = a.career_posting_id
          WHERE a.id = ? LIMIT 1`,[d]);if(0===a.length)return b.status(404).json({success:!1,error:"Applicant not found."});let e=await (0,l.gf)(y);return b.status(200).json({success:!0,applicant:a[0],chain:e})}let e=await (0,i.P)(`SELECT a.id, a.application_no, a.full_name, a.email, a.status, a.current_level,
              DATE_FORMAT(a.interview_date, '%Y-%m-%d %H:%i') AS interview_date,
              a.interview_notes, a.rejection_reason, a.expected_salary,
              c.title AS job_title
         FROM career_applicants a
         LEFT JOIN career_postings c ON c.id = a.career_posting_id
        WHERE a.id = ? LIMIT 1`,[d]);if(0===e.length)return b.status(404).json({success:!1,error:"Applicant not found."});let f=e[0];if("DELETE"===a.method){if(!(0,j.OD)(c,b,y,"delete"))return;if("archived"===f.status)return b.status(409).json({success:!1,error:`${f.full_name} is already archived.`});return await (0,i.P)(`UPDATE career_applicants
            SET status = 'archived', status_before_archive = ?, archived_at = NOW(),
                reviewed_at = NOW(), reviewed_by = ?
          WHERE id = ?`,[f.status,c.adminId,d]),await (0,k.At)(a,{action:"UPDATE",module:"Career: Applicants",target:`Applicant: ${f.application_no}`,description:`${f.full_name} archived from ${v.$j[f.status]}`,before:{status:f.status},after:{status:"archived",status_before_archive:f.status}}),b.status(200).json({success:!0,message:`${f.full_name} archived. Restore puts them back at ${v.$j[f.status]}.`})}if("PATCH"!==a.method)return b.setHeader("Allow","GET, PATCH, DELETE"),b.status(405).json({success:!1,error:"Method not allowed"});let g=(0,j.J9)(a),h=void 0===g.status||null===g.status||""===g.status?null:g.status;if(null!==h&&!(0,v.F3)(h))return b.status(400).json({success:!1,error:`"${String(h)}" is not an applicant status.`});if("archived"===h)return b.status(400).json({success:!1,error:"Archiving is not a status change — send DELETE, which also records the stage being left so Restore can put it back."});if(h&&h!==f.status){let a=(0,v.aJ)(f.status,h);if(a)return b.status(409).json({success:!1,error:a})}if("hired"===h||"rejected"===h&&"offered"===f.status){if(!(0,j.OD)(c,b,y,"approve"))return;let e="hired"===h?"approve":"reject",k=(0,u.gx)(g.remarks,500)||(0,u.gx)(g.admin_notes,500)||null,m=await (0,l.jt)(y,f.current_level||0,c.adminId,c.isSuperAdmin);if(m)return b.status(403).json({success:!1,error:m});let n=await (0,l.ex)({module:y,applicationId:d,action:e,actor:{adminId:c.adminId,name:c.username},remarks:k,currentStatus:f.status,currentLevel:f.current_level||0,statusWords:x});await (0,i.P)("UPDATE career_applicants SET reviewed_at = NOW(), reviewed_by = ? WHERE id = ?",[c.adminId,d]),"reject"===e&&await (0,i.P)("UPDATE career_applicants SET rejection_reason = ? WHERE id = ?",[(0,u.gx)(g.rejection_reason,65535)||k,d]);let o="";if(n.finalized&&"approved"===n.status)try{let a=await t(d,c.adminId);o=a.created?` Employee record ${a.employeeId} created with ${a.leaveTypes} leave balance(s).`:"already-exists"===a.reason?" An employee record already existed for this person, so none was created.":" The applicant record could not be re-read, so no employee was created."}catch(a){console.error("Employee creation error:",a),o=" The employee record could NOT be created: "+(a instanceof Error?a.message:"unknown error")+". Create it from Employee Management."}let p=f.application_no||`#${d}`;await (0,l.aV)(a,{module:y,reference:p,outcome:n,beforeStatus:f.status,beforeLevel:f.current_level||0,remarks:k});let q=await (0,l.OL)({module:y,applicationId:d,reference:p,employee:f.email?{email:f.email,name:f.full_name}:null,outcome:n,actorName:c.username,remarks:k}),r=await (0,l.gf)(y),s="rejected"===n.status?`${f.full_name} was not hired.`:n.finalized?`${f.full_name} is hired.${o}`:`Approved at level ${n.level} of ${r.length}. ${f.full_name} stays at Offer Made until the remaining level(s) sign.`;return b.status(200).json({success:!0,status:n.writtenStatus,level:n.level,total_levels:n.totalLevels,finalized:n.finalized,email_sent:q.sent,email_error:q.sent?null:q.reason,message:s})}let m=[],n=[],o=!!h&&h!==f.status;if(o){if(!(0,j.OD)(c,b,y,"approve"))return;m.push("status = ?"),n.push(h)}let p=["interview_date","interview_mode","interview_location","interview_link","interviewer","interview_duration_mins","interview_notes"].some(a=>void 0!==g[a]),q=null;if(p){if(!(0,j.OD)(c,b,y,"edit"))return;let a=h||f.status;if(!v.Dd.includes(a))return b.status(409).json({success:!1,error:`An interview cannot be arranged while the applicant is at "${v.$j[a]}". Shortlist them first — that is the record that somebody read the application before inviting them in.`});q=(0,v.bE)(g.interview_mode)?g.interview_mode:"in_person";let d=(0,u.gx)(g.interview_location,200),e=(0,u.gx)(g.interview_link,400),i=v.mm[q];if("location"===i&&!d)return b.status(400).json({success:!1,error:"An in-person interview needs a location — the applicant has to be told where to go."});if("link"===i&&!e)return b.status(400).json({success:!1,error:"An online interview needs a meeting link."});let k=(0,u.gx)(g.interview_date,40);if(void 0!==g.interview_date){if(!k)return b.status(400).json({success:!1,error:"An interview needs a date and time."});m.push("interview_date = ?"),n.push(k.replace("T"," ").slice(0,19))}m.push("interview_mode = ?"),n.push(q),m.push("interview_location = ?"),n.push(d||null),m.push("interview_link = ?"),n.push(e||null),m.push("interviewer = ?"),n.push((0,u.gx)(g.interviewer,200)||null);let l=Number(g.interview_duration_mins);m.push("interview_duration_mins = ?"),n.push(Number.isInteger(l)&&l>0&&l<=600?l:null),void 0!==g.interview_notes&&(m.push("interview_notes = ?"),n.push((0,u.gx)(g.interview_notes,65535)||null))}if(void 0!==g.rejection_reason){if(!o&&!(0,j.OD)(c,b,y,"edit"))return;m.push("rejection_reason = ?"),n.push((0,u.gx)(g.rejection_reason,65535)||null)}if(void 0!==g.admin_notes){if(!o&&!p&&!(0,j.OD)(c,b,y,"edit"))return;m.push("admin_notes = ?"),n.push((0,u.gx)(g.admin_notes,65535)||null)}if(0===m.length)return b.status(400).json({success:!1,error:"Nothing to change."});m.push("reviewed_at = NOW()"),m.push("reviewed_by = ?"),n.push(c.adminId),n.push(d),await (0,i.P)(`UPDATE career_applicants SET ${m.join(", ")} WHERE id = ?`,n);let r=[];if(o&&"interview-scheduled"===h)try{let a=(0,u.gx)(g.interview_date,40)||f.interview_date||"";await (0,w.Mn)({full_name:f.full_name,email:f.email,application_no:f.application_no,position:f.job_title||"Position",interview_date:a,interview_location:(0,u.gx)(g.interview_location,200)||void 0,interview_notes:(0,u.gx)(g.interview_notes,65535)||f.interview_notes||void 0})}catch(a){r.push(`interview invitation (${a instanceof Error?a.message:"failed"})`)}if(o&&"shortlisted"===h)try{await (0,w.jo)({full_name:f.full_name,email:f.email,application_no:f.application_no,position:f.job_title||"Position",expected_salary:Number(f.expected_salary)||0,interview_date:f.interview_date||"",interview_notes:f.interview_notes||""})}catch(a){r.push(`shortlist notice (${a instanceof Error?a.message:"failed"})`)}if(o&&"rejected"===h)try{await (0,w.Hi)({full_name:f.full_name,email:f.email,application_no:f.application_no,position:f.job_title||"Position",rejection_reason:(0,u.gx)(g.rejection_reason,65535)||f.rejection_reason||""})}catch(a){r.push(`rejection notice (${a instanceof Error?a.message:"failed"})`)}return await (0,k.At)(a,{action:"UPDATE",module:"Career: Applicants",target:`Applicant: ${f.application_no}`,description:o?`${f.full_name} moved from ${v.$j[f.status]} to ${v.$j[h]}`:p?`Interview details updated for ${f.full_name}`:`Notes updated for ${f.full_name}`,before:{status:f.status},after:{status:h||f.status,interview_mode:q}}),b.status(200).json({success:!0,status:h||f.status,message:(o?`${f.full_name} is now ${v.$j[h]}.`:p?"Interview details saved.":"Saved.")+(r.length>0?` The record is updated, but the ${r.join(" and ")} could not be sent — check the email profile under Career > Settings > Notifications.`:""),email_errors:r})}catch(a){return console.error("Applicant API error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to update the applicant"})}}var A=c(58112),B=c(18766);let C=(0,h.M)(d,"default"),D=(0,h.M)(d,"config"),E=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/applicants/[id]",pathname:"/api/admin/applicants/[id]",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function F(a,b,c){let d=await E.prepare(a,b,{srcPage:"/api/admin/applicants/[id]"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,A.getTracer)(),e=d.getActiveScopeSpan(),j=E.instrumentationOnRequestError.bind(E),k=async e=>E.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:E.isDev,page:"/api/admin/applicants/[id]",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==B.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(B.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:A.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(E.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},21572:a=>{a.exports=require("nodemailer")},55511:a=>{a.exports=require("crypto")},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},80283:(a,b,c)=>{c.d(b,{$j:()=>f,Co:()=>e,Dd:()=>m,F3:()=>h,aJ:()=>i,bE:()=>l,hm:()=>d,mm:()=>k});let d=["active","inactive","draft"],e=["pending","shortlisted","interview-scheduled","interview-completed","offered","hired","rejected","withdrawn","archived"],f={pending:"Pending Review",shortlisted:"Shortlisted","interview-scheduled":"Interview Scheduled","interview-completed":"Interview Completed",offered:"Offer Made",hired:"Hired",rejected:"Rejected",withdrawn:"Withdrawn",archived:"Archived"},g={pending:["shortlisted","rejected","withdrawn"],shortlisted:["interview-scheduled","offered","rejected","withdrawn"],"interview-scheduled":["interview-completed","rejected","withdrawn"],"interview-completed":["offered","shortlisted","rejected","withdrawn"],offered:["hired","rejected","withdrawn"],hired:[],rejected:[],withdrawn:[],archived:[]};function h(a){return"string"==typeof a&&e.includes(a)}function i(a,b){if(a===b||g[a].includes(b))return null;let c=g[a];return 0===c.length?`${f[a]} is final — this applicant cannot be moved again.`:`An applicant at "${f[a]}" can only move to ${c.map(a=>f[a]).join(", ")}.`}let j=["in_person","online","phone"],k={in_person:"location",online:"link",phone:null};function l(a){return"string"==typeof a&&j.includes(a)}let m=["shortlisted","interview-scheduled","interview-completed"]},91823:(a,b,c)=>{c.d(b,{BR:()=>k,Dw:()=>g,Hi:()=>j,Mn:()=>h,jo:()=>i});var d=c(2066),e=c(2922);let f={async sendMail(a){let b=await (0,e.it)("applicants"),c=b.email_profile||"hr",f=await (0,d.OT)(c,{to:a.to,subject:a.subject,html:a.html,cc:a.cc||b.cc_email||void 0});if(!f.success)throw Error(f.error||`the "${c}" email profile could not send`);return f}};async function g(a){let b={from:"hr@ansartechnologies.my",to:"hr@ansartechnologies.my",subject:`New Job Application - ${a.application_no}`,html:`
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
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending application confirmation:",a),{success:!1,error:a}}}},96543:(a,b,c)=>{function d(a){if(null==a||""===a)return null;let b=Number(String(a).replace(/,/g,"").trim());return Number.isFinite(b)?b:null}function e(a){if(null==a||""===a)return null;let b=String(a).trim().slice(0,10);return/^\d{4}-\d{2}-\d{2}$/.test(b)?b:null}function f(a,b){if(null==a)return null;let c=String(a).trim();return""===c?null:c.slice(0,b)}function g(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>0?b:null}function h(a,b,c){let d=String(a??"").trim().toLowerCase();return b.includes(d)?d:c}function i(a){let b=a.replace(/\\/g,"\\\\").replace(/%/g,"\\%").replace(/_/g,"\\_");return`%${b}%`}c.d(b,{AR:()=>i,Bq:()=>r,Mw:()=>l,N6:()=>o,Ov:()=>x,TG:()=>d,_$:()=>e,aI:()=>w,af:()=>s,cM:()=>u,fk:()=>g,gx:()=>f,i9:()=>n,iv:()=>v,jI:()=>t,jT:()=>p,ni:()=>j,qB:()=>q,yH:()=>k,yL:()=>h,zN:()=>m});let j=["draft","in_progress","submitted","evaluation","awarded","unsuccessful","closed"],k=["government","private"],l=["open","selective","quotation","direct"],m=["technical","financial","both"],n=["pending","in_progress","completed"],o=["active","completed"],p=["unsuccessful","cancelled","expired"],q=["active","inactive","blacklisted"],r=["prospect","active","inactive"],s=["government","education","healthcare","private","local_government","other"],t=["new","contacted","qualified","proposal","negotiation","won","lost"],u=["referral","cold_call","website","event","tender","other"],v=["draft","sent","accepted","rejected","expired"];function w(a){if(!a)return"open";let b=new Date(a);if(Number.isNaN(b.getTime()))return"open";let c=new Date;c.setHours(0,0,0,0),b.setHours(0,0,0,0);let d=Math.round((b.getTime()-c.getTime())/864e5);return d<0?"closed":d<=7?"closing":"open"}function x(a){return!a||a<=0?"":a<1024?`${a} B`:a<1048576?`${Math.round(a/1024)} KB`:`${(a/1048576).toFixed(1)} MB`}}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,2816,4461,5514,5680],()=>b(b.s=8493));module.exports=c})();