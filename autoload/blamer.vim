scriptencoding utf-8

if exists('g:blamer_autoloaded')
  finish
endif
let g:blamer_autoloaded = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:blamer_prefix = get(g:, 'blamer_prefix', '   ')
let s:blamer_template = get(g:, 'blamer_template', '<author>, <author-time> • <summary>')
let s:blamer_date_format = get(g:, 'blamer_date_format', '%d/%m/%y %H:%M')
let s:blamer_user_name = ''
let s:blamer_user_email = ''
let s:blamer_info_fields = filter(map(split(s:blamer_template, ' '), {key, val -> matchstr(val, '\m\C<\zs.\{-}\ze>')}), {idx, val -> val != ''})
if exists('*nvim_create_namespace')
  let s:blamer_namespace = nvim_create_namespace('blamer')
endif
if exists('*prop_type_add')
  let s:prop_type_name = 'blamer_popup_marker'
endif
let s:blamer_delay = get(g:, 'blamer_delay', 1000)
let s:blamer_show_in_visual_modes = get(g:, 'blamer_show_in_visual_modes', 1)
let s:blamer_show_in_insert_modes = get(g:, 'blamer_show_in_insert_modes', 1)
let s:blamer_timer_id = -1
let s:blamer_relative_time = get(g:, 'blamer_relative_time', 0)

let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')
let s:missing_popup_feature = !has('nvim') && !exists('*popup_create')

let s:blamer_buffer_enabled = 0
let s:blamer_show_enabled = 0


function! s:GetRelativeTime(commit_timestamp) abort
  let l:current_timestamp = localtime()
  let l:elapsed = l:current_timestamp - a:commit_timestamp

  let l:minute_seconds = 60
  let l:hour_seconds = l:minute_seconds * 60
  let l:day_seconds = l:hour_seconds * 24
  let l:month_seconds = l:day_seconds * 30
  let l:year_seconds = l:month_seconds * 12

  " We have no info how long ago line saved
  if(l:elapsed == 0)
    return 'a while ago'
  endif

  let l:ToPlural = {word,number -> number > 1 ? word . 's' : word}
  let l:ToRelativeString = {time,divisor,time_word -> string(float2nr(round(time / divisor))) . l:ToPlural(' ' . time_word, float2nr(round(time / divisor))) . ' ago'}


  if l:elapsed < l:minute_seconds
    return l:ToRelativeString(l:elapsed,1,'second')
  elseif l:elapsed < l:hour_seconds
    return l:ToRelativeString(l:elapsed,60,'minute')
  elseif l:elapsed < l:day_seconds
    return l:ToRelativeString(l:elapsed,l:hour_seconds,'hour')
  elseif l:elapsed < l:month_seconds
    return l:ToRelativeString(l:elapsed,l:day_seconds,'day')
  elseif l:elapsed < l:year_seconds
    return l:ToRelativeString(l:elapsed,l:month_seconds,'month')
  else
    return l:ToRelativeString(l:elapsed,l:year_seconds,'year')
  endif

endfunction

function! s:Head(array) abort
  if len(a:array) == 0
    return ''
  endif

  return a:array[0]
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

function! blamer#CommitDataToMessage(commit_data) abort
  let l:message = s:blamer_template
  for field in s:blamer_info_fields
    let l:message = substitute(l:message, '\m\C<' . field . '>', a:commit_data[field], 'g')
  endfor
  return l:message
endfunction

function! blamer#ParseCommitDataLine(line) abort
  let l:info = {}
  let l:words = split(a:line, ' ')
  let l:property = l:words[0]
  let l:value = join(l:words[1:], ' ')
  if  l:property =~? 'time'
    if(s:blamer_relative_time)
      let l:value = s:GetRelativeTime(l:value)
    else
      let l:value = strftime(s:blamer_date_format, l:value)
    endif
  endif
  let l:value = escape(l:value, '&')
  let l:value = escape(l:value, '~')

  if l:value ==? s:blamer_user_name
    let l:value = 'You'
  elseif l:value ==? s:blamer_user_email
    let l:value = 'You'
  endif

  let l:info[l:property] = l:value
  return l:info
endfunction

