$ = require 'jquery'
_ = require 'underscore'

window.app = new (require 'app')

window.keydown = (pattern) ->
  keys = pattern.split '+'
  $.Event "keydown",
    ctrlKey: 'ctrl' in keys
    altKey: 'alt' in keys
    shiftKey: 'shift' in keys
    metaKey: 'meta' in keys
    which: _.last(keys).toUpperCase().charCodeAt 0
