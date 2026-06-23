#!/usr/bin/env bash
# Stage 3 (VGGT-Omega backend) — counterpart to 3_megasam.sh.
# Produces results/init/vslam/raw_mega_priors/<seq>.npz from VGGT-Omega instead of MegaSAM.
# Runs in the sam3d-objects conda env (torch 2.5.1 + numpy<2 + VGGT-Omega deps already present).
#set -eo pipefail

cd ../prep/MogeSAM

ROOT="$1"
DATA_PATH="${ROOT%/}_videos"          # same convention as 3_megasam.sh

DIRS=("$DATA_PATH"/*)                  # each entry is a video file (.mp4)
NUM_DIRS=${#DIRS[@]}

VGGT_PY="${VGGT_PY:-/home/ubuntu/miniconda3/envs/sam3d-objects/bin/python}"

GPU_COUNT=$(nvidia-smi -L | wc -l)
GPU_IDS=($(seq 0 $((GPU_COUNT-1))))

worker() {
    local gpu_id="$1"; shift
    local files=("$@")
    for vid in "${files[@]}"; do
        # only process video files (skip stray dirs)
        case "$vid" in
            *.mp4|*.avi|*.mov|*.webm) ;;
            *) echo "→ skip non-video $vid"; continue ;;
        esac
        echo "→ GPU $gpu_id │ $vid"
        CUDA_VISIBLE_DEVICES="$gpu_id" \
        "$VGGT_PY" vggt_omega_infer.py --input_path "$vid"
    done
}

for gpu_id in "${GPU_IDS[@]}"; do
    gpu_files=()
    for (( idx=gpu_id; idx<NUM_DIRS; idx+=GPU_COUNT )); do
        gpu_files+=("${DIRS[idx]}")
    done
    worker "$gpu_id" "${gpu_files[@]}" &
done

wait
echo "🏁  VGGT-Omega depth/camera stage finished."
