# AGENTS

Repo-local maintainer notes for tmux-csi-u.

## durable truths

Record stable repo facts here first.

- user install, migration, troubleshooting, manual verification matrix: `README.md`
- protocol shape, modifier model, skip lists, references: `doc/ref/protocol.md`
- machine-readable mapping contracts: `test/fixture/generated-matrix.json`, `test/fixture/punctuation.json`
- release and CI metadata: `.github/release.yml`, `.github/workflows/ci.yml`

## collision policy

Policy is warn-and-preserve.

- do not silently overwrite external bindings
- preserve exact conflicting bindings
- keep escaped sequence strings in reports
- use `(tmux-csi-u-describe)` for maintainer handoff and debugging

## verification floor

No completion claims without fresh command evidence.

Run these from the repo root:

- `script/format`
- `script/lint`
- `script/compile`
- `script/test`
- `script/check`
- `script/qa-smoke` when TTY behavior or manual verification guidance changed

When mapping behavior changes, also verify docs and fixtures still match the implementation, then rerun the README manual verification matrix items that the change touches.

## docs and fixtures

If behavior changes, update the owning artifact in the same change.

- user-facing behavior change → `README.md`
- protocol or skip-list change → `doc/ref/protocol.md`
- printable baseline change → regenerate and reassert `test/fixture/generated-matrix.json`
- punctuation capture change → refresh `test/fixture/punctuation.json` and cite the capture command
- release/community workflow change → `CONTRIBUTING.md` or `.github/`

## non-goals

Avoid scope creep.

- do not change tmux away from `csi-u`
- do not add a generic terminal input framework
- do not make unverified claims about layouts beyond the recorded fixture capture
- do not replace warn-and-preserve with force-overwrite modes unless explicitly requested
