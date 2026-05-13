# Spark VSS

Spark VSS is an event-ready deployment wrapper for NVIDIA Video Search and Summarization (VSS) on DGX Spark. It runs the VSS `base` profile with both models local to the Spark:

- LLM: `nvidia/NVIDIA-Nemotron-Nano-9B-v2-FP8`
- VLM: `nvidia/cosmos-reason2-8b`
- UI: `http://<spark-ip>:3000`
- Agent API: `http://<spark-ip>:8000`
- VST: `http://<spark-ip>:30888`

This repo is intended for demos where an operator needs a simple start, stop, and restart workflow.

## What This Demo Supports

Use this deployment for:

- Uploading short videos
- Asking natural-language questions about video content
- Generating video analysis reports
- Demonstrating that the LLM and VLM are running locally on DGX Spark

This deployment intentionally uses the VSS `base` profile. The upstream deployment script currently supports `DGX-SPARK` for `base` and `alerts`; `search` and `lvs` need separate Spark validation before they should be used at events.

## Tested Setup

Validated on May 13, 2026 with:

- Host: DGX Spark, NVIDIA GB10
- OS: Ubuntu 24.04.4 LTS, ARM64
- NVIDIA driver: `580.142`
- Docker: `29.2.1`
- Docker Compose: `v5.0.2`
- NGC CLI: `4.10.0`
- Git LFS: `3.4.1`

Keep at least `150GB` free for the first setup. The first pull can use around `100GB` of Docker image/model storage.

## Required Keys

The shell needs:

- `NVIDIA_API_KEY`
- `NGC_CLI_API_KEY` or `NGC_API_KEY`

If the key is named `NGC_API_KEY`, `start.sh` automatically exports it as `NGC_CLI_API_KEY` for the VSS deployment script.

Optional:

- `HF_TOKEN`, only needed for alternate Hugging Face model experiments.

## One-Time Host Bootstrap

SSH to the Spark:

```bash
ssh nvidia@<spark-ip>
```

Install required tools:

```bash
sudo apt-get update
sudo apt-get install -y git git-lfs curl unzip
git lfs install --skip-repo
```

Install NGC CLI locally:

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
curl -L -o /tmp/ngccli_arm64.zip \
  https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/4.10.0/files/ngccli_arm64.zip
unzip -q -o /tmp/ngccli_arm64.zip -d "$HOME/.local/lib"
ln -sfn "$HOME/.local/lib/ngc-cli/ngc" "$HOME/.local/bin/ngc"

grep -q 'HOME/.local/bin' "$HOME/.bashrc" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
ngc --version
```

Expected:

```text
NGC CLI 4.10.0
```

## Clone

```bash
cd "$HOME"
git clone https://github.com/nv-drollins/spark-vss.git
cd "$HOME/spark-vss"
git lfs pull
```

Verify the LFS asset is real and not a pointer file:

```bash
ls -lh agent/3rdparty/ffmpeg/FFmpeg-n8.0.1.tar.gz
```

Expected size is about `16M`. If it is about `133` bytes, run `git lfs pull` again after installing Git LFS.

## Persistent Model Cache

The compose files in this repo bind model caches to the host instead of Docker named volumes. This keeps model downloads across `stop.sh`, `restart.sh`, and `scripts/dev-profile.sh down`.

Default cache root:

```text
$HOME/.cache/nim
```

Model cache directories:

```text
$HOME/.cache/nim/cosmos-reason2-8b
$HOME/.cache/nim/nemotron-nano-9b-v2-fp8
```

The `start.sh` script creates them automatically:

```bash
mkdir -p ~/.cache/nim/cosmos-reason2-8b ~/.cache/nim/nemotron-nano-9b-v2-fp8
chmod -R 777 ~/.cache/nim
```

To use a different disk or cache location, set `NIM_CACHE_ROOT` before starting:

```bash
export NIM_CACHE_ROOT=/mnt/models/nim-cache
./start.sh
```

The relevant compose files use:

```yaml
volumes:
  - ${NIM_CACHE_ROOT:-/home/nvidia/.cache/nim}/cosmos-reason2-8b:/opt/nim/.cache
```

and:

```yaml
volumes:
  - ${NIM_CACHE_ROOT:-/home/nvidia/.cache/nim}/nemotron-nano-9b-v2-fp8:/opt/nim/.cache
