" Mustache & Handlebars syntax
" Language:	Mustache, Handlebars
" Maintainer:	Juvenn Woo <machese@gmail.com>
" Screenshot:   http://imgur.com/6F408
" Version:	2
" Last Change:  Oct 10th 2015
" Remarks: based on eruby indent plugin by tpope
" References:
"   [Mustache](http://github.com/defunkt/mustache)
"   [Handlebars](https://github.com/wycats/handlebars.js)
"   [ctemplate](http://code.google.com/p/google-ctemplate/)
"   [ctemplate doc](http://google-ctemplate.googlecode.com/svn/trunk/doc/howto.html)
"   [et](http://www.ivan.fomichev.name/2008/05/erlang-template-engine-prototype.html)

if exists("b:did_indent_hbs")
  finish
endif

unlet! b:did_indent
setlocal indentexpr=

runtime! indent/html.vim
unlet! b:did_indent

" Force HTML indent to not keep state.
let b:html_indent_usestate = 0

if &l:indentexpr == ''
  if &l:cindent
    let &l:indentexpr = 'cindent(v:lnum)'
  else
    let &l:indentexpr = 'indent(prevnonblank(v:lnum-1))'
  endif
endif
let b:handlebars_subtype_indentexpr = &l:indentexpr

let b:did_indent = 1
let b:did_indent_hbs = 1

setlocal indentexpr=GetHandlebarsIndent()
setlocal indentkeys=o,O,*<Return>,<>>,{,},0),0],o,O,!^F,=end,=else,=elsif,=rescue,=ensure,=when

" Only define the function once.
if exists("*GetHandlebarsIndent")
  finish
endif

function! GetHandlebarsIndent(...)
  " The value of a single shift-width
  if exists('*shiftwidth')
    let sw = shiftwidth()
  else
    let sw = &sw
  endif

  if a:0 && a:1 == '.'
    let v:lnum = line('.')
  elseif a:0 && a:1 =~ '^\d'
    let v:lnum = a:1
  endif
  let vcol = col('.')
  call cursor(v:lnum,1)
  call cursor(v:lnum,vcol)
  exe "let ind = ".b:handlebars_subtype_indentexpr

  " Workaround for Andy Wokula's HTML indent. This should be removed after
  " some time, since the newest version is fixed in a different way.
  if b:handlebars_subtype_indentexpr =~# '^HtmlIndent('
  \ && exists('b:indent')
  \ && type(b:indent) == type({})
  \ && has_key(b:indent, 'lnum')
    " Force HTML indent to not keep state
    let b:indent.lnum = -1
  endif
  let plnum = prevnonblank(v:lnum-1)
  let pline = getline(plnum)
  let cline = getline(v:lnum)

  " all indent rules only apply if the block opening/closing
  " tag is on a separate line

  " check for a hanging attribute
  let last_plnum_col = col([plnum, '$']) - 1
  if synIDattr(synID(plnum, last_plnum_col, 1), "name") =~ '^mustache'
    let hanging_attribute_pattern = '{{\#\=\%(\k\|[/-]\)\+\s\+\zs\k\+='
    let just_component_pattern = '^\s*{{\%(\k\|[/-]\)\+\s*$'

    if pline =~ hanging_attribute_pattern
      " {{component attribute=value
      "             other=value}}
      let [line, col] = searchpos(hanging_attribute_pattern, 'Wbn', plnum)
      if line == plnum
        return col - 1
      endif
    elseif pline =~ just_component_pattern
      " {{component
      "   attribute=value}}
      return indent(plnum) + sw
    endif
  endif

  " check for a closing }}, indent according to the opening one
  if pline =~# '}}$' && pline !~# '^\s*{{'
    " Is it a block component?
    let [line, col] = searchpos('{{#', 'Wbn')
    if line > 0
      return (col - 1) + sw
    endif

    " Is it a single component?
    let [line, col] = searchpos('{{', 'Wbn')
    if line > 0
      return (col - 1)
    endif
  endif

  " indent after block {{#block
  if pline =~# '\v\{\{\#.*\s*' &&
        \ pline !~# '{{#\(.\{}\)\s.\{}}}.*{{\/\1}}'
    let ind = ind + sw
  endif
  " unindent after block close {{/block}}
  if cline =~# '\v^\s*\{\{\/\S*\}\}\s*'
    let ind = ind - sw
  endif
  " unindent {{else}}
  if cline =~# '\v^\s*\{\{else.*\}\}\s*$'
    let ind = ind - sw
  endif
  " indent again after {{else}}
  if pline =~# '\v^\s*\{\{else.*\}\}\s*$'
    let ind = ind + sw
  endif

  return ind
endfunction
