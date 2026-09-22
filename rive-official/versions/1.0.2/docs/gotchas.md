# Things that fail quietly

Ordered by how often they waste time. Everything here **compiles cleanly** —
that is what makes it expensive. A zero exit code means no name was misspelled;
it does not mean the file does what you asked.

## What the compiler does catch

Names are checked. A misspelled element or attribute is a build error with a
suggestion, so you never have to guess whether a name landed:

```
unknown element <Rect>; did you mean <Rectangle>?
Rectangle has no property "radius"; did you mean "cornerRadiusTL"?
ArtboardProvider is abstract and cannot be authored as an element
```

Everything below is the opposite: every name is real, and the wiring is wrong.
Those are only visible through `rive inspect`.

## Enum values are the exception

Enums *are* validated. An unrecognised name is a real error listing the accepted
values. So prefer symbolic names over integers — it is the one place a typo gets
caught for you.

```xml
<LayoutComponentStyle layoutWidthScaleType="fill"/>   <!-- checked -->
<LayoutComponentStyle layoutWidthScaleType="1"/>      <!-- equivalent, unchecked -->
```

## Rotation is radians, sizes are frames

Two unit traps in the same construct:

- `rotation` (propertyKey 15) is **radians**. A full turn is `6.2831855`. Writing
  `360` spins fifty-seven times.
- `LinearAnimation.duration` is **frames**, with `fps` defaulting to 60. Two
  seconds is `duration="120"`.
- `StateTransition.duration`, confusingly, is **milliseconds**.

## The keyframe type has to match the property

`KeyFrameDouble` only writes `double` properties. Point one at a colour, a
boolean or a reference and it builds clean, inspects clean, and never writes the
value — the property holds still while the timeline runs.

```xml
<KeyedProperty propertyKey="37">                  <!-- SolidColor.colorValue -->
    <KeyFrameDouble value="123" frame="0"/>       <!-- silently does nothing -->
    <KeyFrameColor value="FFE0573C" frame="0"/>   <!-- correct -->
</KeyedProperty>
```

