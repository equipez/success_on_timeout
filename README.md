# run-bash-command

Run one or more commands with a time limit in GitHub Actions. If the command **times out**, this action **treats it as success** (exits `0`). If the command **fails before** the time limit, the action **fails** with the command’s exit code.

This is useful for long-running stress tests where “ran long enough without crashing” is considered a pass.

**Vibe-coded, use at your own risk!!!**

## Why this exists

GitHub-hosted runners have a hard job timeout (commonly 6 hours). When the runner kills a job for timeout, the workflow is marked failed and cannot be “fixed” afterward. The practical approach is to end the long-running command **before** the job limit and convert “timeout reached” into a successful outcome.

## How it works

Internally, this action runs your commands via GNU `timeout`:

- On **Linux**: uses `timeout`
- On **macOS**: uses `gtimeout` (from Homebrew `coreutils`)

GNU `timeout` returns exit code **124** when the time limit is reached; this action converts that case into overall success (`exit 0`) and sets an output flag.

---

## Usage

```yaml
- name: Conduct the test; treat timeout as SUCCESS (exit 0)
  uses: equipez/run-bash-command@v1
  with:
    timelimit: 350m
    command: |
      command1
      command2 argA argB
      ./mycommand a b c
```

### Using outputs

```yaml
- name: Run stress test (timeout => success)
  id: stress
  uses: equipez/run-bash-command@v1
  with:
    timelimit: 350m
    command: |
      ./stress-test --big

- name: Report
  run: |
    echo "timed_out=${{ steps.stress.outputs.timed_out }}"
    echo "exit_code=${{ steps.stress.outputs.exit_code }}"
```

---

## Inputs

| Name | Required | Default | Description |
|---|---:|---|---|
| `timelimit` | yes | — | Time limit passed to `(g)timeout` (e.g. `300s`, `45m`, `2h`). |
| `command` | yes | — | Command(s) to run. Multiline supported. |
| `signal` | no | `TERM` | Signal sent when the time limit is reached. |
| `kill-after` | no | `30s` | Wait time before sending `SIGKILL` after `signal`. |
| `working-directory` | no | `""` | Working directory to run the command(s) in. |
| `install-coreutils` | no | `true` | On macOS, install Homebrew `coreutils` to provide `gtimeout` if missing. |
| `quiet` | no | `false` | If `true`, reduces log output. |

---

## Outputs

| Name | Description |
|---|---|
| `timed_out` | `true` if the command hit the time limit (and was treated as success), else `false`. |
| `exit_code` | The underlying command’s exit code (note: `124` typically means timeout for GNU `timeout`). |

---

## Examples

### 1) Treat “ran 30 minutes” as pass, but fail on real errors

```yaml
- uses: equipez/run-bash-command@v1
  with:
    timelimit: 30m
    command: |
      ./run-long-test-suite
```

- If `./run-long-test-suite` exits `0` within 30 minutes → success.
- If it exits nonzero within 30 minutes → failure.
- If it’s still running at 30 minutes → terminated and treated as success.

### 2) Use a different signal first

Some processes prefer `INT` (Ctrl+C) or `HUP` for graceful shutdown:

```yaml
- uses: equipez/run-bash-command@v1
  with:
    timelimit: 50m
    signal: INT
    kill-after: 20s
    command: |
      ./myserver --run-load-test
```

### 3) Set a working directory

```yaml
- uses: equipez/run-bash-command@v1
  with:
    timelimit: 20m
    working-directory: matlab/tests
    command: |
      ./run_tests.sh
```

---

## macOS note (coreutils / gtimeout)

On `macos-latest`, GNU `timeout` is not available by default. This action can install it automatically via:

- `brew install coreutils` → provides `gtimeout`

By default, `install-coreutils: true` on macOS.

If you set `install-coreutils: false`, ensure `gtimeout` is already available on the runner.

---

## Important notes & limitations

- **GitHub-hosted runner hard limit still applies.** Choose `timelimit` with a buffer below your job’s `timeout-minutes` and below GitHub’s platform limit.
- **This action requires Bash and `(g)timeout`.** It is intended for `ubuntu-latest` and `macos-latest` runners.
- **Timeout is treated as success by design.** Only use this when “time limit reached without crashing” is an acceptable success criterion.
- **Exit code semantics:** GNU `timeout` uses `124` for timeouts. If your wrapped command itself returns `124`, it will be indistinguishable from a timeout in this action’s current design.

---

## License

See `LICENSE.txt`.
