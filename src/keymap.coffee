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

  constructor: ({resourcePath, @configDirPath})->
    @bundledKeymapsDirPath = path.join(resourcePath, "keymaps")
    @bindingSets = []
    @bindingSetsByFirstKeystroke = {}

  loadBundledKeymaps: ->
    @loadDirectory(@bundledKeymapsDirPath)
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

  # Private: Returns a user friendly description of where a keybinding was
  # loaded from.
  #
  # * filePath:
  #   The absolute path from which the keymap was loaded
  #
  # Returns one of:
  # * `Core` indicates it comes from a bundled package.
  # * `User` indicates that it was defined by a user.
  # * `<package-name>` the package which defined it.
  # * `Unknown` if an invalid path was passed in.
  determineSource: (filePath) ->
    return 'Unknown' unless filePath

    pathParts = filePath.split(path.sep)
    if _.contains(pathParts, 'node_modules') or _.contains(pathParts, 'atom') or _.contains(pathParts, 'src')
      'Core'
    else if _.contains(pathParts, '.atom') and _.contains(pathParts, 'keymaps') and !_.contains(pathParts, 'packages')
      'User'
    else
      packageNameIndex = pathParts.length - 3
      pathParts[packageNameIndex]

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
    @queuedKeystroke = null
    shouldBubble = undefined

    for {command, isMultiKeystroke} in @commandsForKeystroke(keystroke, element)
      if isMultiKeystroke
        @queuedKeystroke = keystroke
        shouldBubble = false
      else
        if command is 'native!' then shouldBubble = true
        else if @triggerCommandEvent(element, command) then shouldBubble = false

      break if shouldBubble?

    shouldBubble

  # Public: Returns an array of objects that represent every keystroke to
  # command mapping. Each object contains the following keys `source`,
  # `selector`, `command`, `keystroke`.
  getAllKeyMappings: ->
    mappings = []
    for bindingSet in @bindingSets
      selector = bindingSet.getSelector()
      source = @determineSource(bindingSet.getName())
      for keystroke, command of bindingSet.getCommandsByKeystroke()
        mappings.push {keystroke, command, selector, source}

    mappings

  bindingsForElement: (element) ->
    keystrokeMap = {}
    for bindingSet in @bindingSetsForElement(element)
      _.defaults(keystrokeMap, bindingSet.commandsByKeystroke)

    keystrokeMap

  commandsForKeystroke: (keystroke, element) ->
    firstKeystroke = keystroke.split(' ')[0]
    bindingSetsForKeystroke = @bindingSetsByFirstKeystroke[firstKeystroke] ? []
    @bindingSetsForElement(element, bindingSetsForKeystroke).map (bindingSet) ->
      bindingSet.commandForKeystroke(keystroke)

  bindingSetsForElement: (element, bindingSets=@bindingSets) ->
    bindingSets = bindingSets.filter (bindingSet) ->
      $(element).closest(bindingSet.selector).length > 0

    return [] unless bindingSets.length > 0

    bindingSets.sort (a, b) ->
      if b.specificity == a.specificity
        b.index - a.index
      else
        b.specificity - a.specificity

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
      if keystroke in Modifiers then previousKeystroke
      else "#{previousKeystroke} #{keystroke}"
    else
      keystroke

  keystrokeByCommandForSelector: (selector)->
    keystrokeByCommand = {}
    for bindingSet in @bindingSets
      for keystroke, command of bindingSet.commandsByKeystroke
        continue if selector? and selector != bindingSet.selector
        keystrokeByCommand[command] ?= []
        keystrokeByCommand[command].push keystroke
    keystrokeByCommand

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
