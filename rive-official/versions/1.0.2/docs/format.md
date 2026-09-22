# The RML format

RML is an XML projection of Rive's object model. There is no separate schema to
learn: **every element is a core type, every attribute is one of its properties,
and nesting stands in for the references those objects hold to each other.**

One `.rml` file describes a whole Rive file. `rive` compiles it to both outputs:
the runtime `.riv`, and the editor-openable `.rev`.

If you know the type you want, ask the tool rather than guessing:

```bash
rive schema Rectangle
```

## Read this first: build success is a weak signal

Misspelled names *are* caught -- `<Rect>` is a build error suggesting
`<Rectangle>`, and an unknown attribute names the property you probably meant.
You never have to wonder whether a name landed.

What survives a clean build is everything where the names are right and the
wiring is wrong: a bind pointing at a property that does not exist, a bind on
the wrong object, a type mismatch, a script input matching no field. Each
produces a file that loads, renders, and quietly does the wrong thing.

So two habits:

1. Look names up rather than inventing them: `rive schema --search`.
2. Check what you built, not that the build succeeded:

```bash
rive inspect . --json
```

`problems` lists what is wired wrong, and the tree shows what was really
produced.

## Document structure

A document is a `<Rive>` root holding a flat sequence of root elements — a
forest under one wrapper, not a single tree:

```xml
<Rive version="1" kind="fragment">
    <Artboard defaultStateMachineId="0:7" width="500" height="500" name="Artboard" id="0:2">
        ...scene content...
    </Artboard>


    <ViewModel name="Settings" id="0:50">...</ViewModel>

    <ScriptAsset file="main.luau" name="main" id="0:80"/>
</Rive>
```

`<Rive>` carries two attributes, both required. `version` is the format
version, `1` today. `kind` is `fragment` for a project file, the only kind a
project holds, and `bundle` for the self-contained backup the editor exports.
The CLI refuses a file without it; only the rml library API, used on its own,
reads a bare document as a fragment. A fragment never declares a
`<MarkupFragment>` element: the file is the fragment, and a push records it.
Only a bundle lists them, one per file the project had.

A project may hold any number of `.rml` files, in any folders. They compile as
one document: an id declared in one file can be referenced from another, an id
may not repeat across files, and a problem is reported against the file it is
in. Split by whatever reads well, artboards in one file and view models in
another, say. Files compile in path order, so that is the order artboards take
in the `.riv` and what "first artboard declared" means for `main`; name the
default artboard in `rive.yaml` rather than relying on a filename sorting
first.

Artboards hold scene content. Assets, view models, data converters and enums are
**root elements**, direct children of `<Rive>` and never nested inside an
artboard.

A fragment never declares a `Backboard`. What the editor keeps there, the
default artboard, the core version, the publish levels and shader outputs, is
project configuration, so it lives in `rive.yaml`: `main` names the default
artboard (the first one declared when absent), `debugLevel`, `optimizationLevel`
and `shaderOutputs` set the publish options, and the core version is the CLI's
own. The build synthesizes the Backboard from them, a push carries it, and
`create --from-rev` writes a rev's Backboard back into `rive.yaml`. Only a
bundle, the editor's self-contained export, carries a `<Backboard>` element.

An artboard's own `x` and `y` are its position on the editor's stage. Nothing
the CLI shows uses them, so a file with several artboards builds and runs
fine without any, but it opens in the editor with every artboard stacked at
the origin. Space them out when there is more than one, by their sizes plus
a gutter.

## Ids and references

An id is a numeric pair, `client:object` — `0:12`, `14:11981`. Anything else
is a compile error — leading zeros included (`04:23` is malformed, not an
alternate spelling of `4:23`) — and the `0:0` id is reserved.

A project created from an editor file (`create --from-rev`) already carries an
id on every element — those are the file's identities, preserved through build
and push; keep them.

It is valid for an element which isn't referenced anywhere in the file to not
have an id. It gets one at build and push, and `rive` writes that id back into
your `.rml` — so an element you left without one comes back with one, and keeps
it from then on. The first export after adopting this puts an `id=` on nearly
every element, which is a large diff worth taking on a commit of its own.

That write-back is what holds identity across rebuilds and pushes: without it
the same element can be handed a different number the next time the numbering
shifts, and a push then reads it as a delete and an add rather than an edit.

