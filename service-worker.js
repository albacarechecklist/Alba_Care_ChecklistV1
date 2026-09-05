const CACHE='alba-care-v1';
const ASSETS=['./','./index.html','./styles.css','./app.js','./config.js','./data/checklists.js','./assets/alba-care-logo.jpeg','./manifest.webmanifest'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS))));
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET') return;
  e.respondWith(fetch(e.request).then(r=>{const c=r.clone(); caches.open(CACHE).then(x=>x.put(e.request,c)); return r;}).catch(()=>caches.match(e.request)));
});
