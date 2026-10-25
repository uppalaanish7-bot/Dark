let installPrompt;
const help = document.querySelector('#install-help');
addEventListener('beforeinstallprompt', event => {event.preventDefault();installPrompt=event;});
document.querySelector('#install').addEventListener('click', async () => {
  if(installPrompt){await installPrompt.prompt();await installPrompt.userChoice;installPrompt=null;return;}
  document.querySelector('#install-text').textContent = !isSecureContext
    ? 'Home-screen installation needs an HTTPS website (or localhost on this PC). You can still play in your browser here.'
    : 'On iPhone or iPad, open this site in Safari, then choose Share → Add to Home Screen. On Android, open the browser menu and choose Install app or Add to Home screen. On a PC, use the install icon in Chrome or Edge when available. Wait for “Ready for offline play” before disconnecting.';
  help.showModal();
});
document.querySelector('#close-help').addEventListener('click',()=>help.close());
if('serviceWorker' in navigator && isSecureContext){
  navigator.serviceWorker.register('./sw.js').then(async registration=>{
    const ready = () => {document.querySelector('#offline-status').textContent='Ready for offline play on this device.';};
    if(registration.active) ready();
    registration.addEventListener('updatefound',()=>{
      const worker=registration.installing;
      worker?.addEventListener('statechange',()=>{if(worker.state==='activated')ready();});
    });
  }).catch(()=>{document.querySelector('#offline-status').textContent='Offline download was unavailable. You can still play while connected.';});
}
