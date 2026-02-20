#!/usr/bin/env bash
set -Eeuo pipefail

: "${INPUT_TIME:?Missing input: timelimit}"
: "${INPUT_COMMAND:?Missing input: command}"
: "${INPUT_SIGNAL:=TERM}"
: "${INPUT_KILL_AFTER:=30s}"
: "${INPUT_WORKING_DIRECTORY:=}"
: "${INPUT_QUIET:=false}"

quiet=0
case "${INPUT_QUIET}" in
  true|TRUE|True|1) quiet=1 ;;
esac

log() { (( quiet )) || echo "$@" >&2; }

# Pick timeout binary
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  echo "ERROR: Neither 'timeout' nor 'gtimeout' found. On macOS: set install-coreutils: true or run: brew install coreutils" >&2
  exit 2
fi

# Move to working directory if provided
if [[ -n "${INPUT_WORKING_DIRECTORY}" ]]; then
  cd "${INPUT_WORKING_DIRECTORY}"
fi

# Write the user commands to a temp script (multiline supported)
cmdfile="${RUNNER_TEMP:-/tmp}/run-bash-command-cmd.sh"
cat >"$cmdfile" <<'HEADER'
#!/usr/bin/env bash
set -Eeuo pipefail
HEADER
printf '%s\n' "${INPUT_COMMAND}" >>"$cmdfile"
chmod +x "$cmdfile"

log "run-bash-command: using ${TIMEOUT_BIN}, limit=${INPUT_TIME}, signal=${INPUT_SIGNAL}, kill-after=${INPUT_KILL_AFTER}"

set +e
"$TIMEOUT_BIN" \
  --signal="${INPUT_SIGNAL}" \
  --kill-after="${INPUT_KILL_AFTER}" \
  "${INPUT_TIME}" \
  bash "$cmdfile"
rc=$?
set -e

# Outputs (always emit)
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "exit_code=${rc}" >>"$GITHUB_OUTPUT"
fi

# coreutils: 124 indicates timeout
if [[ $rc -eq 124 ]]; then
  log "run-bash-command: time limit reached -> treating as SUCCESS (exit 0)."
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "timed_out=true" >>"$GITHUB_OUTPUT"
  fi
  exit 0
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "timed_out=false" >>"$GITHUB_OUTPUT"
fi

exit "$rc"
