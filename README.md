# s_hud

A custom HUD manager replacing the native GTA HUD with a movable, persistent UI layer
that any other Saga resource can register elements into.

## Function

s_hud hides the native HUD entirely and renders a custom replacement, while exposing an
opt-in registration system so any other resource (needs, wyrd, inventory, etc.) can add
its own movable UI element without s_hud needing to know anything about it in advance.

## Key Features

- Opt-in element registration via `TriggerEvent('s_hud:register', ...)`, so resources
  remain fully decoupled from s_hud's internals
- Load-order independence: an `s_hud:ready` event allows any resource to (re)register
  its elements regardless of which resource started first
- Native HUD component hiding via a tight loop calling `HideHudComponentThisFrame`
- Custom square or circular minimap replacement with correct aspect ratio handling
- Per-player UI position persistence using KVPs, with no database round-trip required
- Drag-to-reposition editor mode for customising HUD layout

## Security Updates

- **Position save clamping added.** The `hud:save` NUI callback now clamps both the
  x and y coordinates to a 0–100 range before writing to KVP storage. Previously an
  unvalidated or corrupted value could place a HUD element permanently off-screen with
  no way to recover it without manually clearing the KVP.

## Dependencies

`s_lib` (used internally for utility functions). No hard dependency on `s_core`, making
s_hud usable as a lightweight standalone UI layer if needed.
