_ = require 'underscore'

{ace} = require 'editor'

modeMap =
  js: 'javascript'
  c: 'c_cpp'
  cpp: 'c_cpp'
  h: 'c_cpp'
  m: 'c_cpp'
  md: 'markdown'
  cs: 'csharp'

modeForLanguage = (language) ->
  console.log "modeForLanguage(#{language})"
  language = language.toLowerCase()
  modeName = modeMap[language] or language

  console.log "modeName: #{modeName}"
  try
    require("ace/mode/#{modeName}").Mode
  catch e
    null

setMode = ({filename}) ->
  console.log "setMode(#{filename})"
  if mode = modeForLanguage _.last filename.split '.'
    console.dir mode
    ace.getSession().setMode new mode

exports.init = ->
  ace.on 'open', setMode
  ace.on 'save', setMode

exports.modeMap = modeMap