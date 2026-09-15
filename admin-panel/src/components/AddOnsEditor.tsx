import { useCallback, useEffect, useState } from "react";
import { toast } from "react-toastify";
import { ArrowDown, ArrowUp, Plus, Trash2, X } from "lucide-react";
import { supabase } from "../lib/supabase";

/**
 * Edits one dish's add-ons and requests — "Extra Shito +$1.99", "No Coleslaw".
 *
 * They belong to the dish, not to one option: Jollof's list is shared by all
 * of its proteins, which is why this opens from any of them. The website reads
 * them from meal_modifiers and the server prices orders from there, so a price
 * changed here is what the next customer pays.
 *
 * Nothing is written until Save; Cancel discards everything. Switching one
 * off hides it from customers without deleting it — for the day the kitchen
 * runs out of tilapia. Past orders keep the name and price they were sold at,
 * so editing or deleting here never rewrites an order.
 */

type Kind = "extra" | "request";

interface Row {
  /** Stable React key, for new rows too. */
  key: string;
  /** Set for rows already in the database. */
  id?: string;
  name: string;
  /** As typed, so a half-typed "3." isn't rewritten under the cursor. */
  price: string;
  kind: Kind;
  hideWhenVegetarian: boolean;
  active: boolean;
}

interface DbRow {
  id: string;
  name: string;
  price: number | string;
  kind: Kind;
  hide_when_vegetarian: boolean;
  active: boolean;
  position: number;
}

const GROUPS: { kind: Kind; title: string; example: string }[] = [
  { kind: "extra", title: "Extras", example: "Extra Shito" },
  { kind: "request", title: "Preferences", example: "No Shito" },
];

let seq = 0;
const newKey = () => `new-${++seq}`;

