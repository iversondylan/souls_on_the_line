[P2] Run checkpointing mirrors the same data twice: once as rich context objects and again as flattened pending_* fields. ShopContext (line 6) and RewardContext (line 10) define the runtime shape, but RunState (line 41) stores parallel serialized fields, and run.gd (line 590) plus run.gd (line 695) manually copy values back and forth. It works, but it creates subsystem-level redundancy: every new shop/reward field has to be added in three places.


# Lifecycle Refactor Notes

Current split:

- `StatusFromOppTurnModel`
- `StatusFromOppTurnUntilMyActionModel`
- `StatusFromOppTurnUntilEndOfMyTurnModel`
- `StatusIntentLifecycleModel`

These four models share the same core behavior:

- resolve a status id from serialized fields
- guard against forecast or missing sim/api state
- apply a self-targeted status on one lifecycle hook
- remove that same self-targeted status on one lifecycle hook
- optionally route through the lifecycle helper with `pending = true/false`

`StabilityUntilMyActionModel` is the nearby special case. It shares the same
shape, but applies and removes the status directly through `ctx.api` instead of
going through `PendingStatusSystem.apply_lifecycle_status()` and
`remove_lifecycle_status()`.

Recommended future pattern:

- introduce one shared configurable status lifecycle implementation
- export status resolution fields:
  - `status`
  - `status_id`
  - `intensity`
  - `duration`
  - `pending`
- export hook configuration for when to apply and when to remove
- export an application mode enum for:
  - direct self apply/remove via `ctx.api`
  - helper-driven apply/remove via `PendingStatusSystem`

Adoption recommendation:

- build the shared implementation first
- then choose between:
  - thin wrapper scripts for readability and lower content churn
  - one generic serialized resource with migrated `.tres` content

Because enemy content already serializes these lifecycle model types, the best
migration path should be chosen separately from the core deduplication work.
