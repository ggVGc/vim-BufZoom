fun! <SID>doClose()
  let __bufsearch_goto_buf=b:__bufsearch_bufid
  let id = bufnr('%')
  close
  let name = fnameescape(bufname(__bufsearch_goto_buf))
  exec "drop ".name
  return id
endfun

fun! <SID>quitZoomBuf()
  let id= <SID>doClose()
  call setpos('.', b:__bufsearch_start_pos)
  match none
  exec "bdelete! ".id
endfun

fun! <SID>acceptLine()
  let __bufzoom_linenum = matchstr(getline("."), "^\\s*\\d\\+")+1
  let id= <SID>doClose()
  silent exe __bufzoom_linenum
  silent match none
  exec "bdelete! ".id
endfun

fun! BufZoom(searchString)
  let bufid=bufnr('%')
  let n=&number
  let ft=&ft
  %y
  let b:__bufsearch_start_pos = getpos('.')
  let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufid
  exec "tabnew ".bufName
  let b:__bufsearch_bufid=bufid
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
  map <buffer> <cr> :call <SID>acceptLine()<cr>
  map <buffer> <c-c> :call <SID>quitZoomBuf()<cr>
  map <buffer> q :call <SID>quitZoomBuf()<cr>
endf
