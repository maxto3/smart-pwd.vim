vim9script

if exists('g:loaded_smart_pwd')
  finish
endif
g:loaded_smart_pwd = 1

import autoload 'smart_pwd.vim'

command! SmartPwdStatus call smart_pwd.Status()
command! SmartPwdDetect call smart_pwd.ShowDetect()
command! SmartPwdApply call smart_pwd.Apply()
command! SmartPwdClearCache call smart_pwd.ClearCache()
command! SmartPwdLock call smart_pwd.Lock()
command! SmartPwdUnlock call smart_pwd.Unlock()

augroup smart_pwd
  autocmd!
  autocmd BufEnter * call smart_pwd.OnBufEnter()
  autocmd VimEnter * call smart_pwd.Apply()
  autocmd DirChanged * call smart_pwd.OnDirChanged()
  autocmd User ProjectClosed call smart_pwd.OnProjectClosed()
augroup END

smart_pwd.Init()
