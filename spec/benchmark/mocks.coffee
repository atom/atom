exports.config =
  get: (key) ->
    switch key
      when 'editor.tabLength' then return 2
      when 'editor.invisibles' then return {
        eol: '\u00ac'
        space: '\u00b7'
        tab: '\u00bb'
        cr: '\u00a4'
      }
      when 'editor.showInvisibles' then return true
  onDidChange: ->
    dispose: ->

exports.packageManager =
  triggerActivationHook: ->

exports.assert = ->
