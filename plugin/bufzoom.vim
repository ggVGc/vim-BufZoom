
"TODO:
" - Prevent undoing to empty buffer
" - Use record instead of separate __bufzoom variables
" - Preview:
"   - Open new tab, make vertical split, jump to file there (nomodifiable).
" - Auto-preview mode:
"   - Previews on every jump to next search (n/N)
" - Check for treesitter before calling TSBufDisable
" - Bug:
"   - Open buffer in split
"   - Use Zoom in right pane
"   - AccepLine jumps to the left pane

"Readme (TODO):
"- Calling BufZoom in a zoomed buffer reuses the same space.

syn keyword BufZoomPattern containedIn=All
highlight BufZoomPattern ctermbg=237 ctermfg=254

fun! <SID>add_mappings()
  noremap <buffer> <cr> :call <SID>acceptLine()<cr>
  noremap <buffer> <c-c> :call <SID>quitZoomBuf()<cr>
  noremap <buffer> f :call BufZoom()<cr>
  noremap <buffer> F :call BufZoom(@/)<cr>
  noremap <buffer> # *:call BufZoom(@/)<cr><cr>
  noremap <buffer> * *:call BufZoom(@/)<cr><cr>
  noremap <buffer> q :call <SID>quitZoomBuf()<cr>
  noremap <buffer> u :set modifiable<cr>:undo<cr>:set nomodifiable<cr>
  noremap <buffer> U :call <SID>zoom_from_start(@/)<cr>
  noremap <buffer> <c-r> :set modifiable<cr>:redo<cr>:set nomodifiable<cr>
endfun

fun! <SID>doClose()
  let __bufzoom_goto_buf=b:__bufzoom_bufid
  let id = bufnr('%')
  bprev
  let name = fnameescape(bufname(__bufzoom_goto_buf))
  exec "drop ".name

  let &modifiable = b:__bufzoom_original_modifiable
  match none
  return id
endfun

fun! <SID>quitZoomBuf()
  let id= <SID>doClose()
  call setpos('.', b:__bufzoom_original_view)
endfun

fun! <SID>acceptLine()
  let __bufzoom_linenum = matchstr(getline("."), "^\\s*\\d\\+")+1
  let id= <SID>doClose()
  silent exe __bufzoom_linenum
  normal! zt
endfun

fun! Zoom(searchString)
  set modifiable
  " Add extra lines to prevent cutoff of results at end of file
  call append(line('$'), "")
  call append(line('$'), "")
  call append(line('$'), "")
  silent! exec 'g/'.a:searchString.'/ --,++ s/^/__buf_search_uid/'
  silent! v/__buf_search_uid.*/s/.*//
  silent! g/^$/,/./-j
  silent! ?.
  silent! normal! jdG
  silent! %s/\(__buf_search_uid\)*//
  silent! %s/^$/-----------------------------------------------------------------------------------------------------------------------------------------------------------/
  normal! ggdd
  silent! %s/\s*$//g
endf

fun! <SID>update(query)
  set modifiable
  silent exec "u ".b:__bufzoom_undo_seq
  echo "Zoom: " . a:query
  if a:query != ''
    let patterns = split(a:query, " ")
    for pattern in patterns
      silent call Zoom(pattern)
    endfor
    match none

    let match_pattern = join(patterns[:-2], "\\|")

    if len(patterns) > 1
      exec 'match BufZoomPattern /'.match_pattern.'/'
    endif
    normal! gg
    let @/=patterns[-1]
    silent! normal! n
  else
    let @/=""
    silent! call winrestview(b:__bufzoom_view)
  endif
  redraw!
endfun

fun! s:goto_undo()
  exec "u ".b:__bufzoom_undo_seqs[-(b:__bufzoom_undo_index + 1)]
endfun


fun! <SID>zoom_from_start(query)
  "silent exec "u ".b:__bufzoom_start_undo_seq
  set modifiable
  silent call deletebufline('', 1, '$')
  silent call setline('.', b:__bufzoom_start_content)
  call BufZoom(a:query)
endfun


fun! s:add_line_numbers()
  silent! %s/^/\=printf('%-7d', line('.')-1)
endfun

function! BufZoom(...)
  let view = winsaveview()
  let b:__bufzoom_original_view = view
  let b:__bufzoom_original_modifiable = &modifiable
  let content = getline(1, '$')
  let bufid=bufnr('%')
  let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufid
  let ft=&ft

  if !exists('b:__bufzoom_bufid')
    exec "edit ".bufName
    call setline('.', content)
    call s:add_line_numbers()
    let b:__bufzoom_start_content = getline(1, '$')
    let b:__bufzoom_start_undo_seq = undotree().seq_cur
    let b:__bufzoom_undo_index = 0
    let b:__bufzoom_bufid=bufid
    setlocal bufhidden=delete
    call <SID>add_mappings()
    exec "set ft=".l:ft
    set bt=nofile

    if has('nvim')
      lua vim.diagnostic.enable(false, {bufnr = 0})
      "TODO: Check for treesitter
      TSBufDisable highlight
    endif
  else
    set modifiable
    let b:__bufzoom_nested = 1
  endif

  let b:__bufzoom_view = view
  let b:__bufzoom_undo_seq = undotree().seq_cur

  let query = get(a:, 1, '')

  let c = ''
  while 1
    set modifiable
    call <SID>update(query)
    let keyCode = getchar()
    let c = nr2char(keyCode)

    if c == "\<esc>"
      if !exists('b:__bufzoom_nested')
        call <SID>quitZoomBuf()
      else
        set nomodifiable
      end
      break

    elseif c == "\<cr>"
      set nomodifiable
      break

    elseif keyCode == 23 "CTRL-W
      let patterns = split(query, " ")
      let query = join(patterns[:-2], " ")
      if query != ""
        let query .= " "
      endif

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

command -nargs=? BufZoom call BufZoom("<args>")
