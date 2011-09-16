_ = require 'underscore'

{bindKey} = require 'keybinder'

module.exports =
class Pane
  position: null

  html: null

  keymap: {}

  persistantProperties: {}

  editableProperties: {}

  constructor: (options={}) ->
    @createPersistentProperty(k, v) for k, v of @persistantProperties
    @createPersistentProperty(k, v) for k, v of @editableProperties

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

  createPersistentProperty: (property, defaultValue) ->
    storedPropertyName = "__" + property + "__"
    Object.defineProperty @, property,
      get: ->
        key = @persistentanceNamespace() + property

        if @[storedPropertyName]
          # Cool, just chill for awhile
        else if localStorage[key]
          try
            @[storedPropertyName] = JSON.parse(localStorage[key] ? "null")
          catch error
            @[storedPropertyName] = defaultValue
            error.message += "\n#{key}: #{JSON.stringify localStorage[key]}"
            console.log(error)
        else
          @[storedPropertyName] = defaultValue

        return @[storedPropertyName]

      set: (value) ->
        key = @persistentanceNamespace() + property

        try
          @[storedPropertyName] = value
          localStorage[key] = JSON.stringify value
        catch error
          error.message += "\n value = #{JSON.stringify value}"
          console.log(error)

  toggle: ->
    if @showing
      @html.parent().detach()
    else
      # This require should be at the top of the file, BUT it doesn't work.
      # Would like to figure out why.
      {activeWindow} = require 'app'
      activeWindow.addPane this

    @showing = not @showing

  # Override these in your subclass
  initialize: ->

  persistentanceNamespace: -> @.constructor.name
