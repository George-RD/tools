# Assets

An asset is anything that comes from a file rather than from markup: images,
fonts, audio, scripts, shaders, arbitrary data. This page is the model — the
per-type detail lives with the feature that uses it.

## Every file in the project is an asset

You do not register files. The build scans the project directory and classifies
each one by extension:

| Extension | Becomes | Declared in RML? |
|---|---|---|
| `.luau` | script | **no** — a `ScriptAsset` is created for you |
| `.wgsl` | shader | **no** — a `ShaderAsset` is created for you |
| `.png` `.jpg` `.jpeg` `.webp` | image | yes, `<ImageAsset file="…">` |
| `.rml` | markup | n/a |
| **anything else** | **blob** | yes, `<BlobAsset file="…">` |

`rive.yaml`, `.riv`, `.rev` and `.log` are skipped.

Two things follow that are worth holding on to. **Scripts and shaders need no
markup at all** — dropping a `.luau` or `.wgsl` file in is the whole step.
And **there is no unrecognised-file error**: a `.ttf`, a `.json`, a `.csv` and a
typo'd filename all land in the blob bucket without complaint.

## Three ways an asset gets its bytes

**Scanned.** Scripts and shaders, above. The file is compiled and embedded.

**By `file=`.** Everything else. The path is relative to the project directory
and the bytes are embedded into the built file. It may leave the project
(`file="../../assets/fonts/Inter.ttf"` for a folder several projects share),
with one cost: the watcher only sees the project directory, so a change to a
shared file needs a manual rebuild. A file that is missing, empty, or an
unfetched Git LFS pointer is a build error, not an asset with no bytes.

> `file` is an RML authoring attribute rather than a core property, so
> **`rive schema` never lists it** — on `FontAsset`, `ImageAsset` or any other.
> It is valid on all of them regardless. This is the one place where "look the
> name up rather than guessing" does not work.

```xml
<ImageAsset file="logo.png" name="logo" id="0:60"/>
```

Because they are embedded, the `.riv` is self-contained — and building it
**redistributes** whatever you embed, which matters for fonts.

