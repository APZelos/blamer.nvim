if exists('g:blamer_loaded')
  finish
endif
let g:blamer_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

let g:blamer_enabled = get(g:, 'blamer_enabled', 0)

function! BlamerToggle() abort
  if g:blamer_enabled == 0
    call blamer#Enable()
    call blamer#Show()
  else
    call blamer#Disable()
    call blamer#Hide()
  endif
endfunction

call blamer#Init()

:command! -nargs=0 BlamerToggle call BlamerToggle()

highlight default link Blamer Comment

let &cpo = s:save_cpo
unlet s:save_cpo
