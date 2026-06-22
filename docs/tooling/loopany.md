# Loopany for Storia Mobile

This repo supports using the globally-installed [`loopany`](https://github.com/superdesigndev/loopany) CLI with a Storia-specific workspace.

## What this is for

Use loopany when you want long-running, local agent memory for work connected to `storia-mobile` without changing the repo's existing Pi / Symphony automation.

## What this setup does

- keeps the actual `loopany` install outside this repo
- stores Storia loopany state under `~/.loopany/storia-mobile` by default
- provides a repo-local wrapper at `./bin/loopany-storia.sh`

## Install the global CLI

Follow the upstream install flow:

```bash
git clone https://github.com/superdesigndev/loopany.git ~/loopany-src
curl -fsSL https://bun.sh/install | bash       # if Bun is not yet installed
export PATH="$HOME/.bun/bin:$PATH"
cd ~/loopany-src
bun install
bun link
loopany --version
```

If `loopany` is not found, add this line to `~/.zshrc` and reload your shell:

```bash
export PATH="$HOME/.bun/bin:$PATH"
```

## Initialize the Storia workspace

```bash
./bin/loopany-storia.sh init
```

This creates or updates the Storia-scoped loopany home at:

```text
~/.loopany/storia-mobile
```

## Normal usage

Run upstream loopany commands through the wrapper so the Storia-specific home is applied automatically:

```bash
./bin/loopany-storia.sh --version
./bin/loopany-storia.sh init
```

If you need a different location temporarily, override `LOOPANY_HOME`:

```bash
LOOPANY_HOME=/tmp/storia-loopany ./bin/loopany-storia.sh init
```

## What is not integrated yet

This first pass does **not**:

- modify `.pi` orchestration
- modify `bin/pi-symphony.sh`
- auto-run inside Flutter bootstrap/test flows
- commit loopany runtime state into the repo
