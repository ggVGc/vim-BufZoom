fun! <SID>doClose()
  let __bufzoom_goto_buf=b:__bufzoom_bufid
  let id = bufnr('%')
  close
  let name = fnameescape(bufname(__bufzoom_goto_buf))
  exec "drop ".name
  return id
endfun

fun! <SID>quitZoomBuf()
  let id= <SID>doClose()
  call setpos('.', b:__bufzoom_start_pos)
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

fun! Zoom(searchString)
  if !exists('b:__bufzoom_nested')
    silent! %s/^/\=printf('%-7d', line('.')-1)
  endif
  silent! exec 'g/'.a:searchString.'/ --,++ s/^/__buf_search_uid/'
  silent! v/__buf_search_uid.*/s/.*//
  silent! g/^$/,/./-j
  silent! ?.
  silent! normal jdG
  silent! %s/\(__buf_search_uid\)*//
  silent! %s/^$/-----------------------------------------------------------------------------------------------------------------------------------------------------------/
  normal ggdd
  silent! %s/\s*$//g
  "nohlsearch
  "exec 'match ColorColumn /\c'.a:searchString.'/'
endf

fun! <SID>update(query)
  %d
  call setline('.', b:__bufzoom_content)
  if a:query != ''
    silent call Zoom(a:query)
  endif
  normal gg
  echo "Zoom: " . a:query
  let @/=a:query
  redraw!
endfun


function! BufZoom()
  let content = getline(1, '$')
  let b:__bufzoom_start_pos = getpos('.')
  let bufid=bufnr('%')
  let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufid
  let ft=&ft

  if !exists('b:__bufzoom_bufid')
    exec "tabnew ".bufName
    let b:__bufzoom_bufid=bufid
    map <buffer> <cr> :call <SID>acceptLine()<cr>
    map <buffer> <c-c> :call <SID>quitZoomBuf()<cr>
    map <buffer> q :call <SID>quitZoomBuf()<cr>
    map <buffer> u :call <SID>update('')<cr>

    exec "set ft=".l:ft
    set bt=nofile
    set modifiable
  else
    let b:__bufzoom_nested = 1
  endif

  let b:__bufzoom_content = content
  call setline('.', content)

  let query = ''

  let c = ''
  while 1
    call <SID>update(query)
    let keyCode = getchar()
    let c = nr2char(keyCode)

    if c == "\<esc>"
      call <SID>quitZoomBuf()
      break

    elseif c == "\<cr>"
      break

    elseif keyCode == 23 "CTRL-W
      let query = ''

    elseif keyCode is# "\<BS>"
      if query != ''
        let query = query[:-2]
      endif
    else
      let query .= c
    endif
  endwhile
  redraw!
endfunction

command! BufZoom call BufZoom()
