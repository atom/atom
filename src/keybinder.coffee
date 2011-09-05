ace = require 'ace/ace'
canon = require 'pilot/canon'

key = require 'keymaster'

exports.bindKey = (name, shortcut, callback) ->
  key shortcut, -> callback(); false
