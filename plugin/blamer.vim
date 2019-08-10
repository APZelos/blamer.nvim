if exists('g:blamer_loaded')
  finish
endif
let g:blamer_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

let g:blamer_enabled = get(g:, 'blamer_enabled', 0)
let s:blamer_delay = get(g:, 'blamer_delay', 1000)
let s:blamer_timer_id = -1

function! BlamerToggle() abort
  if g:blamer_enabled == 0
    let g:blamer_enabled = 1
    call blamer#Show()
  else
    let g:blamer_enabled = 0
    call blamer#Hide()
  endif
endfunction

function! BlamerRefresh() abort
  if g:blamer_enabled == 0
    return
  endif

  call timer_stop(s:blamer_timer_id)
  call blamer#Hide()
  let s:blamer_timer_id = timer_start(s:blamer_delay, { tid -> blamer#Show() })
endfunction

augroup blamer
  autocmd!
  autocmd BufWritePost,CursorMoved * :call BlamerRefresh()
augroup END

:command! -nargs=0 BlamerToggle call BlamerToggle()

highlight link Blamer Comment

let &cpo = s:save_cpo
unlet s:save_cpo