**Detect:** `rive schema SolidColor` gives the property's type; match it against
the table in [format.md](format.md#the-keyframe-type-must-match-the-property).

## Bind the property that exists on the target

`width` lives on `Rectangle`, not on the enclosing `Shape`.

```xml
<Shape>
    <DataBindContext propertyKey="20"/>      <!-- Shape has no width; does nothing -->
    <Rectangle>
        <DataBindContext propertyKey="20"/>  <!-- correct -->
    </Rectangle>
</Shape>
```

**Detect:** `rive schema Shape` — if the property is not listed, the bind is dead.

## Dangling bind paths compile

A `sourcePathIds` naming a view model property that does not exist loads, runs,
and does nothing. This is common enough that real editor-exported files contain
it.

**Detect:** `rive inspect . --json` resolves the paths and flags unresolved ones.

## Bind paths you author here are absolute

`sourcePathIds` starts at a view model id and walks property ids. Bind the
deepest concrete property directly rather than expecting context to be
inherited.

**The format does have a relative form. This toolchain cannot author it**, and
the flag that turns it on is accepted without complaint, which is the trap.

Setting `nameBased="true"` on a `DataBindContext` changes what `sourcePathIds`
*means*: instead of a chain of ids it becomes a **single index** into a table of
names, which the runtime resolves against whatever instance is bound at the
time. That is the point of it — a component bound by name accepts any view model
with a matching shape, rather than the one view model it was authored against.
It is what the editor writes when a file is set to create relative binds, so
files that arrive from there are full of it.

The table it indexes is a `ManifestAsset`: a small binary blob — a list of
names, then a list of paths built from those name ids — that the editor's
exporter produces. Nothing in this toolchain generates one.

So a hand-written `nameBased="true"` builds clean and then does nothing: there
is no manifest, the index resolves to no path, and the bind is inert with the
target left at its authored value.

**And `problems` cannot help you here.** It walks `sourcePathIds` as ids whether
the flag is set or not, so on a name-based bind its verdict is meaningless in
both directions — a clean report on a bind that will never resolve, or an
`unresolved-bind-path` on one that would have.

**Detect:** the flag is visible even though the path is not.

```bash
rive inspect . --json | jq -c '[..|objects|select((.type//"")=="DataBindContext")
                               |select(((((.flags//0)/16)|floor)%2)==1)|.propertyKey]'
```

Anything it returns is a name-based bind. In a project you wrote, that is a
mistake — drop the flag and spell the path out. In one converted with
`rive create --from-rev` it came from the editor, and the manifest should have
come with it as a separate asset file beside your scene; that path is untested
here, so check the binds actually drive something before building on it.

## Layer boilerplate is mandatory

Every `StateMachineLayer` needs `AnyState`, `ExitState` **and** `EntryState`,
even when unused. Missing any of the three and the layer does not import.

An `EntryState` with no `StateTransition` inside means nothing ever starts.

## A listener's input type and inputs must be nested, not referenced

A `ListenerInputType*` belongs inside its `StateMachineListener`, and a
`KeyboardInput`/`GamepadInput`/`SemanticInput` inside its input type; the
nesting is the link, and there is no attribute to spell it otherwise:

```xml
<StateMachineListener targetId="0:2" name="Bound">
    <ListenerInputTypeViewModel viewModelPathIds="0:14-0:24" listenerTypeValue="11"/>
    <ListenerViewModelChange bindablePropertyId="0:60"/>
</StateMachineListener>
```

Older files, and projects converted before this landed, have these as
root-level siblings with a `listenerId` / `targetId` pointing back. That still
compiles, but a root-level `KeyboardInput` never reaches the `.riv`, and an
input type with no inputs matches **every** key — the listener fires on
everything with nothing in the log. Regenerate with `rive create --from-rev`,
or nest by hand.

Same rule for script inputs: a `ScriptInput*` is an input by being a child of
its `Scripted*` object, see
[luau/protocols.md](luau/protocols.md#an-input-is-a-custom-property). If a
construct is not in the tables in [format.md](format.md), assume it needs an
explicit id.

## A style with no link does nothing

`LayoutComponentStyle` carries every flex property, but only applies if the
`LayoutComponent` names it:

```xml
<LayoutComponent styleId="0:11">          <!-- required -->
    <LayoutComponentStyle id="0:11"/>
</LayoutComponent>
```

Same shape for text: a `TextValueRun` with no `styleId`, or a `TextStylePaint`
with no `Fill` child, renders nothing.

## Script inputs match by name, silently

`ScriptInput*` objects bind to a script's `Input<T>` fields **by name**, checked
by neither side. A rename on either half falls back to the field's default.

```xml
<ScriptInputNumber propertyValue="3" name="speed"/>
```

```luau
type Spin = { speed: Input<number> }   -- must match exactly
```

**Nothing detects this.** `inspect` does not read Luau, so a `ScriptInput*`
whose name matches no field inspects completely clean — the script silently
keeps its default and the scene's value is discarded.

**Detect:** compare the two lists yourself.

```bash
grep -oh 'ScriptInput[A-Za-z]*[^>]*name="[^"]*"' *.rml | sed 's/.*name="//;s/"//' | sort -u > /tmp/scene-inputs
grep -oh '^\s*[a-zA-Z_]*\s*:\s*Input<' *.luau | sed 's/[[:space:]]*//;s/:.*//' | sort -u > /tmp/script-inputs
diff /tmp/scene-inputs /tmp/script-inputs
```

Anything that appears on one side only is a broken input.

## Names are checked by the editor, not the CLI

View model, property and enum names are validated when a file is opened in the
editor — casing against a convention, characters against what a Luau identifier
allows. None of that runs here, so a name the editor would object to builds
clean and inspects clean:

```xml
<ViewModel defaultInstanceId="0:41" name="charge_state" id="0:40">
    <ViewModelPropertyNumber name="battery level" id="0:45"/>
    <ViewModelPropertyBoolean name="type" id="0:46"/>
</ViewModel>
```

All three names are wrong and `problems` is empty. `charge_state` should be
`ChargeState`; `battery level` should be `batteryLevel`, and its space leaves
it reachable from a script only by bracket access; `type` is a Luau keyword,
which the editor rejects outright despite being flawless camelCase.

That matters because the warnings surface *after* handoff — in the Problems tab
of whoever opens the `.rev`, which is usually the designer. See
[data.md](data.md#naming) for the rules.

**Detect:** the names are in the tree, so check them yourself.

```bash
rive inspect . --json | jq -r '[..|objects|select((.type//"")|startswith("ViewModelProperty"))|.name]
  | .[]
  | select((test("^_*[a-z][a-zA-Z0-9]*$")|not)
           or IN("and","break","do","else","elseif","end","false","for","function",
                 "goto","if","in","local","nil","not","or","repeat","return","then",
                 "true","type","typeof","until","while"))'
```

Anything printed is off-convention or a reserved word. Swap the pattern for
`^_*[a-z][a-z0-9]*(_[a-z0-9]+)*$` if your workspace has chosen snake_case.

## Unpositioned states and artboards all land on the same point

`AnyState`, `EntryState`, `ExitState`, `AnimationState` and the blend states
all inherit `x`/`y` (default `0`) from `LayerState` — the node's position in
the editor's state graph canvas. `Artboard` inherits its own `x`/`y` (also
default `0`) from `Node` — its position on the editor's Stage, when a file
holds more than one. Neither affects anything at runtime: a state machine
transitions the same way and a standalone artboard renders pixel-identical
regardless of what either says.

Nothing forces you to set either one, so a hand-authored file typically
leaves every state — and every artboard — at `(0, 0)`:

```xml
<AnyState/>
<ExitState/>
<EntryState><StateTransition stateToId="0:12"/></EntryState>
<AnimationState animationId="0:20" id="0:12"/>
```

All four sit exactly on top of each other. It builds clean and runs clean —
this only surfaces when the `.rev` is opened in the editor, as a stack of
fully overlapping nodes with no way to tell them apart, since states also
carry [no `name`](state-machines.md#states). The same thing happens to the
Stage when a file has several artboards and none of them carries `x`/`y`.

Give each a distinct position instead. Editor-authored files space states
roughly 100–400 units apart and put `EntryState` near the left of the group:

```xml
<AnyState x="400" y="0"/>
<ExitState x="480" y="0"/>
<EntryState x="0" y="16"><StateTransition stateToId="0:12"/></EntryState>
<AnimationState animationId="0:20" x="160" y="0" id="0:12"/>
```

Do the same for every `Artboard` in a multi-artboard file — space them out on
the Stage the way you would if you had dragged them into place by hand. The
exact numbers do not matter; only that no two overlap.

**Detect:** a state's `x`/`y` are editor-only, so `inspect` omits them
entirely — querying the tree reports *every* state as unpositioned, including
the ones you just placed. Read the source instead:

```bash
grep -Eoh '<(AnyState|ExitState|EntryState|AnimationState|BlendState[A-Za-z]*)[^>]*' *.rml \
  | grep -v 'x="'
```

Anything printed is a state sitting at the origin — harmless alone, a problem
once a second one lands there too.

An artboard's `x`/`y` are ordinary properties rather than editor-only ones, so
those the tree does show:

```bash
rive inspect . --json | jq -c '[..|objects|select(.type=="Artboard")|{name,x,y}]'
```

Two artboards reading `0` for both are stacked on the Stage.

## A missing asset file reports nothing at all

```xml
<FontAsset file="NoSuchFont.ttf" name="Missing" id="0:30"/>
```

That builds clean and inspects clean. `problems` is empty. The text using it
simply renders as nothing, and no diagnostic anywhere points at the filename.
The same holds for image assets.

This is the worst silent failure in the set, because every other one leaves
*some* trace in the tree. Here the tree looks perfect.

**Detect:** you cannot do this from `inspect` — it does not report the `file`
attribute at all, so a query against the tree comes back empty whether or not
the file is there. Check the source and the disk directly:

```bash
grep -oh 'file="[^"]*"' *.rml | sed 's/file="//;s/"//' \
  | while read -r f; do [ -e "$f" ] || echo "MISSING: $f"; done
```

Reference-by-id inside the file is checked for scalar references: a
`styleId` naming an id no element declares is a compile error. Id *lists*
are not checked -- path lists (`sourcePathIds`, `dataBindPathIds`) are
resolved at runtime and editor exports legitimately carry stale segments,
and the remaining lists (`tagIds` and editor-state lists) simply are not
validated yet -- and the editor's own dangling marker `0:0` always builds
clean. So a bind path or a list entry can still be quietly wrong. A
`DrawTarget` that exists but is not nested inside its `DrawRules` is caught,
as `draw-target-not-child-of-rules`.

## `cubic` with no interpolator eases nothing

```xml
<KeyFrameDouble value="0" frame="0" interpolationType="cubic"/>
```

That builds clean and inspects clean. `cubic` says "use the curve nested inside
me" — with no `CubicEaseInterpolator` child there is no curve, and the segment
does not ease. Same for `elastic` without an `ElasticInterpolator`.

**Detect:** every `cubic` keyframe should have an interpolator child. Ask each
keyframe directly, rather than comparing totals:

```bash
rive inspect . --json | jq '[..|objects
  |select((.type//"")|startswith("KeyFrame"))
  |select(.enums.interpolationType=="cubic")
  |select(([.children[]?|select((.type//"")|test("Interpolator$"))]|length)==0)
  |{frame, type}]'
```

An empty result is what you want: every cubic keyframe has its curve.

Two things make this easy to get wrong. **`interpolationType` reads back as an
integer** — the decoded name is under `.enums`, so `.interpolationType=="cubic"`
matches nothing. And **`interpolatorId` is never emitted at all**: the curve
appears as a `children` entry, so any filter on that id reports every keyframe
as broken.

```json
{"type":"KeyFrameDouble","interpolationType":2,"frame":0,
 "enums":{"interpolationType":"cubic"},
 "children":[{"type":"CubicEaseInterpolator","x1":0,"y1":0,"x2":0.58,"y2":1}]}
```

See [easing.md](easing.md#custom-ease-curves).

## Fields in `inspect` you did not author

Verifying by querying the tree means reading output full of properties you never
set, and two of them look like your work failed when it did not:

```json
{"type": "SolidColor", "colorValue": "FF1D1D1D",
 "colorRed": 0, "colorGreen": 0, "colorBlue": 0, "colorAlpha": 0}
```

`colorRed`/`Green`/`Blue`/`Alpha` are **passthrough views** onto `colorValue`,
provided so data binding can drive one channel. They read `0` unless something
sets them. `colorValue` is the authoritative one — if it is right, your colour
is right.

Likewise every `Fill` and `Stroke` shows `blendModeValue: 127`, which is the
"inherit from the shape" sentinel rather than a blend mode. See
[transforms.md](transforms.md#fills-and-strokes-have-a-separate-one).

Properties marked `D` by `rive schema` are computed rather than authored, and
`computed*` values are `0` until something lays the scene out — so they are not
a way to check the size of what you built.

## Without a state machine, an artboard is half alive

An artboard with no `defaultStateMachineId` still draws, and still plays a
timeline — but it receives nothing. This one omission breaks three unrelated
features at once, and each looks like a separate bug:

<!-- rml:skip -->
```xml
<Artboard viewModelId="0:40" name="Chart" id="0:2">
```

| | Without a state machine |
|---|---|
| **Data binds** | never applied. Bound text shows its authored literal, bound colours and sizes stay as drawn, and an `ArtboardComponentList` produces **no rows at all**. |
| **Pointer input** | never routed. Listeners are present in the tree and nothing reaches them, so no button, toggle or scroll view responds. |
| **Animations** | *these still play.* With no machine the runtime falls back to the first animation on the artboard, which is why a file can look alive and still be inert. |

That last row is what makes it hard to spot: something moves, so the file does
not look dead. Meanwhile `problems` is empty, every bind path resolves, every
list item is in the tree, and every listener reads back correctly with `jq`.

**Detect:** a literal probe. Set a bound text run's authored `text` to something
unmistakable like `LITERAL-HERE` and render. If you see it, the bind is inert; if
you see the view model's value, it is live. An inert bind and a working one are
otherwise indistinguishable whenever the authored value resembles the data.

For input, click it — `--pointer=click@x,y` twice and compare the captures. See
[workflow.md](workflow.md#prove-the-interaction-works).

**Fix:** give the artboard a state machine. One layer with a single
`AnimationState` is enough; it does not have to animate anything.

```xml
<StateMachine name="SM" id="0:70">
    <StateMachineLayer name="L" id="0:71">
        <AnyState/>
        <ExitState/>
        <EntryState><StateTransition stateToId="0:73"/></EntryState>
        <AnimationState animationId="0:80" id="0:73"/>
    </StateMachineLayer>
</StateMachine>
```

## Keyboard events need a `FocusData` child

`keyboardEvent` / `textEvent` only run if the `ScriptedLayout` has a **direct**
`<FocusData/>` child and that node is focused. Script-only projects get that
child for free; RML does not. `--verify` and `inspect` stay green, pointer
still works, arrows do nothing.

```xml
<ScriptedLayout scriptAssetId="0:80" name="Game">
    <FocusData/>
</ScriptedLayout>
```

A state-machine keyboard listener uses the same rule: `targetId` must own that
child, not the artboard. `KeyboardInput.keyPhase` is a bitmask (`1` down,
`2` repeat, `4` up); `0` matches nothing.

See [luau/protocols.md](luau/protocols.md#keyboard-and-text-input).

## Probe a suspect bind with a number, not a string

When a bind produces nothing, the hard part is telling *which* nothing you have:
the bind never resolved, or it resolved and delivered a value the target could
not use. On a text run those look identical — both leave the authored text on
screen.

Point the same source and converter at a **numeric** property you can see, such
as a shape's `opacity`, and the ambiguity disappears. A number target renders
whatever value actually reached it, so:

- the art changes to something *wrong* → the bind is live and the value arrived
  unconverted, so the converter is the problem
- the art does not change at all → nothing arrived, so the path or the target
  property is the problem

Choose the numbers so the two outcomes cannot be confused. Authoring
`opacity="0.5"` and expecting `0.25` means "unchanged" (0.5), "converted" (0.25)
and "raw value clamped" (1.0) are three distinct pictures rather than two
similar ones.

This is the companion to the literal probe in
[data.md](data.md#checking-your-work): the literal tells you a text bind is
inert, and this tells you why.

## Every listener under the pointer fires

By default nothing blocks anything. A `StateMachineListenerSingle` fires
whenever its target's hit area contains the point, whatever is drawn on top of
it and whatever other listeners also matched.

Blocking exists but is opt-in. The runtime walks hit targets front-to-back
(reverse draw order, with artboard-wide targets first) and passes each one a
`canHit` flag that goes false once something returns an *opaque* hit — which
means a drawable with `isTargetOpaque="true"`, one carrying the opaque drawable
flag, or a scroll listener that has started scrolling. A plain shape on top is
not opaque, so it does not stop anything behind it. Two listeners writing the same
property will fight, and the one that runs last wins.

The expensive version of this is a control that is only dead in one spot. A menu
whose items collapse onto their launch button leaves every item's listener
stacked under it while closed — the button's own toggle runs, then six `Pick`
listeners undo it, and the result is a small dead zone in the middle of a
working button.

**A fully transparent fill is still hit-testable**, and so is a shape at opacity
`0`; neither is a way to switch a target off. `hidden` is not animatable, so
"un-clickable for part of a timeline" has no direct spelling — key the hit
shape's `x` far off-artboard with `hold` keyframes instead.

Detect: only by elimination. Remove listeners a group at a time until the
behaviour changes, or move the suspect targets far off-artboard and see whether
the control starts working.

## `Feather` in a `Fill` renders nothing

The paint disappears completely — at any `strength`, and with `inner="true"` —
while the build stays clean and `problems` stays empty. On a `Stroke` it works
correctly. See [drawing.md](drawing.md#effects-and-clipping) for the working
spellings and the gradient substitute for filled glows.

Detect: only a screenshot. A shape that vanished entirely reads as a broken
shape rather than a broken effect, so check the paint before the geometry.

## A capture with no `--advance` is the pose before anything advanced

The state machine has not run before the first advance, so the capture is
the authored artboard pose rather than the animation's opening frame. It looks like a
perfectly valid frame, which is what makes it costly: use it as the wrap point
of a loop and every cycle flashes the rest pose.

Detect: capture frame 0 and frame 2 and compare. If frame 0 is much further from
frame 2 than frame 2 is from frame 4, you are looking at the rest pose. Start
previews at `--advance=1`.

## Dropping `resize`'s `scale` renders your effect at half resolution

`resize(self, size, scale)` has a third parameter — the surface's device pixels
per point. Every example that predates this note omits it, so it is easy to
never learn it exists.

It costs nothing while you draw through the `Renderer`. It costs you half your
resolution the moment you size a `Canvas`, `GPUCanvas` or `GPUTexture` yourself:
size it in points and the runtime upscales your surface 2x on a Retina display,
while the text and shapes beside it rasterise at full device resolution. The
result reads as "my effect looks pixelated but the rest of the screen is fine".

```luau
-- wrong: a 942x566 canvas stretched over an 1880x1130 raster
self.canvas = context:canvas({ width = size.x, height = size.y })

-- right
self.canvas = context:canvas({ width = size.x * scale, height = size.y * scale })
```

Detect: **not with `--screenshot`.** The headless capture always runs at `@1x`
and passes `scale = 1`, so the mistake is invisible to it by construction — this
is the one class of defect the render check cannot see. Open the live window and
read the viewport line (`viewport 1880x1130 @2x`), or `print` the scale you were
handed and compare it with the size of the surface you allocated.

## `fill` on the cross axis of a `wrap` container collapses to zero

Cross-axis `fill` becomes `alignSelf: stretch`, but nothing sets
`alignContent: stretch` on the container — so a wrapped flex line is only as
tall as its tallest *item*, never as tall as the container. A row that wraps and
whose children fill the cross axis therefore lays out at zero height, and the
whole region disappears.

Clean `--verify`, empty `problems`, correct object count. It bites hardest in
the wireframe pass, which is exactly when the docs tell you to check
responsiveness, and "responsive row of cards" is the construct that leads you
straight into it.

Detect: only a screenshot. Give one child a fixed or `hug` height to establish
the line, or size the container explicitly instead of relying on the children.

## `Component.flags` is editor state, not runtime state

`rive schema` advertises `hidden`, `locked`, `disconnected`, `opaque` and
`guide` as attributes you can write, and the parser accepts them — but the
property is not read at runtime, so `hidden="true"` renders exactly the same as
leaving it off. Use it to organise a file for the editor, never to change what a
`.riv` draws.

A raw integer does not work either: `flags="5"` parses and stores nothing.
Write bits as their own boolean attributes.

## `--data` is silently overridden by a two-way bind

If a property is also driven by a `DataBind` with `direction="true"`, that bind
wins on the first frame and `--data` has no visible effect — while the log still
prints `data: <path> = <value>`, because the write did happen. The documented
"change the data and see the picture change" check then reads as "nothing is
bound" when the truth is the opposite.

Detect: if `--data` logs the assignment but nothing moves, look for a two-way
bind on that property before concluding the binding is broken.

**The fix is `sourceToTargetRunsFirst="true"`** on the `DataBindContext`, which
runs the read before the write and lets an externally-set value survive the
frame. It is one of three bits on `DataBind.flags`, visible only through
`rive schema DataBindContext --all`. The other pattern that works is to point
the pointer at its own `*Base` property and derive the live value from it, so
the host and the user drive different properties and never fight.

## A clean build is not a correct file

The through-line for everything above. `--verify` exiting 0 means the project
compiles and the `.riv` it produces can be loaded — a real claim, and a
narrower one than it sounds.

What it does not mean:

- **that anything ran.** Scripts are type-checked, not executed. A converter
  with the wrong signature, or a `require` that cannot resolve at run time,
  compiles clean and then does nothing.
- **that the data arrived.** Binds resolve at build time; whether they ever
  fire is a run-time question. See
  [data.md](data.md#checking-your-work).
- **that it looks right.** Nothing in `--verify` or `inspect` renders a pixel,
  and neither has ever caught an appearance bug.

So follow it with `rive inspect` and query for what you intended to build, then
with `--screenshot` and *look*. The three checks are cumulative, not
alternatives — see [workflow.md](workflow.md#what-each-one-actually-proves).
