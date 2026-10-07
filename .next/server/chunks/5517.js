"use strict";exports.id=5517,exports.ids=[5517],exports.modules={63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},91823:(a,b,c)=>{c.d(b,{BR:()=>k,Dw:()=>g,Hi:()=>j,Mn:()=>h,jo:()=>i});var d=c(2066),e=c(2922);let f={async sendMail(a){let b=await (0,e.it)("applicants"),c=b.email_profile||"hr",f=await (0,d.OT)(c,{to:a.to,subject:a.subject,html:a.html,cc:a.cc||b.cc_email||void 0});if(!f.success)throw Error(f.error||`the "${c}" email profile could not send`);return f}};async function g(a){let b={from:"hr@ansartechnologies.my",to:"hr@ansartechnologies.my",subject:`New Job Application - ${a.application_no}`,html:`
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
    `};try{return await f.sendMail(b),{success:!0}}catch(a){return console.error("Error sending application confirmation:",a),{success:!1,error:a}}}}};