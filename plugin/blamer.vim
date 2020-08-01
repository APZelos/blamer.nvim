if exists('g:blamer_loaded')
  finish
endif
let g:blamer_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

let g:blamer_enabled = get(g:, 'blamer_enabled', 0)

function! BlamerShow() abort
  call blamer#Enable()
  call blamer#Show()
endfunction

function! BlamerHide() abort
  call blamer#Disable()
  call blamer#Hide()
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
