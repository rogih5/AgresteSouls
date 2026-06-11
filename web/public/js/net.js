// Conexão WebSocket com o servidor co-op.
export class Net {
  constructor() {
    this.ws = null;
    this.handlers = new Map();   // tipo de mensagem -> callback
    this.connected = false;
  }

  connect() {
    return new Promise((resolve, reject) => {
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      this.ws = new WebSocket(`${proto}://${location.host}`);
      this.ws.onopen = () => { this.connected = true; resolve(); };
      this.ws.onerror = (e) => reject(e);
      this.ws.onclose = () => {
        this.connected = false;
        const h = this.handlers.get('_closed');
        if (h) h({});
      };
      this.ws.onmessage = (ev) => {
        let msg;
        try { msg = JSON.parse(ev.data); } catch { return; }
        const h = this.handlers.get(msg.t);
        if (h) h(msg);
      };
    });
  }

  on(type, fn) { this.handlers.set(type, fn); }

  send(msg) {
    if (this.connected && this.ws.readyState === 1) {
      this.ws.send(JSON.stringify(msg));
    }
  }
}
