if exists('g:blamer_autoloaded')
  finish
endif
let g:blamer_autoloaded = 1

let s:save_cpo = &cpo
set cpo&vim

let s:blamer_prefix = get(g:, 'blamer_prefix', '   ')
let s:blamer_template = get(g:, 'blamer_template', '<committer>, <committer-time> • <summary>')
let s:blamer_user_name = split(system('git config --get user.name'), '\n')[0]
let s:blamer_user_email = split(system('git config --get user.email'), '\n')[0]
let s:blamer_info_fields = filter(map(split(s:blamer_template, ' '), {key, val -> matchstr(val, '\m\C<\zs.\{-}\ze>')}), {idx, val -> val != ''})
let s:blamer_namespace = nvim_create_namespace('blamer')

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

  let l:lines = split(l:result, '\n')
  let l:info = {}
  for line in l:lines
    let l:words = split(line, ' ')
    let l:property = l:words[0]
    let l:value = join(l:words[1:], ' ')
    if  l:property =~? 'time'
      let l:value = strftime('%d/%m/%y %H:%M', l:value)
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

function! blamer#SetVirtualText(line_number, message) abort
  let l:buffer_number = bufnr('')
  let l:line_index = a:line_number - 1
  call nvim_buf_set_virtual_text(l:buffer_number, s:blamer_namespace, l:line_index, [[s:blamer_prefix . a:message, 'Blamer']], {})
endfunction

function! blamer#Show() abort
  let l:file = expand('%')
  if l:file == ''
    return
  endif

	let l:line_numbers = s:GetLines()
	for line_number in l:line_numbers
    let l:message = blamer#GetMessage(l:file, line_number, '+1')
    call blamer#SetVirtualText(line_number, l:message)
  endfor
endfunction

function! blamer#Hide() abort
  let l:current_buffer_number = bufnr('')
  call nvim_buf_clear_namespace(l:current_buffer_number, s:blamer_namespace, 0, -1)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
