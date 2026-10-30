// Local build preview only. Production uses Nginx.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const port = Number(process.env.PREVIEW_PORT || 3001);
const types = {'.html':'text/html', '.js':'application/javascript', '.json':'application/json',
  '.wasm':'application/wasm', '.png':'image/png', '.jpg':'image/jpeg', '.jfif':'image/jpeg',
  '.svg':'image/svg+xml', '.css':'text/css', '.ttf':'font/ttf', '.otf':'font/otf'};
http.createServer((req,res)=>{
  if(req.url.startsWith('/api/')) {
    const upstream=http.request({hostname:'127.0.0.1',port:8082,path:req.url,method:req.method,headers:req.headers},
      response=>{res.writeHead(response.statusCode,response.headers);response.pipe(res);});
    upstream.on('error',()=>{res.writeHead(503,{'content-type':'application/json'});res.end('{"message":"API unavailable."}');});
    req.pipe(upstream);
    return;
  }
  let name;
  try { name=decodeURIComponent(new URL(req.url,'http://localhost').pathname); }
  catch {res.writeHead(400);res.end();return;}
  const file=path.resolve(root,'.'+(name==='/'?'/index.html':name));
  if(!file.startsWith(root+path.sep)) {res.writeHead(403);res.end();return;}
  fs.readFile(file,(error,data)=>{
    if(error){res.writeHead(404);res.end();return;}
    res.writeHead(200,{'content-type':types[path.extname(file)]||'application/octet-stream','cache-control':'no-store'});
    res.end(data);
  });
}).listen(port,'127.0.0.1',()=>console.log('Preview: http://localhost:'+port));
