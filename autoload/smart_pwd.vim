vim9script

# Smart PWD: switch the global working directory to the nearest project root
# when a normal file buffer is entered.  See README.md for the rationale and
# the configuration options.

var cache: dict<string> = {}
var last_pwd: string = getcwd()
var timer_id: number = -1

const DEFAULT_MARKERS: list<string> = [
  '.smart-pwd',
  '.git', '.hg', '.svn',
  'pnpm-workspace.yaml', 'go.work',
  'package.json', 'tsconfig.json',
  'pyproject.toml', 'setup.py', 'setup.cfg', 'Pipfile',
  'go.mod', 'Cargo.toml',
  'pom.xml', 'build.gradle', 'build.gradle.kts',
  'settings.gradle', 'settings.gradle.kts',
  'global.json', '*.sln', '*.csproj', '*.fsproj',
  'CMakeLists.txt', 'compile_commands.json',
  'composer.json', '.luarc.json',
]

const DEFAULT_SKIP_FILETYPES: list<string> = [
  'netrw', 'help', 'qf', 'terminal', 'fugitive', 'gitcommit',
  'coc', 'coctree', 'list',
]

def ConfigMarkers(): list<string>
  var markers: list<string> = get(g:, 'smart_pwd_markers', DEFAULT_MARKERS)
  return markers
enddef

def ConfigSkipFiletypes(): list<string>
  var filetypes: list<string> = get(g:, 'smart_pwd_skip_filetypes', DEFAULT_SKIP_FILETYPES)
  return filetypes
enddef

def NormKey(path: string): string
  var p = substitute(fnamemodify(path, ':p'), '[/\\]\+$', '', '')
  return has('win32') ? tolower(p) : p
enddef

# g:project_management_active is set to a Vim9 boolean (true/false) by the
# project-management plugin, while user options are usually numbers.  Accept
# both without triggering E1138 (using a bool as a number).
def Truthy(value: any): bool
  if type(value) == v:t_bool
    return value
  endif
  if type(value) == v:t_number
    return value != 0
  endif
  return false
enddef

def IsUnder(key: string, root: string): bool
  if empty(root)
    return false
  endif
  if key ==# root
    return true
  endif
  var sep = has('win32') ? '\' : '/'
  return stridx(key, root .. sep) == 0
enddef

def IsIgnored(key: string, ignores: list<string>): bool
  for root in ignores
    if IsUnder(key, root)
      return true
    endif
  endfor
  return false
enddef

def ConfigIgnoreKeys(): list<string>
  var dirs: list<string> = get(g:, 'smart_pwd_ignore_dirs', ['~/.vim', '$TEMP', '$TMP'])
  var keys: list<string> = []
  for dir in dirs
    var expanded = expand(dir)
    if !empty(expanded)
      add(keys, NormKey(fnamemodify(expanded, ':p')))
    endif
  endfor
  return keys
enddef

def HasMarker(dir: string, markers: list<string>): bool
  for marker in markers
    var path = dir .. '/' .. marker
    if marker =~ '\*'
      if !empty(glob(path, 0, 1))
        return true
      endif
    elseif !empty(getftype(path))
      return true
    endif
  endfor
  return false
enddef

def HasStrongMarker(dir: string): bool
  for marker in ['.git', '.hg', '.svn', '.smart-pwd']
    if !empty(getftype(dir .. '/' .. marker))
      return true
    endif
  endfor
  return false
enddef

# $HOME is a container directory: a stray package.json there must not turn the
# whole home directory into a project.  Require a VCS or .smart-pwd marker.
def IsHomeContainer(dir: string): bool
  return NormKey(dir) ==# NormKey(expand('~')) && !HasStrongMarker(dir)
enddef

# Return the nearest ancestor directory that contains a project marker, or an
# empty string when the path does not belong to a known project.
export def DetectRoot(path: string): string
  var dir = path
  if !isdirectory(dir)
    dir = fnamemodify(path, ':p:h')
  endif
  dir = substitute(fnamemodify(dir, ':p'), '[/\\]\+$', '', '')
  var key = NormKey(dir)
  if has_key(cache, key)
    return cache[key]
  endif

  var markers = ConfigMarkers()
  var ignores = ConfigIgnoreKeys()
  var current = dir
  var root = ''
  var guard = 0
  while !empty(current) && guard < 64
    var current_key = NormKey(current)
    if IsIgnored(current_key, ignores)
      break
    endif
    if IsHomeContainer(current)
      break
    endif
    if HasMarker(current, markers)
      root = current
      break
    endif
    var parent = fnamemodify(current, ':h')
    if parent ==# current
      break
    endif
    current = parent
    guard += 1
  endwhile
  cache[key] = root
  return root
