_ = require 'underscore'
fs = require 'fs'
Watcher = require 'watcher'
{CoffeeScript} = require 'coffee-script'

module.exports =
class KeyBinder
  # keymaps are name => { binding: method } mappings
  keymaps: {}

  constructor: ->
    @load require.resolve "key-bindings.coffee"
    if fs.isFile "~/.atomicity/key-bindings.coffee"
      @load "~/.atomicity/key-bindings.coffee"

  register: (name, scope) ->

  load: (path) ->
    try
#       Watcher.watch path, =>
#         @load path

      json = CoffeeScript.eval "return " + (fs.read path)
      # Iterate in reverse order scopes are declared.
      # Scope at the top of the file is checked last.
      for name in _.keys(json).reverse()
        bindings = json[name]
        @keymaps[name] ?= {}
        for binding, method of bindings
          @keymaps[name][@bindingParser binding] = method
    catch error
      console.error "Can't load key bindings at `#{path}`."
      console.error error

  handleEvent: (event) ->
    keys = []
    if event.modifierFlags & OSX.NSCommandKeyMask
      keys.push @modifierKeys.command
    if event.modifierFlags & OSX.NSControlKeyMask
      keys.push @modifierKeys.control
    if event.modifierFlags & OSX.NSAlternateKeyMask
      keys.push @modifierKeys.alt
    if event.modifierFlags & OSX.NSShiftKeyMask
      keys.push @modifierKeys.shift
    keys.push event.charactersIgnoringModifiers.toLowerCase().charCodeAt 0

    binding = keys.sort().join "-"
    try
      @triggerBinding binding
    catch error
      console.error "Failed to run binding #{@bindingFromAscii binding}."
      console.error error


  # Given a keyboard combination, goes through the responder
  # chain and checks if any object (or any of that object's super
  # classes) respond to the binding.
  #
  # If so, it triggers the binding.
  #
  # binding - A String in the form of "#{charCode}-#{chardCode}"
  #
  # Returns true if we found and triggered the binding, false if not.
  triggerBinding: (binding) ->
    for responder in @responders()
      name = responder.constructor.name?.toLowerCase()
      name = 'window' if responder is window

      if method = @keymaps[name]?[binding]
        if _.isFunction method
          method responder
        else
          responder[method]()
        return true

    false

  responders: ->
    extensions = _.select (_.values atom.extensions), (extension) ->
      extension.running?
    _.flatten [ extensions, window.resource.responder(), window, atom.app ]

  bindingParser: (binding) ->
    keys = binding.trim().split '-'

    modifiers = []
    key = null
    for k in keys
      if modifier = @modifierKeys[k.toLowerCase()]
        modifiers.push modifier
      else if key
        throw "#{@name}: #{binding} specifies TWO keys, we don't handle that yet."
      else if namedKey = @namedKeys[k.toLowerCase()]
        key = namedKey
      else if k.toLowerCase() isnt k
        if not _.include modifiers, @modifierKeys.shift
          modifiers.push @modifierKeys.shift
        key = k.toLowerCase().charCodeAt 0
      else if k.length > 1
        throw "#{@name}: #{binding} uses an unknown key #{k}."
      else
        charCode = k.charCodeAt 0
        key = k.charCodeAt 0

    modifiers.concat(key).sort().join "-"

  bindingFromAscii: (binding) ->
    inverseModifierKeys = {}
    inverseModifierKeys[number] = label for label, number of @modifierKeys

    inverseNamedKeys = {}
    inverseNamedKeys[number] = label for label, number of @namedKeys

    asciiKeys = binding.split '-'
    keys = []

    for asciiKey in asciiKeys.reverse()
      key = inverseModifierKeys[asciiKey]
      key ?= inverseNamedKeys[asciiKey]
      key ?= String.fromCharCode asciiKey
      keys.push key or "?"

    keys.join '-'

  modifierKeys:
    '⇧': 16
    '⌘': 91
    '⌥': 18
    shift: 16
    alt: 18
    option: 18
    control: 17
    ctrl: 17
    command: 91
    cmd: 91

  namedKeys:
    backspace: 8
    tab: 9
    clear: 12
    enter: 13
    return: 13
    esc: 27
    escape: 27
    space: 32
    left: 37
    up: 38
    right: 39
    down: 40
    del: 46
    delete: 46
    home: 36
    end: 35
    pageup: 33
    pagedown: 34
    ',': 188
    '.': 190
    '/': 191
    '`': 192
    '-': 189
    '=': 187
    ';': 186
    '\'': 222
    '[': 219
    ']': 221
    '\\': 220
