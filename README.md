# LivingWorldNPC SP Skeleton

Single-player only Project Zomboid Build 42 NPC mod skeleton.

This package is intentionally **data-first**:

- Off-screen NPCs exist only as `NPCRecord` data in `ModData`.
- On-screen NPCs are embodied as `IsoSurvivor` only inside the activation envelope.
- All high-frequency AI is limited to embodied NPCs.
- Legacy/continuation uses a **snapshot promotion** model.

The `42/` directory contains the runtime mod files. `common/` is reserved for shared assets.
