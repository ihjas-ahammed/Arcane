# Missions 2026.10.11 (build 2126101103)

- Floating task button: now visibly dims when idle (contents fade, the disc stays solid) and settles again after dialogs and menus close.
- Floating task button: no longer vanishes on every halt. It stays, paused, for ten minutes, and short state flips can no longer make it flash away and back.
- Floating task button: task state is published atomically and in order, so it never shows half-written or outdated state. Widgets Studio previews no longer hide the button or freeze its clock.
- Floating task button: rebuilds come back docked, a duplicate button is no longer created after a service reconnect, and dragging it away no longer triggers an immediate "Continue" notification. Disabling it now needs a second confirmation, and TalkBack gets halt, check, add and plan actions.
- Taps made while Arcane is still loading are dropped after 15 seconds instead of replaying minutes later, and are never applied twice.
- Desktop Focus Clock: stays on screen and keeps its position when the window is resized, fades when idle, can no longer be dragged off-screen, and is remembered across restarts.
- Fixed "The local database could not be read" on Android caused by the WAL pragma (included since 2026.10.11 build 2126101102).

Still blocked on administrator access to the task-dominion Firebase project: deployment of the reviewed Firebase privacy and Storage rules, and authenticated publication of instant-update metadata. Until the rules are deployed the public database read exposure remains unresolved. See docs/data-hazard-implementation.md.
