" mise の tera テンプレート用。core/autocmds.lua で "<中身>.tera" の複合 filetype にしたバッファで、
" 中身の言語の syntax の上に tera のタグ（{# #} / {% %} / {{ }}）のハイライトを重ねる。
" containedin=ALL で、中身の言語の文字列やコメントの中に書いたタグもハイライトする。
" 中身が判定できず filetype が "tera" 単体のときは、Neovim 組み込みの syntax/tera.vim に任せる。
if get(b:, 'current_syntax', '') ==# 'tera'
  finish
endif

syntax region teraComment start=/{#/ end=/#}/ keepend containedin=ALL contains=@Spell
syntax region teraStatement matchgroup=teraDelimiter start=/{%-\=/ end=/-\=%}/ keepend containedin=ALL contains=teraKeyword,teraString,teraNumber,teraBoolean,teraFilter
syntax region teraExpression matchgroup=teraDelimiter start=/{{-\=/ end=/-\=}}/ keepend containedin=ALL contains=teraKeyword,teraString,teraNumber,teraBoolean,teraFilter

syntax keyword teraKeyword contained if else elif endif for endfor in macro endmacro
syntax keyword teraKeyword contained block endblock extends include import set endset set_global
syntax keyword teraKeyword contained break continue filter endfilter raw endraw and or not is as
syntax region teraString contained start=/"/ skip=/\\"/ end=/"/
syntax region teraString contained start=/'/ skip=/\\'/ end=/'/
syntax match teraNumber contained /\<\d\+\(\.\d\+\)\=\>/
syntax keyword teraBoolean contained true false
syntax match teraFilter contained /|\s*\w\+/

highlight default link teraComment Comment
highlight default link teraDelimiter PreProc
highlight default link teraStatement Identifier
highlight default link teraExpression Identifier
highlight default link teraKeyword Statement
highlight default link teraString String
highlight default link teraNumber Number
highlight default link teraBoolean Boolean
highlight default link teraFilter Function
