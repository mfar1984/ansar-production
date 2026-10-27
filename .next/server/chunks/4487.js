"use strict";exports.id=4487,exports.ids=[4487],exports.modules={64487:(a,b,c)=>{c.d(b,{Il:()=>l,L:()=>m,NN:()=>p,Nm:()=>h,Ol:()=>j,Rq:()=>s,Zk:()=>g,pV:()=>r,pw:()=>o,s4:()=>i,vE:()=>q});var d=c(88251),e=c(92102),f=c(93452);let g=`(w.assignee_employee_id = ?
         OR EXISTS (SELECT 1 FROM work_order_crew c
                     WHERE c.work_order_id = w.id AND c.employee_id = ?))`;function h(a){return[a,a]}async function i(a){let b=String(a??"").trim();if(!b)return null;let c=(await (0,d.P)(`SELECT name FROM work_order_types
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)).map(a=>a.name),e=c.find(a=>a===b);if(e)return e;let f=c.find(a=>a.toLowerCase()===b.toLowerCase());return f||null}async function j(){return await (0,d.P)(`SELECT name, icon, expects_next_due, maintenance_kind, default_template_id
       FROM work_order_types
      WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)}async function k(){let a=await (0,d.P)(`SELECT id, table_key, label, prefix, padding
       FROM work_order_numbering WHERE table_key = ? LIMIT 1`,["work_orders"]);return a.length>0?a[0]:null}async function l(a){let b=await k(),c=String(b?.prefix||"").trim()||"WO",d=Number(b?.padding);return(0,e.fp)("work_orders","work_order_no",c,a,Number.isInteger(d)&&d>=2&&d<=8?d:4)}let m=["pending","done","skipped"],n=`SELECT wa.id, wa.asset_id, wa.state, wa.skip_reason,
              DATE_FORMAT(wa.completed_at, '%Y-%m-%d %H:%i') AS completed_at,
              wa.completed_by_employee_id, wa.maintenance_id,
              a.asset_no, a.name AS asset_name, a.serial_no, a.category,
              a.holder, a.status,
              cu.company_name AS client_name,
              COALESCE(s.name, a.site_name) AS site_name,
              am.batch_id AS service_batch_id,
              sb.title    AS service_batch_title,
              DATE_FORMAT(sb.created_at,   '%Y-%m-%d') AS service_batch_on,
              am.kind     AS service_kind,
              DATE_FORMAT(am.service_date, '%Y-%m-%d') AS service_date,
              DATE_FORMAT(am.next_due,     '%Y-%m-%d') AS service_next_due,
              am.performed_by,
              am.cost     AS service_cost,
              am.summary  AS service_summary
         FROM work_order_assets wa
         JOIN assets a            ON a.id  = wa.asset_id
         LEFT JOIN client_users cu ON cu.id = a.client_id
         LEFT JOIN asset_sites s   ON s.id  = a.site_id
         LEFT JOIN asset_maintenance am     ON am.id = wa.maintenance_id
         LEFT JOIN asset_service_batches sb ON sb.id = am.batch_id`;async function o(a){return await (0,d.P)(`${n}
        WHERE wa.work_order_id = ?
        ORDER BY COALESCE(s.name, a.site_name) ASC, a.name ASC, a.asset_no ASC`,[a])}async function p(a){let b=(await (0,d.P)(`SELECT COUNT(*)                         AS total,
            SUM(state = 'done')              AS done,
            SUM(state = 'skipped')           AS skipped,
            SUM(state = 'pending')           AS pending
       FROM work_order_assets WHERE work_order_id = ?`,[a]))[0]||{};return{total:Number(b.total||0),done:Number(b.done||0),skipped:Number(b.skipped||0),pending:Number(b.pending||0)}}async function q(a,b,c){if(await a("UPDATE work_orders SET asset_id = ? WHERE id = ?",[c[0]??null,b]),await a("DELETE FROM work_order_assets WHERE work_order_id = ?",[b]),0===c.length)return;let d=c.map(()=>"(?, ?)").join(", "),e=[];for(let a of c)e.push(b,a);await a(`INSERT INTO work_order_assets (work_order_id, asset_id) VALUES ${d}`,e)}class r extends Error{constructor(a){super(a),this.name="WorkOrderTransitionError"}}async function s(a,b,c,d,e,g={}){if(!(0,f.w)(c,d))throw new r(`A work order cannot go from ${c.replace(/_/g," ")} to ${d.replace(/_/g," ")}.`);let h=[],i=[],j=(a,b)=>{if(!(b in g))return;let c=g[b];void 0!==c&&(h.push(`, \`${a}\` = ?`),i.push(c))};switch(d){case"draft":case"open":break;case"in_progress":h.push(", `started_on` = COALESCE(`started_on`, CURDATE())",", `completed_on` = NULL");break;case"completed":h.push(", `completed_on` = CURDATE()"),j("completion_note","completion_note");break;case"closed":h.push(", `closed_on` = CURDATE()",", `closed_by` = ?"),i.push(e),j("actual_cost","actual_cost"),j("maintenance_id","maintenance_id"),j("batch_id","batch_id"),j("next_due","next_due");break;case"cancelled":j("cancel_reason","cancel_reason")}let k=await a(`UPDATE work_orders SET status = ?${h.join("")} WHERE id = ? AND status = ?`,[d,...i,b,c]);if(!Number(k?.affectedRows))throw new r(`This work order is no longer ${c.replace(/_/g," ")}. Reload it and try again.`)}},93452:(a,b,c)=>{c.d(b,{Gr:()=>d,_q:()=>e,db:()=>f,ob:()=>i,qY:()=>j,w:()=>h});let d=["draft","open","in_progress","completed","closed","cancelled"],e=["low","normal","high","urgent"],f=["asset","ticket","project","sales_order"],g={draft:["open","cancelled"],open:["in_progress","cancelled"],in_progress:["completed","cancelled"],completed:["closed","in_progress"],closed:[],cancelled:[]};function h(a,b){let c=g[a];return!!c&&c.includes(b)}let i=200;function j(a,b=i){let c=new Set,d=[];for(let b of a){let a=String(b??"").trim().replace(/\s+/g," ");if(!a)continue;let e=a.toLowerCase();c.has(e)||(c.add(e),d.push(a))}if(0===d.length)return null;let e=d.join(", ");if(e.length<=b)return e;for(let a=d.length-1;a>=1;a--){let c=` +${d.length-a} more`,e=d.slice(0,a).join(", ");if(e.length+c.length<=b)return`${e}${c}`}return d[0].slice(0,b)}}};