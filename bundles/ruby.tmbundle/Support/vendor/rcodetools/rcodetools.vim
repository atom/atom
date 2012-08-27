" Copyright (C) 2006    Mauricio Fernandez <mfp@acm.org>
" rcodetools support plugin
"

if exists("loaded_rcodetools")
    finish
endif

let loaded_rcodetools = 1
let s:save_cpo = &cpo
set cpo&vim

"{{{ set s:sid

map <SID>xx <SID>xx
let s:sid = maparg("<SID>xx")
unmap <SID>xx
let s:sid = substitute(s:sid, 'xx', '', '')

"{{{ function: s:spellgetoption(name, default)
" grab a user-specified option to override the default provided.  options are
" searched in the window, buffer, then global spaces.
function! s:GetOption(name, default)
    if exists("w:{&filetype}_" . a:name)
        execute "return w:{&filetype}_".a:name
    elseif exists("w:" . a:name)
        execute "return w:".a:name
    elseif exists("b:{&filetype}_" . a:name)
        execute "return b:{&filetype}_".a:name
    elseif exists("b:" . a:name)
        execute "return b:".a:name
    elseif exists("g:{&filetype}_" . a:name)
        execute "return g:{&filetype}_".a:name
    elseif exists("g:" . a:name)
        execute "return g:".a:name
    else
        return a:default
    endif
endfunction

"{{{ IsOptionSet
function! s:IsOptionSet(name)
    let bogus_val = "df hdsoi3y98 hjsdfhdkj"
    return s:GetOption(a:name, bogus_val) == bogus_val ? 0 : 1
endfunction


"{{{ RCT_completion function

let s:last_test_file = ""
let s:last_test_lineno = 0

let s:rct_completion_col = 0
let s:rct_tmpfile = ""

function! <SID>RCT_command_with_test_options(cmd)
    if s:last_test_file != ""
	return a:cmd .
		    \ "-" . "-filename='" . expand("%:p") . "' " .
		    \ "-t '" . s:last_test_file . "@" . s:last_test_lineno . "' "
    endif
    return a:cmd
endfunction

function! <SID>RCT_completion(findstart, base)
    if a:findstart
	let s:rct_completion_col = col('.') - 1
	let s:rct_tmpfile = "tmp-rcodetools" . strftime("Y-%m-%d-%H-%M-%S.rb")
        silent exec ":w " . s:rct_tmpfile
	return strridx(getline('.'), '.', col('.')) + 1
    else
	let line    = line('.')
	let column  = s:rct_completion_col

	let command = "rct-complete --completion-class-info --dev --fork --line=" .
		    \ line . " --column=" . column . " "
	let command = <SID>RCT_command_with_test_options(command) . s:rct_tmpfile

	let data = split(system(command), '\n')

	for dline in data
	    let parts    = split(dline, "\t")
	    let name     = get(parts, 0)
	    let selector = get(parts, 1)
	    echo name
	    echo selector
	    if s:GetOption('rct_completion_use_fri', 0) && s:GetOption('rct_completion_info_max_len', 20) >= len(data)
		let fri_data = system('fri -f plain ' . "'" .  selector . "'" . ' 2>/dev/null')
		call complete_add({'word': name,
			        \  'menu': get(split(fri_data), 2, ''),
			        \  'info': fri_data } )
	    else
		call complete_add(name)
	    endif
	    if complete_check()
		break
	    endif
	endfor

	call delete(s:rct_tmpfile)
	return []
    endif
endfunction

"{{{ ri functions

function! <SID>RCT_new_ri_window()
  execute "new"
  execute "set bufhidden=delete buftype=nofile noswapfile nobuflisted"
  execute 'nmap <buffer><silent> <C-T> 2u'
  execute 'nmap <buffer><silent> <C-]> :call' . s:sid . 'RCT_execute_ri(expand("<cWORD>"))<cr>'
endfunction

function! <SID>RCT_execute_ri(query_term)
  silent %delete _
  let term = matchstr(a:query_term, '\v[^,.;]+')
  let cmd = s:GetOption("RCT_ri_cmd", "fri -f plain ")
  let text = system(cmd . "'" . term . "'")
  call append(0, split(text, "\n"))
  normal gg
endfunction

function! RCT_find_tag_or_ri(fullname)
    " rubikitch: modified for rtags-compatible tags
    let tagname = '::' . a:fullname
    let tagresults = taglist(tagname)
    if len(tagresults) != 0
	execute "tjump " . tagname
    else
        call <SID>RCT_new_ri_window()
        call <SID>RCT_execute_ri(a:fullname)
    endif
endfunction

function! <SID>RCT_smart_ri()
  let tmpfile = "tmp-rcodetools" . strftime("Y-%m-%d-%H-%M-%S.rb")
  silent exec ":w " . tmpfile

  let line    = line('.')
  let column  = col('.') - 1
  let command = "rct-doc --ri-vim --line=" . line . " --column=" . column . " "
  let command = <SID>RCT_command_with_test_options(command) . tmpfile
  "let term = matchstr(system(command), "\\v[^\n]+")
  exec system(command)
  call delete(tmpfile)
  "call RCT_find_tag_or_ri(term)
endfunction

function! <SID>RCT_ruby_toggle()
  let curr_file = expand("%:p")
  let cmd = "ruby -S ruby-toggle-file " . curr_file
  if match(curr_file, '\v_test|test_') != -1
      let s:last_test_file = curr_file
      let s:last_test_lineno = line(".")
  endif
  let dest = system(cmd)
  silent exec ":w"
  exec ("edit " . dest)
  silent! normal g;
endfunction

"{{{ bindings and au

if v:version >= 700
    execute "au Filetype ruby setlocal completefunc=" . s:sid . "RCT_completion"
endif
execute 'au Filetype ruby nmap <buffer><silent> <C-]> :exec "call ' .
         \ 'RCT_find_tag_or_ri(''" . expand("<cword>") . "'')"<cr>'
execute 'au Filetype ruby nmap <buffer><silent>' . s:GetOption("RCT_ri_binding", "<LocalLeader>r") .
        \ ' :call ' .  s:sid . 'RCT_smart_ri()<cr>'
execute 'au Filetype ruby nmap <buffer><silent>' . s:GetOption("RCT_toggle_binding", "<LocalLeader>t") .
        \ ' :call ' .  s:sid . 'RCT_ruby_toggle()<cr>'
let &cpo = s:save_cpo
