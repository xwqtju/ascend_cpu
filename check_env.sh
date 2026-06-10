#!/usr/bin/env bash
set -euo pipefail

source /etc/profile.d/ascend.sh

echo "ASCEND_HOME_PATH=${ASCEND_HOME_PATH:-}"
echo "ASCEND_OPP_PATH=${ASCEND_OPP_PATH:-}"
echo "ATB_HOME_PATH=${ATB_HOME_PATH:-}"
echo

command -v atc || true
command -v ascendebug || true
command -v gdb || true
python3 --version
