// HUD em HTML sobreposto ao canvas (legível e fácil de estilizar).
export class HUD {
  constructor() {
    this.el = {
      hud: document.getElementById('hud'),
      hpFill: document.getElementById('hp-fill'),
      staminaFill: document.getElementById('stamina-fill'),
      amago: document.getElementById('amago-value'),
      lunarIcon: document.getElementById('lunar-icon'),
      lunarName: document.getElementById('lunar-name'),
      players: document.getElementById('players-online'),
      prompt: document.getElementById('prompt'),
      ghostHint: document.getElementById('ghost-hint'),
      death: document.getElementById('death-screen'),
      vignette: document.getElementById('damage-vignette'),
    };
  }

  show() { this.el.hud.classList.remove('hidden'); }

  setHp(hp, max) {
    this.el.hpFill.style.width = `${Math.max(0, (hp / max) * 100)}%`;
  }

  setStamina(st, max) {
    this.el.staminaFill.style.width = `${Math.max(0, (st / max) * 100)}%`;
  }

  setAmago(v) { this.el.amago.textContent = String(v); }

  setLunar(icon, name) {
    this.el.lunarIcon.textContent = icon;
    this.el.lunarName.textContent = name;
  }

  setPlayers(names) {
    this.el.players.innerHTML = names.map(n => `✦ ${escapeHtml(n)}`).join('<br>');
  }

  showPrompt(visible) { this.el.prompt.classList.toggle('hidden', !visible); }
  showGhostHint(visible) { this.el.ghostHint.classList.toggle('hidden', !visible); }
  showDeath(visible) { this.el.death.classList.toggle('hidden', !visible); }

  damageFlash() {
    this.el.vignette.classList.add('flash');
    setTimeout(() => this.el.vignette.classList.remove('flash'), 120);
  }
}

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}
