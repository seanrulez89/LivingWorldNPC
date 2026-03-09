# LivingWorldNPC SP Skeleton

Single-player only Project Zomboid Build 42 NPC mod skeleton.

This package is intentionally **data-first**:

- Off-screen NPCs exist only as `NPCRecord` data in `ModData`.
- On-screen NPCs are embodied as NPC-flagged `IsoPlayer` actors only inside the activation envelope.
- All high-frequency AI is limited to embodied NPCs.
- Legacy/continuation uses a **snapshot promotion** model.
- Canonical NPC state stays in `ModData`; embodied actors are disposable runtime caches.

Current Build 42 embodiment notes:

- The runtime uses `SurvivorDesc` + `IsoPlayer.new(...)` + `setNPC(true)` rather than `IsoSurvivor`.
- Spawn selection prefers solid, free tiles near the NPC anchor and avoids popping directly onto the player.
- Failure logging records the NPC record, descriptor, actor runtime-core state, and spawn source to `console.txt`.
- Debug mode exposes right-click tools to spawn, delete, and inspect embodied NPC failures during local testing.

The `42/` directory contains the runtime mod files. `common/` is reserved for shared assets.
