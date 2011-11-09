_ = require 'underscore'
fs = require 'fs'
Watcher = require 'watcher'
{CoffeeScript} = require 'coffee-script'

module.exports =
class KeyBinder
  @bindings: {}

  @scopes: {}

  @register: (name, scope) ->
    @scopes[name] = scope

  @load: (path) ->
    try
      Watcher.watch path, =>
        # Should we keep track of which file bindings are associated with? That
        # way we could clear bindings when the file is changed or deleted. I
        # think the answer is yes, but I don't want to do this right now.
        console.log "#{@name}: Reloading #{path}"
        @load path

      json = CoffeeScript.eval "return " + (fs.read path)
      for scopeName, bindings of json
        @create scopeName, binding, method for binding, method of bindings
    catch error
      console.error "#{@name}: Could not load key bindings at `#{path}`. #{error}"

  @create: (scope, binding, method) ->
    if typeof scope is "string"
      throw "#{@name}: Unknown scope `#{scope}`" unless @scopes[scope]
      scope = @scopes[scope]

    callback = if _.isFunction method
      -> method scope
    else if scope[method]
      -> scope[method]()
    else
      throw "#{@name}: '#{method}' not found found in scope #{scope}"

    callbacks = @bindings[@bindingParser binding] ?= []

    callbacks.push callback

  @handleEvent: (event) ->
    keys = []
    keys.push @modifierKeys.command if event.modifierFlags & OSX.NSCommandKeyMask
    keys.push @modifierKeys.shift if event.modifierFlags & OSX.NSShiftKeyMask
    keys.push @modifierKeys.control if event.modifierFlags & OSX.NSControlKeyMask
    keys.push @modifierKeys.alt if event.modifierFlags & OSX.NSAlternateKeyMask
    keys.push event.charactersIgnoringModifiers.toLowerCase().charCodeAt 0

    binding = keys.sort().join "-"

    callbacks = @bindings[binding]
    return false if not callbacks

    # Only use the most recently added binding
    try
      _.last(callbacks)()
    catch e
      console.warn "Failed to run binding #{@bindingFromAscii binding}. #{e}"

    true

  @bindingParser: (binding) ->
    keys = binding.trim().split '-'

    modifiers = []
    key = null

    for k in keys
      k = k.toLowerCase()
      if @modifierKeys[k]
        modifiers.push @modifierKeys[k]
      else if key
        throw "#{@name}: #{binding} specifies TWO keys, we don't handle that yet."
      else if @namedKeys[k]
        key = @namedKeys[k]
      else if k.length > 1
        throw "#{@name}: #{binding} uses an unknown key #{k}."
      else
        key = k.charCodeAt 0

    modifiers.concat(key).sort().join "-"

  @bindingFromAscii: (binding) ->
    inverseModifierKeys = {}
    inverseModifierKeys[number] = label for label, number of @modifierKeys

    inverseNamedKeys = {}
    inverseNamedKeys[number] = label for label, number of @namedKeys

    asciiKeys = binding.split '-'
    keys = []

    for asciiKey in asciiKeys
      key = inverseModifierKeys[asciiKey]
      key ?= inverseNamedKeys[asciiKey]
      key ?= String.fromCharCode asciiKey
      keys.push key or "?"

    keys.join '-'

  @modifierKeys:
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

  @namedKeys:
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
