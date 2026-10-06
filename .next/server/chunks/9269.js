"use strict";exports.id=9269,exports.ids=[9269],exports.modules={7534:(a,b,c)=>{c.d(b,{PK:()=>q,R8:()=>o,UH:()=>n,tP:()=>f,tZ:()=>m,uK:()=>i});let d=[{code:"jhr",label:"Johor"},{code:"kdh",label:"Kedah"},{code:"ktn",label:"Kelantan"},{code:"kul",label:"Kuala Lumpur"},{code:"lbn",label:"Labuan"},{code:"mlk",label:"Melaka"},{code:"nsn",label:"Negeri Sembilan"},{code:"phg",label:"Pahang"},{code:"png",label:"Penang"},{code:"prk",label:"Perak"},{code:"pls",label:"Perlis"},{code:"pjy",label:"Putrajaya"},{code:"sbh",label:"Sabah"},{code:"swk",label:"Sarawak"},{code:"sgr",label:"Selangor"},{code:"trg",label:"Terengganu"}],e=Object.fromEntries(d.map(a=>[a.code,a.label])),f=d.map(a=>a.code),g={"01":"jhr","02":"kdh","03":"ktn","04":"mlk","05":"nsn","06":"phg","07":"png","08":"prk","09":"pls",10:"sgr",11:"trg",12:"sbh",13:"swk",14:"kul",15:"lbn",16:"pjy"},h=Object.fromEntries(Object.entries(g).map(([a,b])=>[b,a]));function i(a){let b=m(a);return b?h[b]??null:null}let j=Object.fromEntries(d.flatMap(a=>[[a.label.toLowerCase(),a.code],[a.label.toLowerCase().replace(/\s+/g,""),a.code]])),k={"pulau pinang":"png",pulaupinang:"png","wp kuala lumpur":"kul","w.p. kuala lumpur":"kul","wilayah persekutuan":"kul","wp labuan":"lbn","wp putrajaya":"pjy",malacca:"mlk","negri sembilan":"nsn"},l=Object.fromEntries(Object.entries(k).map(([a,b])=>[a.replace(/[^a-z]/g,""),b]));function m(a){let b=String(a??"").replace(/[[\]"']/g,"").trim();if(!b)return null;let c=b.toLowerCase();if(f.includes(c))return c;let d=c.replace(/\D/g,"");if(d&&g[d.padStart(2,"0")])return g[d.padStart(2,"0")];let e=c.replace(/[.,]/g," ").replace(/\s+/g," ").trim(),h=c.replace(/[^a-z]/g,"");return j[e]||k[e]||j[h]||l[h]||null}function n(a){let b=m(a);return b?e[b]:String(a??"").trim()||"—"}function o(a){if(null==a||""===a)return[];let b=[];if(Array.isArray(a))b=a;else if("string"==typeof a)try{let c=JSON.parse(a);b=Array.isArray(c)?c:[a]}catch{b=a.split(",")}let c=[];for(let a of b){let b=m(a);b&&!c.includes(b)&&c.push(b)}return c}let p={jhr:"MY-01",kdh:"MY-02",ktn:"MY-03",mlk:"MY-04",nsn:"MY-05",phg:"MY-06",png:"MY-07",prk:"MY-08",pls:"MY-09",sgr:"MY-10",trg:"MY-11",sbh:"MY-12",swk:"MY-13",kul:"MY-14",lbn:"MY-15",pjy:"MY-16"};function q(a){let b=m(a);return b?p[b]:null}},59269:(a,b,c)=>{c.d(b,{WG:()=>k,c8:()=>m,kY:()=>l,uJ:()=>j});var d=c(88251),e=c(92565),f=c(7534),g=c(23943);async function h(){let a=await (0,e.f)();return 1===a.length?a[0]:""}async function i(){let a=await (0,d.P)("SELECT value FROM hr_module_settings WHERE module = 'leave' AND setting_key = 'rest_days' LIMIT 1"),b=String(a[0]?.value??"0,6").split(",").map(a=>Number(a.trim())).filter(a=>Number.isInteger(a)&&a>=0&&a<=6);return b.length>0?b:[0,6]}async function j(a,b){let c=(0,f.tZ)(b)||await h(),e=JSON.stringify([c]),j=await (0,d.P)(`SELECT id, name, type
       FROM public_holidays
      WHERE date = ?
        AND is_active = TRUE
        AND (type = 'national' OR (type = 'regional' AND JSON_CONTAINS(state_codes, ?)))
      LIMIT 1`,[a,e]),k=await (0,d.P)(`SELECT id, name
       FROM custom_holidays
      WHERE ? BETWEEN start_date AND end_date
        AND (state_codes IS NULL OR JSON_CONTAINS(state_codes, ?))
      LIMIT 1`,[a,e]),l=j.length>0||k.length>0,m=j[0]?.name||k[0]?.name||null,n=j[0]?.type||(k.length>0?"custom":null),[o,p,q]=a.split("-").map(Number),r=new Date(o,(p||1)-1,q||1),s=(await i()).includes(r.getDay()),t=l&&s?"public_holiday_weekend":l?"public_holiday":s?"weekend":"weekday",u=(await (0,d.P)(`SELECT id, name, rate_multiplier
       FROM overtime_rates
      WHERE day_type = ? AND status = 'active'
      ORDER BY is_default DESC, id ASC
      LIMIT 1`,[t]))[0]||null;return{date:a,state:c,isHoliday:l,isWeekend:s,holidayName:m,holidayType:n,dayType:t,rateId:u?.id??null,rateName:u?.name??null,multiplier:u?Number(u.rate_multiplier):g.mo[t]}}async function k(a,b,c){let e=await (0,d.P)(`SELECT COALESCE(SUM(total_hours), 0) AS total
       FROM overtime_applications
      WHERE employee_id = ?
        AND status IN ('pending', 'approved', 'paid')
        AND YEAR(overtime_date) = YEAR(?)
        AND MONTH(overtime_date) = MONTH(?)
        ${c?"AND id <> ?":""}`,c?[a,b,b,c]:[a,b,b]);return Number(e[0]?.total||0)}async function l(a,b){let c=[...new Set((b||[]).filter(a=>/^\d{4}-\d{2}$/.test(a)))].sort();if(0===c.length)return{};let e=`${c[0]}-01`,f=`${c[c.length-1]}-01`,g=await (0,d.P)(`SELECT DATE_FORMAT(overtime_date, '%Y-%m') AS month,
            COALESCE(SUM(total_hours), 0) AS total
       FROM overtime_applications
      WHERE employee_id = ?
        AND status IN ('pending', 'approved', 'paid')
        AND overtime_date >= ?
        AND overtime_date <= LAST_DAY(?)
      GROUP BY DATE_FORMAT(overtime_date, '%Y-%m')`,[a,e,f]),h={};for(let a of c)h[a]=0;for(let a of g)h[a.month]=Number(a.total||0);return h}async function m(a,b){let c=[...new Set((b||[]).filter(g.tf))].sort();return 0===c.length?[]:await (0,d.P)(`SELECT DATE_FORMAT(overtime_date, '%Y-%m-%d') AS overtime_date,
            start_time, end_time, overtime_number
       FROM overtime_applications
      WHERE employee_id = ?
        AND status IN ('pending', 'approved', 'paid')
        AND overtime_date >= DATE_SUB(?, INTERVAL 1 DAY)
        AND overtime_date <= DATE_ADD(?, INTERVAL 1 DAY)
      ORDER BY overtime_date ASC, start_time ASC`,[a,c[0],c[c.length-1]])}},88251:(a,b,c)=>{c.d(b,{Ay:()=>i,G$:()=>h,P:()=>f,rN:()=>g});var d=c(3498);let e=c.n(d)().createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function f(a,b){let[c]=b&&b.length>0?await e.query(a,b):await e.query(a);return c}async function g(){try{return(await e.getConnection()).release(),!0}catch(a){return console.error("Database connection test failed:",a),!1}}function h(){return{totalConnections:10,activeConnections:0,idleConnections:0,queuedRequests:0}}let i=e},92565:(a,b,c)=>{c.d(b,{Ym:()=>h,f:()=>f,xQ:()=>g});var d=c(88251),e=c(7534);async function f(){let a=await (0,d.P)("SELECT holidays_include_states FROM integrations LIMIT 1");return(0,e.R8)(a[0]?.holidays_include_states)}async function g(a){let b=await (0,d.P)("SELECT duty_state FROM employees WHERE id = ? LIMIT 1",[a]),c=(0,e.tZ)(b[0]?.duty_state);if(c)return c;let g=await f();return 1===g.length?g[0]:null}async function h(a){let b=(0,e.tZ)(a);return!!b&&(await f()).includes(b)}}};