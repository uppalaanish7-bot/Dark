// VERSION is replaced by the package script with a hash of the deployed game.
const CACHE = 'relic-__BUILD_HASH__';
const FILES = ['./','./index.html','./style.css','./site.js','./manifest.webmanifest','./arena.webp','./Rajdhani-SemiBold.ttf','./icons/relic_180.png','./icons/relic_192.png','./icons/relic_512.png','./game.html','./game.js','./game.wasm','./game.pck','./game.audio.worklet.js','./game.audio.position.worklet.js','./credits.txt'];
self.addEventListener('install', event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)).then(()=>self.skipWaiting())));
self.addEventListener('activate', event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('relic-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch', event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  if(url.origin!==self.location.origin || url.pathname.includes('/downloads/'))return;
  event.respondWith(caches.match(event.request,{ignoreSearch:true}).then(cached=>cached || fetch(event.request)));
});
