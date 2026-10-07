"use strict";(()=>{var a={};a.id=5812,a.ids=[5812],a.modules={3498:a=>{a.exports=require("mysql2/promise")},49793:(a,b,c)=>{c.r(b),c.d(b,{config:()=>s,default:()=>r,handler:()=>u});var d={};c.r(d),c.d(d,{default:()=>o});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(60379),k=c(58224);async function l(a){if(!a)return null;let[b]=await i.Ay.query("SELECT username, expires_at FROM admin_sessions WHERE hash = ?",[a]);if(!b||0===b.length)return null;let c=b[0];return new Date(c.expires_at)<new Date?null:c}async function m(a){let b=await i.Ay.getConnection();try{let[c]=await b.query("SELECT id FROM admins WHERE username = ? LIMIT 1",[a]);if(!c||0===c.length)return[];let d=c[0].id,[e]=await b.query(`
      SELECT DISTINCT p.module, p.action
      FROM permissions p
      INNER JOIN role_permissions rp ON p.id = rp.permission_id
      INNER JOIN admin_roles ar ON rp.role_id = ar.role_id
      WHERE ar.admin_id = ?
      ORDER BY p.module, p.action
    `,[d]);return e.map(a=>`${a.module}_${a.action}`)}finally{b.release()}}async function n(a){let[b]=await i.Ay.query("SELECT id FROM admins WHERE username = ? LIMIT 1",[a]);return b[0]?.id||0}async function o(a,b){let{hash:c}=a.query,d=await l(c);if(!d)return b.status(401).json({error:"Unauthorized"});let e=await m(d.username);if("GET"===a.method){if(!(0,j._m)(e,"bonuses_view"))return b.status(403).json({error:"Forbidden"});try{let{employee_id:c,period_id:d,status:e,year:f,month:g}=a.query,h=`
        SELECT 
          eb.*,
          e.employee_id as employee_number,
          e.full_name as employee_name,
          e.position as employee_position,
          d.name as department_name,
          pp.period_name,
          pp.period_month,
          pp.period_year,
          creator.username as created_by_name,
          approver.username as approved_by_name
        FROM employee_bonuses eb
        INNER JOIN employees e ON eb.employee_id = e.id
        LEFT JOIN departments d ON e.department_id = d.id
        LEFT JOIN payroll_periods pp ON eb.payroll_period_id = pp.id
        LEFT JOIN admins creator ON eb.created_by = creator.id
        LEFT JOIN admins approver ON eb.approved_by = approver.id
        WHERE 1=1
      `,j=[];c&&(h+=" AND eb.employee_id = ?",j.push(c)),d&&(h+=" AND eb.payroll_period_id = ?",j.push(d)),e&&(h+=" AND eb.status = ?",j.push(e)),f&&(h+=" AND pp.period_year = ?",j.push(f)),g&&(h+=" AND pp.period_month = ?",j.push(g)),h+=" ORDER BY eb.created_at DESC";let[k]=await i.Ay.query(h,j);return b.status(200).json(k)}catch(a){return console.error("Bonuses fetch error:",a),b.status(500).json({error:"Failed to fetch bonuses"})}}if("POST"===a.method){if(!(0,j._m)(e,"bonuses_create"))return b.status(403).json({error:"Forbidden"});try{let{employee_id:c,payroll_period_id:e,bonus_type:f,bonus_name:g,bonus_date:h,amount:j,remarks:l,status:m="pending"}=a.body;if(!c||!e||!f||!j)return b.status(400).json({error:"Employee ID, period, bonus type, and amount are required"});let o=g||`${f.charAt(0).toUpperCase()+f.slice(1)} Bonus`,p=h||(0,k.Ec)(),q=new Date,r=(0,k.Rh)(q),s=`BNS-${r}-`,[t]=await i.Ay.query(`SELECT bonus_number FROM employee_bonuses 
         WHERE bonus_number LIKE ? 
         ORDER BY bonus_number DESC LIMIT 1`,[`${s}%`]),u=1;if(t&&t.length>0){let a=t[0].bonus_number;u=parseInt(a.split("-").pop()||"0")+1}let v=`${s}${String(u).padStart(3,"0")}`,w=await n(d.username),[x]=await i.Ay.query(`INSERT INTO employee_bonuses (
          bonus_number, employee_id, payroll_period_id, bonus_type,
          bonus_name, bonus_date, amount, remarks, status, created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,[v,c,e,f,o,p,j,l||null,m,w]);return b.status(201).json({message:"Bonus created successfully",id:x.insertId,bonus_number:v})}catch(a){return console.error("Bonus creation error:",a),b.status(500).json({error:"Failed to create bonus"})}}return b.status(405).json({error:"Method not allowed"})}var p=c(58112),q=c(18766);let r=(0,h.M)(d,"default"),s=(0,h.M)(d,"config"),t=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/bonuses",pathname:"/api/admin/bonuses",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function u(a,b,c){let d=await t.prepare(a,b,{srcPage:"/api/admin/bonuses"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,p.getTracer)(),e=d.getActiveScopeSpan(),j=t.instrumentationOnRequestError.bind(t),k=async e=>t.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:t.isDev,page:"/api/admin/bonuses",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==q.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(q.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:p.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(t.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,3646],()=>b(b.s=49793));module.exports=c})();