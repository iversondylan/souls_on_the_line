# Card and Status Text Rules

## Card Descriptions

### `%s` Placeholders

Card descriptions use `%s` as slots filled left-to-right by each `CardAction`'s `get_description_value()`. Actions that contribute nothing return `""`, leaving the slot invisible in the final string.

**Soul cards** always open with `%s` (the summon action slot):
- `"%s"` — soul with no additional text beyond the summon
- `"%sOn death, ..."` — soul with a triggered ability and no named ongoing status
- `"%s%s: ..."` — soul with a non-numerical named ongoing status; the second `%s` fills to the status name, followed by `: ` and the effect description

**Enchantment cards** use:
- `"Gain %s: effect. Deplete."` — the `%s` fills to the status name if the provided status is non-numerical, otherwise use plain English filling the placeholder with the stacks value provided by the card.

**Convocation/Effusion cards** are plain prose, no leading `%s`.

The `{percent}` token in source text renders as `%` in the final description. Use it anywhere a literal `%` is needed (e.g. `"50{percent} reduced damage"`). Do not write `%%` or a bare `%` in description strings.

### Numerical values

Variable numbers in a description come from a `%s` placeholder, not hardcoded. The action's `get_description_value()` returns the number (e.g. stacks, damage amount).

### Sentence and capitalization rules

- Capitalize the first word of the description string.
- Capitalize after `. ` (new sentence).
- Capitalize after `StatusName: ` (the colon pattern that introduces a status effect — e.g. `"Bequeath: On death, draw %s."`).
- Capitalize after `%s: ` when `%s` resolves to a status name (e.g. `"%s%s: On hit, ..."`).
- Capitalize after `%s` when it is the very first token in the string (e.g. `"%sOn death, ..."`).
- Do **not** capitalize trigger phrases that appear mid-sentence as objects or complements (e.g. `"An ally gains on death: ..."`, `"allies have on death, ..."`).

Trigger phrases ("on death", "on strike", "on hit", "on summon", "on attack", etc.) are ordinary lowercase words, not keywords. Capitalize them only when the rules above require it.

### Permanent HP gain / healing

Use `"increase max health by N and heal that amount"` for permanent HP increases (Full Fortitude). Alternatively `"gain N max health and heal that amount"`. These are interchangeable; pick whichever reads better in context.

### Draw and Deplete

- Draw cards are written `"Draw N."` (capital D, number, period).
- Depleting cards end with `"Deplete."` as a standalone sentence at the end.

### Damage to all enemies / heals

- `"deal N damage to all enemies"` — lowercase, no "the".
- `"heal your most damaged ally N"` or `"heal your most damaged ally for N"`.

### Negation / Absorb

- `"negate the next N hits"` — not "block", not "absorb".

### Stat notation

- Attack and max health bonuses: `+N|+N` (attack/max health), e.g. `"+1|+2"`.
- Damage bonuses inline: `"+N damage"`.

---

## Status Tooltips

### Format

Tooltips from `get_tooltip(stacks)` follow `"StatusName: description."` — the status name as a header, colon, space, then the effect in lowercase prose.

Examples:
- `"Absorb: negate the next N hit(s). Clears at the start of the player's turn."`
- `"Might: deal +N damage."`
- `"Bulwark: take N% less damage until your next turn."`
- `"Bequeath: On death, draw N."`

Non-numerical statuses (no stacks param needed) can use `_stacks` in the signature and ignore it, or describe the effect without a number.

The static `tooltip` field on the `.tres` resource is a short fallback used in the editor and for display contexts that don't call `get_tooltip()`. Keep it in sync with `get_tooltip()` in intent if both exist.

### `numerical` field

- Set `numerical = true` on a status `.tres` when stacks represent a meaningful quantity shown in descriptions (damage amount, hit count, etc.).
- Set `numerical = false` when the status is binary or its stacks are not displayed as a number.
- The default on `Status` is `false`. Always set this field explicitly on every status `.tres`.

### Trigger phrases in tooltips

Same capitalization rules as card descriptions: capitalize at sentence start or after `: `, lowercase mid-sentence.
