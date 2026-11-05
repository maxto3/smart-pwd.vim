# smart-pwd.vim

Automatically switch Vim's global working directory to the nearest project
root when you open a file, without enabling `'autochdir'`.

`'autochdir'` changes the working directory to the directory of the current
file. This plugin instead finds the **project root** (the nearest `.git`,
`package.json`, `go.mod`, `Cargo.toml`, ...), so terminals, fzf, ripgrep and
`:ProjectOpen` keep a sensible base directory.

## Features

- Detects project roots by marker files and directories.
- Uses the **nearest** marker, so nested packages in monorepos stay
  independent.
- Keeps the current PWD for files that do not belong to a project.
- Skips special buffers: netrw, help, quickfix, terminals, coc lists and
  other `buftype`/filetype exclusions.
- Does nothing while `project-management` has an active workspace; after
  `:ProjectClose` it restores the directory you were working in before the
  project opened.
- Includes commands for inspection, manual application, locking and cache
  invalidation.

## Requirements

- Vim 9.2 or newer with Vim9 script support (GVim included).
- Optional: `project-management` with `User ProjectClosed` support for the
  close restore behavior. Without it, the plugin still works; only the
  restore step is skipped.

## Installation

The plugin is developed as a local repository. Install it into the Vim plugin
directory and let vim-plug manage it:

```vim
" Adjust the path to your checkout.
Plug 'file:///D:/source/repos/smart-pwd.vim', { 'as': 'smart-pwd' }
```

Or copy/clone it into `~/.vim/plugged/smart-pwd` and add it to
`'runtimepath'`:

```vim
set runtimepath^=~/.vim/plugged/smart-pwd
```

Restart Vim after installing.

## Configuration

```vim
" Master switch.
let g:smart_pwd_enable = 1

" Debounce BufEnter before changing directories.
let g:smart_pwd_debounce_ms = 150

" Marker files checked from the file's directory upwards. The nearest
" directory that contains any marker wins.
let g:smart_pwd_markers = [
      \ '.smart-pwd', '.git', '.hg', '.svn',
      \ 'pnpm-workspace.yaml', 'go.work',
      \ 'package.json', 'tsconfig.json',
      \ 'pyproject.toml', 'setup.py', 'setup.cfg', 'Pipfile',
      \ 'go.mod', 'Cargo.toml',
      \ 'pom.xml', 'build.gradle', 'build.gradle.kts',
      \ 'settings.gradle', 'settings.gradle.kts',
      \ 'global.json', '*.sln', '*.csproj', '*.fsproj',
      \ 'CMakeLists.txt', 'compile_commands.json',
      \ 'composer.json', '.luarc.json',
      \ ]

" Never detect projects under these directories.
let g:smart_pwd_ignore_dirs = ['~/.vim', '$TEMP', '$TMP']

" Filetypes that must never trigger a switch.
let g:smart_pwd_skip_filetypes = [
      \ 'netrw', 'help', 'qf', 'terminal', 'fugitive', 'gitcommit',
      \ 'coc', 'coctree', 'list',
      \ ]

" Log every automatic cd.
let g:smart_pwd_verbose = 0
```

`$HOME` is treated as a container, not as a project: a stray `package.json`
in the home directory does not make every file under `~` resolve to `~`. A
`.git`, `.hg`, `.svn` or `.smart-pwd` marker in `$HOME` opts in explicitly.

## Commands

| Command | Description |
| --- | --- |
| `:SmartPwdStatus` | Show enabled/lock state, PWD, buffer root and last PWD. |
| `:SmartPwdDetect` | Print the detected root for the current buffer. |
| `:SmartPwdApply` | Apply the detected root now, bypassing the debounce. |
| `:SmartPwdLock` / `:SmartPwdUnlock` | Disable/enable automatic changes. |
| `:SmartPwdClearCache` | Clear the per-directory root cache. |

## Behavior

1. A normal, listed file buffer with a real path is entered.
2. Buffer types and skipped filetypes are ignored.
3. The nearest ancestor with a marker becomes the project root.
4. The root must differ from the current PWD.
5. `:cd` switches the global directory (not `:tcd`/`:lcd`), so terminals,
   fzf and ripgrep follow the project.
6. While `g:project_management_active` is true, automatic switching is
   disabled. `User ProjectClosed` restores the last non-project PWD.

## Testing

```powershell
.\test\run.ps1
```

The headless test covers nearest-marker detection, out-of-project files,
nested packages, locking, ignored roots, special buffers and the
`ProjectClosed` restore path.

## Limitations

- The global `:cd` also changes the directory of terminals created later and
  of fzf/ripgrep started from Vim; this is intentional but visible.
- Nearest-marker mode treats a nested `package.json` as a separate project.
  Add a `.smart-pwd` file at the intended root to override.
- The `ProjectClosed` restore requires the project-management event; older
  versions only restore their own startup directory.
