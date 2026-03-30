import React, { useState, useEffect } from "react";

const DEFAULTS = {
  waterLow: 20,
  waterHigh: 85,
  phLow: 6.8,
  phHigh: 8.0,
  tempLow: 18,
  tempHigh: 30,
};

export default function SettingsModal({ open, onClose, onSave }) {
  const [vals, setVals] = useState(DEFAULTS);

  useEffect(() => {
    if (!open) return;
    try {
      const saved = JSON.parse(localStorage.getItem("aq-thresholds"));
      if (saved) setVals({ ...DEFAULTS, ...saved });
    } catch (e) {
      /* ignore */
    }
  }, [open]);

  function save() {
    localStorage.setItem("aq-thresholds", JSON.stringify(vals));
    onSave && onSave(vals);
    onClose && onClose();
  }

  if (!open) return null;
  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow p-6 w-96">
        <h3 className="text-lg font-medium mb-4">Threshold Settings</h3>
        <div className="space-y-3 text-sm">
          <div>
            <div className="text-xs text-slate-500">Water Low</div>
            <input
              type="number"
              value={vals.waterLow}
              onChange={(e) =>
                setVals({ ...vals, waterLow: Number(e.target.value) })
              }
              className="w-full mt-1 p-2 border rounded"
            />
          </div>
          <div>
            <div className="text-xs text-slate-500">Water High</div>
            <input
              type="number"
              value={vals.waterHigh}
              onChange={(e) =>
                setVals({ ...vals, waterHigh: Number(e.target.value) })
              }
              className="w-full mt-1 p-2 border rounded"
            />
          </div>
          <div className="grid grid-cols-2 gap-2">
            <div>
              <div className="text-xs text-slate-500">pH Low</div>
              <input
                type="number"
                step="0.1"
                value={vals.phLow}
                onChange={(e) =>
                  setVals({ ...vals, phLow: Number(e.target.value) })
                }
                className="w-full mt-1 p-2 border rounded"
              />
            </div>
            <div>
              <div className="text-xs text-slate-500">pH High</div>
              <input
                type="number"
                step="0.1"
                value={vals.phHigh}
                onChange={(e) =>
                  setVals({ ...vals, phHigh: Number(e.target.value) })
                }
                className="w-full mt-1 p-2 border rounded"
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <div>
              <div className="text-xs text-slate-500">Temp Low</div>
              <input
                type="number"
                value={vals.tempLow}
                onChange={(e) =>
                  setVals({ ...vals, tempLow: Number(e.target.value) })
                }
                className="w-full mt-1 p-2 border rounded"
              />
            </div>
            <div>
              <div className="text-xs text-slate-500">Temp High</div>
              <input
                type="number"
                value={vals.tempHigh}
                onChange={(e) =>
                  setVals({ ...vals, tempHigh: Number(e.target.value) })
                }
                className="w-full mt-1 p-2 border rounded"
              />
            </div>
          </div>
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <button onClick={onClose} className="px-3 py-2 rounded border">
            Cancel
          </button>
          <button
            onClick={save}
            className="px-3 py-2 rounded bg-sky-600 text-white"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
