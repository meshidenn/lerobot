# ローカルランタイムで SmolVLA 学習を実行する手順

`train_smolvla_airoa_moma_baseline_local.ipynb` を Google Colab のローカルランタイム接続で実行するためのガイドです。

## 前提条件

- サーバー: A100 80GB / CUDA / FFmpeg インストール済み
- [uv](https://docs.astral.sh/uv/) がインストール済み
- サーバーへの SSH 接続が可能
- 以下のトークンを取得済み
  - [Hugging Face トークン](https://huggingface.co/settings/tokens)（`HF_TOKEN`）
  - [W&B API キー](https://wandb.ai/authorize)（`WANDB_API_KEY`）

## 1. サーバー側の準備

### Jupyter サーバーの起動

```bash
cd eval/colab-local-runtime
./scripts/start_jupyter.sh
```

起動すると以下のような URL が表示されます。控えてください。

```
http://localhost:8888/?token=xxxxxxxxxxxxxxxx
```

### FFmpeg の確認

torchcodec がビデオデコードに FFmpeg を使用します。未インストールの場合:

```bash
sudo apt-get update && sudo apt-get install -y ffmpeg
```

## 2. ローカル PC 側の準備

### SSH ポートフォワーディング

```bash
ssh -L 8888:localhost:8888 <ユーザー名>@<サーバー>
```

このターミナルは Colab 使用中は開いたままにしてください。

### Colab からローカルランタイムに接続

1. [Google Colab](https://colab.research.google.com) でノートブックを開く
2. 右上の **「接続」** ボタン横の **▼** をクリック
3. **「ローカル ランタイムに接続」** を選択
4. 手順 1 で控えた URL を貼り付けて **「接続」**

## 3. ノートブックの実行

`train_smolvla_airoa_moma_baseline_local.ipynb` を開き、上から順にセルを実行します。

### セル 1: インストール確認

uv 仮想環境にインストール済みの lerobot / torch のバージョンと GPU 認識を確認します。

### セル 2: トークン入力

セル実行時にパスワード入力欄が表示されます。

1. `HF_TOKEN を入力:` → Hugging Face トークンを貼り付けて Enter
2. `WANDB_API_KEY を入力:` → W&B API キーを貼り付けて Enter

入力内容は画面に表示されません。トークンはメモリ上の環境変数にのみ保持され、サーバーにファイルとして保存されません。

### セル 3: パラメータ設定

学習ハイパーパラメータが定義されています。必要に応じて変更してください。

| パラメータ | デフォルト値 | 説明 |
|-----------|------------|------|
| `STEPS` | 147,233 | 学習ステップ数 |
| `BATCH_SIZE` | 64 | バッチサイズ |
| `SAVE_FREQ` | 50,000 | チェックポイント保存間隔 |

### セル 4: データセットダウンロード

airoa-moma データセットを `/home/llm-user/datadrive/icra_2026_ramen/lerobot_datasets/airoa-moma` にダウンロードします。初回は時間がかかります（約 9.4M フレーム）。2回目以降はスキップされます。

### セル 5: データ前処理

action キーのリネームと不要な特徴量の除去を行います。

### セル 6: 学習実行

学習を開始します。進捗は WandB で確認できます。学習完了後、モデルは Hugging Face Hub にプッシュされます。

## ファイル構成

```
model/sample_code/
├── train_smolvla_airoa_moma_baseline.ipynb        # 元のノートブック（Colab クラウドランタイム用）
├── train_smolvla_airoa_moma_baseline_local.ipynb   # ローカルランタイム用
├── secrets.sample.json                             # トークンファイルのサンプル（参考用）
└── LOCAL_RUNTIME_GUIDE.md                          # 本ファイル
```

## 元のノートブックとの差分

| 項目 | 元（クラウドランタイム） | ローカルランタイム版 |
|------|----------------------|-------------------|
| インストール | `pip install lerobot[smolvla]` | uv 仮想環境にインストール済み（確認のみ） |
| バージョン確認 | `pip show` + 自動修正 | `importlib.metadata`（pip 不要） |
| トークン | `google.colab.userdata` | `getpass` で手動入力 |
| 出力先 | `./outputs/...` | `/home/llm-user/datadrive/icra_2026_ramen/outputs/...` |
| データセット | `/content/...` | `/home/llm-user/datadrive/icra_2026_ramen/lerobot_datasets/...` |
| ライブラリ競合対策 | なし | `LD_PRELOAD` でシステムの libstdc++/libgcc_s を強制ロード |

## トラブルシューティング

### torchcodec が FFmpeg を見つけられない

```
RuntimeError: Could not load libtorchcodec.
```

**原因**: FFmpeg がインストールされていない、またはホームディレクトリ配下の古い C ランタイムライブラリが競合している。

**対処**:
1. `sudo apt-get install -y ffmpeg` で FFmpeg をインストール
2. 学習セルの `LD_PRELOAD` 設定が有効になっていることを確認

### パッケージのバージョン不整合

```bash
cd eval/colab-local-runtime
rm -rf .venv uv.lock
uv sync
```

仮想環境を再構築します。
