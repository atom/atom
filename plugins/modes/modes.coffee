_ = require 'underscore'

Plugin = require 'plugin'

module.exports =
class Modes extends Plugin
  load: ->
    # NO! Do not use editor to handle events!
    editor = @window.document

    editor.ace.on 'open', ({filename}) => @setMode(filename)
    editor.ace.on 'save', ({filename}) => @setMode(filename)

  modeMap:
    js: 'javascript'
    c: 'c_cpp'
    cpp: 'c_cpp'
    h: 'c_cpp'
    m: 'c_cpp'
    md: 'markdown'
    cs: 'csharp'
    rb: 'ruby'

  modeForLanguage: (language) ->
    language = language.toLowerCase()
    modeName = @modeMap[language] or language

    try
      require("ace/mode/#{modeName}").Mode
    catch e
      null

  setMode: (filename) ->
    if mode = @modeForLanguage _.last filename.split '.'
      @window.document.ace.getSession().setMode new mode
