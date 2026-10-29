"use strict";exports.id=46982,exports.ids=[46982],exports.modules={46982:(a,b,c)=>{c.d(b,{JL:()=>q,JM:()=>p,JN:()=>o,Lk:()=>m,Qb:()=>s,T4:()=>h,bZ:()=>t,cG:()=>n,dg:()=>g,vy:()=>e});var d=c(88251);let e=["id","asset_no","holder","ownership","name","category","asset_class","brand","model","serial_no","tag_no","label_printed_at","description","purchase_date","purchase_cost","useful_life_years","vendor_id","tender_id","invoice_no","employee_id","department_id","location","location_id","client_id","site_id","project_id","site_name","site_address","installed_on","pic_name","pic_position","handed_over_on","status","is_loanable","condition_note","photo_path","notes","created_by","created_at","updated_at"];function f(a){return!!a&&e.includes(a)}let g=["pending","done","na"],h=["before","after"],i=`SELECT a.id              AS asset_id,
              a.asset_no, a.name AS asset_name, a.serial_no, a.category,
              ac.id             AS category_id,
              ac.parent_id      AS category_parent_id,
              COALESCE(parent.name, ac.name) AS top_category_name,
              COALESCE(t.id, fb.id)                  AS template_id,
              COALESCE(t.name, fb.name)              AS template_name,
              COALESCE(t.form_title, fb.form_title)  AS form_title,
              (t.id IS NULL AND fb.id IS NOT NULL)   AS used_fallback
         FROM assets a
         LEFT JOIN asset_categories ac     ON ac.name = a.category
         LEFT JOIN asset_categories parent ON parent.id = ac.parent_id
         LEFT JOIN work_order_form_templates t
                ON t.category_id = COALESCE(ac.parent_id, ac.id) AND t.is_active = 1
         LEFT JOIN work_order_form_templates fb
                ON fb.category_id IS NULL AND fb.is_active = 1`;async function j(a,b){if(0===b.length)return[];let c=b.map(()=>"?").join(", ");return await a(`${i} WHERE a.id IN (${c})`,b)}async function k(a,b){let c=(await a("SELECT DATE_FORMAT(CURDATE(), '%y%m%d') AS stamp"))[0].stamp,d=`${b}-${c}-`,e=await a(`SELECT COALESCE(MAX(CAST(SUBSTRING(form_no, ?) AS UNSIGNED)), 0) AS top
       FROM work_order_service_sheets
      WHERE form_no LIKE ?`,[d.length+1,`${d}%`]),f=Number(e[0]?.top||0)+1;return`${d}${String(f).padStart(3,"0")}`}async function l(){let a=await (0,d.P)("SELECT prefix FROM work_order_numbering WHERE table_key = ? LIMIT 1",["work_orders"]);return String(a[0]?.prefix||"").trim().replace(/[^A-Za-z0-9]/g,"")||"WO"}async function m(a,b){let c=await a(`SELECT wa.id, wa.asset_id
       FROM work_order_assets wa
      WHERE wa.work_order_id = ?
        AND NOT EXISTS (SELECT 1 FROM work_order_service_sheets s
                         WHERE s.work_order_asset_id = wa.id)
      ORDER BY wa.id ASC`,[b]);if(0===c.length)return[];let d=await j(a,c.map(a=>Number(a.asset_id))),e=new Map;for(let a of d)e.set(Number(a.asset_id),a);return c.map(a=>{let b=e.get(Number(a.asset_id));return{work_order_asset_id:Number(a.id),asset_id:Number(a.asset_id),asset_no:b?.asset_no||String(a.asset_id),asset_name:b?.asset_name||"",serial_no:b?.serial_no??null,category:b?.category??null,category_id:b?.category_id??null,category_parent_id:b?.category_parent_id??null,top_category_name:b?.top_category_name??null,template_id:b?.template_id??null,template_name:b?.template_name??null,form_title:b?.form_title??null,used_fallback:Number(b?.used_fallback||0)}})}async function n(a,b){let c=await m(a,b);if(0===c.length)return{raised:0,skipped_no_template:0,skipped_assets:[]};let d=c.map(a=>a.asset_id),e=await a("SELECT work_order_no FROM work_orders WHERE id = ? LIMIT 1",[b]),g=String(e[0]?.work_order_no||""),h=Array.from(new Set(c.map(a=>a.template_id).filter(a=>null!==a)));if(0===h.length)return{raised:0,skipped_no_template:c.length,skipped_assets:c.map(a=>a.asset_no).slice(0,12)};let i=h.map(()=>"?").join(", "),j=await a(`SELECT template_id, label, field_key, input_type, autofill_from, is_required, sort_order
       FROM work_order_form_fields
      WHERE template_id IN (${i})
      ORDER BY template_id ASC, sort_order ASC, id ASC`,h),n=await a(`SELECT g.template_id, g.title AS group_title, g.sort_order AS group_sort,
            i.title, i.notes, i.is_required, i.sort_order
       FROM work_order_form_items i
       JOIN work_order_form_groups g ON g.id = i.group_id
      WHERE g.template_id IN (${i})
      ORDER BY g.template_id ASC, g.sort_order ASC, i.sort_order ASC, i.id ASC`,h),o=Array.from(new Set(j.map(a=>a.autofill_from).filter(f))),p=new Map;{let b=["id",...o.filter(a=>"id"!==a)].map(a=>`\`${a}\``).join(", "),c=d.map(()=>"?").join(", ");for(let e of(await a(`SELECT ${b} FROM assets WHERE id IN (${c})`,d)))p.set(Number(e.id),e)}let q=await l(),r=0,s=[];for(let d of c){if(null===d.template_id){s.push(d.asset_no);continue}let c=p.get(d.asset_id)||{},e=j.filter(a=>Number(a.template_id)===Number(d.template_id)).map((a,b)=>{let d=f(a.autofill_from)?a.autofill_from:null;return{label:a.label,field_key:a.field_key,input_type:a.input_type,source_column:d,is_required:+!!Number(a.is_required),sort_order:Number(a.sort_order)||b+1,value:null===d?null:function(a){if(null==a)return null;if(a instanceof Date){let b=a=>String(a).padStart(2,"0");return`${a.getFullYear()}-${b(a.getMonth()+1)}-${b(a.getDate())}`}let b=String(a).trim();return 0===b.length?null:b.slice(0,500)}(c[d])}}),h=n.filter(a=>Number(a.template_id)===Number(d.template_id)).map((a,b)=>({group_title:a.group_title,group_sort:Number(a.group_sort)||1,title:a.title,notes:a.notes,is_required:+!!Number(a.is_required),sort_order:Number(a.sort_order)||b+1})),i=0,l=null;for(let c=0;c<5&&0===i;c+=1){let c=await k(a,q);try{let e=await a(`INSERT INTO work_order_service_sheets
             (work_order_asset_id, work_order_id, asset_id, template_id, form_no,
              template_name, form_title, category_name,
              asset_no, asset_name, serial_no, work_order_no)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[d.work_order_asset_id,b,d.asset_id,d.template_id,c,d.template_name||"",d.form_title||"",d.top_category_name,d.asset_no,d.asset_name,d.serial_no,g]);i=Number(e?.insertId||0)}catch(a){if(l=a,a?.code!=="ER_DUP_ENTRY"||!String(a.sqlMessage||"").includes("uq_woss_form_no"))throw a}}if(0===i)throw l instanceof Error?l:Error("Could not allocate a service sheet number.");if(e.length>0){let b=e.map(()=>"(?, ?, ?, ?, ?, ?, ?, ?)").join(", "),c=[];for(let a of e)c.push(i,a.label,a.field_key,a.input_type,a.source_column,a.is_required,a.sort_order,a.value);await a(`INSERT INTO work_order_sheet_fields
           (sheet_id, label, field_key, input_type, source_column, is_required, sort_order, value)
         VALUES ${b}`,c)}if(h.length>0){let b=h.map(()=>"(?, ?, ?, ?, ?, ?, ?)").join(", "),c=[];for(let a of h)c.push(i,a.group_title,a.group_sort,a.title,a.notes,a.is_required,a.sort_order);await a(`INSERT INTO work_order_sheet_items
           (sheet_id, group_title, group_sort, title, notes, is_required, sort_order)
         VALUES ${b}`,c)}r+=1}return{raised:r,skipped_no_template:s.length,skipped_assets:s.slice(0,12)}}function o(a){if(null===a)return"";let b=[];if(a.raised>0&&b.push(`${a.raised} service sheet${1===a.raised?"":"s"} raised.`),a.skipped_no_template>0){let c=a.skipped_assets.join(", ");b.push(`${a.skipped_no_template} asset${1===a.skipped_no_template?"":"s"} got no sheet because that device category has no active service form${c?`: ${c}`:""}${a.skipped_no_template>a.skipped_assets.length?", and others":""}.`)}return b.length>0?` ${b.join(" ")}`:""}async function p(a,b,c){let d=c.length>0?c.map(()=>"?").join(", "):null;return await a(`SELECT s.form_no, s.asset_no
       FROM work_order_service_sheets s
      WHERE s.work_order_id = ?
        AND s.submitted_at IS NOT NULL
        ${null===d?"":`AND s.asset_id NOT IN (${d})`}
      ORDER BY s.form_no ASC`,[b,...c])}async function q(a){let b=(await (0,d.P)(`SELECT COUNT(*)                                AS total,
            SUM(submitted_at IS NOT NULL)           AS submitted,
            SUM(not_required_at IS NOT NULL)        AS not_required
       FROM work_order_service_sheets WHERE work_order_id = ?`,[a]))[0]||{},c=Number(b.total||0),e=Number(b.submitted||0),f=Number(b.not_required||0);return{total:c,submitted:e,not_required:f,outstanding:c-e-f}}let r=`SELECT s.id, s.work_order_asset_id, s.asset_id, s.form_no,
              s.template_name, s.form_title, s.category_name,
              s.asset_no, s.asset_name, s.serial_no,
              DATE_FORMAT(s.submitted_at, '%Y-%m-%d %H:%i')    AS submitted_at,
              s.submitted_by_employee_id,
              e.full_name                                      AS submitted_by_name,
              s.engineer_name,
              (s.signature_path IS NOT NULL)                   AS signed,
              s.no_signature_reason,
              DATE_FORMAT(s.not_required_at, '%Y-%m-%d %H:%i') AS not_required_at,
              s.not_required_by, s.not_required_reason,
              DATE_FORMAT(s.reopened_at, '%Y-%m-%d %H:%i')     AS reopened_at,
              s.reopened_by, s.reopen_reason,
              (SELECT COUNT(*) FROM work_order_sheet_items i
                WHERE i.sheet_id = s.id)                       AS items_total,
              (SELECT COUNT(*) FROM work_order_sheet_items i
                WHERE i.sheet_id = s.id AND i.state = 'done')  AS items_done,
              (SELECT COUNT(*) FROM work_order_sheet_items i
                WHERE i.sheet_id = s.id AND i.state = 'na')    AS items_na,
              (SELECT COUNT(*) FROM work_order_sheet_photos p
                WHERE p.sheet_id = s.id AND p.kind = 'before') AS photos_before,
              (SELECT COUNT(*) FROM work_order_sheet_photos p
                WHERE p.sheet_id = s.id AND p.kind = 'after')  AS photos_after
         FROM work_order_service_sheets s
         LEFT JOIN employees e ON e.id = s.submitted_by_employee_id`;async function s(a){return await (0,d.P)(`${r}
      WHERE s.work_order_id = ?
      ORDER BY s.form_no ASC`,[a])}async function t(a,b={fullIc:!1}){let c=await (0,d.P)(`SELECT s.id, s.work_order_asset_id, s.work_order_id, s.asset_id, s.template_id, s.form_no,
            s.template_name, s.form_title, s.category_name,
            s.asset_no, s.asset_name, s.serial_no, s.work_order_no,
            DATE_FORMAT(s.commence_at,  '%Y-%m-%d %H:%i') AS commence_at,
            DATE_FORMAT(s.completed_at, '%Y-%m-%d %H:%i') AS completed_at,
            s.attended_by, s.customer_remarks, s.arrival_note, s.completion_summary, s.notes,
            s.customer_name, s.customer_designation,
            ${u} AS customer_ic_masked,
            ${b.fullIc?"s.customer_ic,":""}
            (s.signature_path IS NOT NULL) AS signed,
            s.no_signature_reason,
            DATE_FORMAT(s.submitted_at, '%Y-%m-%d %H:%i')    AS submitted_at,
            s.submitted_by_employee_id, s.engineer_name,
            DATE_FORMAT(s.reopened_at, '%Y-%m-%d %H:%i')     AS reopened_at,
            s.reopened_by, s.reopen_reason,
            DATE_FORMAT(s.not_required_at, '%Y-%m-%d %H:%i') AS not_required_at,
            s.not_required_by, s.not_required_reason,
            e.full_name AS submitted_by_name,
            e.position  AS submitted_by_position
       FROM work_order_service_sheets s
       LEFT JOIN employees e ON e.id = s.submitted_by_employee_id
      WHERE s.id = ? LIMIT 1`,[a]);if(0===c.length)return null;let[e,f,g]=await Promise.all([(0,d.P)(`SELECT id, label, field_key, input_type, source_column, is_required, sort_order,
              value, is_typed
         FROM work_order_sheet_fields
        WHERE sheet_id = ? ORDER BY sort_order ASC, id ASC`,[a]),(0,d.P)(`SELECT id, group_title, group_sort, title, notes, is_required, sort_order,
              state, remark,
              DATE_FORMAT(decided_at, '%Y-%m-%d %H:%i') AS decided_at, decided_by
         FROM work_order_sheet_items
        WHERE sheet_id = ? ORDER BY group_sort ASC, sort_order ASC, id ASC`,[a]),(0,d.P)(`SELECT p.id, p.kind, p.caption,
              DATE_FORMAT(p.device_at, '%Y-%m-%d %H:%i') AS device_at,
              DATE_FORMAT(p.server_at, '%Y-%m-%d %H:%i') AS server_at,
              p.gps_lat, p.gps_lng, p.sort_order,
              e.full_name AS taken_by_name
         FROM work_order_sheet_photos p
         LEFT JOIN employees e ON e.id = p.taken_by_employee_id
        WHERE p.sheet_id = ? ORDER BY p.kind ASC, p.sort_order ASC, p.id ASC`,[a])]);return{sheet:c[0],fields:e,items:f,photos:g}}let u=`CONCAT(
  LEFT(REPLACE(s.customer_ic, ' ', ''), 6), '-**-**',
  RIGHT(REPLACE(s.customer_ic, ' ', ''), 2))`}};