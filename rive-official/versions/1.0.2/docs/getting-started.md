# Getting started

For a person setting the tool up for the first time. Everything after this page
is reference for authoring, most of it written for a coding agent to read.

## Install

```bash
curl -fsSL https://releases.rive.app/cli/install.sh | sh
```

The installer puts the binary in `~/.rive/bin` and prints an `export PATH=...`
line if that directory is not already on your `PATH`. Add it to your shell
profile, or the `rive` command will not be found in a new terminal.

Check it:

```bash
rive --version
rive doctor
```

`doctor` reports the version, whether you are signed in, whether the ports the
watcher needs are free, and whether the current directory is a project.

## Sign in

```bash
rive login
```

Opens a browser to authorise the CLI. You need this for `--publish`, which
signs through the API, for `--rev`, which exports the file a designer opens
in the editor, and for `rive push`. One login covers all three.

Every other project run is local and works signed out *and* offline: watching,
`--once`, `--verify`, `--test`, `--screenshot`, `--serve`.

The standalone commands — `create`, `docs`, `samples`, `schema`, `inspect`,
`doctor` and the rest — need no account either, but not all of them are
offline: `update` fetches release metadata, `whoami` and `doctor` call the
account service. `rive --help` has the full map.

## Make a project

A project is any directory with a `rive.yaml` in it. `rive create` writes one:

```bash
rive create myproject
```

That gives you four files:

| File | What it is |
|---|---|
| `rive.yaml` | project config; only `name` is required |
| `scene.rml` | the scene — an empty artboard, timeline and state machine |
| `AGENTS.md` | instructions a coding agent reads when it opens the folder |
| `.gitignore` | ignores `build/` |

Everything else in the directory is picked up by extension — `.luau` scripts,
`.wgsl` shaders, `.png`/`.jpg` images, fonts, and any other file as a blob.
There is no manifest to maintain. See
[project/rive-yaml.md](project/rive-yaml.md).

## Run it

```bash
rive myproject
```

Opens a window showing the scene and watches the directory. Save any file and
it rebuilds and reloads. The built file lands at `myproject/build/myproject.riv`
— that is the file you ship to a runtime.

A fresh project's scene has nothing drawn in it yet, so what you get is a dark
rectangle. That is the loop working. What it does have is the frame the editor
gives a new file — an artboard, a timeline named `Animation 1`, and a state
machine that plays it on load — so a shape you add and key starts animating
without any further wiring. [skeleton.md](skeleton.md) fills that same frame in
line by line, and `rive samples` has larger scenes.

Type `?` in the terminal while watching for the commands available there
(screenshot, pause, artboard, rev export).

One-shot alternatives, for scripts and CI:

```bash
rive myproject --verify     # compile only, no output, exit 1 on errors
rive myproject --once       # write an unsigned .riv
rive myproject --publish    # write a signed .riv (required for web)
```

Scripts destined for the web must be built with `--publish` — unsigned scripts
are rejected by the CDN and web runtimes. See [publishing.md](publishing.md).

## Then what — hand it to an agent

Authoring a scene means writing RML and Luau, and the CLI is built for a coding
agent to do that: `rive create` drops an `AGENTS.md` in the project telling the
agent how to look things up and how to check its work.

So the intended loop is: create the project, open the folder in your coding
agent, and describe what you want. The agent reads `AGENTS.md`, uses
`rive docs` and `rive schema` to look up types, and runs `rive . --verify` and
`rive inspect . --json` to check what it built. Keep `rive myproject` running in
another terminal and you will watch it happen.

Authoring by hand works too — [skeleton.md](skeleton.md) is a complete file
annotated line by line, and [format.md](format.md) is the shortest path to
understanding RML.

## Start from something that works

```bash
rive samples
```

Opens a picker over the runnable example projects that ship with the CLI,
each a complete project on its own. Up and down move, typing narrows the
list, and enter asks where to copy the one you chose:

```
which sample?
> hello_rive    A script drawing a scene, with an image asset and a shader
  rml_triangle  The smallest RML document: one artboard, one shape
```

Then build it:

```bash
rive myproject
```

Where no picker can draw -- Windows, stdin or stderr not a terminal as in
CI, `TERM=dumb`, or `RIVE_NO_TUI=1` -- the same command lists the samples
instead and you copy one by hand. Redirecting stdout alone is not enough: the picker
draws on stderr, so `rive samples > log` still asks.

```bash
cp -R "$(rive samples --path)/rml_triangle" myproject
```

## Start from an existing Rive file

If you already have a file in the Rive editor, export a `.rev` and convert it:

```bash
rive create demo --from-rev=demo_file.rev
rive demo
```

Scripts, shaders and assets come out as files laid out the way the editor's
Assets panel had them. `rive push` sends changes back. See
[push.md](push.md).

## When something is wrong

- `rive doctor` — environment, auth, ports, project
- `rive <dir> --verify` — does it compile (Luau type errors included)
- `rive inspect <dir> --json` — what actually got built, plus a `problems` list
- [gotchas.md](gotchas.md) — the things that fail silently
