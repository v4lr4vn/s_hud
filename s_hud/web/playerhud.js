// s_hud player HUD — renders hunger/thirst/stamina/armour/IDs from client pushes.
(function () {
    const hud = document.getElementById('player-hud');
    const f = {
        hunger:  document.getElementById('ph-hunger'),
        thirst:  document.getElementById('ph-thirst'),
        stamina: document.getElementById('ph-stamina'),
        armour:  document.getElementById('ph-armour'),
    };
    const armourRow = document.getElementById('ph-armour-row');
    const idEl = document.getElementById('ph-id');
    const clamp = (v) => Math.max(0, Math.min(100, v || 0));

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'hud:pos') {
            hud.style.left = d.x + '%';
            hud.style.top = d.y + '%';
            return;
        }
        if (d.action !== 'hud:player') return;
        if (d.show === false) { hud.classList.add('ph-hidden'); return; }
        hud.classList.remove('ph-hidden');

        f.hunger.style.width = clamp(d.hunger) + '%';
        f.thirst.style.width = clamp(d.thirst) + '%';
        f.stamina.style.width = clamp(d.stamina) + '%';

        if ((d.armour || 0) > 0) {
            armourRow.classList.remove('hidden');
            f.armour.style.width = clamp(d.armour) + '%';
        } else {
            armourRow.classList.add('hidden');
        }

        idEl.textContent = (d.sagaId || '\u2014') + '  \u00B7  ID ' + (d.playerId || 0);
    });
})();
