"use strict";(()=>{var a={};a.id=1716,a.ids=[1716],a.modules={3498:a=>{a.exports=require("mysql2/promise")},21572:a=>{a.exports=require("nodemailer")},22024:(a,b,c)=>{c.d(b,{ad:()=>g,jE:()=>n,kA:()=>m,cz:()=>q,vj:()=>j,lS:()=>p,mJ:()=>l,m:()=>k,TE:()=>o});var d=c(88251),e=c(35830),f=c(81342);let g=["pending","cancelled"];async function h(a){let b=new Date,c=`${b.getFullYear()}${String(b.getMonth()+1).padStart(2,"0")}`,[d]=await a.query(`SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(request_no, '-', -1) AS UNSIGNED)), 0) AS max_seq
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
      ORDER BY issued_date ASC, id ASC`,[a]),c=[];for(let a of b){let b=await (0,f.Q8)(Number(a.id));c.push({...a,outstanding:b.issued-b.spent-b.returned})}return c}async function q(a,b,c){let g=(await (0,d.P)("SELECT id, request_no, status, employee_id FROM petty_cash_requests WHERE id = ? LIMIT 1",[a]))[0];if(!g)return"That petty cash float does not exist.";if(Number(g.employee_id)!==Number(b))return`${g.request_no} was issued to somebody else. A receipt can only be charged to the float the same person is holding.`;if("issued"!==g.status)return"closed"===g.status?`${g.request_no} has been closed, so its figures are settled. Record this as an ordinary expense, or ask for the float to be reopened if the receipt belongs to it.`:`${g.request_no} is ${g.status}, so there is no cash in it to have spent. A receipt can only be charged to a float that has been issued.`;let h=await (0,f.Q8)(a),i=h.issued-h.spent-h.returned;return c>i?`${g.request_no} has ${(0,e.sp)(i)} left unaccounted for, and this receipt is ${(0,e.sp)(c)}. More than the float held did not come out of it — record the difference as an ordinary expense or a claim.`:null}},53067:(a,b,c)=>{c.r(b),c.d(b,{config:()=>r,default:()=>q,handler:()=>t});var d={};c.r(d),c.d(d,{default:()=>n});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(69486),k=c(13813),l=c(81342),m=c(22024);async function n(a,b){if("GET"!==a.method)return b.setHeader("Allow","GET"),b.status(405).json({success:!1,error:"Method not allowed"});let c=await (0,j.U)(a,b);if(c&&(0,j.T)(c,b,a.query.employee_id))try{let a=await (0,i.P)(`SELECT ${m.kA} ${m.jE}
        WHERE r.employee_id = ?
        ORDER BY r.applied_date DESC, r.id DESC`,[c.employeeId]),d=(0,k._O)(await (0,k.gf)("petty_cash")),e=a.map(a=>Number(a.id)).filter(Number.isFinite),f={};if(e.length>0)for(let a of(await (0,i.P)(`SELECT application_id, level, action, actor_name, remarks, created_at
           FROM hr_approval_records
          WHERE module = 'petty_cash' AND application_id IN (${e.map(()=>"?").join(", ")})
          ORDER BY id ASC`,e)))(f[a.application_id]||=[]).push(a);let g=[];for(let b of a){let a=Number(b.id),c=Number(b.current_level||0),e="issued"===b.status||"closed"===b.status;g.push({...b,current_level:c,total_levels:d,awaiting_level:"pending"===b.status&&d>0?c+1:null,balance:e?await (0,l.Q8)(a):null,receipts:e?await (0,m.TE)(a):[],trail:f[a]||[]})}let h=a.find(a=>"issued"===a.status)||null;return b.status(200).json({success:!0,floats:g,total_levels:d,open_float:h?{id:Number(h.id),request_no:String(h.request_no)}:null,can_request:!h})}catch(c){let a=c instanceof Error?c.message:"Unknown error";return console.error("ESS petty cash list error:",c),b.status(500).json({success:!1,error:`Failed to load petty cash: ${a}`})}}var o=c(58112),p=c(18766);let q=(0,h.M)(d,"default"),r=(0,h.M)(d,"config"),s=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/employee/petty-cash",pathname:"/api/employee/petty-cash",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function t(a,b,c){let d=await s.prepare(a,b,{srcPage:"/api/employee/petty-cash"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,o.getTracer)(),e=d.getActiveScopeSpan(),j=s.instrumentationOnRequestError.bind(s),k=async e=>s.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:s.isDev,page:"/api/employee/petty-cash",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==p.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(p.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:o.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(s.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},55511:a=>{a.exports=require("crypto")},69486:(a,b,c)=>{c.d(b,{T:()=>f,U:()=>e});var d=c(88251);async function e(a,b){let c="string"==typeof a.query.hash?a.query.hash:"";if(!c)return b.status(400).json({success:!1,error:"Session hash is required."}),null;let e=(await (0,d.P)(`SELECT username, user_type, employee_id, expires_at
       FROM admin_sessions WHERE hash = ? LIMIT 1`,[c]))[0];return e?new Date(e.expires_at)<=new Date?(b.status(401).json({success:!1,error:"Your session has expired. Sign in again."}),null):"employee"===e.user_type&&e.employee_id?{employeeId:e.employee_id,username:e.username}:(b.status(403).json({success:!1,error:"This endpoint is for employee accounts."}),null):(b.status(401).json({success:!1,error:"Invalid or expired session."}),null)}function f(a,b,c){return null==c||""===c||Number(c)===a.employeeId||(b.status(403).json({success:!1,error:"You can only access your own records."}),!1)}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,4560,2066,3813,1342],()=>b(b.s=53067));module.exports=c})();