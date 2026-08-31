"use strict";(()=>{var a={};a.id=4479,a.ids=[4479],a.modules={3498:a=>{a.exports=require("mysql2/promise")},21674:(a,b,c)=>{c.d(b,{k:()=>e});let d=`
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
            WHERE ${b}.asset_id = ${a}.id)`}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},99558:(a,b,c)=>{c.r(b),c.d(b,{config:()=>w,default:()=>v,handler:()=>y});var d={};c.r(d),c.d(d,{default:()=>q});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19275),l=c(96543),m=c(92102),n=c(21674),o=c(95514);let p={internal:"assets_internal",external:"assets_external"};async function q(a,b){let c=await (0,j.OC)(a,b);if(!c)return;b.setHeader("Cache-Control","no-store");let d=String(a.query.holder||"").trim();if(!o.F7.includes(d))return b.status(400).json({success:!1,error:"A register must be named: holder=internal or holder=external."});let e=p[d];try{if("GET"===a.method){if(!(0,j.OD)(c,b,e,"view"))return;if("1"===String(a.query.options||"")){let[a,c,d,e,f,g,h,j,k]=await Promise.all([(0,i.P)(`SELECT id, name, icon, useful_life_years, default_loanable FROM asset_categories
              WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`),(0,i.P)(`SELECT id, employee_id, full_name, department_id FROM employees
              WHERE status = 'active' ORDER BY full_name ASC`),(0,i.P)("SELECT id, name FROM departments ORDER BY name ASC"),(0,i.P)(`SELECT id, company_name, contact_person FROM client_users
              WHERE status = 'active' ORDER BY company_name ASC`),(0,i.P)(`SELECT id, title, client, year FROM projects
              ORDER BY year DESC, title ASC LIMIT 300`),(0,i.P)(`SELECT id, vendor_no, name FROM vendors
              WHERE status = 'active' ORDER BY name ASC`),(0,i.P)(`SELECT id, ref_no, title, contract_no,
                    DATE_FORMAT(handover_date, '%Y-%m-%d') AS handover_date, dlp_months
               FROM tenders
              WHERE stage IN ('awarded', 'closed')
              ORDER BY award_date DESC, id DESC LIMIT 300`),(0,i.P)(`SELECT id, client_id, name FROM asset_sites
              WHERE is_active = 1 ORDER BY name ASC`),(0,i.P)(`SELECT id, brand, model_name, category,
                    default_useful_life_years, default_warranty_months
               FROM asset_models
              WHERE is_active = 1 ORDER BY brand ASC, model_name ASC`)]);return b.status(200).json({success:!0,categories:a,employees:c,departments:d,clients:e,projects:f,vendors:g,tenders:h,sites:j,models:k})}let f=["a.holder = ?"],g=[d],h=String(a.query.status||"").trim();if(h&&"all"!==h){if(!o.aN.includes(h))return b.status(400).json({success:!1,error:"Unknown status filter."});f.push("a.status = ?"),g.push(h)}let k=(0,l.gx)(a.query.category,80);k&&(f.push("a.category = ?"),g.push(k));let m="1"===String(a.query.all||"");if(m&&!(0,j.OD)(c,b,e,"export"))return;let p=Number(a.query.per_page),q=m?5e3:Number.isFinite(p)?Math.min(100,Math.max(1,Math.trunc(p))):100,r=Number(a.query.page),s=m||!Number.isFinite(r)?1:Math.max(1,Math.trunc(r)),t=(s-1)*q,u=String(a.query.q||"").trim();if(u){let a=(0,l.AR)(u);f.push("(a.asset_no LIKE ? ESCAPE '\\\\' OR a.name LIKE ? ESCAPE '\\\\' OR a.serial_no LIKE ? ESCAPE '\\\\' OR a.tag_no LIKE ? ESCAPE '\\\\' OR a.brand LIKE ? ESCAPE '\\\\' OR a.model LIKE ? ESCAPE '\\\\' OR e.full_name LIKE ? ESCAPE '\\\\' OR c.company_name LIKE ? ESCAPE '\\\\')"),g.push(a,a,a,a,a,a,a,a)}let v=await (0,i.P)(`SELECT a.id, a.asset_no, a.holder, a.name, a.category, a.brand, a.model,
                a.serial_no, a.tag_no, a.status, a.condition_note, a.photo_path,
                a.purchase_cost, a.useful_life_years,
                DATE_FORMAT(a.purchase_date, '%Y-%m-%d')  AS purchase_date,
                DATE_FORMAT(a.installed_on, '%Y-%m-%d')   AS installed_on,
                a.ownership,
                -- Cover, derived. warranty_until and contract_until were columns holding one
                -- date each; a unit can sit inside a manufacturer warranty AND a DLP AND a
                -- service contract at once, so cover is the LATEST end date across all of them.
                -- Reporting the earliest would have somebody quote a client for work that is
                -- already covered.
                --
                -- The expression, including the DLP inherited from the tender and the override
                -- rule that suppresses it, lives in @/lib/asset-cover-sql. It is written there as
                -- an UNCORRELATED derived table filtered from the outside, because MariaDB
                -- refuses a derived table that reaches outward for the alias a, and production
                -- runs MariaDB. Read that file before changing the shape of this.
                --
                -- DATE_FORMAT, not the bare column. mysql2 returns a DATE as a JS Date at LOCAL
                -- midnight, which JSON serialises as a UTC timestamp -- east of UTC that is 16:00
                -- the PREVIOUS day. Without this the cell printed
                -- "2026-08-09T16:00:00.000Z" for a date of 2026-08-10.
                DATE_FORMAT(${(0,n.k)("a","cu")}, '%Y-%m-%d')              AS cover_until,
                (SELECT COUNT(*) FROM asset_obligations o WHERE o.asset_id = a.id) AS obligation_count,
                a.location, a.site_name, a.site_id, a.tender_id,
                -- The SITE the unit is installed at, as master data. The site_name column above
                -- is the old free-text field and stays for the room or rack within a site.
                st.name AS site_label,
                t.ref_no      AS tender_ref,
                t.contract_no AS tender_contract_no,
                a.employee_id, a.department_id, a.client_id, a.project_id, a.vendor_id,
                e.full_name   AS employee_name,
                e.employee_id AS employee_code,
                d.name        AS department_name,
                c.company_name AS client_company,
                p.title       AS project_title,
                v.name        AS vendor_name,
                (SELECT COUNT(*) FROM asset_maintenance m WHERE m.asset_id = a.id) AS service_count,
                (SELECT DATE_FORMAT(MIN(m.next_due), '%Y-%m-%d') FROM asset_maintenance m
                  WHERE m.asset_id = a.id AND m.next_due IS NOT NULL
                    AND m.next_due >= CURDATE())                                   AS next_service,
                (SELECT COUNT(*) FROM helpdesk_tickets t WHERE t.asset_id = a.id)  AS ticket_count
           FROM assets a
           LEFT JOIN employees    e ON e.id = a.employee_id
           LEFT JOIN departments  d ON d.id = a.department_id
           LEFT JOIN client_users c ON c.id = a.client_id
           LEFT JOIN projects     p ON p.id = a.project_id
           LEFT JOIN vendors      v ON v.id = a.vendor_id
           LEFT JOIN tenders      t ON t.id = a.tender_id
           LEFT JOIN asset_sites st ON st.id = a.site_id
          WHERE ${f.join(" AND ")}
          ORDER BY a.id DESC
          LIMIT ${q} OFFSET ${t}`,g),w=await (0,i.P)(`SELECT COUNT(*) AS n
           FROM assets a
           LEFT JOIN employees    e ON e.id = a.employee_id
           LEFT JOIN client_users c ON c.id = a.client_id
          WHERE ${f.join(" AND ")}`,g),x=Number(w[0]?.n||0),y=await (0,i.P)("SELECT status, COUNT(*) AS n FROM assets WHERE holder = ? GROUP BY status",[d]),z={};for(let a of o.aN)z[a]=0;let A=0;for(let a of y)z[a.status]=Number(a.n),A+=Number(a.n);let B=o.jS.map(()=>"?").join(", "),C=await (0,i.P)(`SELECT COALESCE(SUM(purchase_cost), 0) AS cost, COUNT(*) AS n
           FROM assets
          WHERE holder = ? AND ownership = 'ansar'
            AND status NOT IN (${B}) AND purchase_cost IS NOT NULL`,[d,...o.jS]),D=await (0,i.P)(`SELECT COUNT(*) AS n FROM assets
          WHERE holder = ? AND ownership = 'client' AND status NOT IN (${B})`,[d,...o.jS]),E=await (0,i.P)(`SELECT
           SUM(c.cover_until IS NOT NULL AND c.cover_until < CURDATE())              AS expired,
           SUM(c.cover_until IS NOT NULL AND c.cover_until >= CURDATE()
               AND c.cover_until <= DATE_ADD(CURDATE(), INTERVAL 30 DAY))            AS expiring,
           SUM(c.cover_until IS NULL)                                               AS uncovered
         FROM (
           SELECT a.id,
                  ${(0,n.k)("a","cs")}                                     AS cover_until
             FROM assets a
            WHERE a.holder = ? AND a.status NOT IN (${B})
         ) c`,[d,...o.jS]),F=await (0,i.P)(`SELECT COUNT(DISTINCT a.id) AS n
           FROM assets a
           JOIN asset_maintenance m ON m.asset_id = a.id
          WHERE a.holder = ? AND m.next_due IS NOT NULL AND m.next_due < CURDATE()`,[d]);return b.status(200).json({success:!0,data:v,page:s,per_page:q,total:x,summary:{...z,total:A,in_register:Number(C[0]?.n||0),total_cost:Number(C[0]?.cost||0),client_owned:Number(D[0]?.n||0),cover_expired:Number(E[0]?.expired||0),cover_expiring:Number(E[0]?.expiring||0),uncovered:Number(E[0]?.uncovered||0),service_overdue:Number(F[0]?.n||0)}})}if("POST"===a.method){if(!(0,j.OD)(c,b,e,"create"))return;let f=(0,j.J9)(a),g=(0,l.gx)(f.name,200);if(!g)return b.status(400).json({success:!1,error:"An asset name is required."});let h=(0,l.yL)(f.status,o.aN,"in_store");if(o.W9.includes(h)&&!(0,j.OD)(c,b,e,"dispose"))return;let n="ansar";if("external"===d){let a=String(f.ownership||"").trim();if(!o.v9.includes(a))return b.status(400).json({success:!1,error:"Ownership is required on an installed asset: `ansar` if ANSAR still owns it (rented, or not yet handed over), `client` if it was sold to the client."});n=a}let p="internal"===d?(0,l.fk)(f.employee_id):null,q="external"===d?(0,l.fk)(f.client_id):null;if((p||q)&&!(0,j.OD)(c,b,e,"assign"))return;let t="external"===d?(0,l.fk)(f.site_id):null;if(t){let a=await (0,i.P)(`SELECT s.id, s.name, s.client_id, s.is_active, c.company_name
             FROM asset_sites s
             JOIN client_users c ON c.id = s.client_id
            WHERE s.id = ? LIMIT 1`,[t]);if(0===a.length)return b.status(400).json({success:!1,error:"That site no longer exists."});let c=a[0];if(!q||Number(c.client_id)!==q)return b.status(400).json({success:!1,error:`"${c.name}" belongs to ${c.company_name}. Choose a site belonging to this asset's client, or set the client first.`});if(1!==c.is_active)return b.status(400).json({success:!1,error:`"${c.name}" is inactive and cannot take new equipment. Reactivate it, or choose another site.`})}let u=(0,l.fk)(f.model_id),v=null;if(u){let a=await (0,i.P)(`SELECT brand, model_name, category, default_useful_life_years, default_warranty_months
             FROM asset_models WHERE id = ? LIMIT 1`,[u]);if(0===a.length)return b.status(400).json({success:!1,error:"That model no longer exists."});v=a[0]}for(let[a,c,e]of[[p,"employees","That employee no longer exists."],["internal"===d?(0,l.fk)(f.department_id):null,"departments","That department no longer exists."],[q,"client_users","That client no longer exists."],["external"===d?(0,l.fk)(f.project_id):null,"projects","That project no longer exists."],[(0,l.fk)(f.vendor_id),"vendors","That vendor no longer exists."],["external"===d?(0,l.fk)(f.tender_id):null,"tenders","That tender no longer exists."]]){if(!a)continue;let d=await (0,i.P)(`SELECT id FROM \`${c}\` WHERE id = ? LIMIT 1`,[a]);if(0===d.length)return b.status(400).json({success:!1,error:e})}let w=(0,l.gx)(f.category,80)||v?.category||null,x=0;if("internal"===d){if(void 0!==f.is_loanable)x=+!!f.is_loanable;else if(w){let a=await (0,i.P)("SELECT default_loanable FROM asset_categories WHERE name = ? LIMIT 1",[w]);x=+(1===Number(a[0]?.default_loanable))}}let y={name:g,category:w,brand:(0,l.gx)(f.brand,120)||v?.brand||null,model:(0,l.gx)(f.model,120)||v?.model_name||null,serial_no:(0,l.gx)(f.serial_no,120),tag_no:(0,l.gx)(f.tag_no,60),description:(0,l.gx)(f.description,65535),purchase_date:(0,l._$)(f.purchase_date),purchase_cost:(0,l.TG)(f.purchase_cost),useful_life_years:r(f.useful_life_years)??r(v?.default_useful_life_years),vendor_id:(0,l.fk)(f.vendor_id),tender_id:"external"===d?(0,l.fk)(f.tender_id):null,invoice_no:(0,l.gx)(f.invoice_no,80),employee_id:p,department_id:"internal"===d?(0,l.fk)(f.department_id):null,location:"internal"===d?(0,l.gx)(f.location,200):null,client_id:q,project_id:"external"===d?(0,l.fk)(f.project_id):null,site_id:t,site_name:"external"===d?(0,l.gx)(f.site_name,200):null,site_address:"external"===d?(0,l.gx)(f.site_address,400):null,installed_on:"external"===d?(0,l._$)(f.installed_on):null,status:h,condition_note:(0,l.gx)(f.condition_note,400),notes:(0,l.gx)(f.notes,65535)},z=0,A="";for(let a=0;a<5;a++){A=await (0,m.fp)("assets","asset_no","internal"===d?"AST":"EXA");try{z=(await (0,i.P)(`INSERT INTO assets
               (asset_no, holder, ownership, name, category, brand, model, serial_no, tag_no,
                description, purchase_date, purchase_cost, useful_life_years, vendor_id,
                tender_id, invoice_no, employee_id, department_id, location,
                client_id, site_id, project_id, site_name, site_address, installed_on,
                status, condition_note, notes, is_loanable, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[A,d,n,y.name,y.category,y.brand,y.model,y.serial_no,y.tag_no,y.description,y.purchase_date,y.purchase_cost,y.useful_life_years,y.vendor_id,y.tender_id,y.invoice_no,y.employee_id,y.department_id,y.location,y.client_id,y.site_id,y.project_id,y.site_name,y.site_address,y.installed_on,y.status,y.condition_note,y.notes,x,c.username])).insertId;break}catch(a){if("ER_DUP_ENTRY"===a.code)continue;throw a}}if(!z)return b.status(503).json({success:!1,error:"Could not allocate an asset number. Please try again."});await (0,i.P)(`INSERT INTO asset_movements
           (asset_id, movement, moved_on, from_holder, to_holder, remarks, recorded_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,[z,p?"assigned":q?"deployed":"transferred",y.purchase_date||(0,o.r9)(),y.vendor_id?"Vendor":"Recorded into the register",await s(d,p,q,y.location,y.site_name),"Opening entry.",c.username]);let B="";if(v?.default_warranty_months){let a=y.installed_on||y.purchase_date,b=(0,o.wd)(a,v.default_warranty_months);b&&(await (0,i.P)(`INSERT INTO asset_obligations
               (asset_id, kind, starts_on, ends_on, reference, notes, created_by)
             VALUES (?, 'warranty', ?, ?, ?, ?, ?)`,[z,a,b,null,`${v.default_warranty_months}-month default for ${v.brand} ${v.model_name}.`,c.username]),B=` Warranty recorded to ${b} from the model default.`)}return await (0,k.At)(a,{action:"CREATE",module:"internal"===d?"Assets: Internal":"Assets: External",target:`Asset: ${A}`,description:`Asset "${g}" recorded as ${h}`,after:{asset_no:A,name:g,holder:d,status:h}}),b.status(201).json({success:!0,id:z,asset_no:A,message:`${g} recorded as ${A}.${B}`})}return b.setHeader("Allow","GET, POST"),b.status(405).json({success:!1,error:"Method not allowed"})}catch(a){return console.error("Assets error:",a),b.status(500).json({success:!1,error:a instanceof Error?a.message:"Failed to load the asset register"})}}function r(a){if(null==a||""===a)return null;let b=Number(a);return Number.isInteger(b)&&b>=1&&b<=50?b:null}async function s(a,b,c,d,e){if(b){let a=await (0,i.P)("SELECT full_name FROM employees WHERE id = ? LIMIT 1",[b]);return a[0]?.full_name||"An employee"}if(c){let a=await (0,i.P)("SELECT company_name FROM client_users WHERE id = ? LIMIT 1",[c]),b=a[0]?.company_name||"A client";return e?`${b} — ${e}`:b}return d||("internal"===a?"Store":"Not yet deployed")}var t=c(58112),u=c(18766);let v=(0,h.M)(d,"default"),w=(0,h.M)(d,"config"),x=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/assets",pathname:"/api/admin/operations/assets",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function y(a,b,c){let d=await x.prepare(a,b,{srcPage:"/api/admin/operations/assets"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,t.getTracer)(),e=d.getActiveScopeSpan(),j=x.instrumentationOnRequestError.bind(x),k=async e=>x.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:x.isDev,page:"/api/admin/operations/assets",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==u.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(u.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:t.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(x.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,5514,3950],()=>b(b.s=99558));module.exports=c})();