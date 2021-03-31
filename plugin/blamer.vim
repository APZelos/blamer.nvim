if exists('g:blamer_loaded')
  finish
endif
let g:blamer_loaded = 1
let g:blamer_is_initialized = 0
let g:blamer_show_on_insert_leave = 0

let s:save_cpo = &cpo
set cpo&vim

let g:blamer_enabled = get(g:, 'blamer_enabled', 0)

function! BlamerShow() abort
  call blamer#Enable()
  call blamer#EnableShow()
endfunction

function! BlamerHide() abort
  call blamer#DisableShow()
  call blamer#Disable()
endfunction

function! BlamerToggle() abort
  if g:blamer_enabled == 0
    call BlamerShow()
  else
    call BlamerHide()
  endif
endfunction

call blamer#Init()

:command! -nargs=0 BlamerShow call BlamerShow()
:command! -nargs=0 BlamerHide call BlamerHide()
:command! -nargs=0 BlamerToggle call BlamerToggle()

highlight default link Blamer Comment

let &cpo = s:save_cpo
unlet s:save_cpo
