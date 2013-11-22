{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
CSON = require 'season'
KeyBinding = require './key-binding'
{Emitter} = require 'emissary'

Modifiers = ['alt', 'control', 'ctrl', 'shift', 'meta']

# Internal: Associates keymaps with actions.
#
# Keymaps are defined in a CSON format. A typical keymap looks something like this:
#
# ```cson
# 'body':
#  'ctrl-l': 'package:do-something'
#'.someClass':
#  'enter': 'package:confirm'
# ```
#
# As a key, you define the DOM element you want to work on, using CSS notation. For that
# key, you define one or more key:value pairs, associating keystrokes with a command to execute.
module.exports =
class Keymap
  Emitter.includeInto(this)

  constructor: ({@resourcePath, @configDirPath})->
    @keyBindings = []

  # Public: Returns an array of all {KeyBinding}s.
  getKeyBindings: ->
    _.clone(@keyBindings)

  # Public: Returns a array of {KeyBinding}s (sorted by selector specificity)
  # that match a keystroke and element.
  #
  # * keystroke:
  #   The string representing the keys pressed (e.g. ctrl-P).
  # * element:
  #   The DOM node that will match a {KeyBinding}'s selector.
  keyBindingsForKeystrokeMatchingElement: (keystroke, element) ->
    keyBindings = @keyBindingsForKeystroke(keystroke)
    @keyBindingsMatchingElement(element, keyBindings)

  # Public: Returns a array of {KeyBinding}s (sorted by selector specificity)
  # that match a command.
  #
  # * command:
  #   The string representing the command (tree-view:toggle)
  # * element:
  #   The DOM node that will match a {KeyBinding}'s selector.
  keyBindingsForCommandMatchingElement: (command, element) ->
    keyBindings = @keyBindingsForCommand(command)
    @keyBindingsMatchingElement(element, keyBindings)

  # Public: Returns an array of {KeyBinding}s that match a keystroke
  # * keystroke:
  #   The string representing the keys pressed (e.g. ctrl-P)
  keyBindingsForKeystroke: (keystroke) ->
    keystroke = KeyBinding.normalizeKeystroke(keystroke)
    @keyBindings.filter (keyBinding) -> keyBinding.matches(keystroke)

  # Public: Returns an array of {KeyBinding}s that match a command
  # * keystroke:
  #   The string representing the keys pressed (e.g. ctrl-P)
  keyBindingsForCommand: (command) ->
    @keyBindings.filter (keyBinding) -> keyBinding.command == command

  # Public: Returns a array of {KeyBinding}s (sorted by selector specificity)
  # whos selector matches the element.
  #
  # * element:
  #   The DOM node that will match a {KeyBinding}'s selector.
  keyBindingsMatchingElement: (element, keyBindings=@keyBindings) ->
    keyBindings = keyBindings.filter ({selector}) -> $(element).closest(selector).length > 0
    keyBindings.sort (a, b) -> a.compare(b)

  # Public: Returns a keystroke string derived from an event.
  # * event:
  #   A DOM or jQuery event
  # * previousKeystroke:
  #   An optional string used for multiKeystrokes
  keystrokeStringForEvent: (event, previousKeystroke) ->
    if event.originalEvent.keyIdentifier.indexOf('U+') == 0
      hexCharCode = event.originalEvent.keyIdentifier[2..]
      charCode = parseInt(hexCharCode, 16)
      charCode = event.which if !@isAscii(charCode) and @isAscii(event.which)
      key = @keyFromCharCode(charCode)
    else
      key = event.originalEvent.keyIdentifier.toLowerCase()

    modifiers = []
    if event.altKey and key not in Modifiers
      modifiers.push 'alt'
    if event.ctrlKey and key not in Modifiers
      modifiers.push 'ctrl'
    if event.metaKey and key not in Modifiers
      modifiers.push 'meta'

    if event.shiftKey and key not in Modifiers
      isNamedKey = key.length > 1
      modifiers.push 'shift' if isNamedKey
    else
      key = key.toLowerCase()

    keystroke = [modifiers..., key].join('-')

    if previousKeystroke
      if keystroke in Modifiers
        previousKeystroke
      else
        "#{previousKeystroke} #{keystroke}"
    else
      keystroke

  loadBundledKeymaps: ->
    @loadDirectory(path.join(@resourcePath, 'keymaps'))
    @emit('bundled-keymaps-loaded')

  loadUserKeymap: ->
    userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
    @load(userKeymapPath) if userKeymapPath

  loadDirectory: (directoryPath) ->
    @load(filePath) for filePath in fs.listSync(directoryPath, ['.cson', '.json'])

  load: (path) ->
    @add(path, CSON.readFileSync(path))

  add: (source, keyMappingsBySelector) ->
    for selector, keyMappings of keyMappingsBySelector
      @bindKeys(source, selector, keyMappings)

  remove: (source) ->
    @keyBindings = @keyBindings.filter (keyBinding) -> keyBinding.source isnt source

  bindKeys: (source, selector, keyMappings) ->
    for keystroke, command of keyMappings
      @keyBindings.push new KeyBinding(source, command, keystroke, selector)

  handleKeyEvent: (event) ->
    element = event.target
    element = rootView if element == document.body
    keystroke = @keystrokeStringForEvent(event, @queuedKeystroke)
    keyBindings = @keyBindingsForKeystrokeMatchingElement(keystroke, element)

    if keyBindings.length == 0 and @queuedKeystroke
      @queuedKeystroke = null
      return false
    else
      @queuedKeystroke = null

    for keyBinding in keyBindings
      partialMatch = keyBinding.keystroke isnt keystroke
      if partialMatch
        @queuedKeystroke = keystroke
        shouldBubble = false
      else
        if keyBinding.command is 'native!'
          shouldBubble = true
        else if @triggerCommandEvent(element, keyBinding.command)
          shouldBubble = false

      break if shouldBubble?

    shouldBubble ? true

  triggerCommandEvent: (element, commandName) ->
    commandEvent = $.Event(commandName)
    commandEvent.abortKeyBinding = -> commandEvent.stopImmediatePropagation()
    $(element).trigger(commandEvent)
    not commandEvent.isImmediatePropagationStopped()

  isAscii: (charCode) ->
    0 <= charCode <= 127

  keyFromCharCode: (charCode) ->
    switch charCode
      when 8 then 'backspace'
      when 9 then 'tab'
      when 13 then 'enter'
      when 27 then 'escape'
      when 32 then 'space'
      when 127 then 'delete'
      else String.fromCharCode(charCode)
