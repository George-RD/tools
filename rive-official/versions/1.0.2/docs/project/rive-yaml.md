# Projects and `rive.yaml`

A project is a directory containing a `rive.yaml`. Everything else in it is
bundled by file extension:

| Extension | Becomes |
|---|---|
| `.luau` | scripts — protocol scripts and importable modules |
| `.wgsl` | shaders, compiled to RSTB |
| `.rml` | the scene, in as many files as you like, compiled as one document |
| `.png` `.jpg` `.jpeg` `.webp` | image assets |
| anything else | a blob asset, findable by name from scripts |

**The table is how sources are *discovered*, not a promise that everything in
the directory ends up in the `.riv`.** Assets are embedded when something
references them — a `file=` in the RML, or a `context:image` / blob lookup by
name from a script. A stray `notes.txt`, a font nothing uses, or the generator
script that wrote your scene adds nothing to the output, so `exclude` is for
keeping the *scan* tidy (and for keeping a second `.rml` from being picked up),
not for keeping weight out of the file.

Only `name` is required:

```yaml
name: myproject
```

`rive create <dir>` writes a `rive.yaml` with `name` taken from the directory
and log paths under `build/`, plus a `scene.rml` holding an empty artboard,
timeline and state machine, `AGENTS.md`, and a `.gitignore` for `build/`.
Existing files are left alone.

## Starting from an editor file

```bash
rive create demo --from-rev=demo_file.rev    # or omit demo: the .rev's name is used
rive demo
```

`--from-rev` converts an editor `.rev` into a project: `scene.rml` with every
script, shader and asset written as a file and referenced with `file=`, then
the usual scaffold. Files land where the Assets panel had them — the folder
tree in the editor becomes the directory tree on disk:

    Assets panel                demo/
      main                        rive.yaml
      ui/                         scene.rml
        button                    main.luau
      images/                     ui/button.luau
        logo                      images/logo.png
      fonts/                      fonts/Inter.ttf
        Inter

Scripts keep working because a script's path *is* its module path: the editor's
`require('ui/button')` resolves to `ui/button.luau`. The directory must be empty
or new — the conversion writes a tree it cannot check file by file, so it never
merges into one.

The result is an ordinary project: `.luau` and `.wgsl` compile,
`png`/`jpg`/`jpeg`/`webp` are images, and fonts, svg, audio and other binaries
are blobs — still referenced correctly through `file=`, just not typed by the
scanner. Editor-only state (collaboration cursors, diff history) is dropped;
hosted fonts with no embedded bytes stay unresolved, as in any hand-written rml.

## Full shape

```yaml
name: myproject
main: main

artboard:
  width: 800
  height: 600
  background: "#1D1D1D"      # quote it -- a bare # starts a YAML comment

artboards:
  main:
    width: 1920
    height: 1080

exclude:
  - docs

excludeFromRev:
  scripts:
    - "*_test"
  artboards:
    - tests/*
  assets:
    - raw_*
  contents:
    - logo

libraries:
  - ../shared_widgets

revFlavor: editable          # or "library"

push:
  projectId: 9
  fileId: 512

window:                      # macOS only; other desktops ignore the block
  titleBar: integrated       # or "standard" (default)
  controls:                  # traffic-light position, points from the top-left
    x: 16
    y: 19
  dragHeight: 52             # the strip a press drags the window from

output:
  dir: build

logs:
  file: build/rive.log
  problems: build/problems.log
```

## Keys

**`name`** — required. Also the name other projects use to import this one.

**`main`** — which artboard is the file's default, by name. Without it, the
first artboard declared wins in an RML project, and the first layout script
alphabetically in a script-only one. A name that matches no artboard fails the
build.

**`debugLevel`**, **`optimizationLevel`** — the editor's publish levels for
scripts, `none`, `medium` or `max`; defaults `none` and `max`.

**`shaderOutputs`** — the shader backends compiled on publish, a list from
`msl`, `glsl`, `wgsl`, `hlsl`, `spirv`; default all of them. These three and
`main` are what the editor keeps on the file's Backboard, which a fragment
never declares; `create --from-rev` writes them here from a rev.

**`artboard`** — default size and background for generated artboards. Applies
only when there is no `.rml`; RML artboards carry their own dimensions.
`background` must be quoted.

**`artboards`** — per-artboard overrides, keyed by name.

**`exclude`** — paths not to bundle at all.

**`excludeFromRev`** — drops matching things from the exported `.rev` only. The
`.riv` and the live window always contain everything. Four categories:

