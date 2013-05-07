" Vim syntax file
" Language:  Javascript
" Maintainer:  Maksim Ryzhikov <rv.maksim@gmail.com>
" Extend built in vim javascript syntax highlighting

" common
syn keyword CommonSpecial  has add remove set get toggle replace
syn keyword CommonSpecial  addClass removeClass bind
syn keyword CommonSpecial  cache

syn keyword CommonKeyword  require

" dojo
syn keyword DojoSpecial  byId isDescendant setSelectable getNodeProp
syn keyword DojoKeyword  dojo dijit dojox

" jQuery
syn match jQuerySpecial  "\.\(query\|on\|style\|attr\|forEach\|map\|delegate\|proxy\)"
syn keyword jQueryKeyword  jQuery

" Node
syn keyword NodeKeyword  exports __dirname

" Jasmine
syn keyword JasmineSpecial  afterEach beforeEach describe it expect spyOn runs waits waitsFor
syn keyword JasmineKeyword  jasmine

" Debug
syn keyword Debug console print

command! -nargs=+ HiLink hi def link <args>
HiLink CommonSpecial Special
HiLink CommonKeyword Keyword

HiLink DojoSpecial Special
HiLink DojoKeyword Keyword

HiLink jQuerySpecial Special
HiLink jQueryKeyword Keyword

HiLink NodeKeyword Keyword

HiLink JasmineSpecial Special
HiLink JasmineKeyword Keyword
delcommand HiLink
