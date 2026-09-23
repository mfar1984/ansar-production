"use strict";exports.id=7594,exports.ids=[7594],exports.modules={5437:(a,b,c)=>{c.d(b,{CY:()=>f,_C:()=>j,kx:()=>g,xg:()=>i});var d=c(77598),e=c(51906);function f(a){if(12!==a.length)return!1;for(let b of a)if(!e.kl.includes(b))return!1;return!0}function g(){return h(12)}function h(a){let b=256-256%e.kl.length,c="",f=(0,d.randomBytes)(2*a),g=0;for(;c.length<a;){g>=f.length&&(f=(0,d.randomBytes)(2*a),g=0);let h=f[g];g+=1,h>=b||(c+=e.kl[h%e.kl.length])}return c}function i(){return h(32)}function j(a){return(0,e.Hy)(a)}},51906:(a,b,c)=>{c.d(b,{Hy:()=>g,Pi:()=>f,kl:()=>e});var d=c(77598);let e="0123456789ABCDEFGHJKLMNPQRSTUVWXYZ";function f(){let a=256-256%e.length,b="",c=(0,d.randomBytes)(24),f=0;for(;b.length<12;){f>=c.length&&(c=(0,d.randomBytes)(24),f=0);let g=c[f];f+=1,g>=a||(b+=e[g%e.length])}return b}function g(a){return a.trim().toUpperCase().replace(/O/g,"0").replace(/I/g,"1")}},92102:(a,b,c)=>{c.d(b,{HT:()=>m,MD:()=>o,Nr:()=>i,fp:()=>g,g:()=>k,n0:()=>n,v3:()=>h,yU:()=>l,yk:()=>p});var d=c(88251),e=c(96543),f=c(95514);async function g(a,b,c,e=d.P){let f=new Date().getFullYear(),h=`${c}-${f}-%`,i=await e(`SELECT \`${b}\` AS ref FROM \`${a}\`
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
      WHERE asset_id = ?`,[b.plate_no,b.chassis_no,b.engine_no,b.fuel_type,b.colour,b.registered_on,b.road_tax_until,a]):void await (0,d.P)("DELETE FROM asset_vehicles WHERE asset_id = ?",[a])}function p(a){if(a?.code!=="ER_DUP_ENTRY")return null;let b=String(a?.message||"");for(let[a,c]of Object.entries(f.MY))if(b.includes(a))return`Another asset in the register already has that ${c}. Two assets cannot be the same vehicle, so check whether this one is already recorded.`;return"Another asset in the register already has one of those vehicle numbers."}}};