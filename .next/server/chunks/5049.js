"use strict";exports.id=5049,exports.ids=[5049],exports.modules={22024:(a,b,c)=>{c.d(b,{ad:()=>g,jE:()=>n,kA:()=>m,cz:()=>q,vj:()=>j,lS:()=>p,mJ:()=>l,m:()=>k,TE:()=>o});var d=c(88251),e=c(35830),f=c(81342);let g=["pending","cancelled"];async function h(a){let b=new Date,c=`${b.getFullYear()}${String(b.getMonth()+1).padStart(2,"0")}`,[d]=await a.query(`SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(request_no, '-', -1) AS UNSIGNED)), 0) AS max_seq
       FROM petty_cash_requests WHERE request_no LIKE ?`,[`PC-${c}-%`]),e=Number(d[0]?.max_seq||0)+1;return`PC-${c}-${String(e).padStart(3,"0")}`}let i=/^\d{4}-\d{2}-\d{2}$/;function j(a){let b=String(a.purpose||"").trim();if(!b)return"State what the cash is for. A float with no stated purpose cannot be reviewed, and cannot be checked against the receipts afterwards.";if(b.length>500)return"The purpose must be 500 characters or fewer.";let c=(0,e.Fd)(a.amount);if(null===c)return"Enter the amount you need.";if(c<=0)return"The amount must be more than zero. A nil float releases no cash and records that it did.";if(c>1e8)return`${(0,e.sp)(c)} is not a petty cash float. Amounts that size go through Accounting as a supplier payment, where they reach the supplier ledger.`;let d=String(a.neededBy||"").trim();return d&&!i.test(d)?"The date needed is YYYY-MM-DD, or leave it blank.":String(a.remarks||"").trim().length>500?"Remarks must be 500 characters or fewer.":null}async function k(a){return(await (0,d.P)(`SELECT id, request_no, amount_issued
       FROM petty_cash_requests
      WHERE employee_id = ? AND status = 'issued'
      ORDER BY id ASC LIMIT 1`,[a]))[0]||null}async function l(a,b){let c=(0,e.Fd)(b.amount);if(null===c||c<=0)throw Error("insertPettyCashRequest called with no amount. The caller must validate first.");let d=null;for(let f=0;f<5;f+=1){let f=await h(a);try{let[d]=await a.query(`INSERT INTO petty_cash_requests
           (request_no, employee_id, purpose, needed_by, amount_requested,
            status, current_level, applied_date, remarks)
         VALUES (?, ?, ?, ?, ?, 'pending', 0, ?, ?)`,[f,b.employeeId,String(b.purpose).trim(),String(b.neededBy||"").trim()||null,(0,e.sp)(c),b.appliedDate,String(b.remarks||"").trim()||null]);return{id:d.insertId,requestNo:f}}catch(a){if("ER_DUP_ENTRY"!==a.code)throw a;d=a}}throw d instanceof Error?d:Error("Could not allocate a petty cash reference after five attempts.")}let m=`
  r.id, r.request_no, r.employee_id, r.purpose, r.needed_by,
  r.amount_requested, r.status, r.current_level,
  DATE_FORMAT(r.applied_date, '%Y-%m-%d')   AS applied_date,
  r.reviewed_by, r.reviewed_date, r.review_remarks,
  r.amount_issued, r.issued_by,
  DATE_FORMAT(r.issued_date, '%Y-%m-%d')    AS issued_date,
  r.issued_from_account_id, r.issue_method, r.issue_reference,
  r.amount_returned,
  DATE_FORMAT(r.returned_date, '%Y-%m-%d')  AS returned_date,
  r.returned_to_account_id, r.return_reference,
  r.closed_by, r.closed_date, r.remarks,
  r.issue_journal_id, r.return_journal_id,
  e.full_name    AS employee_name,
  e.employee_id  AS employee_number,
  d.name         AS department_name,
  COALESCE(rve.full_name, rva.username) AS reviewed_by_name,
  COALESCE(ise.full_name, isa.username) AS issued_by_name,
  COALESCE(cle.full_name, cla.username) AS closed_by_name,
  fa.code AS issued_from_code, fa.name AS issued_from_name,
  ta.code AS returned_to_code, ta.name AS returned_to_name,
  ij.journal_no AS issue_journal_no,
  rj.journal_no AS return_journal_no
`,n=`
  FROM petty_cash_requests r
  INNER JOIN employees e        ON e.id = r.employee_id
  LEFT JOIN departments d       ON d.id = e.department_id
  LEFT JOIN admins rva          ON rva.id = r.reviewed_by
  LEFT JOIN employees rve       ON rve.id = rva.employee_id
  LEFT JOIN admins isa          ON isa.id = r.issued_by
  LEFT JOIN employees ise       ON ise.id = isa.employee_id
  LEFT JOIN admins cla          ON cla.id = r.closed_by
  LEFT JOIN employees cle       ON cle.id = cla.employee_id
  LEFT JOIN chart_of_accounts fa ON fa.id = r.issued_from_account_id
  LEFT JOIN chart_of_accounts ta ON ta.id = r.returned_to_account_id
  LEFT JOIN journal_entries ij  ON ij.id = r.issue_journal_id
  LEFT JOIN journal_entries rj  ON rj.id = r.return_journal_id
`;async function o(a){return await (0,d.P)(`SELECT x.id, x.expense_number, x.status, x.total_amount, x.tax_amount,
            DATE_FORMAT(x.expense_date, '%Y-%m-%d') AS expense_date,
            DATE_FORMAT(x.paid_date, '%Y-%m-%d')    AS paid_date,
            x.vendor_name, x.description, x.receipt_url,
            c.name AS category_name, c.color AS category_color
       FROM expenses x
       LEFT JOIN expense_categories c ON c.id = x.category_id
      WHERE x.petty_cash_id = ?
      ORDER BY x.expense_date ASC, x.id ASC`,[a])}async function p(a){let b=await (0,d.P)(`SELECT id, request_no, purpose, amount_issued
       FROM petty_cash_requests
      WHERE employee_id = ? AND status = 'issued'
      ORDER BY issued_date ASC, id ASC`,[a]),c=[];for(let a of b){let b=await (0,f.Q8)(Number(a.id));c.push({...a,outstanding:b.issued-b.spent-b.returned})}return c}async function q(a,b,c){let g=(await (0,d.P)("SELECT id, request_no, status, employee_id FROM petty_cash_requests WHERE id = ? LIMIT 1",[a]))[0];if(!g)return"That petty cash float does not exist.";if(Number(g.employee_id)!==Number(b))return`${g.request_no} was issued to somebody else. A receipt can only be charged to the float the same person is holding.`;if("issued"!==g.status)return"closed"===g.status?`${g.request_no} has been closed, so its figures are settled. Record this as an ordinary expense, or ask for the float to be reopened if the receipt belongs to it.`:`${g.request_no} is ${g.status}, so there is no cash in it to have spent. A receipt can only be charged to a float that has been issued.`;let h=await (0,f.Q8)(a),i=h.issued-h.spent-h.returned;return c>i?`${g.request_no} has ${(0,e.sp)(i)} left unaccounted for, and this receipt is ${(0,e.sp)(c)}. More than the float held did not come out of it — record the difference as an ordinary expense or a claim.`:null}},30148:(a,b,c)=>{c.d(b,{DL:()=>i,Ih:()=>j,MB:()=>k,UW:()=>l,Zn:()=>n,oT:()=>m,pX:()=>e.pX,tl:()=>h});var d=c(88251),e=c(40450);let f=`code = ?, name = ?, description = ?, budget_limit = ?,
                requires_approval = ?, approval_threshold = ?, color = ?, status = ?,
                expense_account_id = ?`,g=a=>[a.code,a.name,a.description,a.budget_limit>0?a.budget_limit:null,a.requires_approval,a.approval_threshold,a.color,a.status,a.expense_account_id];async function h(a){let b="active"===a||"inactive"===a;return await (0,d.P)(`SELECT c.*,
            (SELECT COUNT(*) FROM expenses e WHERE e.category_id = c.id) AS used_expenses,
            (SELECT COALESCE(SUM(e.total_amount), 0) FROM expenses e
               WHERE e.category_id = c.id
                 AND e.status IN ('pending', 'approved', 'paid')
                 AND YEAR(e.expense_date) = YEAR(CURDATE())) AS committed_this_year
       FROM expense_categories c
       ${b?"WHERE c.status = ?":""}
      ORDER BY c.code ASC`,b?[a]:[])}async function i(a){return(await h()).find(b=>Number(b.id)===a)||null}async function j(a){return(await (0,d.P)(`INSERT INTO expense_categories
       (code, name, description, budget_limit, requires_approval, approval_threshold, color, status,
        expense_account_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,g(a))).insertId}async function k(a,b){await (0,d.P)(`UPDATE expense_categories SET ${f} WHERE id = ?`,[...g(b),a])}async function l(a){let b=await (0,d.P)("SELECT COUNT(*) AS n FROM expenses WHERE category_id = ?",[a]);return Number(b[0]?.n||0)}async function m(a,b){let c=await (0,d.P)(`SELECT COALESCE(SUM(total_amount), 0) AS total
       FROM expenses
      WHERE category_id = ?
        AND status IN ('pending', 'approved', 'paid')
        AND YEAR(expense_date) = ?`,[a,b??new Date().getFullYear()]);return Number(c[0]?.total||0)}async function n(a,b){return(await (0,d.P)(`SELECT id FROM expense_categories WHERE code = ?${b?" AND id <> ?":""} LIMIT 1`,b?[a,b]:[a])).length>0}},30686:(a,b,c)=>{function d(a,b){let c=(a||"all").toLowerCase();return"all"===c||c===String(b||"").trim().toLowerCase()}function e(a,b){return a.filter(a=>"active"===String(a.status).toLowerCase()&&d(a.gender_eligibility,b))}function f(a,b,c){if("active"!==String(a.status).toLowerCase())return`${a.name} is no longer available.`;if(!d(a.gender_eligibility,b)){let b=String(a.gender_eligibility).toLowerCase();return`${a.name} is only available to ${b} employees.`}if("half"===c.dayType&&!a.allow_half_days)return`${a.name} cannot be taken as a half day.`;if(a.requires_document&&!c.hasDocument){let b=a.document_label||"a supporting document";return`${a.name} requires ${b}. Attach it and submit again.`}let e=Number(c.entitledDays)||0;return e>0&&c.totalDays>e?`${a.name} allows at most ${e} day(s) per year, and ${c.totalDays} were requested.`:c.totalDays<=0?"The leave period must be at least half a day.":null}c.d(b,{HQ:()=>f,Tj:()=>e,sw:()=>h});let g=["application/pdf","image/jpeg","image/png","image/webp"];function h(a,b,c=5242880){return g.includes(String(a||""))?b>c?`The document must be ${Math.round(c/1024/1024)}MB or smaller.`:null:"The document must be a PDF, JPEG, PNG or WebP file."}},40450:(a,b,c)=>{function d(a){let b=Number(a);return Number.isFinite(b)?Math.round(100*b)/100:NaN}function e(a){if(null==a||""===a)return"—";let b=Number(a);return Number.isFinite(b)?`RM ${b.toLocaleString("en-MY",{minimumFractionDigits:2,maximumFractionDigits:2})}`:"—"}function f(a){let b,c=String(a.code??"").trim().toUpperCase(),d=String(a.name??"").trim();if(!c)return{ok:!1,error:"Code is required."};if(c.length>10)return{ok:!1,error:"Code must be 10 characters or fewer."};if(!/^[A-Z0-9-]+$/.test(c))return{ok:!1,error:"Code may contain only letters, numbers and hyphens."};if(!d)return{ok:!1,error:"Category name is required."};if(d.length>100)return{ok:!1,error:"Name must be 100 characters or fewer."};let e=Number(a.budget_limit??0);if(!Number.isFinite(e)||e<0||e>0x5f5e0ff)return{ok:!1,error:"Budget limit must be between 0 and 99,999,999. Use 0 for no ceiling."};let f=+(!0===(b=a.requires_approval)||1===b||"1"===b||"true"===b),g=null,h=a.approval_threshold;if(null!=h&&""!==h){let a=Number(h);if(!Number.isFinite(a)||a<0||a>0x5f5e0ff)return{ok:!1,error:"The approval threshold must be between 0 and 99,999,999."};g=Math.round(100*a)/100}if(f||(g=null),null!==g&&e>0&&g>e)return{ok:!1,error:"The approval threshold cannot be higher than the budget limit."};let i=String(a.color??"#6b7280").trim()||"#6b7280";if(!/^#[0-9a-fA-F]{6}$/.test(i))return{ok:!1,error:"Colour must be a hex value such as #3b82f6."};let j="inactive"===String(a.status??"active").toLowerCase()?"inactive":"active";return{ok:!0,value:{code:c,name:d,description:String(a.description??"").trim()||null,budget_limit:Math.round(100*e)/100,expense_account_id:Number(a.expense_account_id)||null,requires_approval:f,approval_threshold:g,color:i,status:j}}}function g(a){let b=Number(a.quantity),c=d(a.unit_price);return Number.isFinite(b)&&Number.isFinite(c)?d(b*c):NaN}function h(a,b=0){let c=(a||[]).reduce((a,b)=>a+(g(b)||0),0),e=d(b)||0;return d(c+e)}c.d(b,{Dy:()=>l,Ik:()=>m,JN:()=>g,Mu:()=>d,N4:()=>j,TG:()=>e,ZV:()=>h,pX:()=>f,uq:()=>i,vb:()=>k});let i=["cash","bank_transfer","credit_card","cheque","online"];function j(a,b,c,e=0,f="bank_transfer"){if("active"!==String(a.status).toLowerCase())return`${a.name} is no longer available.`;if(!Array.isArray(b)||0===b.length)return"Add at least one expense line.";if(b.length>50)return"An expense can hold at most 50 lines. Split it into more than one record.";if(!i.includes(f))return"Choose a payment method.";if(!/^\d{4}-\d{2}-\d{2}$/.test(c))return"Enter a valid expense date.";let g=new Date(`${c}T00:00:00`);if(Number.isNaN(g.getTime()))return"Enter a valid expense date.";let k=new Date;if(k.setHours(23,59,59,999),g>k)return"The expense date cannot be in the future.";let l=d(e);if(!Number.isFinite(l)||l<0)return"Tax must be zero or more.";for(let a=0;a<b.length;a++){let c=b[a],e=a+1;if(!String(c.description||"").trim())return`Line ${e}: a description is required.`;if(!/^\d{4}-\d{2}-\d{2}$/.test(String(c.item_date||"")))return`Line ${e}: enter a valid date.`;let f=Number(c.quantity);if(!Number.isFinite(f)||f<=0)return`Line ${e}: the quantity must be greater than zero.`;let g=d(c.unit_price);if(!Number.isFinite(g)||g<=0)return`Line ${e}: the unit price must be greater than zero.`;if(d(f*g)>0x5f5e0ff)return`Line ${e}: that amount is not credible.`}return l>h(b,0)?"Tax cannot be more than the expense lines themselves.":null}function k(a,b){if(!a.requires_approval)return!1;let c=a.approval_threshold;if(null==c||""===c)return!0;let e=d(c);return!Number.isFinite(e)||d(b)>e}function l(a,b){return a.requires_approval?`${e(b)} is at or below the ${e(a.approval_threshold)} approval threshold for ${a.name}`:`${a.name} does not require approval`}function m(a,b,c){let f=d(a.budget_limit??0);if(!Number.isFinite(f)||f<=0)return null;let g=d(b)||0;if(d(g+d(c))<=f)return null;let h=d(f-g);return`${a.name} has ${e(h>0?h:0)} left of its ${e(f)} budget this year, and this expense is ${e(c)}.`}},67336:(a,b,c)=>{c.d(b,{Y:()=>e});var d=c(88251);async function e(a){let b=a.autoApprove?"approved":"pending",c=await d.Ay.getConnection();try{await c.beginTransaction();let d=new Date().toISOString().slice(0,7).replace(/-/g,""),[e]=await c.query(`SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(expense_number, '-', -1) AS UNSIGNED)), 0) AS max_seq
         FROM expenses WHERE expense_number LIKE ?`,[`EXP-${d}-%`]),f=Number(e[0]?.max_seq||0)+1,g=`EXP-${d}-${String(f).padStart(3,"0")}`,[h]=await c.query(`INSERT INTO expenses
         (expense_number, employee_id, category_id, expense_date, vendor_name,
          invoice_number, description, total_amount, tax_amount, payment_method,
          payment_reference, remarks, receipt_url, status, current_level, applied_date,
          petty_cash_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NOW(), ?)`,[g,a.employeeId,a.categoryId,a.expenseDate,a.vendorName,a.invoiceNumber,a.description,a.total,a.tax,a.paymentMethod,a.paymentReference,a.remarks,a.receiptUrl,b,a.pettyCashId||null]),i=h.insertId;for(let b of a.lines)await c.query(`INSERT INTO expense_items
           (expense_id, item_date, description, quantity, unit_price, total_price, remarks)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,[i,b.item_date,b.description,b.quantity,b.unit_price,b.total_price,b.remarks??null]);return a.autoApprove&&await c.query(`INSERT INTO hr_approval_records
           (module, application_id, level, action, actor_admin_id, actor_name, remarks)
         VALUES ('expenses', ?, 1, 'approved', NULL, 'System', ?)`,[i,a.autoApproveNote]),await c.commit(),{id:i,expenseNumber:g,status:b}}catch(a){throw await c.rollback(),a}finally{c.release()}}}};