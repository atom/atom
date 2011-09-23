_ = require 'underscore'

modifierKeys =
  '⇧': 16
  shift: 16
  alt: 18
  option: 18
  '⌥': 18
  control: 17
  ctrl: 17
  command: 91
  cmd: 91
  '⌘': 91

namedKeys =
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

bindings = {}

shortcutParser = (shortcut) ->
  keys = shortcut.trim().split '-'

  modifiers = []
  key = null

  for k in keys
    k = k.toLowerCase()
    if modifierKeys[k]
      modifiers.push modifierKeys[k]
    else if key
      throw "THIS KEYBINDING #{shortcut} specifies TWO keys, we don't handle that yet."
    else if namedKeys[k]
      key = namedKeys[k]
    else if k.length > 1
      throw "THIS KEYBINDING #{shortcut} uses an unknown key #{k}."
    else
      key = k.charCodeAt 0

  modifiers.concat(key).sort().join "-"

exports.bindKey = (scope, shortcut, method) ->
  callback = if _.isFunction method
    -> method.apply scope
  else if scope[method]
    -> scope[method]()
  else
    console.error "keymap: no '#{method}' method found"
    -> console.error "keymap: #{shortcut} failed to bind"

  callbacks = bindings[shortcutParser shortcut] ?= []
  callbacks.push callback

window.handleKeyEvent = (event) ->
  keys = []
  keys.push modifierKeys.command if event.modifierFlags & OSX.NSCommandKeyMask
  keys.push modifierKeys.shift if event.modifierFlags & OSX.NSShiftKeyMask
  keys.push modifierKeys.control if event.modifierFlags & OSX.NSControlKeyMask
  keys.push modifierKeys.alt if event.modifierFlags & OSX.NSAlternateKeyMask
  keys.push event.charactersIgnoringModifiers.charCodeAt 0

  shortcut = keys.sort().join "-"

  callbacks = bindings[shortcut]
  return false if not callbacks

  callback() for callback in callbacks
  true
