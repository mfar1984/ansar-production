exports.id=3020,exports.ids=[3020],exports.modules={2092:(a,b,c)=>{"use strict";c.d(b,{Dx:()=>h,EA:()=>g,Vg:()=>e,bU:()=>i,rN:()=>f,ze:()=>d});let d=4,e=48;function f(a){let b=Number(a??0);return Number.isFinite(b)?b.toLocaleString("en-MY",{minimumFractionDigits:2,maximumFractionDigits:2}):"0.00"}function g(a,b,c,d=0){if(!a)return"Not counted";if(d>0)return`Per option (${d})`;let e=Number(b??0);if(e<=0)return"Out of stock";let f=Number(c??0);return f>0&&e<=f?`${e} left`:String(e)}function h(a){return String(a||"").split(/\r?\n/).map(a=>a.trim()).filter(Boolean)}function i(a){return a.map(a=>{let b=a.indexOf(":");if(b<=0)return{label:null,value:a};let c=a.slice(0,b).trim(),d=a.slice(b+1).trim();return c&&d?{label:c,value:d}:{label:null,value:a}})}},18702:(a,b,c)=>{"use strict";c.d(b,{DI:()=>j,KB:()=>l,S5:()=>g,TC:()=>k,lN:()=>h});var d=c(35552),e=c(2092);let f={isOpen:!1,heading:"Shop",intro:"",perPage:12,howToOrder:"",hideSoldOut:!1,showStockLeft:!0};async function g(){try{let a=(await (0,d.P)(`SELECT is_open, page_heading, intro_text, products_per_page, how_to_order,
              hide_sold_out, show_stock_left
         FROM market_place_settings WHERE id = 1`))[0];if(!a)return f;let b=Number(a.products_per_page);return{isOpen:1===Number(a.is_open),heading:(a.page_heading||"").trim()||f.heading,intro:(a.intro_text||"").trim(),perPage:Number.isFinite(b)?Math.min(e.Vg,Math.max(e.ze,Math.trunc(b))):f.perPage,howToOrder:(a.how_to_order||"").trim(),hideSoldOut:1===Number(a.hide_sold_out),showStockLeft:1===Number(a.show_stock_left)}}catch{return f}}async function h(){try{let a=await (0,d.P)("SELECT is_open FROM market_place_settings WHERE id = 1");return 1===Number(a[0]?.is_open)}catch{return!1}}function i(a){return 1===Number(a.track_stock)&&(Number(a.option_count)>0?null!==a.option_stock&&0>=Number(a.option_stock):0>=Number(a.stock_quantity))}async function j(a){try{let b=await (0,d.P)(`SELECT p.id, p.name, p.slug, p.short_description, p.price, p.compare_at_price,
              p.fulfilment, p.featured, p.track_stock, p.stock_quantity, p.low_stock_threshold,
              p.option_label,
              (SELECT COUNT(*) FROM market_place_product_options o
                WHERE o.product_id = p.id) AS option_count,
              (SELECT SUM(o.stock_quantity) FROM market_place_product_options o
                WHERE o.product_id = p.id) AS option_stock,
              (SELECT i.path FROM market_place_product_images i
                WHERE i.product_id = p.id
                ORDER BY i.sort_order ASC, i.id ASC LIMIT 1) AS cover_path
         FROM market_place_products p
        WHERE p.status = 'active'
        ORDER BY p.featured DESC, p.sort_order ASC, p.name ASC
        LIMIT 500`);if(0===b.length)return[];let c=await (0,d.P)(`SELECT pc.product_id, pc.category_id
         FROM market_place_product_categories pc
         JOIN market_place_categories c ON c.id = pc.category_id
        WHERE c.is_active = 1`),e=new Map;for(let a of c){let b=Number(a.product_id),c=e.get(b)||[];c.push(Number(a.category_id)),e.set(b,c)}let f=b.map(a=>{let b=i(a);return{id:Number(a.id),name:a.name,slug:a.slug,summary:(a.short_description||"").trim(),price:String(a.price),compareAt:null===a.compare_at_price?null:String(a.compare_at_price),fulfilment:a.fulfilment,featured:1===Number(a.featured),stock:1===Number(a.track_stock)?Number(a.stock_quantity):null,lowStock:Number(a.low_stock_threshold),soldOut:b,optionCount:Number(a.option_count),optionLabel:(a.option_label||"").trim(),cover:a.cover_path,categoryIds:e.get(Number(a.id))||[]}});return a.hideSoldOut?f.filter(a=>!a.soldOut):f}catch{return[]}}async function k(){try{return await (0,d.P)(`SELECT id, name, icon, slug FROM market_place_categories
        WHERE is_active = 1 ORDER BY sort_order ASC, name ASC`)}catch{return[]}}async function l(a){try{let b=(await (0,d.P)(`SELECT p.id, p.name, p.slug, p.short_description, p.full_description,
              p.price, p.compare_at_price, p.fulfilment, p.featured,
              p.track_stock, p.stock_quantity, p.low_stock_threshold,
              p.option_label, p.key_highlights, p.specifications, p.included_items,
              p.support_text, p.warranty_text,
              p.collection_location,
              DATE_FORMAT(p.collection_at, '%d %b %Y, %l:%i %p') AS collection_at,
              p.weight_kg, p.length_cm, p.width_cm, p.height_cm, p.brand,
              p.seo_title, p.seo_description,
              (SELECT COUNT(*) FROM market_place_product_options o
                WHERE o.product_id = p.id) AS option_count,
              (SELECT SUM(o.stock_quantity) FROM market_place_product_options o
                WHERE o.product_id = p.id) AS option_stock,
              (SELECT i.path FROM market_place_product_images i
                WHERE i.product_id = p.id
                ORDER BY i.sort_order ASC, i.id ASC LIMIT 1) AS cover_path
         FROM market_place_products p
        WHERE p.slug = ? AND p.status = 'active'
        LIMIT 1`,[a]))[0];if(!b)return null;let[c,f,g]=await Promise.all([(0,d.P)(`SELECT path, original_name FROM market_place_product_images
          WHERE product_id = ? ORDER BY sort_order ASC, id ASC`,[b.id]),(0,d.P)(`SELECT name, price, stock_quantity FROM market_place_product_options
          WHERE product_id = ? ORDER BY sort_order ASC, id ASC`,[b.id]),(0,d.P)(`SELECT pc.category_id FROM market_place_product_categories pc
           JOIN market_place_categories c ON c.id = pc.category_id
          WHERE pc.product_id = ? AND c.is_active = 1`,[b.id])]),h=[b.length_cm,b.width_cm,b.height_cm].map(a=>null===a?null:String(a)),j=h.every(a=>null!==a&&Number(a)>0)?`${Number(h[0])} x ${Number(h[1])} x ${Number(h[2])} cm`:null;return{id:Number(b.id),name:b.name,slug:b.slug,summary:(b.short_description||"").trim(),price:String(b.price),compareAt:null===b.compare_at_price?null:String(b.compare_at_price),fulfilment:b.fulfilment,featured:1===Number(b.featured),stock:1===Number(b.track_stock)?Number(b.stock_quantity):null,lowStock:Number(b.low_stock_threshold),soldOut:i(b),optionCount:Number(b.option_count),optionLabel:(b.option_label||"").trim(),cover:b.cover_path,categoryIds:g.map(a=>Number(a.category_id)),description:(b.full_description||"").trim(),highlights:(0,e.Dx)(b.key_highlights),specifications:(0,e.Dx)(b.specifications),included:(0,e.Dx)(b.included_items),support:(0,e.Dx)(b.support_text),warranty:(0,e.Dx)(b.warranty_text),collectionLocation:(b.collection_location||"").trim(),collectionAt:b.collection_at,weightKg:null===b.weight_kg?null:String(b.weight_kg),dimensions:j,brand:(b.brand||"").trim(),seoTitle:(b.seo_title||"").trim(),seoDescription:(b.seo_description||"").trim(),images:c.map((a,c)=>{let d=(a.original_name||"").replace(/\.[a-z0-9]+$/i,"").trim(),e=/[a-z]{3}/i.test(d)&&!/^(img|image|photo|dsc|screenshot)[\s_-]*\d*$/i.test(d);return{path:a.path,alt:e?d:`${b.name} — picture ${c+1}`}}),options:f.map(a=>({name:a.name,price:null===a.price?null:String(a.price),stock:null===a.stock_quantity?null:Number(a.stock_quantity)}))}}catch{return null}}},28303:a=>{function b(a){var b=Error("Cannot find module '"+a+"'");throw b.code="MODULE_NOT_FOUND",b}b.keys=()=>[],b.resolve=b,b.id=28303,a.exports=b},35552:(a,b,c)=>{"use strict";c.d(b,{P:()=>e});let d=c(29382).createPool({host:process.env.DB_HOST||"localhost",user:process.env.DB_USER||"root",password:process.env.DB_PASSWORD||"root",database:process.env.DB_NAME||"ansar",waitForConnections:!0,connectionLimit:10,queueLimit:0});async function e(a,b){let[c]=b&&b.length>0?await d.query(a,b):await d.query(a);return c}}};