enddef

export def DetectCurrent(): string
  var name = bufname('%')
  if empty(name) || name =~# '^\a\+://'
    return ''
  endif
  return DetectRoot(fnamemodify(name, ':p'))
enddef

export def ShowDetect(): void
  var root = DetectCurrent()
  echomsg 'smart-pwd: ' .. (empty(root) ? '<none>' : root)
enddef

# Switch the global working directory to the detected project root.
# Returns true when the directory changed.
export def Apply(): bool
  if !Truthy(get(g:, 'smart_pwd_enable', 1))
    return false
  endif
  if Truthy(get(g:, 'smart_pwd_lock', 0)) || Truthy(get(b:, 'smart_pwd_lock', 0))
    return false
  endif
  if Truthy(get(g:, 'project_management_active', 0))
    return false
  endif

  var buf = bufnr('%')
  if !buflisted(buf)
    return false
  endif
  var name = bufname(buf)
  if empty(name) || name =~# '^\a\+://'
    return false
  endif
  if !empty(getbufvar(buf, '&buftype'))
    return false
  endif
  var filetype: string = getbufvar(buf, '&filetype')
  if index(ConfigSkipFiletypes(), filetype) >= 0
    return false
  endif

  var path = fnamemodify(name, ':p')
  if isdirectory(path)
    return false
  endif
  var root = DetectRoot(path)
  if empty(root)
    return false
  endif
  if NormKey(root) ==# NormKey(getcwd())
    return false
  endif

  last_pwd = getcwd()
  execute 'cd ' .. fnameescape(root)
  if get(g:, 'smart_pwd_verbose', 0) != 0
    echomsg 'smart-pwd: cd ' .. root
  endif
  return true
enddef

export def OnBufEnter(): void
  if !Truthy(get(g:, 'smart_pwd_enable', 1))
    return
  endif
  if timer_id != -1
    timer_stop(timer_id)
  endif
  var delay: number = get(g:, 'smart_pwd_debounce_ms', 150)
  timer_id = timer_start(delay, (_) => Apply())
enddef

export def OnDirChanged(): void
  if !Truthy(get(g:, 'project_management_active', 0))
    last_pwd = getcwd()
  endif
enddef

# project-management emits User ProjectClosed after restoring its own state.
# Restore the directory the user was working in before the project opened.
export def OnProjectClosed(): void
  if empty(last_pwd) || !isdirectory(last_pwd)
    return
  endif
  if NormKey(last_pwd) ==# NormKey(getcwd())
    return
  endif
  execute 'cd ' .. fnameescape(last_pwd)
  if get(g:, 'smart_pwd_verbose', 0) != 0
    echomsg 'smart-pwd: restored ' .. last_pwd
  endif
enddef

export def Lock(): void
  g:smart_pwd_lock = 1
  echomsg 'smart-pwd: locked'
enddef

export def Unlock(): void
  g:smart_pwd_lock = 0
  echomsg 'smart-pwd: unlocked'
enddef

export def ClearCache(): void
  cache = {}
  echomsg 'smart-pwd: cache cleared'
enddef

export def Status(): void
  var name = bufname('%')
  var root = empty(name) ? '' : DetectRoot(fnamemodify(name, ':p'))
  echomsg printf(
    'smart-pwd: enabled=%d lock=%d cwd=%s',
    Truthy(get(g:, 'smart_pwd_enable', 1)) ? 1 : 0,
    Truthy(get(g:, 'smart_pwd_lock', 0)) ? 1 : 0,
    getcwd(),
  )
  echomsg printf('smart-pwd: buffer=%s', empty(name) ? '<none>' : fnamemodify(name, ':p'))
  echomsg printf('smart-pwd: root=%s', empty(root) ? '<none>' : root)
  echomsg printf('smart-pwd: last=%s cache=%d', empty(last_pwd) ? '<none>' : last_pwd, len(cache))
enddef

export def Init(): void
  last_pwd = getcwd()
  if !exists('g:smart_pwd_enable')
    g:smart_pwd_enable = 1
  endif
enddef
