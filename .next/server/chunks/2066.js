"use strict";exports.id=2066,exports.ids=[2066],exports.modules={2066:(a,b,c)=>{c.d(b,{A5:()=>m,Dc:()=>r,IX:()=>s,OT:()=>u,UV:()=>v,Xv:()=>o,mc:()=>p});var d=c(3498),e=c.n(d),f=c(55511),g=c.n(f),h=c(21572),i=c.n(h);let j=e().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0}),k=process.env.EMAIL_ENCRYPTION_KEY||"ansar-email-secure-key-2025-v1-prod",l="aes-256-cbc";async function m(){let a=await j.getConnection();try{let[b]=await a.query("SELECT * FROM email_profiles ORDER BY profile_key ASC");return b}finally{a.release()}}async function n(a){let b=await j.getConnection();try{let[c]=await b.query("SELECT * FROM email_profiles WHERE profile_key = ? AND is_active = 1 LIMIT 1",[a]);if(0===c.length)return null;let d=c[0],e=function(a){let b=g().createHash("sha256").update(k).digest(),c=a.split(":"),d=Buffer.from(c[0],"hex"),e=c[1],f=g().createDecipheriv(l,b,d),h=f.update(e,"hex","utf8");return h+=f.final("utf8")}(d.smtp_password);return{...d,smtp_password_decrypted:e}}finally{b.release()}}async function o(a){let b=await j.getConnection();try{let[c]=await b.query("SELECT id FROM email_profiles WHERE profile_key = ? LIMIT 1",[a.profile_key]),d=c.length>0&&(!a.smtp_password||""===a.smtp_password.trim()),e=d?null:function(a){let b=g().createHash("sha256").update(k).digest(),c=g().randomBytes(16),d=g().createCipheriv(l,b,c),e=d.update(a,"utf8","hex");return e+=d.final("hex"),c.toString("hex")+":"+e}(a.smtp_password);if(c.length>0)return await b.query(`UPDATE email_profiles SET
          profile_name = ?,
          provider_type = ?,
          email_address = ?,
          from_name = ?,
          reply_to = ?,
          smtp_host = ?,
          smtp_port = ?,
          smtp_encryption = ?,
          smtp_authentication = ?,
          smtp_username = ?,
          ${d?"":"smtp_password = ?,"}
          connection_timeout = ?,
          max_retries = ?,
          is_active = ?,
          updated_by = ?,
          updated_at = NOW()
        WHERE profile_key = ?`,[a.profile_name,a.provider_type,a.email_address,a.from_name,a.reply_to||null,a.smtp_host,a.smtp_port,a.smtp_encryption,+!!a.smtp_authentication,a.smtp_username,...d?[]:[e],a.connection_timeout||30,a.max_retries||3,+(!1!==a.is_active),a.updated_by||null,a.profile_key]),c[0].id;{let[c]=await b.query(`INSERT INTO email_profiles (
          profile_key, profile_name, provider_type, email_address, from_name,
          reply_to, smtp_host, smtp_port, smtp_encryption, smtp_authentication,
          smtp_username, smtp_password, connection_timeout, max_retries,
          is_active, created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[a.profile_key,a.profile_name,a.provider_type,a.email_address,a.from_name,a.reply_to||null,a.smtp_host,a.smtp_port,a.smtp_encryption,+!!a.smtp_authentication,a.smtp_username,e,a.connection_timeout||30,a.max_retries||3,+(!1!==a.is_active),a.updated_by||null]);return c.insertId}}finally{b.release()}}async function p(a,b){let c=await n(a);if(!c)return{success:!1,message:"Email profile not found or inactive"};let d=r(c);if(d)return{success:!1,message:d};try{let d=i().createTransport(q(c));if(await d.verify(),b){let a=new Date().toLocaleString("en-GB",{day:"2-digit",month:"short",year:"numeric",hour:"2-digit",minute:"2-digit",second:"2-digit"});await d.sendMail({from:`"${c.from_name}" <${c.email_address}>`,replyTo:c.reply_to||c.email_address,to:b,subject:`Test Email from ${c.profile_name}`,html:`
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
              .content { background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }
              .info-box { background: white; border-left: 4px solid #667eea; padding: 15px; margin: 15px 0; border-radius: 4px; }
              .info-label { font-weight: 600; color: #667eea; font-size: 12px; text-transform: uppercase; }
              .info-value { color: #374151; margin-top: 5px; }
              .success-badge { background: #d1fae5; color: #065f46; padding: 8px 16px; border-radius: 20px; display: inline-block; font-weight: 600; font-size: 14px; }
              .footer { text-align: center; margin-top: 20px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #6b7280; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1 style="margin: 0; font-size: 24px;">✅ Test Email Successful</h1>
                <p style="margin: 10px 0 0 0; opacity: 0.9;">SMTP Configuration Verified</p>
              </div>
              <div class="content">
                <div style="text-align: center; margin-bottom: 20px;">
                  <span class="success-badge">✓ Connection Verified</span>
                </div>
                
                <p style="font-size: 14px; color: #374151;">
                  This is a test email to confirm that your SMTP configuration is working correctly.
                </p>

                <div class="info-box">
                  <div class="info-label">Email Profile</div>
                  <div class="info-value">${c.profile_name}</div>
                </div>

                <div class="info-box">
                  <div class="info-label">From Address</div>
                  <div class="info-value">${c.email_address}</div>
                </div>

                <div class="info-box">
                  <div class="info-label">SMTP Server</div>
                  <div class="info-value">${c.smtp_host}:${c.smtp_port} (${c.smtp_encryption.toUpperCase()})</div>
                </div>

                <div class="info-box">
                  <div class="info-label">Test Date & Time</div>
                  <div class="info-value">${a}</div>
                </div>

                <div style="background: #eff6ff; border: 1px solid #bfdbfe; padding: 15px; border-radius: 4px; margin-top: 20px;">
                  <p style="margin: 0; font-size: 13px; color: #1e40af;">
                    <strong>✓ Success!</strong> If you received this email, your SMTP configuration is working perfectly.
                  </p>
                </div>

                <div class="footer">
                  <p style="margin: 0;">This is an automated test email from <strong>ANSAR TECHNOLOGIES</strong></p>
                  <p style="margin: 5px 0 0 0;">Email Profile Management System</p>
                </div>
              </div>
            </div>
          </body>
          </html>
        `,text:`
Test Email Successful

This is a test email to confirm that your SMTP configuration is working correctly.

Email Profile: ${c.profile_name}
From Address: ${c.email_address}
SMTP Server: ${c.smtp_host}:${c.smtp_port} (${c.smtp_encryption.toUpperCase()})
Test Date & Time: ${a}

If you received this email, your SMTP configuration is working perfectly.

---
This is an automated test email from ANSAR TECHNOLOGIES
Email Profile Management System
        `})}let e=await j.getConnection();try{await e.query(`UPDATE email_profiles SET 
          last_test_at = NOW(),
          test_status = 'success',
          test_message = ?
        WHERE profile_key = ?`,[b?`Test email sent to ${b}`:"Connection successful",a])}finally{e.release()}return{success:!0,message:b?`Test email sent successfully to ${b}`:"SMTP connection successful"}}catch(c){let b=await j.getConnection();try{await b.query(`UPDATE email_profiles SET 
          last_test_at = NOW(),
          test_status = 'failed',
          test_message = ?
        WHERE profile_key = ?`,[c.message||"Connection failed",a])}finally{b.release()}return{success:!1,message:c.message||"SMTP connection failed"}}}function q(a){return{host:a.smtp_host,port:a.smtp_port,secure:"ssl"===a.smtp_encryption,requireTLS:"tls"===a.smtp_encryption,auth:a.smtp_authentication?{user:a.smtp_username,pass:a.smtp_password_decrypted}:void 0,connectionTimeout:1e3*(a.connection_timeout||30),greetingTimeout:15e3,socketTimeout:45e3}}function r(a){let b=Number(a.smtp_port),c=a.smtp_encryption;return a.smtp_host&&a.smtp_host.trim()?!Number.isInteger(b)||b<1||b>65535?"The SMTP port must be a number between 1 and 65535.":465===b&&"ssl"!==c?'Port 465 is encrypted from the first byte, so Encryption must be SSL. With TLS or None the client sends a plain greeting to a server waiting for a TLS handshake, and the failure reads "wrong version number" — which looks like a broken server rather than a wrong setting.':(587===b||25===b)&&"ssl"===c?`Port ${b} starts in plain text and is upgraded by STARTTLS, so Encryption must be TLS. With SSL the client begins a TLS handshake against a server sending its greeting as text, and the failure reads "wrong version number".`:null:"An SMTP host is required. Without it there is nothing to connect to."}function s(a){let b=(a.smtp_host||"").toLowerCase();return a.smtp_authentication&&("gmail"===a.provider_type||b.includes("smtp.gmail.com"))?'Gmail rejects an ordinary account password with "534-5.7.9 Please log in with your web browser". Use a 16-character App Password from the Google account\'s security settings.':null}async function t(a){let b=await n(a);if(!b)throw Error(`Email profile '${a}' not found or inactive`);let c=r(b);if(c)throw Error(`Email profile '${a}' cannot connect: ${c}`);return i().createTransport(q(b))}async function u(a,b){try{let c=await n(a);if(!c)return{success:!1,error:`Email profile '${a}' not found or inactive`};let d=await t(a),e=await d.sendMail({from:`"${c.from_name}" <${c.email_address}>`,replyTo:c.reply_to||c.email_address,to:b.to,subject:b.subject,html:b.html,text:b.text,cc:b.cc,bcc:b.bcc,attachments:b.attachments});return{success:!0,messageId:e.messageId}}catch(b){return console.error(`[Email Profile: ${a}] Send error:`,b),{success:!1,error:b.message||"Failed to send email"}}}async function v(a,b){let c=await j.getConnection();try{let[d]=await c.query("UPDATE email_profiles SET is_active = ?, updated_at = NOW() WHERE profile_key = ?",[+!!b,a]);return d.affectedRows>0}finally{c.release()}}}};