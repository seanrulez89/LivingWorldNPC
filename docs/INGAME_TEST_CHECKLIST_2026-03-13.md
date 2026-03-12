# In-Game Test Checklist - 2026-03-13

## Goal

Use one evening test pass to decide whether the current LWN architecture is still worth advancing.

## Highest-priority scenarios

### 1. Fresh embodiment visibility

- Spawn a debug NPC near the player.
- Confirm the actor is visibly present immediately after embodiment.
- Confirm no transparent or fully alpha-zero actor appears.

Watch for:

- `createActor.presentation_ready`
- `refreshEmbodiedPresentation.ready`
- `onCreateLivingCharacter.*`
- absence of repeated alpha-repair spam

### 2. Rapid spawn / despawn stability

- Move in and out of embodiment radius several times.
- Confirm the same NPC can embody, despawn, and re-embody without duplicate actors.
- Confirm the context menu only targets the live embodied actor.

Watch for:

- `tryEmbody.*`
- `tryDespawn.*`
- `registerActor.bound`
- `unregisterActor.complete`
- no `stale_registered_actor` context rejections for the active NPC

### 3. Death latch without corpse flicker

- Let an embodied NPC be downed and killed in view.
- Confirm the actor does not repeatedly reappear as a living presentation after death.
- Confirm corpse appearance does not visibly flicker on/off during cleanup.

Watch for:

- `death.latched`
- `death.awaiting_corpse`
- `death.corpse_observed`
- `death_corpse_cleanup` or `death_timeout_cleanup`

### 4. Corpse / reanimation overlap

- After death, stay nearby long enough to see whether a corpse, reanimated zombie, or both appear.
- Confirm LWN no longer deletes the corpse or zombie just because it is cleaning up ownership.
- Confirm the world object is not targetable as a living NPC.

Watch for:

- `leftover.cleanup.preserved`
- context rejection reason `leftover_death_object`
- absence of a live `candidate.accepted` for the dead NPC id

### 5. Delete / remove cleanup contract

- Use the debug delete action on a living embodied NPC.
- Use it again after a death event on another NPC if possible.
- Confirm the record disappears cleanly and the UI closes.

Watch for:

- `CleanupTrace stage=request`
- `record.deactivated`
- `actor.cleanup.*`
- `registry.cleared`
- `record.removed` for delete cases

### 6. Stale target regression check

- Open radial menu, command panel, and dialogue window on a live NPC.
- Walk away, despawn the NPC, or kill/delete it.
- Confirm each UI closes instead of sticking to an invalid actor ref.

Watch for:

- automatic UI close
- no lingering panel/dialogue on deleted or dead NPC

## Pass / fail guidance

### Strong pass

- freshly embodied NPCs are visible
- death does not cause cleanup/corpse thrash
- corpse or reanimated objects persist without being mis-targeted as living NPCs
- UI target references self-heal or close cleanly

### Conditional pass

- living embodiment is stable
- death leaves some roughness, but ownership is clearly separated and no duplicate actor/corpse race remains

### Fail that should trigger carrier reevaluation

- transparent actor remains the dominant outcome
- death still causes actor/corpse duplication or deletion races after this pass
- stale actor refs continue to drive UI or gameplay after cleanup

## Console snippets worth collecting

- all lines containing `createActor.presentation_ready`
- all lines containing `death.latched`
- all lines containing `death.corpse_observed`
- all lines containing `CleanupTrace`
- all lines containing `ContextTrace stage=candidate.rejected`
