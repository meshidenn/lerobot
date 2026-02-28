import json, os, glob
import pyarrow.parquet as pq

DATASET_ROOT = "lerobot_datasets/airoa-moma"
ACTION_SOURCE = "action.absolute"
KEEP_FEATURES = {
    "action", "observation.state",
    "observation.image.hand", "observation.image.head",
    "episode_index", "frame_index", "timestamp",
    "next.done", "index", "task_index",
}

# --- info.json ---
info_path = os.path.join(DATASET_ROOT, "meta", "info.json")
with open(info_path) as f:
    info = json.load(f)
features = info["features"]
if ACTION_SOURCE in features:
    features["action"] = features.pop(ACTION_SOURCE)
dropped = [k for k in list(features) if k not in KEEP_FEATURES]
for k in dropped:
    del features[k]
info["features"] = features
with open(info_path, "w") as f:
    json.dump(info, f, indent=4)
print(f"info.json: kept {len(features)}, dropped {len(dropped)}")

# --- stats.json ---
stats_path = os.path.join(DATASET_ROOT, "meta", "stats.json")
if os.path.exists(stats_path):
    with open(stats_path) as f:
        stats = json.load(f)
    if ACTION_SOURCE in stats:
        stats["action"] = stats.pop(ACTION_SOURCE)
    for k in [k for k in stats if k not in KEEP_FEATURES]:
        del stats[k]
    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=4)

# --- Parquet ---
keep_parquet = {k for k in features if features[k].get("dtype") != "video"}
parquet_files = sorted(glob.glob(
    os.path.join(DATASET_ROOT, "data", "**", "*.parquet"), recursive=True
))
print(f"Updating {len(parquet_files)} parquet files ...")
for pf in parquet_files:
    table = pq.read_table(pf)
    if ACTION_SOURCE in table.column_names:
        table = table.rename_columns(
            ["action" if c == ACTION_SOURCE else c for c in table.column_names]
        )
    table = table.drop([c for c in table.column_names if c not in keep_parquet])
    pq.write_table(table, pf)
print("Done")