Two caveats. The write-back covers what the export walked, and `excludeFromRev`
prunes before the walk — so whatever it drops gets no ids. That holds on every
path, `rive push` included; there is no full-export mode. It also means two
exports with different excludes can hand the same number to different objects,
because ids inside a pruned subtree do not raise the ceiling new ones are minted
above. And only elements get ids written back; script lines and runs, asset
contents and code files are invented by the compiler on every build and never
appear in your markup.

They share **one namespace across the whole document**, not one per element
type. A `DataConverterGroupItem` and a `StateMachineLayer` cannot both be
`0:91`, even though nothing could ever confuse the two. Reusing one is a build
failure — `duplicate id "0:91"; every authored id must be unique` — so this
costs you a build rather than a debugging session, but it does mean a document
assembled from two examples that each start numbering at `0:10` will not
compile until you renumber one of them.

References are attributes holding another element's id, and they are always
named `<something>Id`: `styleId`, `scriptAssetId`, `fontAssetId`, `objectId`.
A reference to an id no element declares is a compile error (id lists and
the editor's dangling marker `0:0` excepted).

Most references you never write, because nesting sets them for you.

Nesting one element inside another sets a reference property on one of them. Which property, and which direction, is declared per property in the core defs.

### The child references its parent

Nest one of these inside an element of the referenced type and the property is filled in for you. The referent is found by walking **up** to the nearest matching ancestor, so it need not be the immediate parent.

| Element | Property set | Referenced type |
|---|---|---|
| `Animation` | `artboardId` | `Artboard` |
| `Asset` | `parentId` | `Asset` |
| `BlendAnimation` | `blendStateId` | `BlendState` |
| `CodeComponent` | `codeFileId` | `CodeFile` |
| `CodePoint` | `lineId` | `CodeLine` |
| `CodeRun` | `lineId` | `CodeLine` |
| `Component` | `parentId` | `ContainerComponent` |
| `DataBind` | `targetId` | `ViewModelInstance` |
| `DataConverterGroupItem` | `groupId` | `DataConverterGroup` |
| `DataEnumValue` | `enumId` | `DataEnum` |
| `FileAssetContents` | `assetId` | `FileAsset` |
| `FormulaToken` | `formulaId` | `DataConverterFormula` |
| `KeyFrame` | `keyedPropertyId` | `KeyedProperty` |
| `KeyboardInput`, `GamepadInput`, `SemanticInput` | `targetId` | the matching `ListenerInputType*` |
| `KeyedObject` | `animationId` | `Animation` |
| `KeyedProperty` | `keyedObjectId` | `KeyedObject` |
| `LayerState` | `layerId` | `StateMachineLayer` |
| `LibraryArtboard` | `assetId` | `LibraryAsset` |
| `LibraryEvent` | `artboardId` | `LibraryArtboard` |
| `ListenerAction` | `listenerId` | `StateMachineLayerComponent` or `StateMachineListener` |
| `ListenerInputType*` | `listenerId` | `StateMachineListener` |
| `ParentableDataItem` | `parentId` | `ParentableDataItem` |
| `ScriptInput*` | `scriptedObjectId` | the `Scripted*` object it feeds |
| `StateMachineComponent` | `folderId` | `StateMachineComponentFolder` |
| `StateMachineComponent` | `machineId` *(fallback)* | `StateMachine` |
| `StateMachineFireAction` | `layerComponentId` | `StateMachineLayerComponent` |
| `StateTransition` | `stateFromId` | `LayerState` |
| `TransitionCondition` | `transitionId` | `StateTransition` |
| `ViewModelInstance` | `viewModelId` | `ViewModel` |
| `ViewModelInstanceListItem` | `instanceListId` | `ViewModelInstanceList` |
| `ViewModelInstanceValue` | `viewModelInstanceId` | `ViewModelInstance` |
| `ViewModelProperty` | `viewModelId` | `ViewModel` |

### The parent references its child

These invert: nest the referenced type **inside** the element, and the element points at it.

| Element | Property set | Referenced type (as a child) |
|---|---|---|
| `BlendAnimationDirect` | `bindablePropertyId` | `BindableProperty` |
| `BlendState1DViewModel` | `bindablePropertyId` | `BindableProperty` |
| `DataConverterInterpolator` | `interpolatorId` | `KeyFrameInterpolator` |
| `DataConverterRangeMapper` | `interpolatorId` | `KeyFrameInterpolator` |
| `InterpolatingKeyFrame` | `interpolatorId` | `KeyFrameInterpolator` |
| `LayoutComponentStyle` | `interpolatorId` | `KeyFrameInterpolator` |
| `ListenerViewModelChange` | `bindablePropertyId` | `BindableProperty` |
| `StateTransition` | `interpolatorId` | `KeyFrameInterpolator` |
| `TransitionPropertyViewModelComparator` | `bindablePropertyId` | `BindableProperty` |
| `TransitionViewModelCondition` | `leftComparatorId` | `TransitionComparator` |
| `TransitionViewModelCondition` | `rightComparatorId` | `TransitionComparator` |

### Referenced but not parented

Declared as a reference with no parenting implication; these are resolved by other rules and may need an explicit id.

- `BindableProperty.dataBindId`

### Linked by nesting alone

A few types carry no reference in either direction — being a child *is* the
whole link, and there is no id to get wrong:

- **`LayoutParticipant`** inside the `Shape`, `Text` or `Image` it puts into the
  layout flow — see [layout.md](layout.md#shapes-and-text-can-lay-themselves-out)
- **`ComponentOrigin`** inside the `LayoutComponent` whose pivot it sets
- **`TextStyleAxis`** inside its `TextStylePaint`
- **`Mesh`** inside the `Image` it deforms, and a `Skin` inside that `Mesh` or a
  `PointsPath` — see [rigging.md](rigging.md#skinning)

Contrast `LayoutComponentStyle`, which nests **and** needs `styleId`. The
difference is not guessable, so check which kind you are dealing with rather
than assuming.

Two consequences worth internalising:

**The referent is the nearest matching ancestor, not necessarily the parent.**
A `StateMachineComponent` inside a folder inside a state machine gets *both*
`folderId` (the folder) and `machineId` (the state machine, two levels up).

**Some references point down, not up.** A `KeyFrameInterpolator` nested inside a
`StateTransition` sets the *transition's* `interpolatorId`. The child is the
thing being pointed at.

### Listeners

A listener is a `StateMachineListenerSingle` declared inside the state machine.
It carries both what it watches (`targetId`) and what gesture it responds to
(`listenerTypeValue`), and its action nests inside it:

```xml
<StateMachine name="State Machine 1" id="0:7">
    <StateMachineListenerSingle targetId="0:14" listenerTypeValue="click" name="Listener 1">
        <ListenerTriggerChange inputId="0:40"/>
    </StateMachineListenerSingle>
    <StateMachineTrigger name="pressed" id="0:40"/>
    ...
</StateMachine>
```

The listener action above sets a deprecated `StateMachineTrigger`. New files
should use `ListenerViewModelChange` to write a view model property instead —
same listener, different action. See
[data.md](data.md#writing-a-value-back-from-a-listener).

`listenerTypeValue` accepts `enter`, `exit`, `down`, `up`, `move`, `click` and
more — `rive schema StateMachineListenerSingle` lists them all.

The action determines what the gesture does: `ListenerTriggerChange` fires a
trigger, `ListenerBoolChange` sets a boolean, `ListenerNumberChange` sets a
number. Their shared base `ListenerInputChange` is abstract -- authoring it is
a build error, so pick the one matching your input type.

### Nested artboards

A `NestedArtboard` embeds another artboard by id. The source artboard must be a
component — marked `isComponent="true"` and listed by a `ComponentAsset` — or
the file is malformed. See
[making an artboard nestable](#making-an-artboard-nestable) below.

```xml
<Artboard width="600" height="400" name="Screen" id="0:1">
    <NestedArtboard artboardId="0:30" x="120" y="200" name="Left">
        <NestedStateMachine animationId="0:35" name="SM">
            <NestedBool inputId="0:36" nestedValue="true" name="on"/>
        </NestedStateMachine>
    </NestedArtboard>
</Artboard>

<Artboard isComponent="true" defaultStateMachineId="0:35" width="80" height="40" name="Switch" id="0:30">
    ...
</Artboard>

<ComponentAsset artboardId="0:30" name="Switch"/>
```

To drive the child's state machine inputs from the parent, nest a
`NestedStateMachine` naming the child's machine, and inside it a `NestedBool`,
`NestedNumber` or `NestedTrigger` naming the input. The value goes on
`nestedValue`, not `value`.

`NestedArtboardLeaf` is the lighter variant. It adds `fit` and
`alignmentX`/`alignmentY`, which control how the child is scaled into the space
the parent gives it — relevant when the leaf sits in a layout that sizes it. For
a leaf positioned by plain `x`/`y` the default `fill` is effectively a no-op.

#### Driving the child's timelines

A state machine is not the only thing a parent can reach into. Two more children
of a `NestedArtboard` drive one of the child's `LinearAnimation`s directly,
naming it with `animationId` the same way `NestedStateMachine` names a machine:

```xml
<!-- play it: speed, mix and a playback flag -->
<NestedArtboard artboardId="0:30" x="300" y="100" name="Spinner">
    <NestedSimpleAnimation animationId="0:35" isPlaying="true" speed="2" name="Play"/>
</NestedArtboard>

<!-- or scrub it from data -->
<NestedArtboard artboardId="0:30" x="100" y="100" name="Dial">
    <NestedRemapAnimation animationId="0:35" name="Scrub">
        <DataBindContext sourcePathIds="0:60-0:62" propertyKey="202"/>
    </NestedRemapAnimation>
</NestedArtboard>
```

`NestedRemapAnimation` is the more useful of the two. Its `time` is
**animatable and bindable**, which makes a component's whole timeline
addressable as a single number — bind a `0`–`1` view model property to it and a
gauge, a progress ring or a character pose scrubs from data, with no state
machine on either side.

**`time` is a fraction of the duration, not seconds**, whatever `rive schema`
says: the runtime multiplies it by the animation's length. `0.5` is halfway
through, and `30` is not thirty seconds, it is thirty times past the end.

`NestedSimpleAnimation` plays instead of scrubbing, and its `isPlaying`
**defaults to `false`** — nest one without it and the child simply holds its
first frame. `speed` scales playback, and `mix` (on both, defaulting to `1`) is
how strongly the animation applies, so several can blend.

Both are only valid as a direct child of a `NestedArtboard`. Put one anywhere
else and it is dropped during load, silently — it does not fail the file, and
`--verify` and `problems` see nothing wrong.

### Making an artboard nestable

An artboard cannot be nested until it has been promoted to a component. In the
editor that is three steps: build the artboard, mark it as a component, and it
appears in the assets panel — only then can it be dropped into another artboard.

RML is the same sequence written out, with one difference: **the editor creates
the assets-panel entry for you, and in markup you write it yourself.** That
entry is the `ComponentAsset`.

```xml
<!-- 1. the artboard, 2. marked as a component -->
<Artboard isComponent="true" width="80" height="40" name="Switch" id="0:30">
    ...
</Artboard>

<!-- 3. its entry in the assets panel -->
<ComponentAsset artboardId="0:30" name="Switch"/>

<!-- 4. now it can be nested -->
<Artboard width="600" height="400" name="Screen" id="0:1">
    <NestedArtboard artboardId="0:30" x="120" y="200" name="Left"/>
</Artboard>
```

`ComponentAsset` is a root element carrying only `artboardId` and `name` — no
file, nothing nested. One per component artboard.

All four steps are required. Skipping the mark or the asset entry produces a
file the editor would never have created, so treat them as one action: an
artboard meant for reuse gets `isComponent="true"` **and** a `ComponentAsset`,
written together.

**Nothing checks this.** `isComponent` is editor-side metadata, so a
`NestedArtboard` pointing at an unmarked artboard, or a component with no asset
entry, builds clean and inspects clean while being malformed. There is no
diagnostic to fall back on.

One consequence worth knowing if you are working from a decompiled `.rev`: the
component flag postdates a lot of existing files, so an older one may nest an
artboard that carries neither the mark nor an asset entry. That is history, not
a pattern — write all four steps in anything new.

### Listeners: two spellings

`StateMachineListenerSingle` is a listener with **one trigger folded into the
element**: `listenerTypeValue` (click, enter, drag, …) sits on the listener
itself. `StateMachineListener` is the general form: the element carries only
`targetId`, and **each trigger is a nested `ListenerInputType*` child** with
its own `listenerTypeValue` — several children make a listener that reacts to
several things. Keyboard and gamepad listeners are always the general form,
because their input types are what the key/button filters nest under:

```xml
<StateMachineListener targetId="0:2" name="Arrows">
    <ListenerInputTypeKeyboard listenerTypeValue="15">
        <KeyboardInput keyType="262" keyPhase="7"/>
        <KeyboardInput keyType="263" keyPhase="7"/>
    </ListenerInputTypeKeyboard>
    <ScriptedListenerAction scriptAssetId="0:80"/>
</StateMachineListener>
```

The nesting is the whole link: no `listenerId` on the input type, no
`targetId` on the inputs. An input type with no inputs matches every key, so
a `KeyboardInput` left outside its input type does not fail the build — it
silently widens the listener to everything. Note `listenerTypeValue` lives on
`ListenerInputType*` for these, and on `StateMachineListenerSingle` for a
pointer listener; the two are different types, and mixing them is a build
error. If a construct is not in the tables above, check with
`rive schema <Type>` which shape it uses.

## Values

**Colors** are ARGB hex, no `#`: `colorValue="FFFF5A3C"` is opaque orange.

**Booleans** are `"true"` / `"false"`.

**Enums** accept a symbolic name or the underlying integer —
`layoutWidthScaleType="fill"` and `="1"` are identical. Prefer names; the
integers are what the `.rev` decompiler emits. An unrecognised name *is* an
error, and lists the accepted values, which makes enums the one place a typo is
caught for you. `rive schema <Type>` lists the names per property.

**Rotation is radians**, not degrees. A full turn is `6.2831855`.

**Fractional indices** are a fraction written as a string: `childOrder="3/4"`.
The type exists so a row can be inserted between two others without renumbering
the rest — pick any fraction that sorts between the neighbours. It appears on
`Component.childOrder` and on the `order` of folders, tags, enum values and view
model list items.

The slash is not optional, and this is the trap: `childOrder="1"` is not the
integer 1, it is a **malformed** fractional index. It does not error — a literal
with no `/` parses to the type's `invalid` value, so the ordering you wrote is
ignored and nothing tells you. Write `"1/1"`.

**Animation timing is frames.** `LinearAnimation` has `fps` (default 60) and
`duration` in frames, so two seconds at 60fps is `duration="120"`. Transition
durations, confusingly, are milliseconds.

**Inline source** for scripts and shaders goes in a CDATA block:

```xml
<ScriptAsset name="inline_main" id="0:80">
<![CDATA[
return function(context: Context): Layout<Inline>
    ...
end
]]>
</ScriptAsset>
```

When both `file` and inline text are present, the file wins.

## Animation

Keyframes address their target by **property key**, a number, not a name:

```xml
<LinearAnimation loopValue="loop" duration="120" name="Spin" id="0:6">
    <KeyedObject objectId="0:14">
        <KeyedProperty propertyKey="15">
            <KeyFrameDouble value="0" interpolationType="linear"/>
            <KeyFrameDouble value="6.2831855" interpolationType="linear" frame="120"/>
        </KeyedProperty>
    </KeyedObject>
</LinearAnimation>
```

`propertyKey="15"` is rotation. Never guess these:

```bash
rive schema Shape --animatable
```

Note `KeyedObject.objectId` is one of the few references you write explicitly —
the animation lives beside the objects it animates, not inside them.

### The keyframe type must match the property

`KeyFrameDouble` is only for `double` properties. Every field type has its own
keyframe element, and the one you nest has to match what the `propertyKey`
points at:

| Property type | Keyframe |
|---|---|
| `double` | `KeyFrameDouble` |
| `Color` | `KeyFrameColor` |
| `bool` | `KeyFrameBool` |
| `uint` (including enums) | `KeyFrameUint` |
| `String` | `KeyFrameString` |
| `Id` | `KeyFrameId` |
| `callback` | `KeyFrameCallback` |

`rive schema <Type>` gives the type of any property, and `--animatable` lists
only the ones that can be keyed at all.

A `callback` property carries no value — `KeyFrameCallback` takes a `frame` and
nothing else, and firing it *does* something rather than setting something. See
[luau/protocols.md](luau/protocols.md#the-trigger-has-two-keys) for the one you
are most likely to key.

Two common non-double cases:

```xml
<!-- fade a fill from blue to red: SolidColor.colorValue is key 37 -->
<KeyedProperty propertyKey="37">
    <KeyFrameColor value="FF57A5E0" frame="0" interpolationType="linear"/>
    <KeyFrameColor value="FFE0573C" frame="60" interpolationType="linear"/>
</KeyedProperty>

<!-- switch which child of a Solo is showing: activeComponentId is key 296 -->
<KeyedProperty propertyKey="296">
    <KeyFrameId value="0:61" frame="0" interpolationType="hold"/>
    <KeyFrameId value="0:62" frame="30" interpolationType="hold"/>
</KeyedProperty>
```

Reference and boolean keyframes only make sense as `hold` — there is no halfway
between two ids. Colours interpolate channel by channel.

Mismatching them fails silently. A `KeyFrameDouble` on a colour property builds
without complaint, `rive inspect` reports nothing, and at runtime the value is
never written — the property just sits at its authored value while the timeline
plays. If a keyed property refuses to animate and everything looks right, check
the keyframe element before anything else.

## State machines

Every `StateMachineLayer` needs an `AnyState`, an `ExitState` and an
`EntryState`, even if unused. Without all three the layer does not import.

```xml
<StateMachine name="State Machine 1" id="0:7">
    <StateMachineLayer name="Layer 1" id="0:8">
        <AnyState/>
        <ExitState/>
        <EntryState>
            <StateTransition stateToId="0:12"/>
        </EntryState>
        <AnimationState animationId="0:6" id="0:12"/>
    </StateMachineLayer>
</StateMachine>
```

An artboard plays a state machine automatically when its `defaultStateMachineId`
names one.

This section covers the grammar only. Exit time, transition flags, view model
conditions, multiple layers and events are in
[state-machines.md](state-machines.md).

### Inputs and conditions

A transition fires when its conditions pass. The current way to write one is
`TransitionViewModelCondition`, reading a view model property — see
[state-machines.md](state-machines.md#from-view-model-data).

The older form names a **state machine input**, which is deprecated but still
present in most existing files, so it is worth being able to read:

```xml
<StateMachineBool name="hovered" id="0:40"/>
...
<StateTransition stateToId="0:13" duration="150">
    <TransitionBoolCondition inputId="0:40" opValue="equal"/>
</StateTransition>
```

**A boolean condition has no value to compare against.** `TransitionBoolCondition`
carries only `inputId` and `opValue`, and the input's own value is tested
against `true`:

| `opValue` | Fires when |
|---|---|
| `equal` | the input is **true** |
| `notEqual` | the input is **false** |

Nothing in the type's shape suggests this — there is no `value` property to
find — so it is worth knowing rather than deriving.

Numeric conditions do compare against a value, and `opValue` takes the full set:
`equal`, `notEqual`, `lessThan`, `lessThanOrEqual`, `greaterThan`,
`greaterThanOrEqual`.

### Setting inputs from listeners

The listener action carries the value to set. `ListenerBoolChange.value` is a
plain integer, `1` for true and `0` for false:

```xml
<StateMachineListenerSingle targetId="0:14" listenerTypeValue="enter">
    <ListenerBoolChange inputId="0:40" value="1"/>
</StateMachineListenerSingle>
```

A trigger needs no value — `ListenerTriggerChange` just fires it.

## Data binding

`DataBindContext` nests under the object it drives, naming the target property
by key and the source by path:

```xml
<TextValueRun styleId="0:21" text="placeholder" name="Run">
    <DataBindContext sourcePathIds="0:40-0:45" propertyKey="268"/>
</TextValueRun>
```

`sourcePathIds` is a dash-separated **absolute** path: it starts at a view model
id and walks property ids. `"0:40-0:45"` means view model `0:40`, its property
`0:45`. To reach through a nested view model, add a segment — the middle segment
must be a `ViewModelPropertyViewModel`, and the walk continues inside the view
model it references.

Relative paths are not supported. Bind the deepest concrete property directly.

A dangling path is not an error. A bind whose `sourcePathIds` names a property
that does not exist compiles, loads, and silently does nothing — so verify with
`rive inspect` rather than assuming.

Bind the property that actually exists on the target: `width` lives on
`Rectangle`, not on the enclosing `Shape`. Binding `propertyKey="20"` under the
`Shape` compiles and does nothing.

## Limits

Authoring these will fail or silently diverge from what the editor produces:

- **Bind paths are absolute.** The relative (`nameBased`) form the editor emits
  resolves through a `ManifestAsset` nothing here builds, so setting the flag by
  hand produces a bind that never resolves — see
  [gotchas.md](gotchas.md#bind-paths-you-author-here-are-absolute).
- **No library assets.** `LibraryAsset` is an error.
- **No treeshaking.** Everything authored is exported.
- Keyframe interpolators are not deduplicated.
- All assets embed; referenced and hosted asset types are unsupported.
