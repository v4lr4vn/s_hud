# NOTICE

All Lua, HTML, CSS and JS in this resource is original work for the Saga framework.

The minimap **assets** under `stream/` — `minimap.gfx`, `minimap.ytd`,
`squaremap.ytd`, `circlemap.ytd` — are taken from **ps-hud (Project Sloth)**,
licensed under **GPL-3.0**. The replacement `minimap.gfx` is what removes GTA's
native health/armour ring: those arcs are drawn inside the minimap Scaleform, so
no native HUD call can hide them — only swapping the `.gfx` works.

The square/circle reshaping ("Dalrae's solve") is the standard community method.

If you redistribute this resource, keep this notice and comply with GPL-3.0 for
the bundled assets, or replace them with your own minimap `.gfx`/`.ytd`.

IMPORTANT: streamed minimap assets only take effect after a full server restart
and client rejoin (clear client cache once). Live-restarting the resource will
NOT swap an already-loaded minimap.
