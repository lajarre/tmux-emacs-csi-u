#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
emacs_bin=${EMACS:-emacs}

tmux_csi_u_batch() {
  "$emacs_bin" -Q --batch -L "$repo_root" -L "$repo_root/script" \
    --eval "(setq load-prefer-newer t)" "$@"
}

tmux_csi_u_gate() {
  TMUX_CSI_U_REPO_ROOT="$repo_root" \
    tmux_csi_u_batch -l "$repo_root/script/gate.el" --funcall "$1"
}
