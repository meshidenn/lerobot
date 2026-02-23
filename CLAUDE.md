# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Installation (from source)

```bash
pip install -e ".[dev,test]"
# For specific robot/policy extras:
pip install -e ".[smolvla,aloha,pusht]"
```

### Code Quality

```bash
# Install pre-commit hooks (runs ruff, typos, mypy, bandit, etc.)
pre-commit install

# Run all checks manually
pre-commit run --all-files
```

### Tests

```bash
# Ensure test artifacts are available
git lfs install && git lfs pull

# Run all tests
pytest -sv ./tests

# Run a specific test file
pytest -sv tests/test_datasets.py

# Run a single test
pytest -sv tests/test_datasets.py::TestLeRobotDataset::test_load
```

### CLI Entry Points

```bash
lerobot-train --policy=act --dataset.repo_id=lerobot/aloha_sim_transfer_cube_human
lerobot-eval --policy.path=<checkpoint_dir> --env.type=aloha
lerobot-record --robot.type=so100 --dataset.repo_id=<user>/<repo>
lerobot-teleoperate --robot.type=so100
lerobot-calibrate --robot.type=so100
lerobot-dataset-viz --dataset.repo_id=lerobot/aloha_mobile_cabinet
lerobot-info
```

### End-to-End Tests (via Makefile)

```bash
make test-end-to-end          # all policies
make test-act-ete-train DEVICE=cpu
make test-diffusion-ete-train DEVICE=cuda
```

## Architecture

### Package Layout (`src/lerobot/`)

The codebase is structured around four main concerns:

**Hardware Abstraction**
- `robots/` — `Robot` ABC with `connect()`, `disconnect()`, `get_observation()`, `send_action()` interface. Each robot subdir has its own `config.py` and implementation.
- `cameras/` — `Camera` ABC. Backends: OpenCV, RealSense, ZMQ, Reachy2.
- `motors/` — `MotorsBus` ABC. Backends: Feetech, Dynamixel, Damiao.
- `teleoperators/` — `Teleoperator` ABC. Devices: gamepads, keyboards, leader arms, phone.

**Dataset**
- `datasets/lerobot_dataset.py` — Core `LeRobotDataset` class. Format: Parquet files for tabular data + MP4 videos for images. Hub-backed or local storage.
- `datasets/video_utils.py` — Video encoding/decoding via `torchcodec`/`av`. Supports hardware-accelerated encoding.
- `datasets/transforms.py` — Image augmentation pipeline.

**Policies**
- `policies/pretrained.py` — `PreTrainedPolicy(nn.Module)` base class.
- `policies/factory.py` — Builds policies and processor pipelines from config; registers feature mappings from dataset/env.
- Each policy subdirectory (e.g. `policies/act/`, `policies/diffusion/`) contains `configuration_<name>.py` (a `PreTrainedConfig` dataclass) and the model implementation.
- Policy registration uses `draccus.ChoiceRegistry` so `--policy.type=act` selects the right config class.

**Processor Pipeline**
- `processor/` — Stateless transform objects that sit between robot observations and policy inputs (and between policy outputs and robot actions). Key classes: `PolicyProcessorPipeline`, `NormalizeProcessor`, `ObservationProcessor`, `RenameProcessor`, etc.
- The pipeline is constructed by `policies/factory.py` from the policy's `input_features`/`output_features` descriptors.

**Configuration System**
- Uses `draccus` (a dataclass-based CLI parser). Config dataclasses live in `configs/`.
- `configs/train.py` — `TrainPipelineConfig` (dataset, policy, env, optimizer, scheduler, eval settings).
- `configs/policies.py` — `PreTrainedConfig` base; each policy overrides it.
- `configs/default.py` — `DatasetConfig`, `WandBConfig`, `EvalConfig`.
- CLI arguments map to nested config fields: `--policy.type=act`, `--dataset.repo_id=...`, `--policy.dim_model=64`.

**Training & Eval Scripts** (`scripts/`)
- `lerobot_train.py` — Main training loop; saves checkpoints under `outputs/train/<date>/<job>/checkpoints/<step>/pretrained_model/`.
- `lerobot_eval.py` — Rolls out a policy in a sim or real env.
- `lerobot_record.py` — Teleoperation + data collection.

**Async Inference** (`async_inference/`)
- `policy_server.py` / `robot_client.py` — gRPC-based client/server for running inference on a separate machine from the robot. Protobuf definitions in `transport/services.proto`.

**Environments** (`envs/`)
- Wrappers around gymnasium environments (Aloha, PushT, LIBERO, MetaWorld).
- `envs/factory.py` — Constructs vectorized envs from `EnvConfig`.

### Key Conventions

- **All configs are dataclasses** decorated with `@dataclass` and registered via `draccus`.
- **Policy type selection** uses `--policy.type=<name>` which maps to the registered `PreTrainedConfig` subclass.
- **Feature descriptors**: `PolicyFeature(type=FeatureType, shape=(...))` describes every input/output tensor. The processor pipeline is built automatically from these.
- **Linting**: `ruff` (line length 110, double quotes). `mypy` is gradually enabled per module; currently enforced for `configs/`, `cameras/`, `motors/`, `envs/`, `transport/`.
- **Test artifacts** are tracked with git-lfs under `tests/artifacts/`.
