#!/bin/zsh
# Starts the probe through `open`, so the app and not this shell asks for Bluetooth.
# Logs: logs/session-<time>.jsonl (every push raw and decoded), logs/latest-state.json.
cd "${0:A:h}"
[[ -d build/CommanderProbe.app ]] || ./build.sh
open -n build/CommanderProbe.app --args --logs "$PWD/logs"
