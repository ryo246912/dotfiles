// Usage: node cdp-watch.mjs <url-prefix> [seconds] [devtools-port]
const [prefix, seconds = '300', port = '9222'] = process.argv.slice(2);
if (!prefix) {
  console.error('usage: node cdp-watch.mjs <url-prefix> [seconds] [devtools-port]');
  process.exit(2);
}

const tabs = await (await fetch(`http://localhost:${port}/json`)).json();
const target = new URL(prefix);
const tab = tabs.find(t => {
  if (t.type !== 'page' || !URL.canParse(t.url)) return false;
  const url = new URL(t.url);
  return url.origin === target.origin && url.pathname.startsWith(target.pathname);
});
if (!tab) {
  console.error(`no tab starts with ${prefix}`);
  process.exit(1);
}

const ws = new WebSocket(tab.webSocketDebuggerUrl);
let id = 0;
const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));
const reqs = new Map();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const isAsset = url => /\/_next\/static|\.(js|css|png|jpe?g|svg|woff2?|ttf|ico)(\?|$)|__nextjs|webpack-hmr/.test(url);

ws.onopen = () => {
  for (const m of ['Network.enable', 'Runtime.enable', 'Log.enable', 'Page.enable']) send(m);
  log('attached', tab.url);
  setTimeout(() => { log('done'); process.exit(0); }, Number(seconds) * 1000);
};
ws.onmessage = ({ data }) => {
  const { method, params } = JSON.parse(data);
  switch (method) {
    case 'Network.requestWillBeSent':
      reqs.set(params.requestId, params.request.url);
      if (!isAsset(params.request.url)) log('REQ', params.request.method, params.request.url.slice(0, 200));
      break;
    case 'Network.responseReceived': {
      const { url, status, headers } = params.response;
      if (!isAsset(url)) log('RES', status, url.slice(0, 200), headers?.location ?? headers?.Location ?? '');
      break;
    }
    case 'Network.responseReceivedExtraInfo':
      for (const c of params.blockedCookies ?? [])
        log('BLOCKED-COOKIE', c.cookie?.name ?? c.cookieLine?.split('=')[0], c.blockedReasons.join(','));
      break;
    case 'Network.loadingFailed':
      log('FAIL', params.errorText, params.blockedReason ?? '', params.corsErrorStatus?.corsError ?? '',
        (reqs.get(params.requestId) ?? '').slice(0, 200));
      break;
    case 'Runtime.consoleAPICalled':
      if (['error', 'warning'].includes(params.type))
        log('CONSOLE', params.type, params.args.map(a => a.value ?? a.description ?? '').join(' ').slice(0, 400));
      break;
    case 'Runtime.exceptionThrown':
      log('EXCEPTION', (params.exceptionDetails.exception?.description ?? params.exceptionDetails.text).slice(0, 400));
      break;
    case 'Log.entryAdded':
      if (params.entry.level !== 'verbose') log('LOG', params.entry.level, params.entry.text.slice(0, 400), params.entry.url ?? '');
      break;
    case 'Page.frameNavigated':
      if (!params.frame.parentId) log('NAV', params.frame.url);
      break;
  }
};
ws.onerror = e => { console.error('ws error', e.message ?? ''); process.exit(1); };
ws.onclose = () => { log('closed'); process.exit(1); };
