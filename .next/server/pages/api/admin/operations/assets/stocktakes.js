"use strict";(()=>{var a={};a.id=9227,a.ids=[9227],a.modules={1726:(a,b,c)=>{c.r(b),c.d(b,{config:()=>v,default:()=>u,handler:()=>x});var d={};c.r(d),c.d(d,{default:()=>r});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19275),l=c(96543),m=c(92102),n=c(95514),o=c(87068);let p="assets_internal";async function q(a){return(await (0,i.P)(`SELECT s.id, s.ref_no, s.title, s.scope_location, s.assigned_to, s.state,
            DATE_FORMAT(s.opened_on, '%Y-%m-%d') AS opened_on,
            DATE_FORMAT(s.closed_on, '%Y-%m-%d') AS closed_on,
            DATE_FORMAT(s.starts_on, '%Y-%m-%d') AS starts_on,
            DATE_FORMAT(s.due_on, '%Y-%m-%d')    AS due_on,
            s.opened_by, s.closed_by, s.notes,
            e.full_name   AS assignee_name,
            e.employee_id AS assignee_code
       FROM asset_stocktakes s
       LEFT JOIN employees e ON e.id = s.assigned_to
      WHERE s.id = ? LIMIT 1`,[a]))[0]||null}async function r(a,b){let c=await (0,j.OC)(a,b);if(c){b.setHeader("Cache-Control","no-store");try{if("GET"===a.method){if(!(0,j.OD)(c,b,p,"view"))return;let d=Number(a.query.id);if(Number.isInteger(d)&&d>0){let c=await q(d);if(!c)return b.status(404).json({success:!1,error:"Stock take not found."});let e=await (0,i.P)(`SELECT l.id, l.asset_id, l.expected_location, l.expected_status, l.counted_state,
                  l.actual_location, l.note, l.counted_by,
                  DATE_FORMAT(l.counted_at, '%Y-%m-%d %H:%i') AS counted_at,
                  a.asset_no, a.name AS asset_name, a.serial_no, a.tag_no, a.category,
                  -- The cover photograph. A count sheet is walked with the unit in hand, and telling
                  -- one of four identical laptops from another is the whole job.
                  a.photo_path,
                  -- The LIVE values, alongside the snapshot. Showing both is the point: the
                  -- difference between them is what a reader is looking for.
                  a.location AS current_location, a.status AS current_status
             FROM asset_stocktake_lines l
             JOIN assets a ON a.id = l.asset_id
            WHERE l.stocktake_id = ?
            -- ── BY NAME, NOT BY asset_no ──
            --
            -- The identifier is a 12-character random ID now. This is the order a count sheet is WALKED
            -- in and the order the printed Count Record groups from, so a random sequence would send
            -- somebody up and down the same aisle. A name puts the four identical laptops together,
            -- which is what the reader is checking off.
            --
            -- NO BACKTICKS ANYWHERE IN THIS COMMENT: the statement is a template literal, and one would
            -- close the string.
            ORDER BY a.name ASC, a.id ASC`,[d]);if("1"===a.query.print){let[a,f]=await Promise.all([(0,o.rC)(),(0,o.P6)()]),g=await (0,i.P)(`SELECT COUNT(*)                                                       AS expected_count,
                    COUNT(counted_state)                                           AS counted_count,
                    SUM(counted_state IN ('not_found', 'found_elsewhere'))          AS discrepancy_count,
                    SUM(counted_state = 'found')                                    AS found_count,
                    SUM(counted_state = 'found_elsewhere')                          AS elsewhere_count,
                    SUM(counted_state = 'not_found')                                AS not_found_count
               FROM asset_stocktake_lines
              WHERE stocktake_id = ?`,[d]);return b.status(200).json({success:!0,session:c,lines:e,totals:g[0]||null,issuer:{...a,logo_path:f.logo_path,logo_height_mm:f.logo_height_mm}})}return b.status(200).json({success:!0,session:c,lines:e})}let e=await (0,i.P)(`SELECT s.id, s.ref_no, s.title, s.scope_location, s.state,
                DATE_FORMAT(s.opened_on, '%Y-%m-%d') AS opened_on,
                DATE_FORMAT(s.closed_on, '%Y-%m-%d') AS closed_on,
                DATE_FORMAT(s.starts_on, '%Y-%m-%d') AS starts_on,
                DATE_FORMAT(s.due_on, '%Y-%m-%d')    AS due_on,
                s.assigned_to,
                e.full_name   AS assignee_name,
                e.employee_id AS assignee_code,
                (s.due_on IS NOT NULL AND s.state <> 'closed'
                  AND s.due_on < CURDATE())                             AS is_overdue,
                s.opened_by, s.closed_by, s.notes,
                (SELECT COUNT(*) FROM asset_stocktake_lines l
                  WHERE l.stocktake_id = s.id)                          AS expected_count,
                (SELECT COUNT(*) FROM asset_stocktake_lines l
                  WHERE l.stocktake_id = s.id AND l.counted_state IS NOT NULL) AS counted_count,
                (SELECT COUNT(*) FROM asset_stocktake_lines l
                  WHERE l.stocktake_id = s.id
                    AND l.counted_state IN ('not_found', 'found_elsewhere'))    AS discrepancy_count
           FROM asset_stocktakes s
           LEFT JOIN employees e ON e.id = s.assigned_to
          ORDER BY s.state = 'closed' ASC, s.id DESC`),f=await (0,i.P)(`SELECT DISTINCT location FROM assets
          WHERE holder = 'internal' AND location IS NOT NULL AND location <> ''
          ORDER BY location ASC`),g=await (0,i.P)(`SELECT id, full_name, employee_id
           FROM employees
          WHERE status = 'active'
          ORDER BY full_name ASC`);return b.status(200).json({success:!0,data:e,locations:f,employees:g})}if("POST"===a.method){if(!(0,j.OD)(c,b,p,"edit"))return;let d=(0,j.J9)(a),e=(0,l.gx)(d.scope_location,200),f=(0,l.gx)(d.title,200),g=(0,l._$)(d.starts_on),h=(0,l._$)(d.due_on),o=(0,l.fk)(d.assigned_to);if(g&&h&&h<g)return b.status(400).json({success:!1,error:`The window ends before it starts: ${g} to ${h}. Check which way round the two dates go.`});if(o){let a=await (0,i.P)("SELECT id, full_name, status FROM employees WHERE id = ? LIMIT 1",[o]);if(0===a.length)return b.status(400).json({success:!1,error:"That employee no longer exists. Reload and choose again."});if("active"!==a[0].status)return b.status(409).json({success:!1,error:`${a[0].full_name} is no longer active, so a count cannot be assigned to them.`})}let q=await (0,i.P)(`SELECT id, ref_no, state FROM asset_stocktakes
          WHERE state <> 'closed' AND scope_location <=> ?
          LIMIT 1`,[e]);if(q.length>0)return b.status(409).json({success:!1,error:`${q[0].ref_no} is still ${q[0].state} for ${e?`"${e}"`:"the whole register"}. Close it before opening another, or two counts of the same equipment will produce two answers.`});let r=(0,n.r9)(),s=await i.Ay.getConnection(),t=async(a,b)=>{let[c]=await s.query(a,b);return c};try{await s.beginTransaction();let i="",j=0;for(let a=0;a<5;a++){i=await (0,m.fp)("asset_stocktakes","ref_no","STK",t);try{let[a]=await s.query(`INSERT INTO asset_stocktakes
                 (ref_no, title, scope_location, assigned_to, state, opened_on,
                  starts_on, due_on, opened_by, notes)
               VALUES (?, ?, ?, ?, 'open', ?, ?, ?, ?, ?)`,[i,f||null,e,o,r,g,h,c.username,(0,l.gx)(d.notes,500)]);j=a.insertId;break}catch(a){if("ER_DUP_ENTRY"===a.code)continue;throw a}}if(!j)return await s.rollback(),b.status(503).json({success:!1,error:"Could not allocate a stock take reference. Please try again."});let p=n.jS.map(()=>"?").join(", "),q=[j,...n.jS],u="";e&&(u=" AND a.location = ?",q.push(e)),await s.query(`INSERT INTO asset_stocktake_lines
             (stocktake_id, asset_id, expected_location, expected_status)
           SELECT ?, a.id, a.location, a.status
             FROM assets a
            WHERE a.holder = 'internal'
              AND a.status NOT IN (${p})
              ${u}`,q);let[v]=await s.query("SELECT COUNT(*) AS n FROM asset_stocktake_lines WHERE stocktake_id = ?",[j]),w=Number(v[0]?.n||0);return await s.commit(),await (0,k.At)(a,{action:"CREATE",module:"Assets: Internal",target:`Stock take: ${i}`,description:`Stock take ${i} opened over ${e||"the whole internal register"} with ${w} expected item(s)`+(f?`, titled "${f}"`:""),after:{ref_no:i,title:f||null,scope_location:e,expected:w,assigned_to:o,starts_on:g,due_on:h}}),b.status(201).json({success:!0,id:j,ref_no:i,message:0===w?`${i} opened, but no internal equipment matches that scope — there is nothing to count.`:`${i} opened with ${w} item(s) to count.`})}catch(a){throw await s.rollback(),a}finally{s.release()}}if("PUT"===a.method){let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid id."});let e=await q(d);if(!e)return b.status(404).json({success:!1,error:"Stock take not found."});let f=(0,j.J9)(a),g=(0,l.yL)(f.state,n.N4,e.state);if(g===e.state){if(!(0,j.OD)(c,b,p,"edit"))return;if("closed"===e.state)return b.status(409).json({success:!1,error:`${e.ref_no} is closed. A closed count is history and cannot be edited.`});let g=(0,l.gx)(f.title,200),h=(0,l._$)(f.starts_on),m=(0,l._$)(f.due_on),n=(0,l.fk)(f.assigned_to);if(h&&m&&m<h)return b.status(400).json({success:!1,error:`The window ends before it starts: ${h} to ${m}. Check which way round the two dates go.`});if(n){let a=await (0,i.P)("SELECT id, full_name, status FROM employees WHERE id = ? LIMIT 1",[n]);if(0===a.length)return b.status(400).json({success:!1,error:"That employee no longer exists. Reload and choose again."});if("active"!==a[0].status)return b.status(409).json({success:!1,error:`${a[0].full_name} is no longer active, so a count cannot be assigned to them.`})}return await (0,i.P)(`UPDATE asset_stocktakes
              SET title = ?, assigned_to = ?, starts_on = ?, due_on = ?, notes = ?
            WHERE id = ?`,[g||null,n,h,m,(0,l.gx)(f.notes,500),d]),await (0,k.At)(a,{action:"UPDATE",module:"Assets: Internal",target:`Stock take: ${e.ref_no}`,description:`${e.ref_no} plan updated`,before:{title:e.title,assigned_to:e.assigned_to,starts_on:e.starts_on,due_on:e.due_on},after:{title:g||null,assigned_to:n,starts_on:h,due_on:m}}),b.status(200).json({success:!0,message:"Saved."})}if(!(0,n.HN)(e.state,g))return b.status(409).json({success:!1,error:`A stock take moves forward one step at a time: ${n.N4.join(" → ")}. ${e.ref_no} is ${e.state}, so it cannot go to ${g}. Reconciling writes "lost" onto real assets, which is why it cannot be reversed.`});if("reconciled"===g){if(!(0,j.OD)(c,b,p,"stocktake"))return;let f=await (0,i.P)(`SELECT COUNT(*) AS n FROM asset_stocktake_lines
            WHERE stocktake_id = ? AND counted_state IS NULL`,[d]);if(Number(f[0]?.n||0)>0)return b.status(409).json({success:!1,error:`${f[0].n} item(s) have not been counted. Reconciling now would write "lost" against equipment nobody has looked for yet.`});let g=await (0,i.P)(`SELECT l.asset_id, a.asset_no, l.expected_location
             FROM asset_stocktake_lines l
             JOIN assets a ON a.id = l.asset_id
            WHERE l.stocktake_id = ? AND l.counted_state = 'not_found'`,[d]),h=await i.Ay.getConnection();try{for(let a of(await h.beginTransaction(),g))await h.query("UPDATE assets SET status = 'lost' WHERE id = ?",[a.asset_id]),await h.query(`INSERT INTO asset_movements
                 (asset_id, movement, moved_on, from_holder, to_holder, remarks, recorded_by)
               VALUES (?, 'status_change', ?, ?, 'Unaccounted for', ?, ?)`,[a.asset_id,(0,n.r9)(),a.expected_location||"Store",`Not found during stock take ${e.ref_no}. Status set to lost.`,c.username]);await h.query("UPDATE asset_stocktakes SET state = 'reconciled' WHERE id = ?",[d]),await h.commit()}catch(a){throw await h.rollback(),a}finally{h.release()}return await (0,k.At)(a,{action:"UPDATE",module:"Assets: Internal",target:`Stock take: ${e.ref_no}`,description:`${e.ref_no} reconciled; ${g.length} asset(s) set to lost`,before:{state:e.state},after:{state:"reconciled",lost:g.map(a=>a.asset_no)}}),b.status(200).json({success:!0,message:0===g.length?`${e.ref_no} reconciled. Everything was accounted for.`:`${e.ref_no} reconciled. ${g.length} asset(s) set to lost: ${g.map(a=>a.asset_no).join(", ")}.`})}if(!(0,j.OD)(c,b,p,"edit"))return;let h="closed"===g;return await (0,i.P)(`UPDATE asset_stocktakes
            SET state = ?, closed_on = ${h?"?":"closed_on"},
                closed_by = ${h?"?":"closed_by"}
          WHERE id = ?`,h?[g,(0,n.r9)(),c.username,d]:[g,d]),await (0,k.At)(a,{action:"UPDATE",module:"Assets: Internal",target:`Stock take: ${e.ref_no}`,description:`${e.ref_no} moved from ${e.state} to ${g}`,before:{state:e.state},after:{state:g}}),b.status(200).json({success:!0,message:h?`${e.ref_no} closed. It is now read-only history.`:`${e.ref_no} is now ${g}.`})}if("DELETE"===a.method){if(!(0,j.OD)(c,b,p,"delete"))return;let d=Number(a.query.id);if(!Number.isInteger(d)||d<1)return b.status(400).json({success:!1,error:"Invalid id."});let e=await q(d);if(!e)return b.status(404).json({success:!1,error:"Stock take not found."});if("reconciled"===e.state||"closed"===e.state)return b.status(409).json({success:!1,error:`${e.ref_no} is ${e.state}. It has already changed asset records and the movement history refers to it, so deleting it would leave those changes unexplained.`});return await (0,i.P)("DELETE FROM asset_stocktakes WHERE id = ?",[d]),await (0,k.At)(a,{action:"DELETE",module:"Assets: Internal",target:`Stock take: ${e.ref_no}`,description:`Stock take ${e.ref_no} removed before reconciling`,before:{ref_no:e.ref_no,state:e.state}}),b.status(200).json({success:!0,message:`${e.ref_no} removed.`})}return b.setHeader("Allow","GET, POST, PUT, DELETE"),b.status(405).json({success:!1,error:"Method not allowed"})}catch(a){return console.error("Stock take error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load stock takes"})}}}var s=c(58112),t=c(18766);let u=(0,h.M)(d,"default"),v=(0,h.M)(d,"config"),w=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets/stocktakes",pathname:"/api/admin/operations/assets/stocktakes",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function x(a,b,c){let d=await w.prepare(a,b,{srcPage:"/api/admin/operations/assets/stocktakes"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,s.getTracer)(),e=d.getActiveScopeSpan(),j=w.instrumentationOnRequestError.bind(w),k=async e=>w.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:w.isDev,page:"/api/admin/operations/assets/stocktakes",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==t.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(t.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:s.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(w.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},3498:a=>{a.exports=require("mysql2/promise")},19275:(a,b,c)=>{c.d(b,{At:()=>j,Mx:()=>g});var d=c(88251),e=c(63415);async function f(a){let b=function(a){let b=(0,e.T1)(a);return"unknown"===b?null:b}(a),c={userId:null,username:"system",role:null,ip:b,portal:"admin"};try{let e="string"==typeof a.query?.hash?a.query.hash:"",f=a.headers.authorization||"",g=f.startsWith("Bearer ")?f.slice(7).trim():"",h=e||g;if(!h)return c;let i=await (0,d.P)("SELECT username, user_type FROM admin_sessions WHERE hash = ? LIMIT 1",[h]);if(!i.length)return c;let{username:j,user_type:k}=i[0],l=await (0,d.P)("SELECT id FROM admins WHERE username = ? LIMIT 1",[j]),m=l.length?l[0].id:null,n=null;if(null!==m){let a=await (0,d.P)(`SELECT r.name FROM roles r
         INNER JOIN admin_roles ar ON ar.role_id = r.id
         WHERE ar.admin_id = ? ORDER BY r.id LIMIT 1`,[m]);a.length&&(n=a[0].name)}return{userId:m,username:j,role:n,ip:b,portal:"client"===k?"client":"employee"===k?"employee":"admin"}}catch{return c}}async function g(a,b){try{let c=b.actor||(a?await f(a):null);await (0,d.P)(`INSERT INTO activity_logs
         (level, category, \`user\`, user_id, ip, \`path\`, portal, message, details)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,[b.level||"INFO",b.category||"System",c?.username||"system",c?.userId??null,c?.ip??null,b.path??null,c?.portal??null,b.message,b.details??null])}catch{}}let h=/password|passwd|token|secret|api_key|hash|receipt|payment_proof|doc_data|file_data|^doc_|_data$/i;function i(a){if(null==a)return null;try{return JSON.stringify(function(a){if(!a||"object"!=typeof a)return a;let b={};for(let[c,d]of Object.entries(a))if(!h.test(c)){if("string"==typeof d&&d.length>300){b[c]=d.slice(0,300)+"…";continue}b[c]=d}return b}(a))}catch{return null}}async function j(a,b){try{let c=b.actor||(a?await f(a):null);await (0,d.P)(`INSERT INTO audit_logs
         (action, module, \`user\`, user_id, user_role, ip, target, description, before_data, after_data)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[b.action,b.module,c?.username||"system",c?.userId??null,c?.role??null,c?.ip??null,b.target,b.description,i(b.before),i(b.after)]),await g(null,{level:["DELETE","REJECT","SUSPEND"].includes(b.action)?"WARN":"INFO",category:b.module,message:b.description,details:b.target,actor:c||void 0})}catch{}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},92102:(a,b,c)=>{c.d(b,{HT:()=>m,MD:()=>o,Nr:()=>i,fp:()=>g,g:()=>k,n0:()=>n,v3:()=>h,yU:()=>l,yk:()=>p});var d=c(88251),e=c(96543),f=c(95514);async function g(a,b,c,e=d.P){let f=new Date().getFullYear(),h=`${c}-${f}-%`,i=await e(`SELECT \`${b}\` AS ref FROM \`${a}\`
      WHERE \`${b}\` LIKE ?
      ORDER BY LENGTH(\`${b}\`) DESC, \`${b}\` DESC
      LIMIT 1`,[h]),j=1;if(i.length>0){let a=Number(String(i[0].ref).split("-").pop()||"0");Number.isFinite(a)&&(j=a+1)}return`${c}-${f}-${String(j).padStart(4,"0")}`}async function h(){return await (0,d.P)(`SELECT a.id, a.application_no, a.company_name, a.ssm_number, a.services,
            a.email, a.office_phone, a.mobile_phone, a.director_name,
            a.business_address, a.city, a.state, a.cidb_grade, a.bumiputera_status,
            DATE_FORMAT(a.approval_date, '%Y-%m-%d') AS approval_date
       FROM procurement_applications a
      WHERE a.status = 'approved'
        AND NOT EXISTS (SELECT 1 FROM vendors v WHERE v.application_id = a.id)
      ORDER BY a.company_name ASC`)}async function i(){return await (0,d.P)(`SELECT p.id, p.reference_no, p.company, p.ssm, p.industry, p.state, p.country,
            p.contact_name, p.position, p.email, p.phone, p.website, p.expected_revenue,
            DATE_FORMAT(p.reviewed_at, '%Y-%m-%d') AS reviewed_at
       FROM partner_applications p
      WHERE p.status = 'approved'
        AND NOT EXISTS (SELECT 1 FROM business_clients c WHERE c.application_id = p.id)
      ORDER BY p.company ASC`)}async function j(){return(await (0,d.P)(`SELECT name FROM asset_repair_categories
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)).map(a=>a.name)}async function k(){return await (0,d.P)(`SELECT name, icon, expects_next_due FROM asset_repair_categories
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)}async function l(a){let b=String(a??"").trim(),c=await j(),d=c.find(a=>a===b);if(d)return d;let e=c.find(a=>a.toLowerCase()===b.toLowerCase());return e||c.find(a=>"Corrective"===a)||c[0]||"Corrective"}function m(a){let b=(0,e.gx)(a.plate_no,20),c=(0,e.gx)(a.chassis_no,40),d=(0,e.gx)(a.engine_no,40),g=String(a.fuel_type??"").trim().toLowerCase();return{plate_no:b?b.toUpperCase().replace(/\s+/g," "):null,chassis_no:c?c.toUpperCase().replace(/\s+/g,""):null,engine_no:d?d.toUpperCase().replace(/\s+/g,""):null,fuel_type:f.Q.includes(g)?g:null,colour:(0,e.gx)(a.colour,40),registered_on:(0,e._$)(a.registered_on),road_tax_until:(0,e._$)(a.road_tax_until)}}function n(a){return f.Dx.some(b=>null!==a[b])}async function o(a,b,c){return n(b)?0===(await (0,d.P)("SELECT asset_id FROM asset_vehicles WHERE asset_id = ? LIMIT 1",[a])).length?void await (0,d.P)(`INSERT INTO asset_vehicles
         (asset_id, plate_no, chassis_no, engine_no, fuel_type, colour, registered_on,
          road_tax_until, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,[a,b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,c]):void await (0,d.P)(`UPDATE asset_vehicles
        SET plate_no = ?, chassis_no = ?, engine_no = ?, fuel_type = ?, colour = ?,
            registered_on = ?, road_tax_until = ?
      WHERE asset_id = ?`,[b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,a]):void await (0,d.P)("DELETE FROM asset_vehicles WHERE asset_id = ?",[a])}function p(a){if(a?.code!=="ER_DUP_ENTRY")return null;let b=String(a?.message||"");for(let[a,c]of Object.entries(f.MY))if(b.includes(a))return`Another asset in the register already has that ${c}. Two assets cannot be the same vehicle, so check whether this one is already recorded.`;return"Another asset in the register already has one of those vehicle numbers."}}};var b=require("../../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,1225,7068,5514],()=>b(b.s=1726));module.exports=c})();