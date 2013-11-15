{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
CSON = require 'season'
BindingSet = require './binding-set'
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

  bindingSets: null
  nextBindingSetIndex: 0
  bindingSetsByFirstKeystroke: null
  queuedKeystroke: null

  constructor: ({@resourcePath, @configDirPath})->
    @bindingSets = []
    @bindingSetsByFirstKeystroke = {}

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

  add: (args...) ->
    name = args.shift() if args.length > 1
    keymap = args.shift()
    for selector, bindings of keymap
      @bindKeys(name, selector, bindings)

  remove: (name) ->
    for bindingSet in @bindingSets.filter((bindingSet) -> bindingSet.name is name)
      _.remove(@bindingSets, bindingSet)
      for keystroke of bindingSet.commandsByKeystroke
        firstKeystroke = keystroke.split(' ')[0]
        _.remove(@bindingSetsByFirstKeystroke[firstKeystroke], bindingSet)

  bindKeys: (args...) ->
    name = args.shift() if args.length > 2
    [selector, bindings] = args
    bindingSet = new BindingSet(selector, bindings, @nextBindingSetIndex++, name)
    @bindingSets.unshift(bindingSet)
    for keystroke of bindingSet.commandsByKeystroke
      keystroke = keystroke.split(' ')[0] # only index by first keystroke
      @bindingSetsByFirstKeystroke[keystroke] ?= []
      @bindingSetsByFirstKeystroke[keystroke].push(bindingSet)

  unbindKeys: (selector, bindings) ->
    bindingSet = _.detect @bindingSets, (bindingSet) ->
      bindingSet.selector is selector and bindingSet.bindings is bindings

    if bindingSet
      _.remove(@bindingSets, bindingSet)

  handleKeyEvent: (event) ->
    element = event.target
    element = rootView[0] if element == document.body
    keystroke = @keystrokeStringForEvent(event, @queuedKeystroke)
    mappings = @mappingsForKeystrokeMatchingElement(keystroke, element)

    if mappings.length == 0 and @queuedKeystroke
      @queuedKeystroke = null
      return false
    else
      @queuedKeystroke = null

    for mapping in mappings
      partialMatch = mapping.keystroke isnt keystroke
      if partialMatch
        @queuedKeystroke = keystroke
        shouldBubble = false
      else
        if mapping.command is 'native!'
          shouldBubble = true
        else if @triggerCommandEvent(element, mapping.command)
          shouldBubble = false

      break if shouldBubble?

    shouldBubble ? true

  # Public: Returns an array of objects that represent every keystroke to
  # command mapping. Each object contains the following keys `source`,
  # `selector`, `command`, `keystroke`, `index`, `specificity`.
  allMappings: ->
    mappings = []

    for bindingSet in @bindingSets
      for keystroke, command of bindingSet.getCommandsByKeystroke()
        mappings.push @buildMapping(bindingSet, command, keystroke)

    mappings

  mappingsForKeystrokeMatchingElement: (keystroke, element) ->
    mappings = @mappingsForKeystroke(keystroke)
    @mappingsMatchingElement(element, mappings)

  mappingsForKeystroke: (keystroke) ->
    mappings = @allMappings().filter (mapping) ->
      multiKeystroke = /\s/.test keystroke
      if multiKeystroke
        keystroke == mapping.keystroke
      else
        keystroke.split(' ')[0] == mapping.keystroke.split(' ')[0]

  mappingsMatchingElement: (element, mappings=@allMappings()) ->
    mappings = mappings.filter ({selector}) -> $(element).closest(selector).length > 0
    mappings.sort (a, b) ->
      if b.specificity == a.specificity
        b.index - a.index
      else
        b.specificity - a.specificity

  buildMapping: (bindingSet, command, keystroke) ->
    selector = bindingSet.selector
    specificity = bindingSet.specificity
    index = bindingSet.index
    source = bindingSet.name
    {command, keystroke, selector, specificity, source}

  triggerCommandEvent: (element, commandName) ->
    commandEvent = $.Event(commandName)
    commandEvent.abortKeyBinding = -> commandEvent.stopImmediatePropagation()
    $(element).trigger(commandEvent)
    not commandEvent.isImmediatePropagationStopped()

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

  #
  # Deprecated
  #

  bindingsForElement: (element) ->
    keystrokeMap = {}
    mappings = @mappingsMatchingElement(@allMappings(), element)
    keystrokeMap[keystroke] ?= command for {command, keystroke} in mappings
    keystrokeMap
