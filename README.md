# fledge-plugin-matrix

Run a command across multiple configurations in parallel. Fan-out across versions, environments, or any variable.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-matrix
```

## Usage

```bash
# Test across Rust toolchains
fledge matrix run "cargo test" --over toolchain=stable,nightly

# Test across Python versions
fledge matrix run "python -m pytest" --over python=3.10,3.11,3.12

# Multi-dimensional matrix
fledge matrix run "npm test" --over node=18,20,22 --over os=linux,darwin

# Variable interpolation
fledge matrix run "./test.sh {db}" --over db=postgres,sqlite

# Dry run - show combinations
fledge matrix show --over env=dev,staging --over region=us,eu

# Control parallelism
fledge matrix run "make test" --over cc=gcc,clang --parallel 2 --fail-fast
```

## How It Works

Each combination exports variables as `MATRIX_<KEY>` (uppercased) and runs the command in a background process. Results are logged to `.matrix-results/`.

## Lane Integration

```toml
[lanes.compat]
steps = ["matrix run 'cargo test' --over toolchain=stable,nightly"]
```
