{bindKey} = require 'keybinder'

module.exports =
class Pane
  position: null
  html: null

  keymap: {}

  constructor: (options={}) ->
    for option, value of options
      @[option] = value

    for shortcut, method of @keymap then do (shortcut, method) =>
      bindKey method, shortcut, (args...) =>
        console.log "#{shortcut}: #{method}"
        if @[method]
          @[method]()
        else
          console.error "keymap: no '#{method}' method found"
    @initialize options

  # Override in your subclass
  initialize: ->