
"TODO:
" * BUG: Restore yank register when exiting
" * Zoom only in current window view:
"   - Floating
"   - Down/Up, like sneak/leap
" * Overload yank to copy without line numbers
" * Prevent undoing to empty buffer
" * Use record instead of separate __bufzoom variables
" * Preview:
"   - Open new tab, make vertical split, jump to file there (nomodifiable).
" * Auto-preview mode:
"   - Previews on every jump to next search (n/N)
" * Check for treesitter before calling TSBufDisable
" * Mode pulling text from all open buffers

"Readme (TODO):
"- Calling BufZoom in a zoomed buffer reuses the same space.

syn keyword BufZoomPattern containedIn=All
highlight BufZoomPattern ctermbg=237 ctermfg=254

fun! <SID>add_mappings()
  noremap <buffer> <cr> :call <SID>accept()<cr>
  noremap <buffer> <c-c> :call <SID>quit()<cr>
  noremap <buffer> f :call BufZoom()<cr>
  noremap <buffer> F :call BufZoom(@/)<cr>
  noremap <buffer> # *:call BufZoom(@/)<cr><cr>
  noremap <buffer> * *:call BufZoom(@/)<cr><cr>
  noremap <buffer> q :call <SID>quit()<cr>
  noremap <buffer> U :call <SID>zoom_from_start(@/)<cr>
  noremap <buffer> u :set modifiable<cr>:undo<cr>:set nomodifiable<cr>
  noremap <buffer> i :call <SID>accept()<cr>i
  noremap <buffer> a :call <SID>accept()<cr>a
  noremap <buffer> <c-r> :set modifiable<cr>:redo<cr>:set nomodifiable<cr>
endfun

fun! <SID>close()
  let original_modifiable = b:__bufzoom_original_modifiable
  let original_buflisted = b:__bufzoom_original_buflisted

  let name = fnameescape(bufname(b:__bufzoom_original_buffer_id))
  exec "buffer ".name

  let &modifiable = original_modifiable
  let &buflisted = original_buflisted
  match none
endfun

fun! <SID>quit()
  let view = b:__bufzoom_original_view
  call <SID>close()
  call setpos('.', view)
endfun

fun! <SID>accept()
  let __bufzoom_linenum = matchstr(getline("."), "^\\s*\\d\\+")+1
  call <SID>close()
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
  if !exists('b:__bufzoom_original_buffer_id')
    let ft=&ft
    let view = winsaveview()
    let content = getline(1, '$')
    let bufid=bufnr('%')

    let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufid
    let original_modifiable = &modifiable
    let original_buflisted = &buflisted
    set buflisted

    exec "edit ".bufName
    let b:__bufzoom_original_modifiable = original_modifiable
    let b:__bufzoom_original_buflisted = original_buflisted
    let b:__bufzoom_original_view = view
    let b:__bufzoom_original_buffer_id = bufid

    set modifiable
    set noreadonly
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nobuflisted
    call setline('.', content)
    call s:add_line_numbers()
    let b:__bufzoom_start_content = getline(1, '$')
    let b:__bufzoom_start_undo_seq = undotree().seq_cur
    let b:__bufzoom_undo_index = 0
    call <SID>add_mappings()
    exec "set ft=".l:ft

    if has('nvim')
      lua vim.diagnostic.enable(false, {bufnr = 0})
      "TODO: Check for treesitter
      silent! TSBufDisable highlight
    endif
  else
    set modifiable
    let b:__bufzoom_nested = 1
  endif

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
        call <SID>quit()
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
