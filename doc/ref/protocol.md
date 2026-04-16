# protocol reference

## tmux CSI-u wire shape

This repo targets tmux `extended-keys-format csi-u` sequences in this form:

- `ESC [ keycode ; modifier u`
- escaped form in docs and fixtures: `\e[keycode;modifieru`
- example: `\e[59;2u`

The package does not parse an open-ended terminal protocol stream. It installs explicit `input-decode-map` entries for known tmux `CSI-u` sequences.

Scope is the delta over Emacs native tmux/xterm decode on the tmux TTY path. When `xterm.el` already decodes a sequence exactly or effectively, this repo documents a skip instead of re-owning it.

## modifier model

Generated printable coverage uses this exact tmux modifier model:

| modifier | prefix |
| --- | --- |
| `2` | `S-` |
| `3` | `M-` |
| `4` | `M-S-` |
| `5` | `C-` |
| `6` | `C-S-` |
| `7` | `C-M-` |
| `8` | `C-M-S-` |

Printable keycodes use these exact base tokens before overrides:

- keycode `32` → `SPC`
- keycodes `33..126` → literal ASCII character for that codepoint

Examples:

- `\e[97;6u` → `C-S-a`
- `\e[59;2u` → generated baseline `S-;`, then repo override `:`
- `\e[32;5u` → `C-SPC`

## normative repo artifacts

The repo keeps two machine-readable source-of-truth artifacts.

### `test/fixture/generated-matrix.json`

This fixture records the generated printable baseline before explicit overrides.

Contract:

- printable ASCII keycodes `32..126`
- tmux modifiers `2..8`
- exact ordering by numeric keycode, then numeric modifier
- exact JSON fields for `format_version`, `encoding`, `entries`, and `skip_list`

Tests assert exact equality against `test/fixture/generated-matrix.json`.

### `test/fixture/punctuation.json`

This fixture records the local shifted punctuation capture.

Captured metadata includes:

- capture command
- tmux version
- Emacs version
- terminal app
- macOS input source

Current capture command: `cat -v`.

## explicit overrides

The generated printable baseline is not the final public behavior. The repo adds explicit overrides for cases where tmux `CSI-u` meaning does not line up with useful Emacs TTY semantics.

Required explicit families:

- explicit space delta: `\e[32;2u`, `\e[32;5u`, `\e[32;6u`, `\e[32;8u`
- generated space baseline still covers `\e[32;4u` as `M-S-SPC`
- native exact skip covers `\e[32;3u` and `\e[32;7u`
- explicit return delta: `\e[13;3u` (`M-<return>`), `\e[13;8u` (`C-M-S-<return>`)
- `xterm.el` already decodes `\e[13;2u`, `\e[13;5u`, `\e[13;6u`, and `\e[13;7u` natively
- explicit tab delta: `\e[9;3u` (`M-<tab>`)
- `\e[9;2u` stays effectively native via `[S-tab]` → `[backtab]`; `xterm.el` already decodes `\e[9;5u` and `\e[9;6u` natively
- backspace family: `\e[127;2u`, `\e[127;3u`, `\e[127;5u`, `\e[127;6u`, `\e[127;7u`
- escape family: `\e[27;3u`, `\e[27;5u`, `\e[27;6u`
- shifted punctuation family derived from `test/fixture/punctuation.json`, including modifiers `2`, `4`, `6`, and `8` for the captured local targets

Current out-of-scope special-key examples that should stay local if needed:

- `\e[13;4u` (`M-S-RET`)
- `\e[9;4u`
- `\e[127;4u`
- `\e[27;4u`

The repo installs candidates in this order:

1. generated printable baseline
2. package special-case overrides
3. user local overrides

## skip lists and limits

### generated printable skip list

Some printable pairs are intentionally skipped because `xterm.el` already decodes them exactly, `xterm.el` already decodes them but collapses the extra shift bit, or `kbd` normalizes them to an existing Emacs event. The skip list lives in `test/fixture/generated-matrix.json`.

Reason text uses exact forms such as:

- `xterm.el decodes M-SPC natively`
- `xterm.el collapses C-S-: to C-:`
- `kbd normalizes C-I to TAB`
- `kbd normalizes C-m to RET`
- `kbd normalizes C-A to C-a`

### special-key skip list

This repo does not claim support for every modifier-bearing special key. The documented v1 special-key skip list is:

- `\e[9;7u`
- `\e[9;8u`
- `\e[127;8u`
- `\e[27;2u`
- `\e[27;7u`
- `\e[27;8u`

### support assumptions

Positive support detection requires all of these:

- non-graphical frame
- live terminal
- tmux evidence from exact `tty-type` match: `tmux` or `tmux-256color`, or explicit `tmux-emacs-csi-u-force-enable`

Outside that context, enable is a no-op and returns a `skipped` report.

### non-goals

This repo does not try to be:

- a generic terminal keyboard framework
- a claim about every keyboard layout
- a fix for unrelated terminal Emacs rendering issues
- a reason to turn tmux off of `csi-u`

## collision model

Policy: warn-and-preserve.

- existing matching bindings are reported as already enabled
- conflicting external bindings are preserved
- reports include exact escaped sequence strings such as `\\e[59;2u`
- human-readable summaries point at `(tmux-emacs-csi-u-describe)`

## prior art and references

- Emacs Bug #50699 — native `CSI-u` support request: <https://debbugs.gnu.org/cgi/bugreport.cgi?bug=50699>
- George Nachman Emacs-side translation gist: <https://gist.github.com/gnachman/b4fb1e643e7e82a546bc9f86f30360e4>
