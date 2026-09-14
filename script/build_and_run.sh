#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
MODE="${1:-run}"
[[ "$MODE" == run || "$MODE" == --verify || "$MODE" == --logs ]] || {
    print -u2 'Usage: script/build_and_run.sh [--verify|--logs]'; exit 2
}
# Use normal termination so a running work session is preserved.
if pgrep -x Clockin >/dev/null; then
    osascript -e 'tell application id "com.ismailakdag.clockin" to quit'
    for attempt in {1..20}; do
        pgrep -x Clockin >/dev/null || break
        sleep 0.25
    done
    if pgrep -x Clockin >/dev/null; then
        print -u2 'Clockin is still running. Finish the open dialog and retry.'; exit 1
    fi
fi
./build-app.sh
/usr/bin/open -n "$PWD/dist/Clockin.app"
if [[ "$MODE" == --verify ]]; then
    sleep 2
    pgrep -x Clockin >/dev/null
    print 'Clockin launched. Inspect the window to verify the UI.'
elif [[ "$MODE" == --logs ]]; then
    /usr/bin/log stream --info --style compact --predicate 'process == "Clockin"'
fi
