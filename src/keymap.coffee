$ = require './jquery-extensions'
_ = require './underscore-extensions'
fsUtils = require './fs-utils'
path = require 'path'
CSON = require 'season'
BindingSet = require './binding-set'

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
  bindingSets: null
  nextBindingSetIndex: 0
  bindingSetsByFirstKeystroke: null
  queuedKeystrokes: null

  constructor: ->
    @bindingSets = []
    @bindingSetsByFirstKeystroke = {}

  loadBundledKeymaps: ->
    @loadDirectory(config.bundledKeymapsDirPath)

  loadUserKeymaps: ->
    @loadDirectory(path.join(config.configDirPath, 'keymaps'))

  loadDirectory: (directoryPath) ->
    @load(filePath) for filePath in fsUtils.listSync(directoryPath, ['.cson', '.json'])

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
      for keystrokes of bindingSet.commandsByKeystrokes
        keystroke = keystrokes.split(' ')[0]
        _.remove(@bindingSetsByFirstKeystroke[keystroke], bindingSet)

  # Public: Returns an array of objects that represent every keystroke to
  # command mapping. Each object contains the following keys `source`,
  # `selector`, `command`, `keystrokes`.
  getAllKeyMappings: ->
    mappings = []
    for bindingSet in @bindingSets
      selector = bindingSet.getSelector()
      source = @determineSource(bindingSet.getName())
      for keystrokes, command of bindingSet.getCommandsByKeystrokes()
        mappings.push {keystrokes, command, selector, source}

    mappings

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
    if _.contains(pathParts, '.atom') and _.contains(pathParts, 'packages')
      packageNameIndex = pathParts.indexOf('keymaps') - 1
      pathParts[packageNameIndex]
    else if _.contains(pathParts, '.atom') and _.contains(pathParts, 'keymaps')
      'User'
    else
      'Core'

  bindKeys: (args...) ->
    name = args.shift() if args.length > 2
    [selector, bindings] = args
    bindingSet = new BindingSet(selector, bindings, @nextBindingSetIndex++, name)
    @bindingSets.unshift(bindingSet)
    for keystrokes of bindingSet.commandsByKeystrokes
      keystroke = keystrokes.split(' ')[0] # only index by first keystroke
      @bindingSetsByFirstKeystroke[keystroke] ?= []
      @bindingSetsByFirstKeystroke[keystroke].push(bindingSet)

  unbindKeys: (selector, bindings) ->
    bindingSet = _.detect @bindingSets, (bindingSet) ->
      bindingSet.selector is selector and bindingSet.bindings is bindings

    if bindingSet
      _.remove(@bindingSets, bindingSet)

  bindingsForElement: (element) ->
    keystrokeMap = {}
    currentNode = $(element)

    while currentNode.length
      bindingSets = @bindingSetsForNode(currentNode)
      _.defaults(keystrokeMap, set.commandsByKeystrokes) for set in bindingSets
      currentNode = currentNode.parent()

    keystrokeMap

  handleKeyEvent: (event) =>
    event.keystrokes = @multiKeystrokeStringForEvent(event)
    isMultiKeystroke = @queuedKeystrokes?
    @queuedKeystrokes = null

    firstKeystroke = event.keystrokes.split(' ')[0]
    bindingSetsForFirstKeystroke = @bindingSetsByFirstKeystroke[firstKeystroke]
    if bindingSetsForFirstKeystroke?
      currentNode = $(event.target)
      currentNode = rootView if currentNode is $('body')[0]
      while currentNode.length
        candidateBindingSets = @bindingSetsForNode(currentNode, bindingSetsForFirstKeystroke)
        for bindingSet in candidateBindingSets
          command = bindingSet.commandForEvent(event)
          if command is 'native!'
            return true
          else if command
            continue if @triggerCommandEvent(event, command)
            return false
          else if command == false
            return false

          if bindingSet.matchesKeystrokePrefix(event)
            @queuedKeystrokes = event.keystrokes
            return false
        currentNode = currentNode.parent()

    return false if isMultiKeystroke
    return false if firstKeystroke is 'tab'

  bindingSetsForNode: (node, candidateBindingSets = @bindingSets) ->
    bindingSets = candidateBindingSets.filter (set) -> node.is(set.selector)
    bindingSets.sort (a, b) ->
      if b.specificity == a.specificity
        b.index - a.index
      else
        b.specificity - a.specificity

  triggerCommandEvent: (keyEvent, commandName) ->
    keyEvent.target = rootView[0] if keyEvent.target == document.body and window.rootView
    commandEvent = $.Event(commandName)
    commandEvent.keyEvent = keyEvent
    aborted = false
    commandEvent.abortKeyBinding = ->
      @stopImmediatePropagation()
      aborted = true
    $(keyEvent.target).trigger(commandEvent)
    aborted

  multiKeystrokeStringForEvent: (event) ->
    currentKeystroke = @keystrokeStringForEvent(event)
    if @queuedKeystrokes
      @queuedKeystrokes + ' ' + currentKeystroke
    else
      currentKeystroke

  keystrokeStringForEvent: (event) ->
    if event.originalEvent.keyIdentifier.indexOf('U+') == 0
      hexCharCode = event.originalEvent.keyIdentifier[2..]
      charCode = parseInt(hexCharCode, 16)
      charCode = event.which if !@isAscii(charCode) and @isAscii(event.which)
      key = @keyFromCharCode(charCode)
    else
      key = event.originalEvent.keyIdentifier.toLowerCase()

    modifiers = []
    if event.altKey and key isnt 'alt'
      modifiers.push 'alt'
    if event.ctrlKey and key isnt 'ctrl'
      modifiers.push 'ctrl'
    if event.metaKey and key isnt 'meta'
      modifiers.push 'meta'

    if event.shiftKey
      isNamedKey = key.length > 1
      modifiers.push 'shift' if isNamedKey
    else
      key = key.toLowerCase()

    [modifiers..., key].join('-')

  keystrokesByCommandForSelector: (selector)->
    keystrokesByCommand = {}
    for bindingSet in @bindingSets
      for keystroke, command of bindingSet.commandsByKeystrokes
        continue if selector? and selector != bindingSet.selector
        keystrokesByCommand[command] ?= []
        keystrokesByCommand[command].push keystroke
    keystrokesByCommand

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
