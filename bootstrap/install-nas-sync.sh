#!/usr/bin/env bash
# install-nas-sync.sh - enable the NAS change watcher + push timer on THIS
# machine. Run it on the laptop where you EDIT files (the spare), not on the
# main laptop — the flow is one-way: edits are pushed up here, the main laptop
# pulls them at login (do_backup also pulls before it pushes).
#
#     install-nas-sync.sh            # enable (and start) watcher + timer
#     install-nas-sync.sh --disable  # stop and disable them again
#     install-nas-sync.sh --status   # what is running now
#
# The unit files live in bootstrap/systemd/user/ and are linked into
# ~/.config/systemd/user/ (systemctl link), so the repo stays the single copy.

set -uo pipefail
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_DIR/lib/common.sh"

UNIT_DIR="$BOOTSTRAP_DIR/systemd/user"
ENABLE_UNITS=( nas-watch.service nas-push.timer )   # service comes via the timer

case "${1:-}" in
    --disable)
        systemctl --user disable --now nas-watch.service nas-push.timer 2>/dev/null || true
        info "NAS watcher + push timer disabled on $(hostname -s)."
        exit 0
        ;;
    --status)
        systemctl --user status nas-watch.service nas-push.timer --no-pager 2>&1 | sed -n '1,40p'
        echo
        echo "Recent pushes:"
        [[ -f ${XDG_STATE_HOME:-$HOME/.local/state}/nas-sync/push.log ]] \
            && tail -n 5 "${XDG_STATE_HOME:-$HOME/.local/state}/nas-sync/push.log" \
            || echo "  (none yet)"
        exit 0
        ;;
    -h|--help)
        sed -n '2,/^set /{/^set /d;p}' "$0" | sed 's/^# \{0,1\}//'; exit 0
        ;;
    "") ;;
    *) die "unknown flag: $1 (try --help)" ;;
esac

mkdir -p "$HOME/.config/systemd/user"
require_cmd systemctl "systemd is required for the background watcher."
# Link every unit file into the user manager's search path first: a timer can
# only start its service if the service file is resolvable by name.
for u in "$UNIT_DIR"/*.service "$UNIT_DIR"/*.timer; do
    [[ -e $HOME/.config/systemd/user/$(basename "$u") ]] || systemctl --user link "$u"
done
systemctl --user daemon-reload
systemctl --user enable --now "${ENABLE_UNITS[@]}" || die "could not enable the units"
systemctl --user restart nas-watch.service || die "could not start the watcher"

info "Enabled on $(hostname -s): nas-watch.service + nas-push.timer (every 5 min)."
echo
echo "Next steps:"
echo "  1. Push these scripts (and your other edits) up to the NAS:"
echo "       $BOOTSTRAP_DIR/sync-to-nas.sh --paths bin/bootstrap bin/startup.sh bin/do_backup"
echo "  2. On the main laptop, fetch this directory once, then run the puller:"
echo "       rsync -aiv ~/nas/Home/bin/bootstrap/ ~/bin/bootstrap/"
echo "       rsync -aiv ~/nas/Home/bin/startup.sh ~/bin/startup.sh"
echo "       ~/bin/bootstrap/nas-pending-pull.sh --terminal"
echo "     From then on the startup hook and do_backup guard handle it automatically."
echo
echo "Check status any time with: $BOOTSTRAP_DIR/sync-to-nas.sh --status"
