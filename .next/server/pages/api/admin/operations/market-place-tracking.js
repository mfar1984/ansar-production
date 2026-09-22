"use strict";(()=>{var a={};a.id=6692,a.ids=[6692],a.modules={3498:a=>{a.exports=require("mysql2/promise")},31327:(a,b,c)=>{c.r(b),c.d(b,{config:()=>u,default:()=>t,handler:()=>w});var d={};c.r(d),c.d(d,{default:()=>q});var e=c(29046),f=c(8667),g=c(33480),h=c(86435),i=c(88251),j=c(3557),k=c(19275),l=c(4775),m=c(18692);let n="market_place_tracking",o="GET, POST";async function p(a){let b=a.filter(a=>a.awb_number),c={checked:b.length,updated:0,newEvents:0,delivered:0,notFound:[]};if(0===b.length)return c;let d=new Map;for(let a of b){let b=String(a.awb_number),c=d.get(b);c?c.push(a):d.set(b,[a])}let e=[...d.keys()];for(let a=0;a<e.length;a+=100){let b=e.slice(a,a+100);for(let a of(await (0,m.af)(b))){let b=d.get(a.awb_number)??[];if(0!==b.length){if(!a.found){c.notFound.push(a.awb_number);continue}for(let d of b){let b=await i.Ay.getConnection();try{for(let e of(await b.beginTransaction(),a.events)){let[a]=await b.query(`INSERT IGNORE INTO market_place_tracking_events
                 (shipment_id, event_date, status_code, tracking_status, location)
               VALUES (?, ?, ?, ?, ?)`,[d.id,e.event_date,e.status_code,e.tracking_status,e.location]);Number(a.affectedRows)>0&&c.newEvents++}if(await b.query(`UPDATE market_place_shipments
                SET shipment_status_code = ?, shipment_status = ?, last_synced_at = NOW()
              WHERE id = ?`,[a.latest_status_code,a.latest_status?a.latest_status.slice(0,160):null,d.id]),c.updated++,a.latest_status_code===l.AN){let[e]=await b.query(`UPDATE market_place_orders
                  SET status = 'completed', received_at = NOW(),
                      received_by = 'EasyParcel tracking',
                      receive_note = ?
                WHERE id = ? AND status = 'shipped' AND received_at IS NULL`,[`Reported delivered by the courier${a.latest_status?`: ${a.latest_status}`:""}`.slice(0,300),d.order_id]);Number(e.affectedRows)>0&&c.delivered++}await b.commit()}catch(a){try{await b.rollback()}catch{}throw a}finally{b.release()}}}}}return c}async function q(a,b){let c=await (0,j.OC)(a,b);if(c){b.setHeader("Cache-Control","no-store");try{let d=Number(a.query.id);if("GET"===a.method){if(!(0,j.OD)(c,b,n,"view"))return;let a=await (0,i.P)(`SELECT o.id            AS order_id,
                o.order_no,
                o.status         AS order_status,
                o.payment_status,
                o.buyer_name,
                o.buyer_phone,
                o.city,
                o.state_code,
                o.total_amount,
                DATE_FORMAT(o.order_date, '%Y-%m-%d %H:%i')   AS order_date,
                DATE_FORMAT(o.received_at, '%Y-%m-%d %H:%i')  AS received_at,
                s.id            AS shipment_id,
                s.shipment_number,
                s.awb_number,
                s.awb_url,
                s.tracking_url,
                s.courier_name,
                s.service_name,
                s.shipment_status_code,
                s.shipment_status,
                s.currency_code,
                s.total_paid,
                s.weight_kg,
                DATE_FORMAT(s.collection_date, '%Y-%m-%d')      AS collection_date,
                DATE_FORMAT(s.last_synced_at, '%Y-%m-%d %H:%i') AS last_synced_at
           FROM market_place_orders o
           LEFT JOIN market_place_shipments s
             ON s.order_id = o.id AND s.cancelled_at IS NULL
          WHERE o.fulfilment = 'online' AND o.status <> 'cancelled'
          ORDER BY o.order_date DESC, o.id DESC
          LIMIT ?`,[300]),d=[],e=a.map(a=>Number(a.shipment_id)).filter(a=>Number.isInteger(a)&&a>0);e.length>0&&(d=await (0,i.P)(`SELECT shipment_id, status_code, tracking_status, location,
                  DATE_FORMAT(event_date, '%Y-%m-%d %H:%i') AS event_date
             FROM market_place_tracking_events
            WHERE shipment_id IN (${e.map(()=>"?").join(", ")})
            ORDER BY event_date ASC, id ASC`,e));let f=a.map(a=>{var b;return{...a,stage:(b=null===a.shipment_status_code||void 0===a.shipment_status_code?null:Number(a.shipment_status_code),a.shipment_id?null===b||7===b||2===b?"booked":3===b||4===b||11===b?"in_transit":b===l.AN?"delivered":"attention":"to_book")}}),g={to_book:0,booked:0,in_transit:0,delivered:0,attention:0};for(let a of f){let b=a.stage;b in g&&g[b]++}let h=await (0,m.Xg)();return b.status(200).json({success:!0,data:f,events:d,counts:g,courier:{configured:!!h&&!!h.connected_at&&!!h.refresh_token,account_label:h?.account_label??null},limit:300,truncated:a.length>=300})}if("POST"===a.method){if(!(0,j.OD)(c,b,n,"sync"))return;let e=Number.isInteger(d)&&d>0,f=e?await (0,i.P)(`SELECT s.id, s.order_id, s.awb_number, s.shipment_number, s.shipment_status_code
             FROM market_place_shipments s
             JOIN market_place_orders o ON o.id = s.order_id
            WHERE s.cancelled_at IS NULL
              AND s.awb_number IS NOT NULL
              AND o.status <> 'cancelled'
              AND o.id = ?
            ORDER BY s.id DESC
            LIMIT ?`,[d,100]):await (0,i.P)(`SELECT s.id, s.order_id, s.awb_number, s.shipment_number, s.shipment_status_code
             FROM market_place_shipments s
             JOIN market_place_orders o ON o.id = s.order_id
            WHERE s.cancelled_at IS NULL
              AND s.awb_number IS NOT NULL
              AND o.status <> 'cancelled'
              AND (s.shipment_status_code IS NULL OR s.shipment_status_code <> ?)
            ORDER BY s.id DESC
            LIMIT ?`,[l.AN,300]);if(0===f.length)return b.status(200).json({success:!0,checked:0,updated:0,new_events:0,delivered:0,not_found:[],message:e?"This order has no courier tracking number yet, so there is nothing to refresh. The number appears once the courier issues one.":"Nothing to refresh. Every booked parcel has either been delivered or has no tracking number yet."});let g=await p(f);await (0,k.At)(a,{action:"UPDATE",module:"Market Place",target:e?`Order tracking: ${d}`:"Tracking queue",description:`${c.username} refreshed tracking for ${g.checked} parcel(s) — ${g.newEvents} new event(s), ${g.delivered} marked delivered`,after:{checked:g.checked,new_events:g.newEvents,delivered:g.delivered,not_found:g.notFound.length}});let h=[`${g.checked} parcel(s) checked.`];return g.newEvents>0?h.push(`${g.newEvents} new event(s).`):h.push("No new events."),g.delivered>0&&h.push(`${g.delivered} order(s) closed as delivered.`),g.notFound.length>0&&h.push(`The courier does not recognise ${g.notFound.join(", ")} yet — normal for a parcel booked but not scanned.`),b.status(200).json({success:!0,checked:g.checked,updated:g.updated,new_events:g.newEvents,delivered:g.delivered,not_found:g.notFound,message:h.join(" ")})}return b.setHeader("Allow",o),b.status(405).json({success:!1,error:`Method not allowed. ${o}.`})}catch(c){if(c instanceof m.Cg)return b.status(400).json({success:!1,error:c.message,reconnect:c.reconnect,detail:c.detail});let a=c instanceof Error?c.message:"Unknown error";return console.error("[market-place-tracking]",a),b.status(500).json({success:!1,error:"The tracking queue could not be loaded.",detail:a})}}}var r=c(58112),s=c(18766);let t=(0,h.M)(d,"default"),u=(0,h.M)(d,"config"),v=new g.PagesAPIRouteModule({definition:{kind:f.A.PAGES_API,page:"/api/admin/operations/market-place-tracking",pathname:"/api/admin/operations/market-place-tracking",bundlePath:"",filename:""},userland:d,distDir:".next",relativeProjectDir:""});async function w(a,b,c){let d=await v.prepare(a,b,{srcPage:"/api/admin/operations/market-place-tracking"});if(!d){b.statusCode=400,b.end("Bad Request"),null==c.waitUntil||c.waitUntil.call(c,Promise.resolve());return}let{query:f,params:g,prerenderManifest:h,routerServerContext:i}=d;try{let c=a.method||"GET",d=(0,r.getTracer)(),e=d.getActiveScopeSpan(),j=v.instrumentationOnRequestError.bind(v),k=async e=>v.render(a,b,{query:{...f,...g},params:g,allowedRevalidateHeaderKeys:[],multiZoneDraftMode:!1,trustHostHeader:!1,previewProps:h.preview,propagateError:!1,dev:v.isDev,page:"/api/admin/operations/market-place-tracking",internalRevalidate:null==i?void 0:i.revalidate,onError:(...b)=>j(a,...b)}).finally(()=>{if(!e)return;e.setAttributes({"http.status_code":b.statusCode,"next.rsc":!1});let f=d.getRootSpanAttributes();if(!f)return;if(f.get("next.span_type")!==s.BaseServerSpan.handleRequest)return void console.warn(`Unexpected root span type '${f.get("next.span_type")}'. Please report this Next.js issue https://github.com/vercel/next.js`);let g=f.get("next.route");if(g){let a=`${c} ${g}`;e.setAttributes({"next.route":g,"http.route":g,"next.span_name":a}),e.updateName(a)}else e.updateName(`${c} ${a.url}`)});e?await k(e):await d.withPropagatedContext(a.headers,()=>d.trace(s.BaseServerSpan.handleRequest,{spanName:`${c} ${a.url}`,kind:r.SpanKind.SERVER,attributes:{"http.method":c,"http.target":a.url}},k))}catch(a){if(v.isDev)throw a;(0,e.sendError)(b,500,"Internal Server Error")}finally{null==c.waitUntil||c.waitUntil.call(c,Promise.resolve())}}},55511:a=>{a.exports=require("crypto")},75600:a=>{a.exports=require("next/dist/compiled/next-server/pages-api.runtime.prod.js")}};var b=require("../../../../webpack-api-runtime.js");b.C(a);var c=b.X(0,[7169,8692,3961],()=>b(b.s=31327));module.exports=c})();