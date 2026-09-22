# Pushing a project to a Rive file

`rive push` builds the project and sends the result straight to a Rive file in
your workspace — no `.rev` on disk, no drag and drop. The file opens from the
editor's file browser like any other, and every push lands as a named entry in
its revision history, so any push can be inspected or restored from the
editor's revision panel.

```bash
rive login              # once per machine: same session as --publish
rive push               # build and push; the first push creates the file
```

## The first push

A file lives in a project, so the first push has to pick one:

- with a single project in your account, it is picked automatically
- with several, the CLI opens a picker: up and down (or Ctrl-P and Ctrl-N)
  move, typing narrows the list -- each word has to appear somewhere, so
  `acme spin` finds "acme / Spinner" -- enter chooses, and escape backs out
- where no picker can draw but somebody is still typing -- Windows,
  `TERM=dumb`, `RIVE_NO_TUI=1`, or a terminal that refuses raw mode -- it
  falls back to the numbered list and prompts for a number
- with stdin not a terminal, as in CI, it lists the projects and exits, so
  scripted runs stay deterministic. Redirecting stdout alone is not enough:
  the picker draws on stderr, so `rive push > log` still asks
- `--project=<id>` skips the picker (`rive push --list` prints every project
  with its id, without building anything)

The created file is recorded in `rive.yaml`:

```yaml
push:
  projectId: 9
  fileId: 512
```

Commit this so everyone pushing the project updates the same file. Delete the
`fileId` line (or the whole block) to make the next push create a fresh file;
edit `projectId` to create it somewhere else.

## Every push after

A later push diffs the new build against the file's live content and sends
only what differs, then names a revision. `--name` labels it — useful when a
push marks something:

```bash
rive push --name="before the terrain rewrite"
```

A push with nothing new reports `already up to date` and adds no revision.
The previous content is never lost: it stays in the revision history, and the
editor can restore any entry. If someone has the file open in the editor while
you push, they see the content swap live, like a collaborator's edit — and
any editor-made changes to pushed content are overwritten, the push is
authoritative.

## Ids stay stable

Logically-same things keep their coop object ids across pushes: an asset by
its module path, an artboard (and its layout graph) by its name, folders by
their path. That matters when the pushed file is used as a library — a
consumer's reference to a library component points at an object id in this
file, and renaming *other* assets or adding new ones does not move it. Ids do
change when the thing itself is renamed or moved (it reads as a new object),
and the internal code line/run tree is renumbered whenever a source file's
text changes.

## Sessions

Push uses the same `rive login` token as `--publish` and watermark. After the
API started issuing `cli:write` on new logins, anyone who signed in before
that must run `rive login` again — refresh does not upgrade an old token.

A 401 on `/api/me` or on opening the bound file is a stale login. `--uat`
keeps a separate token, same as the other signed-in commands.

## What is pushed

Exactly what `--rev` would export: the project's own scripts, assets and
artboards, minus everything `excludeFromRev` drops. Libraries are not pushed —
each library exports its own `.rev` and is published separately.

## Environment overrides

| Variable | Overrides |
|---|---|
| `RIVE_API_BASE` | the API host |
| `RIVE_COOP_HOST` | the sync server |

`--uat` switches all of them to the UAT environment at once.

## When something goes wrong

| Message | Meaning |
|---|---|
| `Not logged in` | never signed in here; run `rive login` |
| `stale login` | token is old or rejected; run `rive login` again |
| `file <id> is missing or not accessible` | the bound file was deleted or you lost access; clear `push.fileId` to create a new one |
| `not authorized for this file` | stale login or no edit permission; try `rive login` |
| `push aborted: build failed` | fix the build first; `rive <dir> --verify` shows the problems |

A failed push never half-applies: content changes only land once the server
has accepted every change set, and the revision entry is added after that.
