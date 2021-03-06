let s:settings_dir = expand('<sfile>:h:h').'/settings'
let s:installer_dir = expand('<sfile>:h:h').'/installer'
let s:servers_dir = expand('<sfile>:h:h').'/servers'
let s:settings = json_decode(join(readfile(expand('<sfile>:h:h').'/settings.json'), "\n"))

function! s:executable(cmd) abort
  if executable(a:cmd)
    return 1
  endif
  let l:paths = get(g:, 'lsp_settings_extra_paths', '')
  if type(l:paths) == type([])
    let l:paths = join(l:paths, ',')
  endif
  let l:paths .= ',' . s:servers_dir . '/' . a:cmd
  if !has('win32')
    return !empty(globpath(l:paths, a:cmd))
  endif
  if !empty(globpath(l:paths, a:cmd . '.exe'))
    return 1
  endif
  if !empty(globpath(l:paths, a:cmd . '.cmd'))
    return 1
  endif
  if !empty(globpath(l:paths, a:cmd . '.bat'))
    return 1
  endif
  return 0
endfunction

function! s:vimlsp_installer() abort
  if !has_key(s:settings, &filetype)
    return ''
  endif
  let l:server = s:settings[&filetype]
  if empty(l:server)
    return ''
  endif
  let l:found = {}
  for l:conf in l:server
    let l:missing = 0
    for l:require in l:conf.requires
      if !s:executable(l:require)
        let l:missing = 1
        break
      endif
    endfor
    if l:missing ==# 0
      let l:found = l:conf
      break
    endif
  endfor
  if empty(l:found)
    return ''
  endif
  for l:conf in l:server
    let l:command = s:vimlsp_settings_get(l:conf.command, 'cmd', l:conf.command)
    if type(l:command) == type([])
      let l:command = l:command[0]
    endif
    let l:command = printf('%s/install-%s', s:installer_dir, l:command)
    if has('win32')
      let l:command = substitute(l:command, '/', '\', 'g') . '.cmd'
    else
      let l:command = l:command . '.sh'
    endif
    if s:executable(l:command)
      return l:command
    endif
  endfor
  return ''
endfunction

function! s:vimlsp_install_server() abort
  let l:command = s:vimlsp_installer()
  exe 'terminal' l:command
endfunction

function! s:vimlsp_settings_suggest() abort
  if empty(s:vimlsp_installer())
    return
  endif
  echomsg printf('If you want to enable Language Server, please do :LspInstallServer')
  command! -buffer LspInstallServer call s:vimlsp_install_server()
endfunction

function! s:vimlsp_settings_get(name, key, default) abort
  let l:config = get(g:, 'lsp_settings', {})
  if !has_key(l:config, a:name)
    if !has_key(l:config, '*')
      return a:default
    endif
    let l:config = l:config['*']
  else
    let l:config = l:config[a:name]
  endif
  if !has_key(l:config, a:key)
    return a:default
  endif
  return l:config[a:key]
endfunction

function! s:vimlsp_setting() abort
  for l:ft in keys(s:settings)
    if has_key(g:, 'lsp_settings_whitelist') && index(g:lsp_settings_whitelist, l:ft) == -1
      continue
    endif
    let l:found = 0
    if empty(s:settings[l:ft])
      continue
    endif
    for l:server in s:settings[l:ft]
      let l:command = s:vimlsp_settings_get(l:server.command, 'cmd', l:server.command)
      if type(l:command) == type([])
        let l:command = l:command[0]
      endif
      if s:executable(l:command)
        let l:script = printf('%s/%s.vim', s:settings_dir, l:server.command)
        if filereadable(l:script)
          exe 'source' l:script
          let l:found += 1
          break
        endif
      endif
    endfor
    if l:found ==# 0
      exe printf('augroup vimlsp_suggest_%s', l:ft)
        au!
        exe printf('autocmd FileType %s call s:vimlsp_settings_suggest()', l:ft)
      augroup END
    elseif !empty(s:vimlsp_installer())
      command! -buffer LspInstallServer call s:vimlsp_install_server()
    endif
  endfor
endfunction

call s:vimlsp_setting()
