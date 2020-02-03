if exists('g:blamer_autoloaded')
  finish
endif
let g:blamer_autoloaded = 1

let s:save_cpo = &cpo
set cpo&vim

let s:git_root = ''
let s:blamer_prefix = get(g:, 'blamer_prefix', '   ')
let s:blamer_template = get(g:, 'blamer_template', '<committer>, <committer-time> • <summary>')
let s:blamer_date_format = get(g:, 'blamer_date_format', '%d/%m/%y %H:%M')
let s:blamer_user_name = ''
let s:blamer_user_email = ''
let s:blamer_info_fields = filter(map(split(s:blamer_template, ' '), {key, val -> matchstr(val, '\m\C<\zs.\{-}\ze>')}), {idx, val -> val != ''})
let s:blamer_namespace = nvim_create_namespace('blamer')
let s:blamer_delay = get(g:, 'blamer_delay', 1000)
let s:blamer_show_in_visual_modes = get(g:, 'blamer_show_in_visual_modes', 1)
let s:blamer_timer_id = -1

function! s:Head(array) abort
  if len(a:array) == 0
    return ''
  endif

  return a:array[0]
endfunction

function! s:IsFileInPath(file_path, path) abort
  if a:file_path =~? a:path
    return 1
  else
    return 0
  endif
endfunction

function! s:GetLines() abort
  let l:visual_line_number = line('v')
  let l:cursor_line_number = line('.')

  if l:visual_line_number < l:cursor_line_number
    return range(l:visual_line_number, l:cursor_line_number)
  elseif l:cursor_line_number < l:visual_line_number
    return range(l:cursor_line_number, l:visual_line_number)
  else
    return [l:cursor_line_number]
  endif
endfunction

function! blamer#GetMessage(file, line_number, line_count) abort
  let l:command = 'git --no-pager blame -p -L ' . a:line_number . ',' . a:line_count . ' -- ' . a:file
  let l:result = system(l:command)

  if l:result =~? 'fatal'
    if l:result =~? 'not a git repository'
      let g:blamer_enabled = 0
      echo '[blamer.nvim] Not a git repository'
      return ''
    elseif l:result =~? 'no such path'
      return ''
    elseif l:result =~? 'is outside repository'
      return ''
    else
      echo '[blamer.nvim] ' . l:result
      return ''
    endif
  endif

  if l:result =~? 'no matches found'
    return ''
  endif

  let l:lines = split(l:result, '\n')
  let l:info = {}
  let l:info['commit-short'] = split(l:lines[0], ' ')[0][:7]
  let l:info['commit-long'] = split(l:lines[0], ' ')[0]
  for line in l:lines[1:]
    let l:words = split(line, ' ')
    let l:property = l:words[0]
    let l:value = join(l:words[1:], ' ')
    if  l:property =~? 'time'
      let l:value = strftime(s:blamer_date_format, l:value)
    endif
    let l:value = escape(l:value, '&')
    let l:value = escape(l:value, '~')

    if l:value ==? s:blamer_user_name
      let l:value = 'You'
    elseif l:value ==? s:blamer_user_email
      let l:value = 'You'
    endif

    let l:info[l:property] = l:value
  endfor

  if l:result =~? 'Not committed yet'
    let l:info.author = 'You'
    let l:info.committer = 'You'
    let l:info.summary = 'Uncommitted changes'
  endif

  let l:message = s:blamer_template
  for field in s:blamer_info_fields
    let l:message = substitute(l:message, '\m\C<' . field . '>', l:info[field], 'g')
  endfor

  return l:message
endfunction

function! blamer#SetVirtualText(buffer_number, line_number, message) abort
  let l:line_index = a:line_number - 1
  call nvim_buf_set_virtual_text(a:buffer_number, s:blamer_namespace, l:line_index, [[s:blamer_prefix . a:message, 'Blamer']], {})
endfunction

function! blamer#Show() abort
  let l:file_path = expand('%:p')
  if s:IsFileInPath(l:file_path, s:git_root) == 0
    return
  endif

  let l:buffer_number = bufnr('')
	let l:line_numbers = s:GetLines()

	let l:is_in_visual_mode = len(l:line_numbers) > 1
	if l:is_in_visual_mode == 1 && s:blamer_show_in_visual_modes == 0
	  return
	endif

	for line_number in l:line_numbers
    let l:message = blamer#GetMessage(l:file_path, line_number, '+1')
    call blamer#SetVirtualText(l:buffer_number, line_number, l:message)
  endfor
endfunction

function! blamer#Hide() abort
  let l:current_buffer_number = bufnr('')
  call nvim_buf_clear_namespace(l:current_buffer_number, s:blamer_namespace, 0, -1)
endfunction

function! blamer#Refresh() abort
  if g:blamer_enabled == 0
    return
  endif

  call timer_stop(s:blamer_timer_id)
  call blamer#Hide()
  let s:blamer_timer_id = timer_start(s:blamer_delay, { tid -> blamer#Show() })
endfunction

function! blamer#Enable() abort
  if g:blamer_enabled == 1
    return
  endif

  let g:blamer_enabled = 1
  call blamer#Init()
endfunction

function! blamer#Disable() abort
  if g:blamer_enabled == 0
    return
  endif

  let g:blamer_enabled = 0
  autocmd! blamer
  call timer_stop(s:blamer_timer_id)
  let s:blamer_timer_id = -1
endfunction

function! blamer#Init() abort
  if g:blamer_enabled == 0
    return
  endif

  let l:result = split(system('git rev-parse --show-toplevel 2>/dev/null'), '\n')
  let s:git_root = s:Head(l:result)

  if s:git_root == ''
    let g:blamer_enabled = 0
    return
  endif

  let s:blamer_user_name = s:Head(split(system('git config --get user.name'), '\n'))
  let s:blamer_user_email = s:Head(split(system('git config --get user.email'), '\n'))

  augroup blamer
    autocmd!
    autocmd BufEnter,BufWritePost,CursorMoved * :call blamer#Refresh()
  augroup END
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
