
fun! BufZoom(searchString)
  let b:__bufsearch_start_pos = getpos('.')
  let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufnr('%')
  "redir @"
  let n=&number
  let ft=&ft
  %y
  exec "tabnew ".bufName
  exec "set ft=".l:ft
  set bt=nofile
  set modifiable
  normal! ggVgp
  %s/^/\=printf('%-7d', line('.')-1)
  silent! exec 'g/'.a:searchString.'/ --,++ s/^/__buf_search_uid/'
  silent! v/__buf_search_uid.*/s/.*//
  silent! g/^$/,/./-j
  ?.
  normal jdG
  silent! %s/\(__buf_search_uid\)*//
  silent! %s/^$/-----------------------------------------------------------------------------------------------------------------------------------------------------------/
  normal ggdd
  "normal gg2dd
  set nomodifiable
  set nobuflisted
  "exec "file '".bufName."'"
  exec 'match ColorColumn /\c'.a:searchString.'/'
  "let quitCmd = ":b #<cr>:bdelete! ".bufName."<cr>:close<cr>:call setpos('.', b:__bufsearch_start_pos)<cr>:match none<cr>"
  let quitCmd = ":close<cr>:call setpos('.', b:__bufsearch_start_pos)<cr>:match none<cr>"
  map <buffer> <cr> :let g:__bufzoom_linenum = matchstr(getline("."), "^\\s*\\d\\+")+1<cr>:close<cr>:silent exe g:__bufzoom_linenum<cr>:silent match none<cr>
  exec "map <buffer> <c-c> ".quitCmd
  exec "map <buffer> q ".quitCmd
endf