**Not at all.** Omit `file` and the asset ships as a named, contentless
reference for the host application to satisfy at load time through its
runtime's asset-handler API. Nothing in this toolchain can render that, so the
preview shows nothing. See [text.md](text.md#shipping-without-embedding).

> A `file` that is not on disk is reported **nowhere** — it builds clean,
> `problems` is empty, and whatever used it renders as nothing. This is the
> worst silent failure in the format; see
> [gotchas.md](gotchas.md#a-missing-asset-file-reports-nothing-at-all).

## What references what

Assets are root elements. Something in the scene names them:

| Asset | Referenced by |
|---|---|
| `ImageAsset` | `Image.assetId` — see [drawing.md](drawing.md#images) |
| `FontAsset` | `TextStylePaint.fontAssetId` — see [text.md](text.md#fonts) |
| `AudioAsset` | `AudioEvent.assetId` |
| `ScriptAsset` | `Scripted*.scriptAssetId`, or nothing in a script-only project |
| `ShaderAsset` | **nothing in RML** — reached from Luau by name |
| `BlobAsset` | **nothing in RML** — reached from Luau by name |

## How an image is sampled

Three properties on `ImageAsset` control sampling, and they ship with the file:

| Property | Values |
|---|---|
| `samplerFilter` | `0` bilinear *(default)*, `1` nearest |
| `samplerWrapX` | `0` clamp *(default)*, `1` repeat, `2` mirror |
| `samplerWrapY` | same as `samplerWrapX` |

They are raw numbers — the names above are not accepted.

```xml
<ImageAsset file="tiles.png" samplerFilter="1" samplerWrapX="1" samplerWrapY="1"
            name="tiles" id="0:60"/>
```

`samplerFilter="1"` is what keeps pixel art crisp; the default bilinear blurs it
at any scale other than 1:1. The wrap modes matter when something samples
outside the image — a tiling texture wants `repeat`, and `clamp` smears the edge
pixel instead.

The other properties you will see on an `ImageAsset` — `format`, `quality`,
`mips`, `astcBlockSize` — are editor and backend encoding settings, marked
editor-only and stripped on export. Setting them here does nothing.

## Shaders

A `.wgsl` file is compiled and registered under its name. No RML property points
at a shader; a script fetches one from its `Context`:

```luau
local shader = context:shader('wave')
```

The name is the asset name — the filename without its extension, namespaced by
folder. **The lookup is by string and unvalidated**, so a typo returns `nil`
rather than failing the build. Check the result before using it.

From there the shader goes into a `GPUPipeline`; the drawing side is in
[luau/api/gpu.md](luau/api/gpu.md).

## Blobs

Any file the build does not recognise becomes a blob, which is how arbitrary
data ships alongside a scene — a JSON table, a binary lookup, level data:

```luau
local levels = context:blob('levels')
```

Same name-based, unvalidated lookup as shaders. `Blob.data` gives you a
`buffer`.

If you meant a file to be an image or a font and mistyped the extension, it
becomes a blob silently and the thing that wanted it renders nothing.

## Audio

> **Only the watch player makes a sound.** The CLI is built
> `with_rive_audio=system`, so audio works — but a device is opened only in
> watch mode, the one mode with a window someone is sitting in front of. Every
> other mode (`--once`, `--verify`, `--test`, `--screenshot`, `--publish`,
> `--headless-serve`) sets `RIVE_NO_AUDIO_DEVICE`, because opening a CoreAudio
> device buys a screenshot nothing and can stall a CI VM for minutes.
>
> **`--screenshot` is silent, not stubbed**, and it is the only headless mode
> that is. It builds a player, so assets decode, `context:audio()` returns an
> `AudioSource`, and `Audio.play()` returns a real `AudioSound`: the engine is
> created with miniaudio's `noDevice`, which is deaf but working.
>
> **The other modes never build a player at all**, so none of that applies to
> them. `--once`, `--verify` and `--publish` share one branch that builds the
> file and exits. `--test` runs its scripts against a standalone scripting
> context over a `NoOpFactory`, which leaves the tools-build `isPlaying` flag
> false — so `Audio.play()` returns `nil` — and gives the harness no file to
> resolve `context:audio()` against. Audio is not assertable from a test script
> today.
>
> An `AudioEvent` fired from a state machine logs a line — `sound ding:
> triggered`, or which check stopped it (`muted`, `did not decode`) — so most
> of that path is verifiable without hearing it. `triggered` means the player
> found nothing wrong, not that a sound was created; it is handed the event
> before the runtime plays it. `Audio.play()` from a script reports no event
> and logs nothing at all. Whether the right sound fired at the right moment is
> still a listening test: run `rive .` and use your ears.
>
> The **first** sound in a watch session opens the audio device, on the main
> thread, inside the advance — a few dropped frames, once per process. That is
> deliberate rather than an oversight: nothing pre-warms the engine here
> because nothing pre-warms it in the runtimes either. rive-ios and
> rive-android only ever call `AudioEngine::RuntimeEngine(false)`, the peek,
> and let the first sound create it. If this is ever worth fixing, it is worth
> fixing in the runtime where every host gains, not in one player.

Pausing the player (**Cmd+P**, or `pause` at the prompt) mutes audio started by
a script, because `Audio.play()` is gated on the scripting context's playing
flag. It does not mute an `AudioEvent` — that path has no such gate — but a
paused scene does not advance, so a state machine cannot fire one anyway.

An `AudioAsset` plays when an `AudioEvent` fires, so audio is driven from a
state machine like any other event:

```xml
<AudioAsset file="click.wav" name="click" id="0:70"/>
```

`volume` on the asset scales every instance. `AudioAssetClip` is the trimmed
form. Scripts can reach audio directly with `context:audio(name)`.

**WAV is not the only format**, despite the example and despite
`AudioAsset::fileExtension()` answering `"wav"`. Decoding is miniaudio's, which
is built here with its WAV, MP3 and FLAC decoders all compiled in — an
`<AudioAsset file="voice.mp3">` decodes and plays. The extension is not
inspected; the bytes are.

## Organising them

`AssetGroup` is an asset-panel folder, and `folderPath` on a script or shader
sets both its folder and the namespace its name is registered under. Neither
affects the built output — they are for keeping a large project navigable in
the editor.

`folderPath` does change the name a script is imported by: with
`folderPath="widgets"`, a script named `button` is `require('widgets/button')`.
A script that exists to be imported rather than to implement a protocol should
also carry `isModule="true"`, and must be declared **before** anything that
requires it — see [luau/protocols.md](luau/protocols.md#modules).

## PSD layers

A `LayeredAsset` names a PSD file and holds one `LayerImageAsset` per layer;
`Image` drawables reference the layers by id. The build decodes each layer
straight from the PSD in the project directory and bakes it as a plain
image, the way the editor exports them. 8-bit RGB documents with raw or RLE
channels — what design tools write — decode; anything else logs which layers
will not render and the build continues. A layer is matched by its authored
`layer` number (one past the PSD's bottom-first record index) and confirmed
by name, so a reordered PSD still resolves by layer name.

## Not supported here

Two asset types exist in the format but are marked editor-only and are
**stripped on export**, so authoring them from RML produces nothing:

| Type | What it is | Do instead |
|---|---|---|
| `SVGAsset` | an imported SVG | convert to shapes and author them as RML |
| `LottieAsset` | an imported Lottie | as above |

SVG and Lottie are converted to real Rive objects on import — the asset only
retains the source for re-importing. That path does not exist in this tool, so
the conversion has to happen before you get here.

## Checking your work

`inspect` does not report the `file` attribute, so the tree cannot tell you
whether a file is present. Check the source against the disk:

```bash
grep -oh 'file="[^"]*"' *.rml | sed 's/file="//;s/"//' \
  | while read -r f; do [ -e "$f" ] || echo "MISSING: $f"; done
```

And confirm the references resolve — an `assetId` pointing at nothing is
equally silent:

```bash
rive inspect . --json | jq -c '[..|objects|select(.assetId!=null)|{type,assetId}]'
```

This only covers assets referenced **from the RML**, because `assetId` is what
it looks for. An image, shader or blob reached from a script by name
(`context:image('backdrop')`) carries no `assetId` anywhere in the tree, so it
is invisible to this check whether or not the file exists. For those, the
missing-file loop above is the only readback.
