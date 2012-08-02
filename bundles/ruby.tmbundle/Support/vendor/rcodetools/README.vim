
Copy rcodetools.vim to your plugin directory (typically $HOME/.vim/plugin) in
order to enable accurate code completion, quick RI execution and exact tag
jumping.

Switching between implementation and test files
===============================================
The <localleader>t binding (by default \t) will call ruby-toggle-file to
switch from test to implementation and vice versa. Moreover, when you switch
from the test to the implementation, rcodetools will remember which test
you were editing (based on the cursor position), and call it as needed for
advanced code completion or precise RI documentation, as documented below.

The actual binding can be changed in your .vimrc as follows:
 let g:RCT_toggle_binding="<C-X><C-t>"  " use ^X^T to go test <=> implementation

Code completion
===============
rcodetools.vim redefines user-defined completion for Ruby programs, so you can
use the intelligent, 100%-accurate completion with <C-X><C-U> in insert mode.
Note that this runs the code to obtain the exact candidate list.

If you've set completeopt to menu,preview then rcodetools.vim can display
information about the completion candidates. The menu will show the synopsis 
as given in the RI documentation, and the preview window will contain the full
RI documentation.

This functionality relies on fri for quick lookups. It can be enabled by setting

  let g:rct_completion_use_fri = 1  " 0 by default (disabled)

in your .vimrc (don't forget to run fastri-server too). 
Obtaining the documentation for many candidates can be slow, so you can set
the threshold above which additional documentation will not be shown with

 " 20 by default, about a couple secs max wait on a normal machine
  let g:rct_completion_info_max_len = 20 

Quick RI documentation and exact tag jumping
============================================
When you're editing a Ruby file, <C-]> will jump to the definition of the
chosen element if found in the TAGS file; otherwise, it will call RI and show
the documentation in a new window.
You can specify the RI executable to use by adding something like
    let g:RCT_ri_cmd = "ri -T -f plain "
to your .vimrc. (rcodetools.vim also honors b:RCT_RI_cmd and w:RCT_RI_cmd if set).
By default, "fri -f plain " will be used. fri (FastRI) is an improved RI
documentation browser, which features more intelligent search modes, gem
integration, vastly better performance... You can find it at
http://eigenclass.org/hiki.rb?fastri  and it's also available in gem format
gem install fastri

If you want to call RI for the word the cursor is on (instead of jumping to
the definition if found), you can use this binding:
 <LocalLeader>r   (\r by default if you haven't changed your localleader)
You can specify another binding in your .vimrc as follows:
 let g:RCT_ri_binding="<C-X><C-R>" " use ^X^R to call vim on current word

Using xmpfilter
===============
xmpfilter takes code from stdin and outputs to stdout so you can filter
your code with ! as usual. 

If you use xmpfilter often, you might want to use mappings like the
following, which allow you to:
* add annotations
* expand assertions
* insert/remove # => markers



" plain annotations
map <silent> <F10> !xmpfilter -a<cr>
nmap <silent> <F10> V<F10>
imap <silent> <F10> <ESC><F10>a

" Test::Unit assertions; use -s to generate RSpec expectations instead
map <silent> <S-F10> !xmpfilter -u<cr>
nmap <silent> <S-F10> V<S-F10>
imap <silent> <S-F10> <ESC><S-F10>a

" Annotate the full buffer
" I actually prefer ggVG to %; it's a sort of poor man's visual bell 
nmap <silent> <F11> mzggVG!xmpfilter -a<cr>'z
imap <silent> <F11> <ESC><F11>

" assertions
nmap <silent> <S-F11> mzggVG!xmpfilter -u<cr>'z
imap <silent> <S-F11> <ESC><S-F11>a

" Add # => markers
vmap <silent> <F12> !xmpfilter -m<cr>
nmap <silent> <F12> V<F12>
imap <silent> <F12> <ESC><F12>a

" Remove # => markers
vmap <silent> <S-F12> ms:call RemoveRubyEval()<CR>
nmap <silent> <S-F12> V<S-F12>
imap <silent> <S-F12> <ESC><S-F12>a


function! RemoveRubyEval() range
  let begv = a:firstline
  let endv = a:lastline
  normal Hmt
  set lz
  execute ":" . begv . "," . endv . 's/\s*# \(=>\|!!\).*$//e'
  normal 'tzt`s
  set nolz
  redraw
endfunction
