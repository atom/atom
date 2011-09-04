ace = require 'ace/ace'
canon = require 'pilot/canon'

exports.bindKey = (name, shortcut, callback) ->
  canon.addCommand
    name: name
    exec: callback
    bindKey:
      win: null
      mac: shortcut
      sender: 'editor'