function! blamer#GetMessages(file, line_number, line_count) abort
  let l:dir_path = shellescape(s:substitute_path_separator(expand('%:h')))
  let l:end_line = a:line_number + a:line_count - 1
  let l:file_path_escaped = shellescape(a:file)
  let l:command = 'git -C ' . l:dir_path . ' --no-pager blame --line-porcelain -L ' . a:line_number . ',' . l:end_line . ' -- ' . l:file_path_escaped
  let l:result = system(l:command)
  let l:lines = split(l:result, '\n')

  let hash = split(l:lines[0], ' ')[0]
  let l:hash_is_empty = empty(matchstr(hash,'\c[0-9a-f]\{40}'))

  if l:hash_is_empty
    if l:result =~? 'fatal' && l:result =~? 'not a git repository'
      " Not a git repository
      let g:blamer_buffer_enabled = 0
      echo '[blamer.nvim] Not a git repository'
      return ''
    endif

    " Known git errors will be silenced
    if l:result =~? 'no matches found'
      return ''
    elseif l:result =~? 'no such path'
      return ''
    elseif l:result =~? 'is outside repository'
      return ''
    elseif l:result =~? 'has only' && l:result =~? 'lines'
      return ''
    elseif l:result =~? 'no such ref'
      return ''
    endif

    " Echo unknown errors in order to catch them
    echo '[blamer.nvim] ' . l:result
    return ''
  endif

  let l:TAB_ASCII = 9
  let l:commit_data = {}
  let l:commit_data_per_line = []

  for line in l:lines[0:]
    let l:line_words = split(line, ' ')
    let l:is_line_hash = !empty(matchstr(l:line_words[0],'\c[0-9a-f]\{40}'))
    let l:has_line_tab = char2nr(l:line_words[0][0]) == l:TAB_ASCII

    if l:is_line_hash
      " line type HASH
      let l:commit_data = {
            \ 'commit-short': l:line_words[0][:7],
            \ 'commit-long': l:line_words[0]
            \ }
    elseif l:has_line_tab
      " line type TAB
      " Change messsage when changes are not commited
      if l:commit_data.author ==? 'Not Committed Yet'
        let l:commit_data.author = 'You'
        let l:commit_data.committer = 'You'
        let l:commit_data.summary = 'Uncommitted changes'
      endif
      let l:commit_data_per_line = add(l:commit_data_per_line,extend({},l:commit_data))
    else
      " line type COMMIT DATA
      let l:commit_data_chunk = blamer#ParseCommitDataLine(line)
      let l:commit_data = extend(l:commit_data,l:commit_data_chunk)
    endif
  endfor

  return map(l:commit_data_per_line,'blamer#CommitDataToMessage(v:val)')
endfunction

function! blamer#SetVirtualText(buffer_number, line_number, message) abort
  let l:line_index = a:line_number - 1
  call nvim_buf_set_virtual_text(a:buffer_number, s:blamer_namespace, l:line_index, [[s:blamer_prefix . a:message, 'Blamer']], {})
endfunction

function! blamer#CreatePopup(buffer_number, line_number, message) abort
  let l:col = strlen(getline(a:line_number))
  let l:col = l:col == 0 ? 1 : l:col
  let l:propid = a:line_number . l:col

  if empty(prop_type_get(s:prop_type_name, {'bufnr': a:buffer_number}))
    call prop_type_add(s:prop_type_name, {'bufnr': a:buffer_number})
  endif

  call prop_add(a:line_number, l:col, {
  \ 'type': s:prop_type_name,
  \ 'bufnr': a:buffer_number,
  \ 'length': 0,
  \ 'id': l:propid,
  \})

  call popup_create(s:blamer_prefix . a:message, {
  \ 'textprop': 'blamer_popup_marker',
  \ 'textpropid': l:propid,
  \ 'line': -1,
  \ 'col': l:col == 1 ? 1 : 2,
  \ 'fixed': 1,
  \ 'wrap': 0,
  \ 'highlight': 'Blamer'
  \})
endfunction

function! blamer#Show() abort
  if g:blamer_enabled == 0 || s:missing_popup_feature
    return
  endif

  let l:is_buffer_special = &buftype !=# '' ? 1 : 0
  if l:is_buffer_special
    return
  endif

  let l:file_path = s:substitute_path_separator(expand('%:p'))

  if empty(l:file_path) 
    return
  endif

  let l:buffer_number = bufnr('')
	let l:line_numbers = s:GetLines()

	let l:is_in_visual_mode = len(l:line_numbers) > 1
	if l:is_in_visual_mode == 1 && s:blamer_show_in_visual_modes == 0
	  return
	endif

  let l:line_count = len(l:line_numbers)
  let l:messages = blamer#GetMessages(l:file_path, l:line_numbers[0], l:line_count)
  let l:index = 0

	for line_number in l:line_numbers
    let l:message = l:messages[l:index]
    if has('nvim')
      call blamer#SetVirtualText(l:buffer_number, line_number, l:message)
    else
      call blamer#CreatePopup(l:buffer_number, line_number, l:message)
    endif
    let l:index += 1
  endfor
