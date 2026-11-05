vim9script

import autoload 'smart_pwd.vim'

var failures: list<string> = []

def Check(cond: bool, msg: string): void
  if !cond
    add(failures, msg)
  endif
enddef

def N(path: string): string
  var p = fnamemodify(path, ':p')
  p = substitute(p, '\\', '/', 'g')
  p = substitute(p, '/\+$', '', '')
  return has('win32') ? tolower(p) : p
enddef

def CwdIs(path: string): bool
  return N(getcwd()) ==# N(path)
enddef

var base = tempname()
mkdir(base)
var plain = base .. '/plain'
var repo = base .. '/repo'
var mono = base .. '/mono'
var ignored = base .. '/ignored'
mkdir(plain, 'p')
mkdir(repo .. '/.git', 'p')
mkdir(repo .. '/src', 'p')
mkdir(mono .. '/.git', 'p')
mkdir(mono .. '/pkg', 'p')
mkdir(ignored .. '/.git', 'p')

writefile(['plain'], plain .. '/a.txt')
writefile(['repo'], repo .. '/src/a.txt')
writefile(['pkg'], mono .. '/pkg/x.js')
writefile(['root'], mono .. '/root.txt')
writefile(['ignored'], ignored .. '/a.txt')
writefile(['{}'], mono .. '/pkg/package.json')

smart_pwd.Init()
smart_pwd.ClearCache()
execute 'cd ' .. fnameescape(base)

# Nearest marker: repo/.git
execute 'edit ' .. fnameescape(repo .. '/src/a.txt')
Check(smart_pwd.Apply(), 'Apply switches into a VCS root')
Check(CwdIs(repo), 'PWD is the repository root')

# A file without markers keeps the current PWD.
execute 'edit ' .. fnameescape(plain .. '/a.txt')
Check(!smart_pwd.Apply(), 'Apply ignores files outside a project')
Check(CwdIs(repo), 'PWD stays unchanged for out-of-project files')

# Nearest marker: mono/pkg/package.json wins over mono/.git.
execute 'edit ' .. fnameescape(mono .. '/pkg/x.js')
Check(smart_pwd.Apply(), 'Apply uses the nearest marker')
Check(CwdIs(mono .. '/pkg'), 'PWD is the nested package root')

# A file next to the outer marker resolves to mono.
execute 'edit ' .. fnameescape(mono .. '/root.txt')
Check(smart_pwd.Apply(), 'Apply resolves the outer root for other files')
Check(CwdIs(mono), 'PWD is the outer repository root')

# Lock blocks automatic changes.
smart_pwd.Lock()
execute 'edit ' .. fnameescape(repo .. '/src/a.txt')
Check(!smart_pwd.Apply(), 'Lock prevents Apply')
Check(CwdIs(mono), 'PWD is unchanged while locked')
smart_pwd.Unlock()

# Ignored roots are never used.
g:smart_pwd_ignore_dirs = [ignored]
smart_pwd.ClearCache()
execute 'edit ' .. fnameescape(ignored .. '/a.txt')
Check(!smart_pwd.Apply(), 'Ignored roots are skipped')
g:smart_pwd_ignore_dirs = []
smart_pwd.ClearCache()

# Special buffers never trigger a switch.
enew
setlocal buftype=nofile
Check(!smart_pwd.Apply(), 'No-file buffers are skipped')
setlocal buftype=

# project-management stickiness and close restore.
execute 'cd ' .. fnameescape(plain)
g:project_management_active = 1
execute 'cd ' .. fnameescape(repo)
Check(!smart_pwd.Apply(), 'Project sessions are not changed by Apply')
g:project_management_active = 0
execute 'doautocmd User ProjectClosed'
Check(CwdIs(plain), 'ProjectClosed restores the last non-project PWD')

execute 'cd ' .. fnameescape(base)

var result = getenv('SP_TEST_RESULT')
if type(result) != v:t_string || result == ''
  result = base .. '/result.txt'
endif

if empty(failures)
  writefile(['PASS'], result)
  execute 'qall!'
else
  writefile(failures, result)
  cquit
endif
