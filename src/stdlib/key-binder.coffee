_ = require 'underscore'
fs = require 'fs'
Watcher = require 'watcher'
{CoffeeScript} = require 'coffee-script'

module.exports =
class KeyBinder
  # keymaps are name => { binding: method } mappings
  keymaps: {}

  constructor: ->
    atom.on 'window:load', ->
      atom.keybinder.load require.resolve "key-bindings.coffee"
      if fs.isFile "~/.atomicity/key-bindings.coffee"
        atom.keybinder.load "~/.atomicity/key-bindings.coffee"

  register: (name, scope) ->

  load: (path) ->
    try
      Watcher.watch path, =>
        # Should we keep track of which file bindings are associated with?
        # That way we could clear bindings when the file is changed
        # or deleted. I think the answer is yes, but I don't want to
        # do this right now.
        console.log "#{@name}: Reloading #{path}"
        @load path

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
    keys.push event.charactersIgnoringModifiers.charCodeAt 0

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
    _.flatten [ (_.values atom.extensions), atom.document, window, atom ]

  triggerBinding: (scope, method) ->
    responder = _.detect @responders(), (responder) =>
      (scope is 'window' and responder is window) or
        responder.constructor.name.toLowerCase() is scope or
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
        modifiers.push modifier unless modifier == @modifierKeys['shift'] # Shift is implied? YES
      else if key
        throw "#{@name}: #{binding} specifies TWO keys, we don't handle that yet."
      else if namedKey = @namedKeys[k.toLowerCase()]
        key = namedKey
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