export default function AddOnsEditor({
  baseSlug,
  dishName,
  optionCount,
  onClose,
  onSaved,
}: {
  baseSlug: string;
  dishName: string;
  optionCount: number;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [rows, setRows] = useState<Row[]>([]);
  const [original, setOriginal] = useState<DbRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from("meal_modifiers")
      .select("id, name, price, kind, hide_when_vegetarian, active, position")
      .eq("base_slug", baseSlug)
      .order("position");
    if (error) toast.error("Could not load add-ons");
    const list = (data ?? []) as DbRow[];
    setOriginal(list);
    setRows(
      list.map((m) => ({
        key: m.id,
        id: m.id,
        name: m.name,
        price: Number(m.price).toFixed(2),
        kind: m.kind,
        hideWhenVegetarian: m.hide_when_vegetarian,
        active: m.active,
      }))
    );
    setLoading(false);
  }, [baseSlug]);

  useEffect(() => {
    load();
  }, [load]);

  const update = (key: string, patch: Partial<Row>) =>
    setRows((rs) => rs.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  const remove = (key: string) => setRows((rs) => rs.filter((r) => r.key !== key));
  const add = (kind: Kind) =>
    setRows((rs) => [
      ...rs,
      { key: newKey(), name: "", price: kind === "extra" ? "" : "0.00", kind, hideWhenVegetarian: false, active: true },
    ]);
  // Within its own group. The groups are fixed: extras first, as customers see them.
  const move = (key: string, dir: -1 | 1) =>
    setRows((rs) => {
      const row = rs.find((r) => r.key === key);
      if (!row) return rs;
      const group = rs.filter((r) => r.kind === row.kind);
      const other = group[group.indexOf(row) + dir];
      if (!other) return rs;
      return rs.map((r) => (r.key === row.key ? other : r.key === other.key ? row : r));
    });

  const problem = (() => {
    const seen = new Set<string>();
    for (const r of rows) {
      const name = r.name.trim();
      if (!name) return "Every add-on needs a name.";
      if (seen.has(name.toLowerCase())) return `"${name}" is listed twice.`;
      seen.add(name.toLowerCase());
      const price = Number(r.price);
      if (r.price.trim() === "" || !Number.isFinite(price) || price < 0) return `Check the price for "${name}".`;
    }
    return null;
  })();

  const save = async () => {
    if (problem) {
      toast.error(problem);
      return;
    }
    setSaving(true);
    try {
      const ordered = [...rows.filter((r) => r.kind === "extra"), ...rows.filter((r) => r.kind === "request")];
      const values = (r: Row, index: number) => ({
        name: r.name.trim(),
        price: Math.round(Number(r.price) * 100) / 100,
        kind: r.kind,
        hide_when_vegetarian: r.hideWhenVegetarian,
        active: r.active,
        position: index + 1,
      });

      // Deletes first, so an add-on removed and re-added under the same name
      // doesn't collide with itself on the one-name-per-dish rule.
      const kept = new Set(rows.map((r) => r.id).filter(Boolean));
      const gone = original.filter((m) => !kept.has(m.id)).map((m) => m.id);
      if (gone.length) {
        const { data, error } = await supabase.from("meal_modifiers").delete().in("id", gone).select("id");
        if (error) throw error;
        // Row-level security refuses silently — no error, nothing deleted.
        if ((data ?? []).length !== gone.length) throw new Error("delete not permitted");
      }

      const before = new Map(original.map((m) => [m.id, m]));
      for (const [index, r] of ordered.entries()) {
        const was = r.id ? before.get(r.id) : undefined;
        if (!r.id || !was) continue;
        const v = values(r, index);
        const changed =
          v.name !== was.name ||
          v.price !== Number(was.price) ||
          v.kind !== was.kind ||
          v.hide_when_vegetarian !== was.hide_when_vegetarian ||
          v.active !== was.active ||
          v.position !== was.position;
        if (!changed) continue;
        const { data, error } = await supabase.from("meal_modifiers").update(v).eq("id", r.id).select("id");
        if (error) throw error;
        if (!data?.length) throw new Error("update not permitted");
      }

      const fresh = ordered
        .map((r, index) => ({ r, index }))
        .filter(({ r }) => !r.id)
        .map(({ r, index }) => ({ ...values(r, index), base_slug: baseSlug }));
      if (fresh.length) {
        const { error } = await supabase.from("meal_modifiers").insert(fresh);
        if (error) throw error;
      }

      toast.success("Add-ons saved");
      onSaved();
      onClose();
    } catch (err) {
      console.error("Add-ons save failed:", err);
      const code = (err as { code?: string }).code;
      toast.error(code === "23505" ? "Two add-ons can't share a name." : "Could not save add-ons");
      // Part of the save may have gone through; show what is really stored.
      onSaved();
      await load();
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm p-4"
      role="dialog"
      aria-modal="true"
      aria-label={`Add-ons for ${dishName}`}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl border border-gray-200 max-h-[90vh] flex flex-col">
        <div className="flex items-start justify-between gap-4 px-6 py-5 border-b border-gray-200">
          <div className="min-w-0">
            <h2 className="text-xl font-bold text-gray-900 truncate">Add-ons · {dishName}</h2>
            {optionCount > 1 && <p className="text-sm text-gray-500 mt-1">Shared by all {optionCount} options</p>}
          </div>
          <button onClick={onClose} aria-label="Close" className="text-gray-400 hover:text-gray-600 transition-colors">
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-5 space-y-6">
          {loading ? (
            <div className="flex justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
          ) : (
            GROUPS.map((g) => {
              const list = rows.filter((r) => r.kind === g.kind);
              return (
                <section key={g.kind} aria-label={g.title}>
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-wide">{g.title}</h3>
                    <button
                      onClick={() => add(g.kind)}
                      className="inline-flex items-center gap-1 text-sm font-medium text-blue-600 hover:text-blue-800"
                    >
                      <Plus className="w-4 h-4" />
                      Add
                    </button>
                  </div>
                  {list.length === 0 ? (
                    <p className="text-sm text-gray-400 py-2">None</p>
                  ) : (
                    <ul className="space-y-2">
                      {list.map((r, i) => (
                        <li
                          key={r.key}
                          data-addon-row
                          className={`rounded-lg border border-gray-200 p-3 ${r.active ? "bg-white" : "bg-gray-50"}`}
                        >
                          <div className="flex flex-wrap items-center gap-2">
                            <input
                              value={r.name}
                              onChange={(e) => update(r.key, { name: e.target.value })}
                              placeholder={g.example}
                              aria-label="Name"
                              autoFocus={!r.id}
                              className={`flex-1 min-w-[10rem] px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                r.active ? "text-gray-900" : "text-gray-400"
                              }`}
                            />
                            <div className="relative w-28">
                              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">$</span>
                              <input
                                type="number"
                                inputMode="decimal"
                                step="0.01"
                                min="0"
                                value={r.price}
                                onChange={(e) => update(r.key, { price: e.target.value })}
                                placeholder="0.00"
                                aria-label="Price"
                                className="w-full pl-6 pr-2 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                              />
                            </div>
                          </div>
                          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-gray-700">
                            <label className="inline-flex items-center gap-2 cursor-pointer">
                              <input
                                type="checkbox"
                                checked={r.active}
                                onChange={(e) => update(r.key, { active: e.target.checked })}
                                className="rounded border-gray-300"
                              />
                              On
                            </label>
                            <label className="inline-flex items-center gap-2 cursor-pointer">
                              <input
                                type="checkbox"
                                checked={r.hideWhenVegetarian}
                                onChange={(e) => update(r.key, { hideWhenVegetarian: e.target.checked })}
                                className="rounded border-gray-300"
                              />
                              Not on vegetarian
                            </label>
                            <select
                              value={r.kind}
                              onChange={(e) => update(r.key, { kind: e.target.value as Kind })}
                              aria-label="Group"
                              className="px-2 py-1 border border-gray-300 rounded-lg bg-white"
                            >
                              {GROUPS.map((o) => (
                                <option key={o.kind} value={o.kind}>{o.title}</option>
                              ))}
                            </select>
                            <span className="ml-auto inline-flex items-center gap-1">
                              <button
                                onClick={() => move(r.key, -1)}
                                disabled={i === 0}
                                aria-label="Move up"
                                className="p-1.5 rounded hover:bg-gray-100 disabled:opacity-30"
                              >
                                <ArrowUp className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => move(r.key, 1)}
                                disabled={i === list.length - 1}
                                aria-label="Move down"
                                className="p-1.5 rounded hover:bg-gray-100 disabled:opacity-30"
                              >
                                <ArrowDown className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => remove(r.key)}
                                aria-label={`Delete ${r.name || "add-on"}`}
                                className="p-1.5 rounded text-red-600 hover:bg-red-50"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </span>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>
              );
            })
          )}
        </div>

        <div className="flex justify-end gap-3 px-6 py-4 border-t border-gray-200">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={save}
            disabled={saving || loading}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
          >
            {saving && <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>}
            {saving ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
