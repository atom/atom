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
      console.error "Can't load key bindings at `#{path}`. #{error}"

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

    for scope, bindings of @keymaps
      break if method = bindings[binding]
    return false if not method

    try
      @triggerBinding scope, method
    catch e
      console.warn "Failed to run binding #{@bindingFromAscii binding}. #{e}"

    true

  responders: ->
    _.flatten [ (_.values atom.extensions), atom.document, window, atom.app ]

  triggerBinding: (scope, method) ->
    responder = _.detect @responders(), (responder) =>
      (scope is 'window' and responder is window) or
        responder.constructor.name?.toLowerCase() is scope or
        @inheritedKeymap responder, scope
    if responder
      if _.isFunction method
        method responder
      else
        responder[method]()

  # If you inherit from a class, you inherit its keymap.
  #
  # Example:
  #   class GistEditor extends Editor
  #
  # Will respond to these bindings:
  #   gisteditor:
  #     'cmd+ctrl-g': 'createGist'
  # And these:
  #   editor:
  #     'cmd-n': 'new'
  #
  # Returns a Boolean
  inheritedKeymap: (responder, scope) ->
    parent = responder.constructor.__super__
    while parent?.constructor?.name
      if parent.constructor.name.toLowerCase() is scope
        return true
      else
        parent = parent.constructor.__super__
    false

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
      else if shiftedKey = @shiftedKeys[k.charCodeAt 0]
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

  shiftedKeys:
    48: ')', 49: '!', 50: '@', 51: '#', 52: '$', 53: '%', 54: '^'
    55: '&', 56: '*', 57: '(', 65: 'A', 66: 'B', 67: 'C', 68: 'D'
    69: 'E', 70: 'F', 71: 'G', 72: 'H', 73: 'I', 74: 'J', 75: 'K'
    76: 'L', 77: 'M', 78: 'N', 79: 'O', 80: 'P', 81: 'Q', 82: 'R'
    83: 'S', 84: 'T', 85: 'U', 86: 'V', 87: 'W', 88: 'X', 89: 'Y'
    90: 'Z', 186: ':', 187: '+', 188: '<', 189: '_', 190: '>'
    191: '?', 192: '~', 219: '{', 220: '|', 221: '}', 222: '"'
