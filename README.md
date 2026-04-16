# tmux-emacs-csi-u

Emacs-side decoder for tmux `CSI-u` sequences in terminal Emacs.

tmux stays on `csi-u`. This repo fixes the Emacs TTY decode gap instead of downgrading tmux key reporting.

Scope: the delta over Emacs native tmux/xterm decode, not a replacement for the native path.

## what it solves

- systematic printable ASCII coverage from generated data
- explicit overrides for the non-native space / return / tab delta, modified backspace / escape, and shifted punctuation
- terminal-local install into `input-decode-map`
- warn-and-preserve conflict handling for already-customized setups
- Pi can keep tmux `extended-keys-format csi-u`

## install

Clone or place the repo on your Emacs load path, then load it from `init.el`.

```elisp
(add-to-list 'load-path (expand-file-name "path/to/tmux-emacs-csi-u"))
(require 'tmux-emacs-csi-u)

;; optional: only for daemon/client edge cases where tty detection cannot
;; see tmux directly
;; (setq tmux-emacs-csi-u-force-enable t)

;; optional: add local overrides after package defaults
;; (setq tmux-emacs-csi-u-local-overrides '(("\e[59;2u" . [f13])))
```

`tmux-emacs-csi-u-auto-enable` defaults to `t`. The package installs from `tty-setup-hook` for supported TTY frames.

Manual enable is available too:

```elisp
(tmux-emacs-csi-u-enable)
```

## public entrypoints

- `tmux-emacs-csi-u-enable` — install candidate mappings for the current TTY terminal and return a report plist
- `tmux-emacs-csi-u-supported-p` — return non-nil when the current frame looks like a supported tmux TTY context
- `tmux-emacs-csi-u-describe` — return the latest report plist; interactively, render a human summary buffer
- `tmux-emacs-csi-u-force-enable` — explicit opt-in for daemon/client edge cases
- `tmux-emacs-csi-u-local-overrides` — local mappings applied after package defaults

## migration from ad hoc bindings

Delete the ad hoc `input-decode-map` entries for sequences this package still owns.

Remove one-off snippets for:

- `\e[32;2u`, `\e[32;5u`, `\e[32;6u`, `\e[32;8u`
- `\e[13;3u`, `\e[13;8u`
- `\e[9;3u`
- `\e[127;2u`, `\e[127;3u`, `\e[127;5u`, `\e[127;6u`, `\e[127;7u`
- `\e[27;3u`, `\e[27;5u`, `\e[27;6u`
- `\e[59;2u` and the shifted punctuation family derived from `test/fixture/punctuation.json` (`;2`, `;4`, `;6`, `;8` for the captured local targets)

Emacs already covers part of the tmux -> xterm path natively or effectively, so this repo no longer claims `\e[32;3u`, `\e[32;7u`, `\e[9;2u`, `\e[9;5u`, `\e[9;6u`, `\e[13;2u`, `\e[13;5u`, `\e[13;6u`, or `\e[13;7u`.

Codepoint-form xterm-native lossy punctuation such as `\e[58;6u` is documented skip behavior in `test/fixture/generated-matrix.json`; the fixture-derived base-keycode family such as `\e[59;6u` stays package-owned.

Keep unrelated terminal bindings that are not tmux `CSI-u` sequences.

Keep local fallbacks for sequences this repo still does not own, for example `\e[13;4u` (`M-S-RET`).

If an old snippet stays in place, the package does not overwrite it silently. Existing external bindings are preserved and reported.

## conflict behavior

Policy: warn-and-preserve.

- package-owned candidates install when the sequence is free
- already-matching bindings count as already enabled
- conflicting external bindings stay in place
- warnings point at `(tmux-emacs-csi-u-describe)` for the full report

## repo source of truth

- usage and troubleshooting: `README.md`
- protocol notes and limits: `doc/ref/protocol.md`
- printable baseline contract: `test/fixture/generated-matrix.json`
- punctuation capture contract: `test/fixture/punctuation.json`
- maintainer workflow notes: `AGENTS.md`, `.github/release.yml`, `.github/workflows/ci.yml`

## nested repo isolation

If this repo lives as a child repo inside a larger workspace, keep that parent workspace free of ordinary untracked child-repo noise.

Operational contract:

- parent workspace status should not list this child repo as ordinary untracked noise
- verify from the parent with `git status --short`
- treat parent-local ignore rules as the isolation mechanism; keep repo-local implementation inside the child repo

## latest local fixture evidence

The punctuation fixture in `test/fixture/punctuation.json` records this captured stack:

- terminal app: Ghostty 1.3.1
- tmux: 3.6a
- Emacs: GNU Emacs 30.2
- input source: ABC
- capture command: `cat -v`

The generated printable baseline in `test/fixture/generated-matrix.json` covers printable ASCII keycodes `32..126` across tmux modifiers `2..8`, with documented skip entries for native xterm overlaps, xterm-lossy punctuation collapses, and lossy `kbd` aliases.

## manual verification matrix

Use a long-lived daemon started outside the current tmux client. Repo-local smoke helper (requires `python3` locally):

```bash
script/qa-smoke
```

That helper starts an isolated daemon outside tmux with `--quick --load .tmp/qa-init-*.el`, opens a tty client inside a private tmux session, injects representative CSI-u sequences, and prints the exact command paths it used.

| check | command | pass condition | current note |
| --- | --- | --- | --- |
| tty client attach | `script/qa-smoke` | tty client opens against the isolated daemon and exits cleanly | pass 2026-04-15 via `script/qa-smoke` |
| support detection | `script/qa-smoke` | result includes `:supported t` | pass 2026-04-15 via `script/qa-smoke` |
| support report | `script/qa-smoke` then `M-x tmux-emacs-csi-u-describe RET` in a normal tty client | smoke output includes `:support-signal tty-type`; interactive command renders the human report buffer | pass 2026-04-15 for `tty-type` detection via `script/qa-smoke`; rerun the interactive describe buffer during review |
| Evil ex prompt | `emacsclient -t -a ''` in tmux, then type `:` in normal state | ex prompt opens; no recursive-edit or minibuffer wedge | reviewer step in the real Evil stack |
| shifted space / backspace | `script/qa-smoke` | result includes `"SPC"` and `"DEL"`; no trailing literal `u` | pass 2026-04-15 via `script/qa-smoke` |
| shifted punctuation | `script/qa-smoke` plus `test/fixture/punctuation.json` | exact characters arrive; no raw escape debris | pass 2026-04-15 via `script/qa-smoke`; fixture captured with `cat -v` on Ghostty 1.3.1 / tmux 3.6a / GNU Emacs 30.2 / ABC |
| special-key baseline | `script/test` and targeted tty spot-checks | automated baseline stays green and tty spot checks show expected events only | pass 2026-04-15 for `script/test`; rerun tty spot checks for the special table during review |
| Pi modified enter sanity | open Pi in tmux after loading the package | `RET`, `S-RET`, and `C-RET` stay distinct; no raw escape debris | reviewer step in a fresh Pi session |

## troubleshooting

- `tmux-emacs-csi-u-supported-p` returns `nil`: check for a TTY frame, a live terminal, and `tty-type` equal to `tmux` or `tmux-256color`; use `tmux-emacs-csi-u-force-enable` only for daemon/client edge cases
- `tmux-emacs-csi-u-describe` reports conflicts: remove old ad hoc bindings or keep them intentionally; the package preserves them either way
- punctuation still follows shifted base characters such as `S-;`: verify the explicit override is present and the old local mapping is gone
- `script/check` fails after a mapping change: update docs and fixtures in the same change
