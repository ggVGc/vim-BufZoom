
"TODO:
" - Content stack instead of one level. Map ctrl-o/u.
" - Reuse original buffer instead of opening tab (option)


"Readme (TODO):
"- Calling BufZoom in a zoomed buffer reuses the same space.

syn keyword BufZoomPattern containedIn=All
highlight BufZoomPattern ctermbg=237 ctermfg=254

fun! <SID>doClose()
  if exists('b:__bufzoom_bufid')
    let @/ = b:__bufzoom_original_search
  end

  let __bufzoom_goto_buf=b:__bufzoom_bufid
  let id = bufnr('%')
  close
  let name = fnameescape(bufname(__bufzoom_goto_buf))
  exec "drop ".name

  set modifiable
  let &modifiable = b:__bufzoom_original_modifiable
  match none
  return id
endfun

fun! <SID>quitZoomBuf()
  let id= <SID>doClose()
  call setpos('.', b:__bufzoom_start_pos)
  "exec "bdelete! ".id
endfun

fun! <SID>acceptLine()
  let __bufzoom_linenum = matchstr(getline("."), "^\\s*\\d\\+")+1
  let id= <SID>doClose()
  silent exe __bufzoom_linenum
  normal zt
  "exec "bdelete! ".id
endfun

fun! Zoom(searchString, nested)
  set modifiable
  " Add extra lines to prevent cutoff of results at end of file
  call append(line('$'), "")
  call append(line('$'), "")
  call append(line('$'), "")
  if !a:nested
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
endf

fun! <SID>update(query)
  set modifiable
  %d
  call setline('.', b:__bufzoom_content)
  echo "Zoom: " . a:query
  if a:query != ''
    let patterns = split(a:query, " ")
    let index = 0
    for pattern in patterns
      let with_numbers = exists('b:__bufzoom_nested') || index > 0
      let index += 1
      silent call Zoom(pattern, with_numbers)
    endfor
    match none

    let match_pattern = join(patterns[:-2], "\\|")

    if len(patterns) > 1
      exec 'match BufZoomPattern /'.match_pattern.'/'
    endif
    normal gg
    let @/=patterns[-1]
    silent! normal n
  else
    let @/=""
    call setpos('.', b:__bufzoom_position)
  endif
  redraw!
endfun


fun! <SID>add_mappings()
  noremap <buffer> <cr> :call <SID>acceptLine()<cr>
  noremap <buffer> <c-c> :call <SID>quitZoomBuf()<cr>
  noremap <buffer> q :call <SID>quitZoomBuf()<cr>
  noremap <buffer> u :call <SID>update('')<cr>
  noremap <buffer> # *:call BufZoom(@/)<cr><cr>
endfun

function! BufZoom(...)
  let position = getpos('.')
  let b:__bufzoom_start_pos = position
  let b:__bufzoom_original_modifiable = &modifiable
  let content = getline(1, '$')
  let bufid=bufnr('%')
  let bufName="[Zoom]".fnamemodify(bufname('%'), ':t')." ".bufid
  let ft=&ft

  if !exists('b:__bufzoom_bufid')
    exec "tabnew ".bufName
    set modifiable
    let b:__bufzoom_bufid=bufid
    let b:__bufzoom_original_search = @/
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

  let b:__bufzoom_position = position
  let b:__bufzoom_content = content
  call setline('.', content)

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

command -nargs=? BufZoom call BufZoom("<args>")
