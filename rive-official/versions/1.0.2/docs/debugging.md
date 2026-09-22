# Debugging scripts

The preview can host a debugger for the Luau and AssemblyScript scripts in
a project. VS Code speaks to it through the Rive extension; any Debug
Adapter Protocol client can connect the same way.

## From VS Code

Install the Rive extension, open the project folder and press F5. The
extension runs `rive <project> --debug` in a terminal, waits for the preview
to come up and attaches. Breakpoints in `.luau` and `.as` files, stepping,
the call stack and the Debug Console work as they do for any other language;
Luau frames also show locals and upvalues and answer a hover. Script errors
pause where they were raised, with the message; turn that off under
Breakpoints, "Script errors".

To attach to a preview you started yourself, run it with `--debug`:

```bash
rive . --debug          # listens on 9641
rive . --debug=9700     # any port
```

then pick "Rive: attach to preview" from the Run and Debug dropdown, or add
the configuration to `launch.json`:

```json
{ "type": "rive", "request": "attach", "name": "Rive: attach", "port": 9641 }
```

The listener is loopback only.

## What to expect

- **Rebuilds keep the session.** Save a script and the preview rebuilds as
  usual; the breakpoints are planted again in the new build. A build that
  lands while you are paused waits until you continue.
- **Breakpoints move to the next executable line.** A breakpoint on a blank
  line, a comment or `end` binds to the next line that runs, and the editor
  shows where it landed. One that binds nowhere stays hollow.
- **The window freezes while paused.** Scripts run on the preview's own
  thread, so a stop holds the whole window, including its menus, until you
  continue. Its terminal keeps logging.
- **Stepping out of a callback lands in the next one.** Protocol methods
  like `advance` and `draw` are called from the runtime, so stepping out of
  the outermost frame stops at the first line the runtime runs next, usually
  the next callback of the frame.
- **Coroutines.** A breakpoint inside a coroutine body stops on that
  coroutine, with its own stack. Stepping over a yield lands where the
  resumer continues.
- **`--optimize` bakes are for shipping, not debugging.** The optimised
  Luau bake keeps line numbers but not the locals panel; the optimised
  AssemblyScript bake carries no line probes at all, so its breakpoints stay
  hollow and nothing stops. A project with `dangerouslyFast: true` in its
  `rive.yaml` takes that release bake for AssemblyScript too.
- **AssemblyScript shows frames, not variables.** Breakpoints, stepping,
  the call stack and stops on traps work; the Variables panel and hover stay
  empty until a later bake can spill locals. Generator bodies carry no
  probes, so a step lands past them.
- **Hover and Watch evaluate names, not expressions.** Dotted paths walk
  tables, vectors and Rive objects, so `self.size.x` works; `self.size.x * 2`
  does not.