- `scripts` — by module path, Luau and WGSL
- `artboards` — by name
- `assets` — by name
- `contents` — asset *bytes*, keeping the asset referenced but unembedded

Patterns support `*` (any run of characters, including `/`) and `?` (one
character). Excluding a layout script also drops its generated artboard.

**`libraries`** — other project directories whose modules become importable
under their project name:

```luau
local button = require('lib:shared_widgets/button')
```

Dependencies resolve transitively, diamonds are shared, cycles are an error.
Each library also exports its own `.rev` alongside the project's.

**`revFlavor`** — `editable` (default) or `library`. Controls whether the
exported `.rev` opens as a normal editor file or as a library others import.

**`push`** — the Rive file `rive push` updates. Written back automatically by
the first push (`projectId` picks where the file is created, `fileId` binds
later pushes to it); edit or remove it to retarget.

**`window`** — how the live window on macOS frames the scene. Every other
desktop keeps its ordinary frame and ignores the block; `--screenshot` and the
other headless runs never open a window and ignore it too.

- `titleBar` — `standard` (default) keeps the usual title bar strip above the
  scene. `integrated` draws the scene across the whole window, under the
  native close, minimize and zoom controls, with no strip of its own: the
  artboard is laid out to the full window height and the title text is
  hidden. The controls stay native, so their hover, accessibility and
  full-screen behaviour is the system's. Edits to the block apply to the
  running window on the next build, like any other edit.
- `controls` — where the native controls sit, `x` and `y` in points from the
  window's top-left corner. Only read with `titleBar: integrated`; leave the
  block out for the stock placement. AppKit offers no supported way to move
  them, so the tool moves the real buttons and re-applies the position after
  every layout the system does (resize, full screen, key window changes). A
  `y` deeper than the stock strip grows the strip to keep the buttons inside
  it, which is how a 52pt header gets its controls centred with `y: 19`.
- `dragHeight` — the strip along the top, in points, where a press on nothing
  interactive drags the window; a double click there zooms (or whatever the
  system title bar double-click setting says). Anything the scene would
  answer a press with keeps it: a listener target, a text input, the box of a
  scripted layout with pointer handlers (scripts receive every pointer event
  and must bounds-check themselves, as [protocols.md](../luau/protocols.md)
  says; only their box is reserved). Left out, the strip is the one the native
  controls occupy, so nothing changes below it. Zero turns dragging off.

The scene learns where the chrome is through two view model numbers on the
artboard's bound instance, written by the tool whenever it declares them and
kept across hot reloads: `titleBarHeight`, the strip's height, and
`titleBarControlsWidth`, how far in from the left edge the native controls
reach. Both are in points, which under the default layout fit are artboard
units, and both read zero in full screen, where the controls hide. Bind a
header's height and a spacer's width to them and the layout keeps its title
clear of the traffic lights on every macOS. The
[integrated_titlebar](../../samples/integrated_titlebar) sample is the
worked example: `rive "$(rive samples --path)/integrated_titlebar"`.

**`output.dir`** — where the `.riv` is written. Defaults to `build`.

**`logs.file`** — append-only interleave of compiler problems, script `print`
output and system messages.

**`logs.problems`** — rewritten atomically per build with a generation header,
so it always reflects exactly one build. This is the file to read when
scripting around the tool.

## Layout on disk

Nothing is enforced beyond `rive.yaml` being at the root. A conventional
project:

```
myproject/
  rive.yaml
  scene.rml
  main.luau
  mathutil.luau
  mathutil_test.luau
  Montserrat.ttf
  logo.png
  build/
```

Asset paths in RML are project-relative:

```xml
<FontAsset file="Montserrat.ttf" name="Montserrat" id="0:30"/>
<ScriptAsset file="main.luau" name="main" id="0:80"/>
```

## Commands

```bash
rive create <dir>                 # scaffold yaml, scene.rml, AGENTS.md, .gitignore
rive create <dir> --from-rev=f.rev  # the same, but scene.rml and its files come from an editor .rev
rive <dir> --once                 # build once, exit non-zero on errors
rive <dir> --test                 # build, run every Tests script, exit non-zero on failures
rive <dir> --once --rev=out.rev   # also export an editor .rev
rive inspect <dir> --json         # dump the built scene and any ignored input
rive <dir> --artboard=<name>      # choose the artboard shown on launch
rive <dir> --optimize             # compile scripts at Luau O2 instead of O1
```

A directory literally named `create` or `login` must be passed as `./create`
or `./login`, so it is not read as the subcommand.
