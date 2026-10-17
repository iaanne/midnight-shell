# yet-another-monochrome-icon-set

Vendored by midnight-shell so that desktop icons do not depend on the icon
theme installed on the machine.

- Upstream: <https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set>
- Revision: `227359bea788d55d202d9aad5f2daf63fe644cc3`
- License: GPL-3.0 (see `LICENSE`; `Authors` is upstream's own)

## What is here

Only the subtrees the shell resolves, all built as paths by
`modules/background/desktopicons/FileEntry.qml`:

| Subtree | Used for |
|---|---|
| `apps/scalable/` | application icons (`DesktopEntry.icon`) |
| `places/scalable/` | `folder.svg`, for directories |
| `mimetypes/scalable/` | file type icons (`image-x-generic`, `application-pdf`, …) |

Upstream's 16px trees and its `actions/`, `categories/`, `devices/`,
`emblems/`, `preferences/` and `status/` trees are unused and were left out,
along with `index.theme`: the shell reads this as a plain directory rather than
registering it as an icon theme.

Symlinks are upstream's own aliases and were copied as-is; they all resolve
inside these three subtrees.

## Updating

Re-copy the three subtrees from a newer upstream revision and update the hash
above. No file list is hard-coded anywhere in the shell.
