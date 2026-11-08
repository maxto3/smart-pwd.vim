# smart-pwd.vim

打开文件时自动把 Vim 的全局工作目录切到最近的**项目根**，而不是启用
`'autochdir'`。

`'autochdir'` 会切到文件所在目录；本插件改为向上查找项目标记（`.git`、
`package.json`、`go.mod`、`Cargo.toml` 等），让终端、fzf、ripgrep 和
`:ProjectOpen` 保持在合理的项目目录。

## 特性

- 通过标记文件/目录识别项目根。
- 使用**最近**的标记，monorepo 中的子包保持独立。
- 不属于任何项目的文件保持当前 PWD，不做切换。
- 跳过特殊 buffer：netrw、help、quickfix、终端、coc 列表等。
- `project-management` 项目激活期间不切换；`:ProjectClose` 后恢复打开项目前
  的工作目录。
- 提供查看、手动应用、锁定和清缓存的命令。

## 依赖

- Vim 9.2+，支持 Vim9 script（GVim 同样适用）。
- 可选：支持 `User ProjectClosed` 的 `project-management`。没有该事件时插件
  仍可工作，只是关闭项目后不会恢复上次目录。

## 安装

从 GitHub 通过 vim-plug 安装：

```vim
Plug 'maxto3/smart-pwd.vim', { 'as': 'smart-pwd' }
```

或克隆到 `~/.vim/plugged/smart-pwd` 后加入 `'runtimepath'`：

```vim
set runtimepath^=~/.vim/plugged/smart-pwd
```

安装后重启 Vim。

## 配置

```vim
" 总开关
let g:smart_pwd_enable = 1

" BufEnter 去抖时间（毫秒）
let g:smart_pwd_debounce_ms = 150

" 从文件目录向上检查的标记；最近的包含任一标记的目录即为项目根。
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

" 这些目录下不进行项目识别
let g:smart_pwd_ignore_dirs = ['~/.vim', '$TEMP', '$TMP']

" 永不触发切换的文件类型
let g:smart_pwd_skip_filetypes = [
      \ 'netrw', 'help', 'qf', 'terminal', 'fugitive', 'gitcommit',
      \ 'coc', 'coctree', 'list',
      \ ]

" 记录每次自动 cd
let g:smart_pwd_verbose = 0
```

`$HOME` 被视为容器目录而不是项目：家目录里偶然存在的 `package.json` 不会让
`~` 下所有文件都切到 `~`。只有家目录存在 `.git`、`.hg`、`.svn` 或
`.smart-pwd` 时才会显式把它当作项目根。

## 命令

| 命令 | 说明 |
| --- | --- |
| `:SmartPwdStatus` | 显示开关/锁定状态、PWD、当前 buffer 的根和上次 PWD。 |
| `:SmartPwdDetect` | 只打印当前 buffer 检测到的根。 |
| `:SmartPwdApply` | 立即应用判定结果，绕过去抖。 |
| `:SmartPwdLock` / `:SmartPwdUnlock` | 锁定/解锁自动切换。 |
| `:SmartPwdClearCache` | 清空目录根缓存。 |

## 行为

1. 进入一个普通、已列出的真实文件 buffer。
2. 跳过特殊 buffer 和配置中排除的 filetype。
3. 向上找到最近的含标记目录作为项目根。
4. 根与当前 PWD 不同才切换。
5. 使用 `:cd` 切换全局目录（不是 `:tcd`/`:lcd`），终端、fzf、ripgrep 跟随。
6. `g:project_management_active` 为真时不做自动切换；`User ProjectClosed`
   触发后恢复到最近一次非项目 PWD。

## 测试

```powershell
.\test\run.ps1
```

headless 测试覆盖：最近标记、项目外文件、嵌套子包、锁定、忽略目录、特殊
buffer，以及 `ProjectClosed` 恢复路径。

## 限制

- 全局 `:cd` 会影响之后创建的终端、fzf/ripgrep 的搜索起点；这是有意的，
  但行为可见。
- 最近标记模式会把嵌套的 `package.json` 当成独立项目；需要时在期望的根目录
  放一个 `.smart-pwd` 覆盖。
- `ProjectClosed` 恢复依赖 project-management 的事件；旧版本只会恢复它自己
  记录的启动目录。
