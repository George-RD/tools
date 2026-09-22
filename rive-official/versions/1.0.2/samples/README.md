# Sample projects

Runnable projects, each a complete `rive.yaml` plus its sources. Copy one out
and build it:

```bash
cp -R "$(rive samples --path)/hello_rive" myproject
rive myproject --verify
```

`rive samples` picks one and copies it for you; `--path` prints the
directory. Where no picker can draw -- Windows, stdin or stderr not a
terminal as in CI, `TERM=dumb`, or `RIVE_NO_TUI=1` -- it lists them with
their descriptions instead. Redirecting stdout alone keeps the picker: it draws on
stderr, so `rive samples > log` still asks.

## What each one shows

| Shows | Sample |
|---|---|
| The smallest layout script: draw a moving shape each frame | [hello_rive](hello_rive) |
| Keyboard, text and gamepad events in a script | [input_demo](input_demo) |
| The smallest RML document: one artboard, one shape | [rml_triangle](rml_triangle) |
| RML driven by view model data, with a script input | [rml_vm_input](rml_vm_input) |
| The same scene split across files: view models in `data/`, referenced by id from the scene | [rml_split](rml_split) |
| Making a scene follow the mouse: pointer to view model to data bind | [pointer_reactive](pointer_reactive) |
| Editable text fields via the TextInput component: placeholder, obscured entry, Tab traversal | [text_input](text_input) |
| Luau unit tests, run with `--test` | [tests_demo](tests_demo) |
| An app shell under the macOS traffic lights: integrated title bar, draggable header, resizable sidebar | [integrated_titlebar](integrated_titlebar) |

Each has its own `rive.yaml`, so the directory you copy is a project in its own
right — nothing outside it is needed.
