# fledge-plugin-matrix

Run a command across multiple configurations in parallel -- fan-out across versions, envs, or targets.

Define one or more variable axes with `--over` and matrix will generate every combination, run them in parallel, and report which passed or failed. Think of it as a local, lightweight version of CI matrix builds.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-matrix
```

## Usage

### Run a command across configurations

```bash
# Test across Rust toolchains
fledge matrix run "cargo test" --over toolchain=stable,nightly

# Test across Python versions
fledge matrix run "python -m pytest" --over python=3.10,3.11,3.12

# Multi-dimensional matrix (2x3 = 6 combinations)
fledge matrix run "npm test" --over node=18,20,22 --over os=linux,darwin

# Variable interpolation in the command string
fledge matrix run "./test.sh {db}" --over db=postgres,sqlite

# Control parallelism and fail-fast
fledge matrix run "make test" --over cc=gcc,clang --parallel 2 --fail-fast
```

### Preview combinations (dry run)

```bash
fledge matrix show --over env=dev,staging,prod --over region=us,eu
# Matrix: 6 combinations
#
#   [1] env=dev region=us
#   [2] env=dev region=eu
#   [3] env=staging region=us
#   [4] env=staging region=eu
#   [5] env=prod region=us
#   [6] env=prod region=eu
```

### Check results of the last run

```bash
fledge matrix status
# Last matrix results (.matrix-results/):
#
#   PASS  toolchain=stable (1234 bytes)
#   FAIL  toolchain=nightly (exit code 1, 5678 bytes)
#
# 1/2 passed
```

## How It Works

Each combination sets environment variables as `MATRIX_<KEY>` (uppercased) and runs the command in a background process. The `{key}` placeholders in the command string are replaced with the corresponding value. Results and logs are written to `.matrix-results/` (or the directory given by `--output`).

### Options

| Flag | Description |
|---|---|
| `--over <key>=<v1,v2,...>` | Define a variable axis (repeatable) |
| `--parallel <n>` | Max parallel jobs (default: 4) |
| `--fail-fast` | Stop all jobs on first failure |
| `--output <dir>` | Directory for logs (default: `.matrix-results`) |

## Lane Integration

Use matrix inside a fledge lane to run compatibility checks as part of a workflow:

```toml
[lanes.compat]
steps = ["matrix run 'cargo test' --over toolchain=stable,nightly"]
```

## Running Tests

```bash
bash tests/run_tests.sh
```
