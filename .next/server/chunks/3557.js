"use strict";exports.id=3557,exports.ids=[3557],exports.modules={53557:(a,b,c)=>{c.d(b,{$A:()=>z,Dk:()=>C,E6:()=>x,F6:()=>A,Ho:()=>v,Ng:()=>p,mW:()=>u,nv:()=>o,p3:()=>w,u8:()=>y,yj:()=>B});var d=c(88251),e=c(87068),f=c(29154),g=c(43713),h=c(20746),i=c(40113),j=c(75534),k=c(12816);async function l(a,b){let c=new Map;if(0===b.length)return c;for(let e of(await (0,d.P)(`SELECT a.target_id, COALESCE(SUM(a.amount), 0) AS applied
       FROM ar_receipt_allocations a
       JOIN ar_receipts r ON r.id = a.receipt_id
      WHERE a.target_table = ?
        AND a.target_id IN (${b.map(()=>"?").join(", ")})
        AND r.status = 'confirmed'
      GROUP BY a.target_id`,[a,...b])))c.set(Number(e.target_id),(0,h.Fd)(e.applied));return c}async function m(a,b){let c=new Map;if(0===b.length)return c;for(let e of(await (0,d.P)(`SELECT a.target_id, COALESCE(SUM(a.amount), 0) AS applied
       FROM ar_refund_allocations a
       JOIN ar_refunds f ON f.id = a.refund_id
      WHERE a.target_table = ?
        AND a.target_id IN (${b.map(()=>"?").join(", ")})
        AND f.status = 'confirmed'
      GROUP BY a.target_id`,[a,...b])))c.set(Number(e.target_id),(0,h.Fd)(e.applied));return c}async function n(a,b){let c=new Map;if(0===b.length)return c;for(let f of j.ES){if(f.appliesToTable!==a||!f.appliedTo||!e.d6.test(f.appliedTo)||!e.d6.test(f.table))continue;let i=Object.values(g.z0).find(a=>a.table===f.table);if(!i)continue;let k=(0,j.$m)(i);if(0!==k.length)for(let a of(await (0,d.P)(`SELECT \`${f.appliedTo}\` AS target_id, COALESCE(SUM(total_amount), 0) AS applied
         FROM \`${f.table}\`
        WHERE \`${f.appliedTo}\` IN (${b.map(()=>"?").join(", ")})
          AND status IN (${k.map(()=>"?").join(", ")})
        GROUP BY \`${f.appliedTo}\``,[...b,...k]))){let b=Number(a.target_id);c.set(b,(c.get(b)||0)+(0,h.Fd)(a.applied))}}return c}async function o(a){let b=new Map;if(0===a.length)return b;let c=new Map;for(let b of a){if(!j.WN[b.table])continue;let a=c.get(b.table)||[];a.push(Number(b.id)),c.set(b.table,a)}for(let[a,g]of c){let c=j.WN[a];if(!e.d6.test(c.table))continue;let i=await (0,d.P)(`SELECT id, total_amount, status FROM \`${c.table}\`
        WHERE id IN (${g.map(()=>"?").join(", ")})`,g),o=await l(a,g),p=await n(a,g),q=await m(a,g),r=await (0,f.I)("customer",a,g);for(let c of i){let d=Number(c.id),e=(0,k.ZD)((0,h.Fd)(c.total_amount),o.get(d)||0,p.get(d)||0,q.get(d)||0,r.get(d)||0);b.set(`${a}#${d}`,{...e,table:a,id:d})}}return b}async function p(a,b,c=[]){let i=[],o=0;for(let[p,s]of Object.entries(j.WN)){if(!e.d6.test(s.table)||!e.d6.test(s.noColumn)||!e.d6.test(s.dateColumn)||s.dueColumn&&!e.d6.test(s.dueColumn))continue;let t=Object.values(g.z0).find(a=>a.table===p);if(!t)continue;let u=(0,j.$m)(t);if(0===u.length)continue;let v=s.dueColumn?`DATE_FORMAT(d.\`${s.dueColumn}\`, '%Y-%m-%d')`:"NULL",w=await (0,d.P)(`SELECT d.id, d.\`${s.noColumn}\` AS reference, d.status, d.total_amount,
              DATE_FORMAT(d.\`${s.dateColumn}\`, '%Y-%m-%d') AS document_date,
              ${v} AS due_date
         FROM \`${s.table}\` d
        WHERE d.customer_id = ? AND d.status IN (${u.map(()=>"?").join(", ")})
        ORDER BY d.\`${s.dateColumn}\` ASC, d.id ASC`,[a,...u]);if(0===w.length)continue;let x=w.map(a=>Number(a.id)),y=await l(p,x),z=await n(p,x),A=await m(p,x),B=await (0,f.I)("customer",p,x),C=new Set(c.filter(a=>a.table===p).map(a=>Number(a.id)));for(let a of w){let c=Number(a.id),d=(0,k.ZD)((0,h.Fd)(a.total_amount),y.get(c)||0,z.get(c)||0,A.get(c)||0,B.get(c)||0);if(d.outstandingCents<=0&&!C.has(c)){o+=1;continue}let e=a.due_date||(s.dueColumn?null:a.document_date);i.push({table:p,id:c,reference:String(a.reference),document_date:String(a.document_date),due_date:e,label:s.label,status:String(a.status),total:q(d.totalCents),receipts:q(d.receiptsCents),credits:q(d.creditsCents),contra:q(d.contraCents),outstanding:q(d.outstandingCents),outstanding_cents:d.outstandingCents,settlement:d.settlement,ageing:(0,k.Ig)(e,b),days_overdue:e?Math.max(0,r(e,b)):0})}}return i.sort((a,b)=>a.document_date===b.document_date?a.reference.localeCompare(b.reference):a.document_date.localeCompare(b.document_date)),{documents:i,settled_count:o}}function q(a){let b=Math.abs(Math.trunc(a));return`${a<0?"-":""}${Math.floor(b/100)}.${String(b%100).padStart(2,"0")}`}function r(a,b){let c=a=>{let b=/^(\d{4})-(\d{2})-(\d{2})$/.exec(a);return b?Date.UTC(Number(b[1]),Number(b[2])-1,Number(b[3])):null},d=c(a),e=c(b);return null===d||null===e?0:Math.round((e-d)/864e5)}async function s(a){let b=await (0,d.P)(`SELECT COALESCE(SUM(r.amount), 0) AS received,
            COALESCE((SELECT SUM(a.amount) FROM ar_receipt_allocations a
                       JOIN ar_receipts r2 ON r2.id = a.receipt_id
                      WHERE r2.customer_id = ? AND r2.status = 'confirmed'), 0) AS applied
       FROM ar_receipts r
      WHERE r.customer_id = ? AND r.status = 'confirmed'`,[a,a]);return(0,h.Fd)(b[0]?.received||"0")-(0,h.Fd)(b[0]?.applied||"0")}async function t(a){let b=await (0,d.P)(`SELECT COALESCE(SUM(f.amount), 0) AS paid,
            COALESCE((SELECT SUM(a.amount) FROM ar_refund_allocations a
                       JOIN ar_refunds f2 ON f2.id = a.refund_id
                      WHERE f2.customer_id = ? AND f2.status = 'confirmed'), 0) AS applied
       FROM ar_refunds f
      WHERE f.customer_id = ? AND f.status = 'confirmed'`,[a,a]);return(0,h.Fd)(b[0]?.paid||"0")-(0,h.Fd)(b[0]?.applied||"0")}async function u(a){return await s(a)-await t(a)}async function v(a){let b=await s(a)-await t(a),c=0;for(let[b,i]of Object.entries(j.WN)){if(!e.d6.test(i.table))continue;let o=Object.values(g.z0).find(a=>a.table===b);if(!o)continue;let p=(0,j.$m)(o);if(0===p.length)continue;let q=await (0,d.P)(`SELECT id, total_amount FROM \`${i.table}\`
        WHERE customer_id = ? AND status IN (${p.map(()=>"?").join(", ")})`,[a,...p]);if(0===q.length)continue;let r=q.map(a=>Number(a.id)),s=await l(b,r),t=await n(b,r),u=await m(b,r),v=await (0,f.I)("customer",b,r);for(let a of q){let b=(0,k.ZD)((0,h.Fd)(a.total_amount),s.get(Number(a.id))||0,t.get(Number(a.id))||0,u.get(Number(a.id))||0,v.get(Number(a.id))||0);b.outstandingCents<0&&(c+=-b.outstandingCents)}}let i=await (0,d.P)("SELECT COALESCE(SUM(amount), 0) AS v FROM ar_refunds WHERE customer_id = ? AND status = 'confirmed'",[a]),o=(0,h.Fd)(i[0]?.v||"0"),p=Math.max(0,-(b+c));return{unallocatedCents:b,overSettledCents:c,refundedCents:o,overRefundedCents:p,availableCents:Math.max(0,b+c)}}async function w(a){let b=(await (0,d.P)(`SELECT r.id, r.refund_no,
            DATE_FORMAT(r.refund_date, '%Y-%m-%d') AS refund_date,
            r.customer_id, r.customer_name, r.status, r.amount, r.reason,
            r.bank_account_id, r.control_account_id,
            c.control_account_id AS customer_control_id
       FROM ar_refunds r
       LEFT JOIN customers c ON c.id = r.customer_id
      WHERE r.id = ? LIMIT 1`,[a]))[0];if(!b)return null;let c=(0,h.Fd)(b.amount),e=await (0,i.H)("ar_refunds",Number(b.id)),f={id:Number(b.id),reference:String(b.refund_no),date:String(b.refund_date),party:b.customer_name||`Customer ${b.customer_id}`,status:String(b.status),subtotal:0,tax:0,total:c,line_count:2},g=a=>({document:f,lines:[],total_debit:0,total_credit:0,posted:e,problem:a});if(e)return{document:f,lines:[],total_debit:0,total_credit:0,posted:e,problem:null};if("confirmed"!==b.status)return g(`${f.reference} is "${b.status}". Only a confirmed refund posts to the ledger — a draft has not been paid out, and a cancelled one never was.`);if(c<=0)return g(`${f.reference} is for nothing, so there is nothing to post.`);let j=Number(b.control_account_id||b.customer_control_id||0);if(!j)return g(`${f.reference} has no receivable control account: neither the refund nor customer "${f.party}" names one. Set one on the customer in Money > Receivables > Customers.`);let k=[Number(b.bank_account_id),j],l=new Map((await (0,d.P)(`SELECT id, code, name, account_type, status FROM chart_of_accounts
      WHERE id IN (${k.map(()=>"?").join(", ")})`,k)).map(a=>[Number(a.id),a])),m=l.get(Number(b.bank_account_id)),n=l.get(j);if(!m)return g(`${f.reference} names bank account id ${b.bank_account_id}, which does not exist.`);if("active"!==m.status)return g(`The account the money left from, ${m.code} "${m.name}", is inactive. Point the refund at the account the money really came out of.`);if("Cash and bank"!==m.account_type)return g(`${m.code} "${m.name}" is a ${m.account_type} account, not Cash and bank. A refund has to leave an account that holds money, or the Balance Sheet will still show cash the company has paid out.`);if(!n)return g(`${f.reference} names receivable control account id ${j}, which does not exist in the chart of accounts.`);if("active"!==n.status)return g(`The receivable control account ${n.code} "${n.name}" is inactive, so nothing may be posted to it.`);let o=[{account_id:Number(n.id),code:n.code,name:n.name,debit:c,credit:0,description:`${f.reference} — ${f.party}`,role:"control"},{account_id:Number(m.id),code:m.code,name:m.name,debit:0,credit:c,description:`${f.reference} — ${f.party}`,role:"bank"}];return{document:f,lines:o,total_debit:c,total_credit:c,posted:null,problem:null}}async function x(a,b,c){return(await (0,d.P)(`SELECT r.id, r.refund_no,
            DATE_FORMAT(r.refund_date, '%Y-%m-%d') AS refund_date,
            r.customer_name, r.customer_id, r.status, r.amount,
            j.id AS journal_id, j.journal_no
       FROM ar_refunds r
       LEFT JOIN journal_entries j
              ON j.source_table = 'ar_refunds' AND j.source_id = r.id
             AND j.status = 'posted' AND j.reverses_id IS NULL
      WHERE r.refund_date BETWEEN ? AND ?
      ORDER BY r.refund_date ASC, r.refund_no ASC`,[a,b])).filter(a=>!c||null===a.journal_id).map(a=>({id:Number(a.id),reference:String(a.refund_no),date:String(a.refund_date),party:a.customer_name?String(a.customer_name):`Customer ${a.customer_id}`,status:String(a.status),total:String(a.amount),posted_journal_no:a.journal_no?String(a.journal_no):null,posted_journal_id:a.journal_id?Number(a.journal_id):null}))}async function y(a){let b=()=>({current:0,d1_30:0,d31_60:0,d61_90:0,d90_plus:0}),c=()=>({current:0,m1:0,m2:0,m3:0,m4:0,m5plus:0}),i=new Map,o=0,p=0;for(let[q,s]of Object.entries(j.WN)){if(!e.d6.test(s.table)||!e.d6.test(s.noColumn)||!e.d6.test(s.dateColumn)||s.dueColumn&&!e.d6.test(s.dueColumn))continue;let t=Object.values(g.z0).find(a=>a.table===q);if(!t)continue;let u=(0,j.$m)(t);if(0===u.length)continue;let v=s.dueColumn?`DATE_FORMAT(d.\`${s.dueColumn}\`, '%Y-%m-%d')`:"NULL",w=await (0,d.P)(`SELECT d.id, d.customer_id, d.customer_name, d.customer_code, d.total_amount,
              DATE_FORMAT(d.\`${s.dateColumn}\`, '%Y-%m-%d') AS document_date,
              ${v} AS due_date
         FROM \`${s.table}\` d
        WHERE d.status IN (${u.map(()=>"?").join(", ")})`,u);if(0===w.length)continue;let x=w.map(a=>Number(a.id)),y=await l(q,x),z=await n(q,x),A=await m(q,x),B=await (0,f.I)("customer",q,x);for(let d of w){let e=Number(d.id),f=(0,k.ZD)((0,h.Fd)(d.total_amount),y.get(e)||0,z.get(e)||0,A.get(e)||0,B.get(e)||0);if(f.outstandingCents<=0){o+=1;continue}let g=d.due_date||(s.dueColumn?null:d.document_date),j=(0,k.Ig)(g,a),l=g?Math.max(0,r(g,a)):0,m=Number(d.customer_id),n=i.get(m)||{name:d.customer_name||`Customer ${m}`,code:d.customer_code,buckets:b(),months:c(),documents:0,oldest:0};n.buckets[j]+=f.outstandingCents,n.months[(0,k.y_)(g,a)]+=f.outstandingCents,n.documents+=1,n.oldest=Math.max(n.oldest,l),i.set(m,n),p+=1}}let s=new Map;for(let a of(await (0,d.P)(`SELECT r.customer_id,
            COALESCE(SUM(r.amount), 0) AS received,
            COALESCE((SELECT SUM(a.amount) FROM ar_receipt_allocations a
                       JOIN ar_receipts r2 ON r2.id = a.receipt_id
                      WHERE r2.customer_id = r.customer_id AND r2.status = 'confirmed'), 0) AS applied
       FROM ar_receipts r
      WHERE r.status = 'confirmed'
      GROUP BY r.customer_id`)))s.set(Number(a.customer_id),(0,h.Fd)(a.received)-(0,h.Fd)(a.applied));for(let a of(await (0,d.P)(`SELECT f.customer_id,
            COALESCE(SUM(f.amount), 0) AS paid,
            COALESCE((SELECT SUM(a.amount) FROM ar_refund_allocations a
                       JOIN ar_refunds f2 ON f2.id = a.refund_id
                      WHERE f2.customer_id = f.customer_id AND f2.status = 'confirmed'), 0) AS applied
       FROM ar_refunds f
      WHERE f.status = 'confirmed'
      GROUP BY f.customer_id`))){let b=Number(a.customer_id);s.set(b,(s.get(b)||0)-((0,h.Fd)(a.paid)-(0,h.Fd)(a.applied)))}let t=b(),u=c(),v=[];for(let[a,b]of i){let c=Object.values(b.buckets).reduce((a,b)=>a+b,0);for(let a of Object.keys(b.buckets))t[a]+=b.buckets[a];for(let a of k.Wd)u[a]+=b.months[a];v.push({customer_id:a,customer_name:b.name,customer_code:b.code,buckets:Object.fromEntries(Object.keys(b.buckets).map(a=>[a,q(b.buckets[a])])),bucket_cents:b.buckets,months:Object.fromEntries(k.Wd.map(a=>[a,q(b.months[a])])),month_cents:b.months,total:q(c),total_cents:c,documents:b.documents,oldest_days:b.oldest,credit_on_account:q(s.get(a)||0)})}v.sort((a,b)=>b.total_cents-a.total_cents);let w=Object.values(t).reduce((a,b)=>a+b,0);return{rows:v,totals:Object.fromEntries(Object.keys(t).map(a=>[a,q(t[a])])),month_totals:Object.fromEntries(k.Wd.map(a=>[a,q(u[a])])),grand_total:q(w),documents:p,settled_excluded:o,credit_on_account:q([...s.values()].reduce((a,b)=>a+b,0))}}async function z(){let a=[];for(let b of[...j.ES.map(a=>({table:a.table,noun:a.noun,appliedTo:a.appliedTo})),...Object.values(g.z0).filter(a=>a.receivable?.direction==="increase"&&"sales-debit-note"===a.key).map(a=>({table:a.table,noun:a.noun,appliedTo:"original_invoice_id"}))]){if(!e.d6.test(b.table)||!e.d6.test(b.appliedTo))continue;let c=await (0,d.P)(`SELECT COUNT(*) AS n, COALESCE(SUM(total_amount), 0) AS v
         FROM \`${b.table}\`
        WHERE \`${b.appliedTo}\` IS NULL
          AND original_invoice_no IS NOT NULL AND original_invoice_no <> ''
          AND status NOT IN ('draft', 'cancelled', 'rejected')`);Number(c[0]?.n||0)>0&&a.push({table:b.table,noun:b.noun,count:Number(c[0].n),value:q((0,h.Fd)(c[0].v))})}return a}async function A(a){let b=(await (0,d.P)(`SELECT r.id, r.receipt_no,
            DATE_FORMAT(r.receipt_date, '%Y-%m-%d') AS receipt_date,
            r.customer_id, r.customer_name, r.status, r.amount,
            r.bank_account_id, r.control_account_id,
            c.control_account_id AS customer_control_id
       FROM ar_receipts r
       LEFT JOIN customers c ON c.id = r.customer_id
      WHERE r.id = ? LIMIT 1`,[a]))[0];if(!b)return null;let c=(0,h.Fd)(b.amount),e=await (0,i.H)("ar_receipts",Number(b.id)),f={id:Number(b.id),reference:String(b.receipt_no),date:String(b.receipt_date),party:b.customer_name||`Customer ${b.customer_id}`,status:String(b.status),subtotal:0,tax:0,total:c,line_count:2},g=a=>({document:f,lines:[],total_debit:0,total_credit:0,posted:e,problem:a});if(e)return{document:f,lines:[],total_debit:0,total_credit:0,posted:e,problem:null};if("confirmed"!==b.status)return g(`${f.reference} is "${b.status}". Only a confirmed receipt posts to the ledger — a draft has not been banked, and a cancelled one never was.`);if(c<=0)return g(`${f.reference} is for nothing, so there is nothing to post.`);let j=Number(b.control_account_id||b.customer_control_id||0);if(!j)return g(`${f.reference} has no receivable control account: neither the receipt nor customer "${f.party}" names one. Set one on the customer in Money > Receivables > Customers — it is the account every balance for that customer rolls up to.`);let k=[Number(b.bank_account_id),j],l=new Map((await (0,d.P)(`SELECT id, code, name, account_type, status FROM chart_of_accounts
      WHERE id IN (${k.map(()=>"?").join(", ")})`,k)).map(a=>[Number(a.id),a])),m=l.get(Number(b.bank_account_id)),n=l.get(j);if(!m)return g(`${f.reference} names bank account id ${b.bank_account_id}, which does not exist.`);if("active"!==m.status)return g(`The account the money was banked into, ${m.code} "${m.name}", is inactive. Somebody retired it on purpose, so either reactivate it or point the receipt at the account the money really reached.`);if("Cash and bank"!==m.account_type)return g(`${m.code} "${m.name}" is a ${m.account_type} account, not Cash and bank. A receipt has to land in an account that holds money, or the Balance Sheet will show cash the company does not have.`);if(!n)return g(`${f.reference} names receivable control account id ${j}, which does not exist in the chart of accounts.`);if("active"!==n.status)return g(`The receivable control account ${n.code} "${n.name}" is inactive, so nothing may be posted to it.`);let o=[{account_id:Number(m.id),code:m.code,name:m.name,debit:c,credit:0,description:`${f.reference} — ${f.party}`,role:"bank"},{account_id:Number(n.id),code:n.code,name:n.name,debit:0,credit:c,description:`${f.reference} — ${f.party}`,role:"control"}];return{document:f,lines:o,total_debit:c,total_credit:c,posted:null,problem:null}}async function B(a,b,c){return(await (0,d.P)(`SELECT r.id, r.receipt_no,
            DATE_FORMAT(r.receipt_date, '%Y-%m-%d') AS receipt_date,
            r.customer_name, r.customer_id, r.status, r.amount,
            j.id AS journal_id, j.journal_no
       FROM ar_receipts r
       LEFT JOIN journal_entries j
              ON j.source_table = 'ar_receipts' AND j.source_id = r.id
             AND j.status = 'posted' AND j.reverses_id IS NULL
      WHERE r.receipt_date BETWEEN ? AND ?
      ORDER BY r.receipt_date ASC, r.receipt_no ASC`,[a,b])).filter(a=>!c||null===a.journal_id).map(a=>({id:Number(a.id),reference:String(a.receipt_no),date:String(a.receipt_date),party:a.customer_name?String(a.customer_name):`Customer ${a.customer_id}`,status:String(a.status),total:String(a.amount),posted_journal_no:a.journal_no?String(a.journal_no):null,posted_journal_id:a.journal_id?Number(a.journal_id):null}))}async function C(){return await (0,d.P)(`SELECT id, code, name FROM chart_of_accounts
      WHERE status = 'active' AND account_type = 'Cash and bank'
      ORDER BY code ASC`)}}};