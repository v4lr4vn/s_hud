// s_hud editor — drag movable HUD panels and report positions back to Lua.
(function () {
    const overlay = document.getElementById('overlay');
    const boxesEl = document.getElementById('boxes');
    let boxes = {};   // id -> { el, x, y, w, h, dx, dy }

    function post(name, data) {
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }
    // FiveM injects this; guard for safety in plain browsers
    if (typeof GetParentResourceName === 'undefined') {
        window.GetParentResourceName = () => 's_hud';
    }

    function clamp(v, min, max) { return Math.min(Math.max(v, min), max); }

    function place(b) {
        b.el.style.left = b.x + '%';
        b.el.style.top = b.y + '%';
    }

    function makeBox(e) {
        const el = document.createElement('div');
        el.className = 'hud-box';
        el.style.width = e.w + 'px';
        el.style.height = e.h + 'px';
        const lbl = document.createElement('div');
        lbl.className = 'lbl';
        lbl.textContent = e.label;
        el.appendChild(lbl);
        boxesEl.appendChild(el);

        const b = { el, x: e.x, y: e.y, w: e.w, h: e.h, dx: e.dx, dy: e.dy };
        boxes[e.id] = b;
        place(b);

        let dragging = false, grabX = 0, grabY = 0;
        el.addEventListener('mousedown', (ev) => {
            dragging = true;
            const r = el.getBoundingClientRect();
            grabX = ev.clientX - r.left;
            grabY = ev.clientY - r.top;
            ev.preventDefault();
        });
        window.addEventListener('mousemove', (ev) => {
            if (!dragging) return;
            const maxX = 100 - (b.w / window.innerWidth) * 100;
            const maxY = 100 - (b.h / window.innerHeight) * 100;
            b.x = clamp(((ev.clientX - grabX) / window.innerWidth) * 100, 0, maxX);
            b.y = clamp(((ev.clientY - grabY) / window.innerHeight) * 100, 0, maxY);
            place(b);
        });
        window.addEventListener('mouseup', () => { dragging = false; });
    }

    function open(elements) {
        boxesEl.innerHTML = '';
        boxes = {};
        elements.forEach(makeBox);
        overlay.classList.remove('hidden');
    }

    function close() { overlay.classList.add('hidden'); }

    function save() {
        const layout = {};
        for (const id in boxes) layout[id] = { x: boxes[id].x, y: boxes[id].y };
        post('hud:save', { layout });
        close();
    }

    function resetAll() {
        for (const id in boxes) {
            const b = boxes[id];
            b.x = b.dx; b.y = b.dy;
            place(b);
        }
    }

    function cancel() { post('hud:close', {}); close(); }

    document.getElementById('btn-save').addEventListener('click', save);
    document.getElementById('btn-reset').addEventListener('click', resetAll);
    document.getElementById('btn-cancel').addEventListener('click', cancel);
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape') cancel(); });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'hud:edit') open(d.elements || []);
    });
})();
