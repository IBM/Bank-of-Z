---
name: dbb-impact
description: >
  Use when the user asks what would be impacted if they changed a file, copybook, or source member —
  walks through DBB metadata store discovery and runs dbb find file via Zowe RSE to show the blast
  radius. Trigger phrases: "what would be impacted", "blast radius", "what recompiles if I change",
  "impact of changing", "who uses this copybook", "dbb find file", "what depends on".
---

# DBB Impact Analysis — Blast Radius

This skill discovers the DBB metadata store via Zowe RSE, lists build groups, and runs
`dbb find file` to show every program that would need recompiling if a given source file changes.

---

## Step 1 — Identify the Zowe RSE profile

Use `ask_followup_question` to ask whether to look in the **project** config or the **global** config:

> "Should I look for Zowe RSE profiles in the **project** config (`zowe.config.json` in the
> workspace root) or the **global** config (`~/.zowe/zowe.config.json`)?"

Suggestions: "Project config (zowe.config.json in workspace)", "Global config (~/.zowe/zowe.config.json)"

Based on the answer, read the appropriate file with `read_file`:
- **Project** → read `zowe.config.json` (workspace root)
- **Global** → read `~/.zowe/zowe.config.json`

### Extracting RSE profiles

Zowe config files use two profile layouts — handle both:

1. **Flat** — top-level `profiles` object where each entry has `"type": "rse"` directly.
   Profile name = the top-level key (e.g. `"manzanita"`).

2. **Nested** — a top-level profile group (e.g. `"bank-of-z"`) whose `profiles` sub-object
   contains entries with `"type": "rse"`. The usable profile name is the dotted path
   `<parent>.<child>` (e.g. `"bank-of-z.rse"`).

Walk the entire `profiles` tree — both the top level and any `profiles` sub-objects — and collect
every entry whose `"type"` is `"rse"`. Build the candidate list as dotted name paths.

Cross-reference with the `defaults.rse` field: if it points to one of the candidates, note that
it is the current default.

**Selection logic:**
- If exactly one RSE profile is found, use it silently.
- If more than one is found, present the list via `ask_followup_question`, marking the default
  (if any) clearly (e.g. `"bank-of-z.rse (default)"`), and ask which profile to use.

The Zowe profile flag for all commands is `--rse-profile <profileName>`.

---

## Step 2 — Ask about the metadata store

Use `ask_followup_question` to ask:

> "Is the DBB metadata store file-based or Db2-based?"

- **File-based** → proceed to Step 3
- **Db2-based** → tell the user this skill currently supports file-based stores only and stop

---

## Step 3 — Ask for the metadata store location

Use `ask_followup_question` to ask:

> "What is the path to the DBB metadata store on z/OS? This is the directory you passed as
> `fileLocation` in MetadataInit — DBB appends `.dbb/metadata` to it internally."
>
> Example: `/usr/local/sandboxes/bank-of-z`

Store this as `METADATA_LOCATION`.

---

## Step 4 — List build groups

Run this command via `execute_command` using the Zowe RSE `issue unix` subcommand (note that `--cwd` is required by the Zowe CLI plugin, typically set to `/u/ibmuser` or the user's home directory):

```
zowe rse-api-for-zowe-cli issue unix \
  "dbb list groups --type file --location <METADATA_LOCATION>" \
  --cwd "/u/ibmuser" \
  --rse-profile <profileName>
```

Parse the output to extract the list of group names (one per line after the `BUILD GROUPS` header).

If the output is empty or contains an error, tell the user the metadata store appears empty and
suggest running a full DBB build first (`./task-dbb-build.sh full` from `.setup/tasks/`).

If exactly one group is found, use it automatically. If more than one group is found, use
`ask_followup_question` to present the list and ask which group to target.

Store the selected group name as `BUILD_GROUP`.

---

## Step 5 — Ask which file to analyse

Use `ask_followup_question` to ask:

> "Which file do you want to analyse? Enter just the member name — for example `CUSTOMER` for
> `CUSTOMER.cpy`, or `ACCOUNT` for `ACCOUNT.cpy`."

Store the answer as `TARGET_MEMBER`.

---

## Step 6 — Run dbb find file

Run via `execute_command`:

```
zowe rse-api-for-zowe-cli issue unix \
  "dbb find file \"<BUILD_GROUP>\" sources dependency :COPY:<TARGET_MEMBER> --type file --location <METADATA_LOCATION>" \
  --cwd "/u/ibmuser" \
  --rse-profile <profileName>
```

> **Note on quoting:** The build group name may contain a `/` (e.g.
> `BANKZ-boz-integration-test/heading-edit`). Wrap the entire `dbb find file ...` command in
> double-quotes for the Zowe `issue unix` argument, and escape the inner double-quotes around
> the group name with backslashes.

---

## Step 7 — Present the results

Format the output as a clear table:

| Program | File |
|---------|------|
| CRDTAGY3 | Bank-of-Z/src/base/cics/cobol/CRDTAGY3.cbl |
| ... | ... |

Then summarise:

> "Changing `<TARGET_MEMBER>.cpy` would require **N programs** to be recompiled. No compile was
> needed to determine this — DBB queried its dependency graph directly."

If the result is empty (no logical files found), tell the user:
- The copybook may not have been scanned yet (run a full build)
- The member name may not match — DBB stores the logical name without extension, so `CUSTOMER`
  not `CUSTOMER.cpy`
