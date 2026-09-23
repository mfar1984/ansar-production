"use strict";exports.id=8430,exports.ids=[8430],exports.modules={2922:(a,b,c)=>{c.d(b,{XG:()=>g,hG:()=>i,it:()=>h});var d=c(88251);let e=["leave","claim","overtime","expenses","payroll","kpi","partners","procurement","business_dev","applicants","asset_loan","petty_cash","market_place","asset_disposal","helpdesk"],f={email_profile:"hr",notify_employee:"1",notify_approver:"1",notify_every_level:"0",cc_email:"",rest_days:"0,6",holiday_state:"",email_subject_approved:"",email_body_approved:"",email_subject_rejected:"",email_body_rejected:""};function g(a){return"string"==typeof a&&e.includes(a)}async function h(a){let b={...f};try{for(let c of(await (0,d.P)("SELECT setting_key, value FROM hr_module_settings WHERE module = ?",[a])))c.setting_key in b&&(b[c.setting_key]=c.value??"")}catch{}return b}async function i(a,b,c){let e=[];for(let g of Object.keys(f)){if(!(g in b))continue;let f=b[g],h=null==f?"":String(f);await (0,d.P)(`INSERT INTO hr_module_settings (module, setting_key, value, updated_by)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE value = VALUES(value), updated_by = VALUES(updated_by)`,[a,g,h,c]),e.push(g)}return e}},38430:(a,b,c)=>{c.d(b,{DR:()=>u,J1:()=>v,O$:()=>t,Rb:()=>w,ZT:()=>q,ai:()=>s,iF:()=>r,kH:()=>p});var d=c(2066),e=c(2922);let f="support",g="NEXT_PUBLIC_BASE_URL",h=/^(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])$/i,i=!1;function j(a){let b=(process.env[g]||"").trim().replace(/\/+$/,""),c="";if(b)try{c=new URL(b).hostname}catch{}return!i&&(!b||!c||h.test(c))&&(i=!0,console.error(`${g} is ${b?`"${b}"`:"not set"}, so helpdesk email is about to send a link a recipient cannot open. Set it to the public address of this site.`)),`${b}${a}`}async function k(a){try{let b=await (0,d.Us)(a),c=b?.email_address?String(b.email_address).trim():"";return c?[c]:[]}catch{return[]}}async function l(){let a=await (0,e.it)("helpdesk");if("0"===a.notify_employee)return{to:[],skipped:"notify_employee is off"};let b=String(a.cc_email||"").split(/[,;]/).map(a=>a.trim()).filter(Boolean);return{to:b.length>0?b:await k(a.email_profile)}}function m(a){if(a)return"string"==typeof a?a:Array.isArray(a)?a.map(a=>"string"==typeof a?a:a.address).filter(Boolean):"address"in a?a.address:void 0}async function n(){try{return(await (0,e.it)("helpdesk")).email_profile||f}catch{return f}}let o={async sendMail(a){let b=m(a.to);if(!b||Array.isArray(b)&&0===b.length)throw Error("No recipient for helpdesk mail.");let c=await n(),e=await (0,d.OT)(c,{to:b,subject:String(a.subject||""),html:String(a.html||""),text:"string"==typeof a.text?a.text:void 0,cc:m(a.cc),bcc:m(a.bcc)});if(!e.success)throw Error(e.error||`Email profile '${c}' could not send.`);return e}};async function p(a,b,c,d){let e=`${j("/client/verify")}?token=${c}`,f={to:a,subject:"Verify Your Email - Ansar Technologies Support Portal",html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .button { display: inline-block; background: #3b82f6; color: white !important; padding: 14px 32px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: 600; }
          .credentials { background: #ffffff; border: 2px solid #3b82f6; padding: 20px; margin: 20px 0; border-radius: 6px; }
          .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0; font-size: 24px;">🎫 Support Ticket Submitted</h1>
          </div>
          <div class="content">
            <p>Dear <strong>${b}</strong>,</p>
            <p>Thank you for submitting a support ticket (<strong>${d}</strong>).</p>
            <p><strong>Please verify your email address to activate your support portal account:</strong></p>
            <div style="text-align: center;">
              <a href="${e}" class="button">Verify Email Address</a>
            </div>
            <p style="font-size: 12px; color: #6b7280;">Or copy and paste this link in your browser:<br>${e}</p>
            
            <div class="credentials">
              <h3 style="margin-top: 0; color: #1e3a8a;">📋 Your Login Credentials</h3>
              <p>After verification, you can login to track your tickets:</p>
              <p style="margin: 8px 0;"><strong>Login URL:</strong> ${j("/auth/login")}</p>
              <p style="margin: 8px 0;"><strong>Username:</strong> ${a}</p>
              <p style="margin: 8px 0;"><strong>Password:</strong> (The password you set during registration)</p>
            </div>

            <h4 style="color: #1e3a8a; margin-top: 30px;">📌 Your Ticket Details:</h4>
            <p style="margin: 5px 0;">• <strong>Ticket No:</strong> ${d}</p>
            <p style="margin: 5px 0;">• <strong>Status:</strong> Pending Review</p>
            
            <p style="margin-top: 30px;">Once verified, you can:</p>
            <ul>
              <li>View your ticket status in real-time</li>
              <li>Reply to our support team</li>
              <li>Upload additional documents</li>
              <li>Track all your support tickets in one place</li>
            </ul>

            <p style="color: #dc2626; font-size: 13px; margin-top: 20px;">⏰ <strong>Note:</strong> This verification link will expire in 24 hours.</p>
          </div>
          <div class="footer">
            <p>\xa9 ${new Date().getFullYear()} Ansar Technologies. All rights reserved.</p>
            <p>If you didn't submit this ticket, please ignore this email.</p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(f),{success:!0}}catch(a){throw console.error("Error sending verification email:",a),a}}async function q(a,b,c,d,e,f,g){let h=await l();if(h.skipped)return{success:!0,skipped:h.skipped};let i=h.to;if(0===i.length)throw Error("No helpdesk notification recipient. Set one on Helpdesk > Settings > Notification, or check the chosen email profile has an address.");let k={to:i,subject:`[New Ticket] ${a} - ${e}`,html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9fafb; }
          .header { background: #1e3a8a; color: white; padding: 20px; text-align: center; }
          .content { background: white; padding: 20px; margin-top: 20px; border: 1px solid #e5e7eb; }
          .badge { display: inline-block; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600; }
          .priority-urgent { background: #fee2e2; color: #dc2626; }
          .priority-high { background: #fed7aa; color: #ea580c; }
          .priority-medium { background: #fef3c7; color: #d97706; }
          .priority-low { background: #dbeafe; color: #2563eb; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2 style="margin: 0;">🎫 New Support Ticket</h2>
          </div>
          <div class="content">
            <h3 style="color: #1e3a8a;">Ticket: ${a}</h3>
            <p><strong>Company:</strong> ${b}</p>
            <p><strong>Contact Person:</strong> ${c}</p>
            <p><strong>Email:</strong> ${d}</p>
            <p><strong>Subject:</strong> ${e}</p>
            <p><strong>Category:</strong> ${f}</p>
            <p><strong>Priority:</strong> <span class="badge priority-${g.toLowerCase()}">${g}</span></p>
            
            <p style="margin-top: 30px;">
              <a href="${j("/auth/login")}" 
                 style="background: #3b82f6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                View in Admin Portal
              </a>
            </p>
            
            <p style="margin-top: 20px; font-size: 12px; color: #6b7280;">
              This ticket is awaiting verification from the client. Once verified, it will appear in your helpdesk dashboard.
            </p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(k),{success:!0}}catch(a){throw console.error("Error sending admin notification:",a),a}}async function r(a,b,c,d,e){let f=j("/auth/login"),g={to:a,subject:`[Reply] ${c} - ${d}`,html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #3b82f6; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; }
          .reply-box { background: white; padding: 20px; margin: 20px 0; border-left: 4px solid #3b82f6; }
          .button { display: inline-block; background: #3b82f6; color: white !important; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2 style="margin: 0;">💬 New Reply to Your Ticket</h2>
          </div>
          <div class="content">
            <p>Dear <strong>${b}</strong>,</p>
            <p>Our support team has replied to your ticket <strong>${c}</strong>:</p>
            
            <div class="reply-box">
              <p style="margin: 0; color: #6b7280; font-size: 12px; margin-bottom: 10px;">Support Team:</p>
              <p style="margin: 0;">${e.replace(/\n/g,"<br>")}</p>
            </div>

            <p>Please login to your support portal to view the full conversation and reply:</p>
            <div style="text-align: center;">
              <a href="${f}" class="button">View Ticket</a>
            </div>
            
            <p style="font-size: 12px; color: #6b7280; margin-top: 20px;">
              <strong>Ticket:</strong> ${c}<br>
              <strong>Subject:</strong> ${d}
            </p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(g),{success:!0}}catch(a){throw console.error("Error sending client reply notification:",a),a}}async function s(a,b,c,d,e){let f=await l();if(f.skipped)return{success:!0,skipped:f.skipped};let g=e?[e.trim()].filter(Boolean):[],h=[...new Set([...f.to,...g])];if(0===h.length)throw Error("No helpdesk notification recipient. Set one on Helpdesk > Settings > Notification, or check the chosen email profile has an address.");let i={to:h.join(", "),subject:`[Client Reply] ${a} - ${c}`,html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9fafb; }
          .header { background: #059669; color: white; padding: 20px; text-align: center; }
          .content { background: white; padding: 20px; margin-top: 20px; border: 1px solid #e5e7eb; }
          .message-box { background: #f0fdf4; padding: 15px; border-left: 4px solid #059669; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2 style="margin: 0;">💬 Client Replied to Ticket</h2>
          </div>
          <div class="content">
            <h3 style="color: #059669;">Ticket: ${a}</h3>
            <p><strong>Company:</strong> ${b}</p>
            <p><strong>Subject:</strong> ${c}</p>
            
            <div class="message-box">
              <p style="margin: 0; color: #065f46; font-size: 12px; margin-bottom: 8px;"><strong>Client Message:</strong></p>
              <p style="margin: 0;">${d.replace(/\n/g,"<br>")}</p>
            </div>

            <p style="margin-top: 20px;">
              <a href="${j("/auth/login")}" 
                 style="background: #059669; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                View & Reply in Portal
              </a>
            </p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(i),{success:!0}}catch(a){throw console.error("Error sending admin client reply notification:",a),a}}async function t(a,b,c,d,e,f){let g={to:a,subject:`[Assigned] ${c} - ${e}`,html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9fafb; }
          .header { background: #7c3aed; color: white; padding: 20px; text-align: center; }
          .content { background: white; padding: 20px; margin-top: 20px; border: 1px solid #e5e7eb; }
          .badge { display: inline-block; padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2 style="margin: 0;">📌 Ticket Assigned to You</h2>
          </div>
          <div class="content">
            <p>Hi <strong>${b}</strong>,</p>
            <p>A support ticket has been assigned to you:</p>
            
            <h3 style="color: #7c3aed;">Ticket: ${c}</h3>
            <p><strong>Company:</strong> ${d}</p>
            <p><strong>Subject:</strong> ${e}</p>
            <p><strong>Priority:</strong> <span class="badge" style="background: #fef3c7; color: #d97706;">${f}</span></p>

            <p style="margin-top: 20px;">
              <a href="${j("/auth/login")}" 
                 style="background: #7c3aed; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                View Ticket Details
              </a>
            </p>
            
            <p style="font-size: 12px; color: #6b7280; margin-top: 20px;">
              Please review and respond to this ticket as soon as possible.
            </p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(g),{success:!0}}catch(a){throw console.error("Error sending assignment notification:",a),a}}async function u(a,b,c,d,e){let f={open:"Your ticket is now open and being reviewed by our team.",in_progress:"Our team is actively working on your ticket.",waiting_client:"We are waiting for additional information from you.",resolved:"Your ticket has been resolved. Please login to view the solution.",closed:"Your ticket has been closed. If you need further assistance, please create a new ticket."}[e]||"Your ticket status has been updated.",g={to:a,subject:`[Status Update] ${c} - ${e.replace("_"," ").toUpperCase()}`,html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #0891b2; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; }
          .status-badge { display: inline-block; padding: 8px 16px; border-radius: 6px; font-weight: 600; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2 style="margin: 0;">🔔 Ticket Status Updated</h2>
          </div>
          <div class="content">
            <p>Dear <strong>${b}</strong>,</p>
            <p>The status of your ticket <strong>${c}</strong> has been updated:</p>
            
            <div style="text-align: center;">
              <span class="status-badge" style="background: #cffafe; color: #0891b2;">${e.replace("_"," ").toUpperCase()}</span>
            </div>

            <p>${f}</p>

            <p style="margin-top: 20px;">
              <a href="${j("/auth/login")}" 
                 style="background: #0891b2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                View Ticket Details
              </a>
            </p>
            
            <p style="font-size: 12px; color: #6b7280; margin-top: 20px;">
              <strong>Ticket:</strong> ${c}<br>
              <strong>Subject:</strong> ${d}
            </p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(g),{success:!0}}catch(a){throw console.error("Error sending status change notification:",a),a}}async function v(a,b,c){let d=j("/auth/login"),e={to:a,subject:"Your Password Has Been Reset - Ansar Technologies Support Portal",html:`
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #dc2626 0%, #f59e0b 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .credentials { background: #ffffff; border: 2px solid #f59e0b; padding: 20px; margin: 20px 0; border-radius: 6px; }
          .button { display: inline-block; background: #f59e0b; color: white !important; padding: 14px 32px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: 600; }
          .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
          .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; color: #92400e; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0; font-size: 24px;">🔑 Password Reset</h1>
          </div>
          <div class="content">
            <p>Dear <strong>${b}</strong>,</p>
            <p>Your password has been reset by our support team.</p>
            
            <div class="credentials">
              <h3 style="margin-top: 0; color: #dc2626;">🔐 Your New Login Credentials</h3>
              <p style="margin: 8px 0;"><strong>Login URL:</strong> <a href="${d}">${d}</a></p>
              <p style="margin: 8px 0;"><strong>Username:</strong> ${a}</p>
              <p style="margin: 8px 0; font-size: 18px;"><strong>New Password:</strong> <code style="background: #fee2e2; padding: 8px 12px; border-radius: 4px; font-size: 16px;">${c}</code></p>
            </div>

            <div class="warning">
              <p style="margin: 0;"><strong>⚠️ Important Security Notice:</strong></p>
              <p style="margin: 5px 0 0 0;">Please change this password immediately after logging in. Keep your password secure and do not share it with anyone.</p>
            </div>

            <div style="text-align: center;">
              <a href="${d}" class="button">Login to Your Account</a>
            </div>

            <p style="font-size: 12px; color: #6b7280; margin-top: 30px;">
              If you did not request this password reset, please contact our support team immediately.
            </p>
          </div>
          <div class="footer">
            <p>\xa9 ${new Date().getFullYear()} Ansar Technologies. All rights reserved.</p>
            <p>This is an automated email. Please do not reply to this message.</p>
          </div>
        </div>
      </body>
      </html>
    `};try{return await o.sendMail(e),{success:!0}}catch(a){throw console.error("Error sending password reset email:",a),a}}async function w(a,b,c,d){let e=`${j("/api/public/helpdesk/confirm-ticket")}?token=${encodeURIComponent(c)}`;await o.sendMail({to:a,subject:`Confirm your support ticket ${d} - Ansar Technologies`,html:`
      <!DOCTYPE html>
      <html>
        <body style="font-family: Arial, Helvetica, sans-serif; color: #1f2937; margin: 0; padding: 24px; background: #f9fafb;">
          <div style="max-width: 560px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 28px;">
            <h2 style="margin: 0 0 16px; font-size: 20px; color: #0056b3;">Confirm your support ticket</h2>
            <p>Dear <strong>${b}</strong>,</p>
            <p>
              A support ticket (<strong>${d}</strong>) was submitted using this email
              address. It is on hold until you confirm it.
            </p>
            <div style="text-align: center; margin: 24px 0;">
              <a href="${e}" style="display: inline-block; padding: 12px 22px; background: #007bff; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600;">
                Confirm this ticket
              </a>
            </div>
            <p style="font-size: 12px; color: #6b7280;">
              Or copy this link into your browser:<br>${e}
            </p>
            <p style="font-size: 12px; color: #6b7280;">
              The link expires in 24 hours. <strong>If you did not submit this ticket, ignore
              this email</strong> - nothing will be actioned without your confirmation.
            </p>
          </div>
        </body>
      </html>
    `})}}};