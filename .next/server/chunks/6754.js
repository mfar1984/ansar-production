"use strict";exports.id=6754,exports.ids=[6754],exports.modules={22024:(a,b,c)=>{c.d(b,{ad:()=>g,jE:()=>n,kA:()=>m,cz:()=>q,vj:()=>j,lS:()=>p,mJ:()=>l,m:()=>k,TE:()=>o});var d=c(88251),e=c(35830),f=c(81342);let g=["pending","cancelled"];async function h(a){let b=new Date,c=`${b.getFullYear()}${String(b.getMonth()+1).padStart(2,"0")}`,[d]=await a.query(`SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(request_no, '-', -1) AS UNSIGNED)), 0) AS max_seq
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
      ORDER BY issued_date ASC, id ASC`,[a]),c=[];for(let a of b){let b=await (0,f.Q8)(Number(a.id));c.push({...a,outstanding:b.issued-b.spent-b.returned})}return c}async function q(a,b,c){let g=(await (0,d.P)("SELECT id, request_no, status, employee_id FROM petty_cash_requests WHERE id = ? LIMIT 1",[a]))[0];if(!g)return"That petty cash float does not exist.";if(Number(g.employee_id)!==Number(b))return`${g.request_no} was issued to somebody else. A receipt can only be charged to the float the same person is holding.`;if("issued"!==g.status)return"closed"===g.status?`${g.request_no} has been closed, so its figures are settled. Record this as an ordinary expense, or ask for the float to be reopened if the receipt belongs to it.`:`${g.request_no} is ${g.status}, so there is no cash in it to have spent. A receipt can only be charged to a float that has been issued.`;let h=await (0,f.Q8)(a),i=h.issued-h.spent-h.returned;return c>i?`${g.request_no} has ${(0,e.sp)(i)} left unaccounted for, and this receipt is ${(0,e.sp)(c)}. More than the float held did not come out of it — record the difference as an ordinary expense or a claim.`:null}},63415:(a,b,c)=>{c.d(b,{$3:()=>g,PS:()=>h,T1:()=>e,iT:()=>f});var d=c(88251);function e(a){let b=a.headers["x-forwarded-for"];return"string"==typeof b&&b?b.split(",")[0].trim():Array.isArray(b)&&b.length?b[0].split(",")[0].trim():a.socket?.remoteAddress||"unknown"}async function f(a){let b=function(a){let b=a.query.hash;if("string"==typeof b&&b)return b;let c=a.headers.authorization;if(c&&c.startsWith("Bearer ")){let a=c.slice(7).trim();if(a)return a}return null}(a);if(!b)return null;let c=await (0,d.P)("SELECT username, expires_at FROM admin_sessions WHERE hash = ? LIMIT 1",[b]);if(!c||0===c.length||new Date(c[0].expires_at)<=new Date)return null;let f=c[0].username,g=await (0,d.P)("SELECT id, user_type, status FROM admins WHERE username = ? LIMIT 1",[f]);if(!g||0===g.length||"active"!==g[0].status)return null;let h=g[0].id,i=await (0,d.P)(`SELECT DISTINCT p.module, p.action, r.name AS role_name
       FROM admin_roles ar
       INNER JOIN roles r            ON r.id = ar.role_id
       INNER JOIN role_permissions rp ON rp.role_id = ar.role_id
       INNER JOIN permissions p       ON p.id = rp.permission_id
      WHERE ar.admin_id = ?`,[h]),j=Array.from(new Set(i.map(a=>`${a.module}_${a.action}`))),k=Array.from(new Set(i.map(a=>a.role_name)));return{adminId:h,username:f,userType:g[0].user_type,roleNames:k,permissions:j,isSuperAdmin:k.some(a=>"super admin"===a.trim().toLowerCase()),ip:e(a)}}function g(a,b,c){return!!a&&(!!a.isSuperAdmin||a.permissions.includes(`${b}_${c}`))}async function h(a,b,c,d){let e=await f(a);return e?g(e,c,d)?e:(b.status(403).json({success:!1,error:`You do not have permission for this: ${c}_${d}`}),null):(b.status(401).json({success:!1,error:"Your session is invalid or has expired. Please sign in again."}),null)}}};