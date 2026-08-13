-- Per-item special instructions (free text, no pricing implications) —
-- a real, currently-working feature the Edge Function was silently
-- dropping. The `extras` system in the Flutter app is keyed by meal names
-- from an older menu that don't match any of the 126 real seeded meals,
-- so it's already dead against the live menu — not ported here.
alter table order_items add column notes text;
