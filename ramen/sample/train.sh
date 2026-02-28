#!/bin/bash
# train_smolvla.sh
set -e

# ===== 設定（ここを書き換える） =====
DATASET_REPO_ID="airoa-org/airoa-moma"
DATASET_REVISION="main"
DATASET_ROOT="lerobot_datasets/airoa-moma"  # データセットのローカルパス
POLICY_PATH="lerobot/smolvla_base"

# W&B設定
WANDB_ENTITY="ken05-matuo-llm-88_llm_2025_suzuki"
WANDB_PROJECT="vast_ai"

# 学習ハイパーパラメータ
STEPS=147233
BATCH_SIZE=128
SAVE_FREQ=50000

# 学習済みポリシーをHF Hubにプッシュ
PUSH_TO_HUB=true
POLICY_REPO_ID="ICRA-2026-RAMEN/vast-test-smolvla-airoa-moma"

# カメラ名マッピング（データセット側 → SmolVLA側）
RENAME_MAP='{"observation.image.hand":"observation.images.camera1","observation.image.head":"observation.images.camera2"}'
EMPTY_CAMERAS=1  # SmolVLAは3台想定、データセットが2台の場合1台をダミー補完

# LRスケジュール（STEPSに比例して自動調整）
WARMUP_STEPS=$((STEPS / 30))
if [ $WARMUP_STEPS -lt 100 ]; then WARMUP_STEPS=100; fi
DECAY_STEPS=$STEPS


# ===== 学習実行 =====
uv run lerobot-train \
  --dataset.repo_id=$DATASET_REPO_ID \
  --dataset.revision=$DATASET_REVISION \
  --dataset.root=$DATASET_ROOT \
  --policy.path=$POLICY_PATH \
  --output_dir=./outputs/smolvla_training \
  --job_name=smolvla_training \
  --policy.device=cuda \
  --steps=$STEPS \
  --batch_size=$BATCH_SIZE \
  --save_freq=$SAVE_FREQ \
  --policy.scheduler_warmup_steps=$WARMUP_STEPS \
  --policy.scheduler_decay_steps=$DECAY_STEPS \
  --wandb.enable=true \
  --wandb.entity=$WANDB_ENTITY \
  --wandb.project=$WANDB_PROJECT \
  --rename_map="$RENAME_MAP" \
  --policy.empty_cameras=$EMPTY_CAMERAS \
  --policy.repo_id=$POLICY_REPO_ID \
  --policy.private=true
