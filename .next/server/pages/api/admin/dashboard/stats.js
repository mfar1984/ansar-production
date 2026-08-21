"use strict";(()=>{var a={};a.id=937,a.ids=[937],a.modules={3498:a=>{a.exports=require("mysql2/promise")},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")},83957:(a,b,c)=>{c.r(b),c.d(b,{config:()=>o,default:()=>n,handler:()=>q});var d={};c.r(d),c.d(d,{default:()=>k});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251);async function j(a){if(!a)return null;let[b]=await i.Ay.query("SELECT username, expires_at FROM admin_sessions WHERE hash = ?",[a]);if(!b||0===b.length)return null;let c=b[0];return new Date(c.expires_at)<new Date?null:c}async function k(a,b){if("GET"!==a.method)return b.status(405).json({error:"Method not allowed"});let{hash:c,dateRange:d,startDate:e,endDate:f}=a.query;if(!await j(String(c||"")))return b.status(401).json({error:"Unauthorized"});if(e&&f){let a=new Date(e),b=new Date(f).getTime()-a.getTime(),c=new Date(a.getTime()-b),d=new Date(a.getTime()-1);c.toISOString().split("T")[0],d.toISOString().split("T")[0]}try{let[a]=await i.Ay.query("SELECT COUNT(*) as count FROM employees WHERE status = 'active'"),c=a[0],[d]=await i.Ay.query("SELECT COUNT(*) as count FROM leave_applications WHERE status = 'pending'"),e=d[0],[f]=await i.Ay.query("SELECT COUNT(*) as count FROM claims WHERE status = 'pending'"),g=f[0],[h]=await i.Ay.query("SELECT COUNT(*) as count FROM overtime_applications WHERE status = 'pending'"),j=h[0],[k]=await i.Ay.query("SELECT COUNT(*) as count FROM expenses WHERE status = 'pending'"),l=k[0],[m]=await i.Ay.query(`SELECT COUNT(*) as count FROM kpi_assignments a
         JOIN kpi_periods p ON p.id = a.period_id
        WHERE a.status <> 'completed' AND p.status = 'open'`),n=m[0],[o]=await i.Ay.query("SELECT COUNT(*) as count FROM procurement_applications WHERE status = 'pending'"),p=o[0],[q]=await i.Ay.query("SELECT COUNT(*) as count FROM career_applicants WHERE status = 'pending'"),r=q[0],[s]=await i.Ay.query("SELECT COUNT(*) as count FROM helpdesk_tickets WHERE status IN ('open', 'in_progress')"),t=s[0],[u]=await i.Ay.query("SELECT COUNT(*) as count FROM career_postings WHERE status = 'active'"),v=u[0],[w]=await i.Ay.query("SELECT COUNT(*) as count FROM departments"),x=w[0],[y]=await i.Ay.query("SELECT COUNT(*) as count FROM news WHERE status = 'published'"),z=y[0],[A]=await i.Ay.query("SELECT COUNT(*) as count FROM newsletter_subscribers WHERE is_active = 1"),B=A[0],C={leave:Number(e?.count||0),claims:Number(g?.count||0),overtime:Number(j?.count||0),expenses:Number(l?.count||0),kpi:Number(n?.count||0),procurement:Number(p?.count||0),applicants:Number(r?.count||0)},D=await i.Ay.query(`
      SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        'Leave' as type,
        COUNT(*) as count
      FROM leave_applications
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')

      UNION ALL

      SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        'Claims' as type,
        COUNT(*) as count
      FROM claims
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')

      UNION ALL

      SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        'Overtime' as type,
        COUNT(*) as count
      FROM overtime_applications
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')

      UNION ALL

      SELECT
        DATE_FORMAT(applied_date, '%Y-%m') as month,
        'Expenses' as type,
        COUNT(*) as count
      FROM expenses
      WHERE applied_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(applied_date, '%Y-%m')

      ORDER BY month ASC
    `),E=await i.Ay.query(`
      SELECT 
        d.name as department,
        COUNT(e.id) as employee_count
      FROM departments d
      LEFT JOIN employees e ON d.id = e.department_id AND e.status = 'active'
      GROUP BY d.id, d.name
      ORDER BY employee_count DESC
      LIMIT 10
    `),[F]=await i.Ay.query(`
      SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        'Claims' as type,
        SUM(total_amount) as amount
      FROM claims
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')

      UNION ALL

      SELECT
        DATE_FORMAT(applied_date, '%Y-%m') as month,
        'Expenses' as type,
        SUM(total_amount) as amount
      FROM expenses
      WHERE applied_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(applied_date, '%Y-%m')

      UNION ALL

      SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        'Overtime' as type,
        SUM(total_amount) as amount
      FROM overtime_applications
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(created_at, '%Y-%m')

      ORDER BY month ASC
    `),[G]=await i.Ay.query(`
      SELECT
        lt.name as leave_type,
        COUNT(la.id) as count
      FROM leave_applications la
      JOIN leave_types lt ON la.leave_type_id = lt.id
      WHERE la.created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY lt.id, lt.name
      ORDER BY count DESC
    `),[H]=await i.Ay.query(`
      SELECT
        status,
        COUNT(*) as count
      FROM helpdesk_tickets
      WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY status
      ORDER BY count DESC
    `),[I]=await i.Ay.query(`
      SELECT
        ec.name as category,
        COUNT(e.id) as count,
        SUM(e.total_amount) as total_amount
      FROM expenses e
      JOIN expense_categories ec ON e.category_id = ec.id
      WHERE e.applied_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY ec.id, ec.name
      ORDER BY total_amount DESC
      LIMIT 5
    `),[J]=await i.Ay.query("SELECT COUNT(*) as count FROM employees WHERE status = 'active' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)"),[K]=await i.Ay.query("SELECT COUNT(*) as count FROM leave_applications WHERE status = 'pending' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)"),[L]=await i.Ay.query("SELECT COUNT(*) as count FROM leave_applications WHERE status = 'pending' AND created_at < DATE_SUB(NOW(), INTERVAL 3 DAY)"),[M]=await i.Ay.query("SELECT COUNT(*) as count FROM claims WHERE status = 'pending' AND created_at < DATE_SUB(NOW(), INTERVAL 3 DAY)"),[N]=await i.Ay.query("SELECT COUNT(*) as count FROM expenses WHERE status = 'pending' AND applied_date < DATE_SUB(NOW(), INTERVAL 3 DAY)"),[O]=await i.Ay.query(`
      (SELECT
        'Leave' as module,
        COALESCE(e.full_name, 'Unknown') as user_name,
        CAST(la.status AS CHAR) as status,
        la.created_at as timestamp
      FROM leave_applications la
      LEFT JOIN employees e ON la.employee_id = e.id
      ORDER BY la.created_at DESC
      LIMIT 3)

      UNION ALL

      (SELECT
        'Claims' as module,
        COALESCE(e.full_name, 'Unknown') as user_name,
        CAST(c.status AS CHAR) as status,
        c.created_at as timestamp
      FROM claims c
      LEFT JOIN employees e ON c.employee_id = e.id
      ORDER BY c.created_at DESC
      LIMIT 3)

      UNION ALL

      (SELECT
        'Overtime' as module,
        COALESCE(e.full_name, 'Unknown') as user_name,
        CAST(oa.status AS CHAR) as status,
        oa.created_at as timestamp
      FROM overtime_applications oa
      LEFT JOIN employees e ON oa.employee_id = e.id
      ORDER BY oa.created_at DESC
      LIMIT 2)

      UNION ALL

      (SELECT
        'Expenses' as module,
        COALESCE(e.full_name, 'Unknown') as user_name,
        CAST(ex.status AS CHAR) as status,
        ex.applied_date as timestamp
      FROM expenses ex
      LEFT JOIN employees e ON ex.employee_id = e.id
      ORDER BY ex.applied_date DESC
      LIMIT 2)

      ORDER BY timestamp DESC
      LIMIT 10
    `),P=Number(c?.count||0),Q=Number(J[0]?.count||0),R=P-Q,S=Q>0?(R/Q*100).toFixed(1):"0",T=Object.values(C).reduce((a,b)=>a+b,0),U=Number(K[0]?.count||0),V=T-U,W=U>0?(V/U*100).toFixed(1):"0";return b.status(200).json({keyMetrics:{totalEmployees:P,pendingApprovals:T,openTickets:Number(t?.count||0),activeJobs:Number(v?.count||0)},comparisons:{employees:{current:P,previous:Q,change:R,changePercent:S,trend:R>=0?"up":"down"},approvals:{current:T,previous:U,change:V,changePercent:W,trend:V>=0?"up":"down"}},alerts:{oldPendingLeave:Number(L[0]?.count||0),oldPendingClaims:Number(M[0]?.count||0),oldPendingExpenses:Number(N[0]?.count||0)},pendingTasks:C,monthlyTrends:D[0],financialTrends:F,leaveTypes:G,ticketStats:H,expenseCategories:I,departmentStats:E[0],recentActivities:O,quickStats:{departments:Number(x?.count||0),publishedNews:Number(z?.count||0),subscribers:Number(B?.count||0),newHires:0},lastUpdated:new Date().toISOString()})}catch(a){return console.error("Dashboard stats error:",a),b.status(500).json({error:"Failed to fetch dashboard statistics"})}}var l=c(58112),m=c(18766);let n=(0,h.M)(d,"default"),o=(0,h.M)(d,"config"),p=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/dashboard/stats",pathname:"/api/admin/dashboard/stats",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function q(a,b,c){let d=await p.prepare(a,b,{srcPage:"/api/admin/dashboard/stats"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,l.getTracer)(),e=d.getActiveScopeSpan(),j=p.instrumentationOnRequestError.bind(p),k=async e=>p.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:p.isDev,page:"/api/admin/dashboard/stats",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==m.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(m.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:l.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(p.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169],()=>b(b.s=83957));module.exports=c})();