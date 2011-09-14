_ = require 'underscore'

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
        if _.isFunction method
          method.call this
        else
          if @[method]
            @[method]()
          else
            console.error "keymap: no '#{method}' method found"
    @initialize options

  # Override in your subclass
  initialize: ->

  toggle: ->
    if @showing
      @html.parent().detach()
    else
      # This require should be at the top of the file, BUT it doesn't work.
      # Would like to figure out why.
      {activeWindow} = require 'app'
      activeWindow.addPane this

    @showing = not @showing