```

## Start

From the repo root:

```bash
source "$HOME/.bashrc"
./start.sh
```

On a cold Spark, the first start may take 20 minutes or more while images and models download. Later starts should be much faster because the image layers and model caches are local.

## Verify

Check containers:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Core services should include:

```text
vss-agent                                   Up ... (healthy)
nvidia-nemotron-nano-9b-v2-fp8-shared-gpu  Up ... (healthy)
cosmos-reason2-8b-shared-gpu               Up ... (healthy)
metropolis-vss-ui                          Up ...
```

Check endpoints from the Spark:

```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:30081/v1/models
curl -sS http://localhost:30082/v1/models
curl -sS -I http://localhost:3000 | head
```

Expected highlights:

- Agent health returns `{"value":{"isAlive":true}}`
- LLM models include `nvidia/NVIDIA-Nemotron-Nano-9B-v2-FP8`
- VLM models include `nvidia/cosmos-reason2-8b`
- UI returns `HTTP/1.1 200 OK`

## Open The UI

From a browser on the same event network:

```text
http://<spark-ip>:3000
```

Example:

```text
http://192.168.1.164:3000
```

## Stop

```bash
./stop.sh
```

This stops the VSS compose project and removes `deployments/data-dir`, which is normal VSS behavior. The persistent model caches under `$HOME/.cache/nim` are preserved.

Do not store event videos or other files you need to keep under `deployments/data-dir`.

## Restart

```bash
./restart.sh
```

This runs `stop.sh` and then `start.sh`. Models should remain cached.

## Manual Deployment Command

If you need to bypass the helper scripts, run:

```bash
export NGC_CLI_API_KEY="${NGC_CLI_API_KEY:-$NGC_API_KEY}"
export NIM_CACHE_ROOT="${NIM_CACHE_ROOT:-$HOME/.cache/nim}"
mkdir -p "$NIM_CACHE_ROOT/cosmos-reason2-8b" "$NIM_CACHE_ROOT/nemotron-nano-9b-v2-fp8"
chmod -R 777 "$NIM_CACHE_ROOT"

scripts/dev-profile.sh up -p base \
  --hardware-profile DGX-SPARK \
  --llm nvidia/NVIDIA-Nemotron-Nano-9B-v2-FP8 \
  --vlm nvidia/cosmos-reason2-8b
```

## Demo Prompts

Good first prompts:

```text
What happens in this video? Provide a chronological summary with timestamps.
```

```text
Generate a video analysis report. Include visible people, vehicles, equipment, safety concerns, and timestamped observations.
```

For intersection clips:

```text
Based only on the video, generate a pedestrian safety assessment. Identify whether the pedestrian used the marked crosswalk correctly, describe nearby vehicles, and state any visible safety risks without using or requesting any external traffic simulation tools.
```

For warehouse clips:

```text
Generate a warehouse safety report. Focus on PPE, ladder use, forklift or pedestrian movement, blocked aisles, cones, caution tape, and timestamped safety observations.
```

For bridge clips:

```text
Generate an inspection report for this bridge video. Include visible structural concerns, areas that need human follow-up, and timestamped observations.
```

## Troubleshooting

### `NGC_CLI_API_KEY is required`

If the key is stored as `NGC_API_KEY`, run:

```bash
export NGC_CLI_API_KEY="${NGC_CLI_API_KEY:-$NGC_API_KEY}"
```

### `ngc: command not found`

Install NGC CLI using the bootstrap steps and make sure `$HOME/.local/bin` is on `PATH`.

### Git LFS files are tiny

```bash
sudo apt-get install -y git-lfs
git lfs install --skip-repo
git lfs pull
```

### Models redownload after stop

Check that `NIM_CACHE_ROOT` is set consistently and that these directories exist:

```bash
echo "${NIM_CACHE_ROOT:-$HOME/.cache/nim}"
ls -ld "${NIM_CACHE_ROOT:-$HOME/.cache/nim}"/cosmos-reason2-8b
ls -ld "${NIM_CACHE_ROOT:-$HOME/.cache/nim}"/nemotron-nano-9b-v2-fp8
```

Permissions should allow UID `1000` to write. For event setups:

```bash
chmod -R 777 "${NIM_CACHE_ROOT:-$HOME/.cache/nim}"
```

### Containers are up but models are not ready

Watch logs:

```bash
docker logs -f cosmos-reason2-8b-shared-gpu
docker logs -f nvidia-nemotron-nano-9b-v2-fp8-shared-gpu
```

Wait until both model containers show healthy in `docker ps`.

### UI cannot be reached

Check the Spark IP:

```bash
hostname -I
```

Check the UI port:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep metropolis-vss-ui
```

Then open:

```text
http://<spark-ip>:3000
```

## Notes

This repo is derived from NVIDIA's VSS blueprint implementation and keeps the upstream project layout. The root-level helper scripts are the preferred event operator interface.

