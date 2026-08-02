#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
CURRENT="$TEST_ROOT/current"
DESTINATION="$TEST_ROOT/destination"
FAKE_BIN="$TEST_ROOT/bin"
mkdir -p "$CURRENT/sub" "$FAKE_BIN"
printf 'important\n' > "$CURRENT/sub/data.txt"

cat > "$FAKE_BIN/docker" <<EOF
#!/usr/bin/env bash
[[ -z \${PCPREP_TEST_DOCKER_CALLS:-} ]] || echo invoked >> "\$PCPREP_TEST_DOCKER_CALLS"
if [[ \$1 == info ]]; then printf '%s\\n' '$CURRENT'; exit 0; fi
exit 1
EOF
cat > "$FAKE_BIN/rsync" <<'EOF'
#!/usr/bin/env bash
echo "rsync invoked" >> "${PCPREP_TEST_EVENTS:?}"
exit 0
EOF
cat > "$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ ${PCPREP_TEST_DOCKER_RUNNING:-1} == 1 ]]
EOF
chmod +x "$FAKE_BIN/docker" "$FAKE_BIN/rsync" "$FAKE_BIN/pgrep"

export PCPREP_TEST_EVENTS="$TEST_ROOT/events"
before=$(find "$TEST_ROOT" -mindepth 1 -printf '%P|%y|%s\n' | sort)
PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/docker-move-data.sh" "$DESTINATION" --dry-run >/dev/null
after=$(find "$TEST_ROOT" -mindepth 1 -printf '%P|%y|%s\n' | sort)
[[ $before == "$after" ]]
[[ ! -e $DESTINATION && ! -e $PCPREP_TEST_EVENTS ]]

# A stopped rootless daemon must not be socket-activated just to preview. The
# configured/default data root is inspected directly and Docker is never run.
ROOTLESS_HOME="$TEST_ROOT/rootless-home"
ROOTLESS_DATA="$TEST_ROOT/rootless-data"
mkdir -p "$ROOTLESS_HOME" "$ROOTLESS_DATA/docker"
PCPREP_TEST_DOCKER_RUNNING=0 \
PCPREP_TEST_DOCKER_CALLS="$TEST_ROOT/docker-calls" \
HOME="$ROOTLESS_HOME" XDG_DATA_HOME="$ROOTLESS_DATA" XDG_CONFIG_HOME="$TEST_ROOT/rootless-config" \
PATH="$FAKE_BIN:$PATH" \
  bash "$SCRIPT_DIR/docker-move-data.sh" "$TEST_ROOT/rootless-destination" --rootless --dry-run >/dev/null
[[ ! -e $TEST_ROOT/docker-calls && ! -e $TEST_ROOT/rootless-destination ]]

if PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/docker-move-data.sh" "$CURRENT/nested" --dry-run >/dev/null 2>&1; then
  echo "containment check accepted destination inside source" >&2
  exit 1
fi

echo "docker-move-data dry-run tests passed"
