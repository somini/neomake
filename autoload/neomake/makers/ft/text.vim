let s:slash = neomake#utils#Slash()
let s:languagetool_script = expand('<sfile>:p:h', 1).s:slash.'text'.s:slash.'languagetool.py'

function! s:getVar(varname, default) abort
    "TODO: Use neomake#utils#GetSetting
    return get(b:, a:varname, get(g:, a:varname, a:default))
endfunction

function! neomake#makers#ft#text#EnabledMakers() abort
    " No makers enabled by default, since text is used as fallback often.
    return []
endfunction

function! neomake#makers#ft#text#proselint() abort
    return {
          \ 'errorformat': '%W%f:%l:%c: %m',
          \ 'postprocess': function('neomake#postprocess#generic_length'),
          \ }
endfunction

function! neomake#makers#ft#text#PostprocessWritegood(entry) abort
    let a:entry.col += 1
    if a:entry.text[0] ==# '"'
      let matchend = match(a:entry.text, '\v^[^"]+\zs"', 1)
      if matchend != -1
        let a:entry.length = matchend - 1
      endif
    endif
endfunction

function! neomake#makers#ft#text#writegood() abort
    return {
                \ 'args': ['--parse'],
                \ 'errorformat': '%W%f:%l:%c:%m,%C%m,%-G',
                \ 'postprocess': function('neomake#makers#ft#text#PostprocessWritegood'),
                \ }
endfunction

let s:languagetool_fallback_language = 'auto'
" Public API: https://languagetool.org/api
let s:languagetool_fallback_server = 'http://localhost:8081'
function! s:fn_languagetool(_jobinfo) abort dict
    let l:args = []
    " Mandatory arguments
    let l:server = s:getVar('neomake_text_languagetool_server', s:languagetool_fallback_server)
    let l:language = s:getVar('neomake_text_languagetool_language',
                \ get(split(&spelllang, ','), 0, s:languagetool_fallback_language) )
    " Optional Arguments
    let motherTongue = s:getVar('neomake_text_languagetool_curl_motherTongue', v:null)
    if motherTongue != v:null
        let args += ['--motherTongue', motherTongue]
    endif
    let preferredVariants = s:getVar('neomake_text_languagetool_curl_preferredVariants', v:null)
    if l:preferredVariants != v:null && l:language ==# 'auto'
        for var in l:preferredVariants
            let args += ['--preferredVariants', var]
        endfor
    endif
    let l:args += [l:server, l:language]
    let self.args = l:args
endfunction

function! neomake#makers#ft#text#GetEntriesForOutput_Languagetool(context) abort
    let output = neomake#utils#JSONdecode(join(a:context.output, ''))
    call neomake#utils#DebugObject('output', output)
    let entries = []

    for _m in output
        let entry = _m
        let _m['bufnr'] = a:context.jobinfo.bufnr
        call add(entries, entry)
    endfor

    return entries
endfunction

function! neomake#makers#ft#text#languagetool() abort
        " \ 'supports_stdin': 1,
    return {
        \ 'exe': s:languagetool_script,
        \ 'fn': function('s:fn_languagetool'),
        \ 'append_file': 1,
        \ 'process_output': function('neomake#makers#ft#text#GetEntriesForOutput_Languagetool'),
        \ }
endfunction