endfunction

function! blamer#Hide() abort
  let l:current_buffer_number = bufnr('')
  if has('nvim')
    call nvim_buf_clear_namespace(l:current_buffer_number, s:blamer_namespace, 0, -1)
  else
    if !empty(prop_type_get(s:prop_type_name, {'bufnr': l:current_buffer_number}))
      call prop_remove({
      \ 'type': s:prop_type_name,
      \ 'bufnr': l:current_buffer_number,
      \ 'all': 1,
      \})
    endif
  endif
endfunction

function! blamer#UpdateGitUserConfig() abort
  let l:dir_path = shellescape(s:substitute_path_separator(expand('%:h')))
  let s:blamer_user_name = s:Head(split(system('git -C ' . l:dir_path . ' config --get user.name'), '\n'))
  let s:blamer_user_email = s:Head(split(system('git -C ' . l:dir_path . ' config --get user.email'), '\n'))
endfunction


function! blamer#IsBufferGitTracked() abort
  let l:file_path = shellescape(s:substitute_path_separator(expand('%:p')))
  if empty(l:file_path) 
    return 0
  endif

  let l:dir_path = shellescape(s:substitute_path_separator(expand('%:h')))
  let l:result = system('git -C ' . l:dir_path . ' ls-files --error-unmatch ' . l:file_path)
  if l:result[0:4] ==# 'fatal'
    return 0
  endif

  return 1
endfunction

function! blamer#BufferEnter() abort
  if g:blamer_enabled == 0
    return
  endif

  let l:is_tracked = blamer#IsBufferGitTracked()
  if l:is_tracked
    let s:blamer_buffer_enabled = 1
    call blamer#UpdateGitUserConfig()
    call blamer#EnableShow()
  else
    let s:blamer_buffer_enabled = 0
  endif
endfunction

function! blamer#BufferLeave() abort
  if g:blamer_enabled == 0
    return
  endif

  call blamer#DisableShow()
endfunction

function! blamer#Refresh() abort
  if g:blamer_enabled == 0 || s:blamer_buffer_enabled == 0 || s:blamer_show_enabled == 0
    return
  endif

  call timer_stop(s:blamer_timer_id)
  call blamer#Hide()
  let s:blamer_timer_id = timer_start(s:blamer_delay, { tid -> blamer#Show() })
endfunction

function! blamer#Enable() abort
  let g:blamer_enabled = 1
endfunction

function! blamer#Disable() abort
  let g:blamer_enabled = 0
endfunction

function! blamer#EnableShow() abort
  if g:blamer_enabled == 0 || s:blamer_buffer_enabled == 0 || s:blamer_show_enabled == 1
    return
  endif

  let s:blamer_show_enabled = 1
  call blamer#Show()
endfunction

function! blamer#DisableShow() abort
  if g:blamer_enabled == 0 || s:blamer_buffer_enabled == 0 || s:blamer_show_enabled == 0
    return
  endif

  let s:blamer_show_enabled = 0
  call timer_stop(s:blamer_timer_id)
  let s:blamer_timer_id = -1
  call blamer#Hide()
endfunction

function! blamer#Init() abort
  if g:blamer_enabled == 0
    return
  endif

  if g:blamer_is_initialized == 1
    return
  endif
  let g:blamer_is_initialized = 1

  if s:missing_popup_feature
    echohl ErrorMsg
    echomsg '[blamer.nvim] Needs popup feature.'
    echohl None
    return
  endif

  augroup blamer
    autocmd!
    autocmd BufEnter * :call blamer#BufferEnter()
    autocmd BufLeave * :call blamer#BufferLeave()
    autocmd BufEnter,BufWritePost,CursorMoved * :call blamer#Refresh()
    if s:blamer_show_in_insert_modes == 0
      autocmd InsertEnter * :call blamer#DisableShow()
      autocmd InsertLeave * :call blamer#EnableShow()
    endif
  augroup END
endfunction

" from neomru
function! s:substitute_path_separator(path) abort
  return s:is_windows ? substitute(a:path, '\\', '/', 'g') : a:path
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
