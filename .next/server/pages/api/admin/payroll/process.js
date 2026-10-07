"use strict";(()=>{var a={};a.id=1832,a.ids=[1832],a.modules={3498:a=>{a.exports=require("mysql2/promise")},25354:(a,b,c)=>{c.r(b),c.d(b,{config:()=>u,default:()=>t,handler:()=>w});var d={};c.r(d),c.d(d,{default:()=>q});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(60379),k=c(47922),l=c(55046),m=c(35565);async function n(a){if(!a)return null;let[b]=await i.Ay.query("SELECT username, expires_at FROM admin_sessions WHERE hash = ?",[a]);if(!b||0===b.length)return null;let c=b[0];return new Date(c.expires_at)<new Date?null:c}async function o(a){let b=await i.Ay.getConnection();try{let[c]=await b.query("SELECT id FROM admins WHERE username = ? LIMIT 1",[a]);if(!c||0===c.length)return[];let d=c[0].id,[e]=await b.query(`
      SELECT DISTINCT p.module, p.action
      FROM permissions p
      INNER JOIN role_permissions rp ON p.id = rp.permission_id
      INNER JOIN admin_roles ar ON rp.role_id = ar.role_id
      WHERE ar.admin_id = ?
      ORDER BY p.module, p.action
    `,[d]);return e.map(a=>`${a.module}_${a.action}`)}finally{b.release()}}async function p(a){let[b]=await i.Ay.query("SELECT id FROM admins WHERE username = ? LIMIT 1",[a]);return b[0]?.id||0}async function q(a,b){let{hash:c}=a.query,d=await n(c);if(!d)return b.status(401).json({error:"Unauthorized"});let e=await o(d.username);if("POST"===a.method){if(!(0,j._m)(e,"payroll_process"))return b.status(403).json({error:"Forbidden"});let c=await i.Ay.getConnection();try{let{period_id:e}=a.body;if(!e)return b.status(400).json({error:"Period ID is required"});let[f]=await c.query('SELECT * FROM payroll_periods WHERE id = ? AND status = "draft"',[e]);if(!f||0===f.length)return b.status(400).json({error:"Period not found or already processed"});let g=f[0],h=new Date(Number(g.period_year),Number(g.period_month)-1,1),i=await (0,k.fo)(),[j]=await c.query(`SELECT 
          id, employee_id, full_name, basic_salary, date_of_birth, status,
          epf_number, socso_number, lindung24_enrolled, tax_number,
          bank_name, bank_account_number
        FROM employees`),n=["active","on_leave"],o={resigned:"Employment ended (resigned). Final pay is settled separately and is not produced by a monthly run.",terminated:"Employment ended (terminated). Final pay is settled separately and is not produced by a monthly run."},q=[],r=[];for(let a of j||[]){let b=null===a.status||void 0===a.status?null:String(a.status);if(null!==b&&n.includes(b)){q.push(a);continue}r.push({id:Number(a.id),employee_id:String(a.employee_id??""),full_name:String(a.full_name??""),status:b,reason:null===b?"Employment status is not set on the employee record, so the run cannot tell whether a salary is owed. Set it under Human Resources > Employee Management.":o[b]||`Employment status "${b}" is not one this payroll run pays. It was added to the employee record after this run was written, so a decision is needed on whether it earns a salary.`})}let s=new Map;for(let a of r){let b=null===a.status?"with no status set":a.status;s.set(b,(s.get(b)||0)+1)}let t=Array.from(s.entries()).map(([a,b])=>`${b} ${a}`).join(", ");if(0===q.length)return b.status(400).json({error:0===r.length?"No active employees found":`No active employees found. ${r.length} employee(s) exist but none hold a payable status: ${t}.`,total_skipped:r.length,skipped:r});await c.beginTransaction();let u=0,v=0,w=0;for(let a of q){let b=`${g.period_year}${String(g.period_month).padStart(2,"0")}`,d=`PS-${b}-`,[f]=await c.query(`SELECT payslip_number FROM payroll_records 
           WHERE payslip_number LIKE ? 
           ORDER BY payslip_number DESC LIMIT 1`,[`${d}%`]),j=1;if(f&&f.length>0){let a=f[0].payslip_number;j=parseInt(a.split("-").pop()||"0")+1}let k=`${d}${String(j).padStart(3,"0")}`,n=parseFloat(a.basic_salary)||0,[o]=await c.query(`SELECT SUM(total_hours * hourly_rate * otr.rate_multiplier) as total_overtime
           FROM overtime_applications oa
           LEFT JOIN overtime_rates otr ON oa.overtime_rate_id = otr.id
           WHERE oa.employee_id = ? 
             AND oa.status = 'approved'
             AND oa.overtime_date BETWEEN ? AND ?`,[a.id,g.start_date,g.end_date]),p=parseFloat(o[0]?.total_overtime)||0,[q]=await c.query(`SELECT housing_allowance, transport_allowance, meal_allowance, other_allowances
           FROM employee_allowances
           WHERE employee_id = ? AND status = 'active'
           LIMIT 1`,[a.id]),r=parseFloat(q[0]?.housing_allowance)||0,s=parseFloat(q[0]?.transport_allowance)||0,t=parseFloat(q[0]?.meal_allowance)||0,x=parseFloat(q[0]?.other_allowances)||0,[y]=await c.query(`SELECT SUM(amount) as total
           FROM employee_bonuses
           WHERE employee_id = ? AND payroll_period_id = ? AND status = 'approved'`,[a.id,e]),z=parseFloat(y[0]?.total)||0,[A]=await c.query(`SELECT eb.kpi_result_id
             FROM employee_bonuses eb
            WHERE eb.employee_id = ?
              AND eb.payroll_period_id = ?
              AND eb.status = 'approved'
              AND eb.kpi_result_id IS NOT NULL`,[a.id,e]),B=A.map(a=>Number(a.kpi_result_id)).filter(a=>Number.isInteger(a)&&a>0),[C]=await c.query(`SELECT SUM(amount) as total
           FROM employee_commissions
           WHERE employee_id = ? AND payroll_period_id = ? AND status = 'approved'`,[a.id,e]),D=parseFloat(C[0]?.total)||0,[E]=await c.query(`SELECT id, monthly_installment, remaining_balance, paid_installments
           FROM employee_loans
           WHERE employee_id = ? AND status = 'active'
           LIMIT 1`,[a.id]),F=E[0]||null,G=F?parseFloat(F.monthly_installment):0,[H]=await c.query(`SELECT id, monthly_deduction, remaining_balance, paid_months
           FROM employee_advances
           WHERE employee_id = ? AND status = 'active'
           LIMIT 1`,[a.id]),I=H[0]||null,J=I?parseFloat(I.monthly_deduction):0,K=(0,m.j0)(a.date_of_birth,h),L=1===Number(a.lindung24_enrolled),M=(0,l.Oj)({basicSalary:n,housingAllowance:r,transportAllowance:s,mealAllowance:t,otherAllowances:x,overtimeAmount:p,bonusAmount:z,commissionAmount:D},{taxDeduction:0,loanDeduction:G,advanceDeduction:J,otherDeductions:0},i,K,L),N=M.epfEmployee,O=M.epfEmployer,P=M.socsoEmployee,Q=M.socsoEmployer,R=M.eisEmployee,S=M.eisEmployer,T=M.socsoNeiEmployee;if(await c.query(`INSERT INTO payroll_records (
            payroll_period_id, employee_id, payslip_number,
            basic_salary, housing_allowance, transport_allowance, 
            meal_allowance, other_allowances, overtime_amount,
            bonus_amount, commission_amount,
            epf_employee, socso_employee, eis_employee, socso_nei_employee,
            tax_deduction, loan_deduction, advance_deduction, other_deductions,
            epf_employer, socso_employer, eis_employer,
            payment_method, status
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft')`,[e,a.id,k,n,r,s,t,x,p,z,D,N,P,R,T,0,G,J,0,O,Q,S,"bank_transfer"]),F&&G>0){let a=parseFloat(F.remaining_balance)-G,b=parseInt(F.paid_installments)+1,d=a<=.01?"completed":"active";await c.query(`UPDATE employee_loans 
             SET remaining_balance = ?, paid_installments = ?, status = ?
             WHERE id = ?`,[Math.max(0,a),b,d,F.id])}if(I&&J>0){let a=parseFloat(I.remaining_balance)-J,b=parseInt(I.paid_months)+1,d=a<=.01?"completed":"active";await c.query(`UPDATE employee_advances 
             SET remaining_balance = ?, paid_months = ?, status = ?
             WHERE id = ?`,[Math.max(0,a),b,d,I.id])}B.length>0&&await c.query(`UPDATE kpi_results SET bonus_paid = 1
              WHERE id IN (${B.map(()=>"?").join(",")})`,B),u+=M.gross,v+=M.totalDeductions,w+=M.net}let x=await p(d.username);return await c.query(`UPDATE payroll_periods SET
          status = 'processing',
          total_employees = ?,
          total_gross_salary = ?,
          total_deductions = ?,
          total_net_salary = ?,
          processed_by = ?,
          processed_date = NOW()
        WHERE id = ?`,[q.length,(0,l.TG)(u),(0,l.TG)(v),(0,l.TG)(w),x,e]),await c.commit(),b.status(200).json({message:0===r.length?"Payroll processed successfully":`Payroll processed successfully. ${r.length} employee(s) were NOT paid (${t}). Check those records under Human Resources > Employee Management.`,total_employees:q.length,total_payslips:q.length,total_skipped:r.length,skipped:r})}catch(a){return await c.rollback(),console.error("Payroll processing error:",a),b.status(500).json({error:"Failed to process payroll"})}finally{c.release()}}return b.status(405).json({error:"Method not allowed"})}var r=c(58112),s=c(18766);let t=(0,h.M)(d,"default"),u=(0,h.M)(d,"config"),v=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/payroll/process",pathname:"/api/admin/payroll/process",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function w(a,b,c){let d=await v.prepare(a,b,{srcPage:"/api/admin/payroll/process"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,r.getTracer)(),e=d.getActiveScopeSpan(),j=v.instrumentationOnRequestError.bind(v),k=async e=>v.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:v.isDev,page:"/api/admin/payroll/process",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==s.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(s.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:r.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(v.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},60379:(a,b,c)=>{function d(a,b){return a.includes(b)}function e(a,b){return[`${b}_edit`,`${b}_update`].some(b=>a.includes(b))}c.d(b,{_m:()=>d,zi:()=>e})},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,7922],()=>b(b.s=25354));module.exports=c})();