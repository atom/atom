{Disposable, CompositeDisposable} = require 'event-kit'
{specificity} = require 'clear-cut'
_ = require 'underscore-plus'
{$} = require './space-pen-extensions'

SequenceCount = 0
SpecificityCache = {}

module.exports =

# Experimental: Associates listener functions with commands in a
# context-sensitive way using CSS selectors. You can access a global instance of
# this class via `atom.commands`, and commands registered there will be
# presented in the command palette.
#
# The global command registry facilitates a style of event handling known as
# *event delegation* that was popularized by jQuery. Atom commands are expressed
# as custom DOM events that can be invoked on the currently focused element via
# a key binding or manually via the command palette. Rather than binding
# listeners for command events directly to DOM nodes, you instead register
# command event listeners globally on `atom.commands` and constrain them to
# specific kinds of elements with CSS selectors.
#
# As the event bubbles upward through the DOM, all registered event listeners
# with matching selectors are invoked in order of specificity. In the event of a
# specificity tie, the most recently registered listener is invoked first. This
# mirrors the "cascade" semantics of CSS. Event listeners are invoked in the
# context of the current DOM node, meaning `this` always points at
# `event.currentTarget`. As is normally the case with DOM events,
# `stopPropagation` and `stopImmediatePropagation` can be used to terminate the
# bubbling process and prevent invocation of additional listeners.
#
# ## Example
#
# Here is a command that inserts the current date in an editor:
#
# ```coffee
# atom.commands.add '.editor',
#   'user:insert-date': (event) ->
#     editor = $(this).view().getModel()
#     # soon the above above line will be:
#     # editor = @getModel()
#     editor.insertText(new Date().toLocaleString())
# ```
class CommandRegistry
  constructor: (@rootNode) ->
    @registeredCommands = {}
    @selectorBasedListenersByCommandName = {}
    @inlineListenersByCommandName = {}

  getRootNode: -> @rootNode

  setRootNode: (newRootNode) ->
    oldRootNode = @rootNode
    @rootNode = newRootNode
    for commandName of @registeredCommands
      @removeDOMListener(oldRootNode, commandName)
      @addDOMListener(newRootNode, commandName)

  # Public: Add one or more command listeners associated with a selector.
  #
  # ## Arguments: Registering One Command
  #
  # * `selector` A {String} containing a CSS selector matching elements on which
  #   you want to handle the commands. The `,` combinator is not currently
  #   supported.
  # * `commandName` A {String} containing the name of a command you want to
  #   handle such as `user:insert-date`.
  # * `callback` A {Function} to call when the given command is invoked on an
  #   element matching the selector. It will be called with `this` referencing
  #   the matching DOM node.
  #   * `event` A standard DOM event instance. Call `stopPropagation` or
  #     `stopImmediatePropagation` to terminate bubbling early.
  #
  # ## Arguments: Registering Multiple Commands
  #
  # * `selector` A {String} containing a CSS selector matching elements on which
  #   you want to handle the commands. The `,` combinator is not currently
  #   supported.
  # * `commands` An {Object} mapping command names like `user:insert-date` to
  #   listener {Function}s.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added command handler(s).
  add: (target, commandName, callback) ->
    if typeof commandName is 'object'
      commands = commandName
      disposable = new CompositeDisposable
      for commandName, callback of commands
        disposable.add @add(target, commandName, callback)
      return disposable

    if typeof target is 'string'
      @addSelectorBasedListener(target, commandName, callback)
    else
      @addInlineListener(target, commandName, callback)

  addSelectorBasedListener: (selector, commandName, callback) ->
    @selectorBasedListenersByCommandName[commandName] ?= []
    listenersForCommand = @selectorBasedListenersByCommandName[commandName]
    listener = new SelectorBasedListener(selector, callback)
    listenersForCommand.push(listener)

    @commandRegistered(commandName)

    new Disposable =>
      listenersForCommand.splice(listenersForCommand.indexOf(listener), 1)
      delete @selectorBasedListenersByCommandName[commandName] if listenersForCommand.length is 0

  addInlineListener: (element, commandName, callback) ->
    @inlineListenersByCommandName[commandName] ?= new WeakMap

    listenersForCommand = @inlineListenersByCommandName[commandName]
    unless listenersForElement = listenersForCommand.get(element)
      listenersForElement = []
      listenersForCommand.set(element, listenersForElement)
    listener = new InlineListener(callback)
    listenersForElement.push(listener)

    @commandRegistered(commandName)

    new Disposable =>
      listenersForElement.splice(listenersForElement.indexOf(listener), 1)
      listenersForCommand.delete(element) if listenersForElement.length is 0
      @listenerRemovedForCommand(commandName)

  # Public: Find all registered commands matching a query.
  #
  # * `params` An {Object} containing one or more of the following keys:
  #   * `target` A DOM node that is the hypothetical target of a given command.
  #
  # Returns an {Array} of {Object}s containing the following keys:
  #  * `name` The name of the command. For example, `user:insert-date`.
  #  * `displayName` The display name of the command. For example,
  #    `User: Insert Date`.
  #  * `jQuery` Present if the command was registered with the legacy
  #    `$::command` method.
  findCommands: ({target}) ->
    commands = []
    target = @rootNode unless @rootNode.contains(target)
    currentTarget = target
    loop
      for commandName, listeners of @selectorBasedListenersByCommandName
        for listener in listeners
          if currentTarget.webkitMatchesSelector(listener.selector)
            commands.push
              name: commandName
              displayName: _.humanizeEventName(commandName)

      break if currentTarget is @rootNode
      currentTarget = currentTarget.parentNode
      break unless currentTarget?

    for name, displayName of $(target).events() when displayName
      commands.push({name, displayName, jQuery: true})

    for name, displayName of $(window).events() when displayName
      commands.push({name, displayName, jQuery: true})

    commands

  # Public: Simulate the dispatch of a command on a DOM node.
  #
  # This can be useful for testing when you want to simulate the invocation of a
  # command on a detached DOM node. Otherwise, the DOM node in question needs to
  # be attached to the document so the event bubbles up to the root node to be
  # processed.
  #
  # * `target` The DOM node at which to start bubbling the command event.
  # * `commandName` {String} indicating the name of the command to dispatch.
  dispatch: (target, commandName) ->
    event = new CustomEvent(commandName, bubbles: true)
    eventWithTarget = Object.create(event, target: value: target)
    @handleCommandEvent(eventWithTarget)

  getSnapshot: ->
    snapshot = {}
    for commandName, listeners of @selectorBasedListenersByCommandName
      snapshot[commandName] = listeners.slice()
    snapshot

  restoreSnapshot: (snapshot) ->
    rootNode = @getRootNode()
    @setRootNode(null) # clear listeners for current commands
    @registeredCommands = {}
    @inlineListenersByCommandName = {}
    @selectorBasedListenersByCommandName = {}
    for commandName, listeners of snapshot
      @selectorBasedListenersByCommandName[commandName] = listeners.slice()
      @registeredCommands[commandName] = true
    @setRootNode(rootNode) # restore listeners for commands in snapshot

  handleCommandEvent: (originalEvent) =>
    originalEvent.__handledByCommandRegistry = true

    propagationStopped = false
    immediatePropagationStopped = false
    matched = false
    currentTarget = originalEvent.target
    invokedListeners = []

    syntheticEvent = Object.create originalEvent,
      eventPhase: value: Event.BUBBLING_PHASE
      currentTarget: get: -> currentTarget
      stopPropagation: value: ->
        originalEvent.stopPropagation()
        propagationStopped = true
      stopImmediatePropagation: value: ->
        originalEvent.stopImmediatePropagation()
        propagationStopped = true
        immediatePropagationStopped = true
      disableInvokedListeners: value: ->
        listener.enabled = false for listener in invokedListeners
        -> listener.enabled = true for listener in invokedListeners

    loop
      inlineListeners = @inlineListenersByCommandName[originalEvent.type]?.get(currentTarget) ? []
      selectorBasedListeners =
        (@selectorBasedListenersByCommandName[originalEvent.type] ? [])
          .filter (listener) -> currentTarget.webkitMatchesSelector(listener.selector)
          .sort (a, b) -> a.compare(b)
      listeners = inlineListeners.concat(selectorBasedListeners)
      matched = true if listeners.length > 0

      for listener in listeners when listener.enabled
        break if immediatePropagationStopped
        invokedListeners.push(listener)
        listener.callback.call(currentTarget, syntheticEvent)

      break if currentTarget is @rootNode
      break if propagationStopped
      currentTarget = currentTarget.parentNode
      break unless currentTarget?

    matched

  handleJQueryCommandEvent: (event) =>
    @handleCommandEvent(event) unless event.originalEvent?.__handledByCommandRegistry

  commandRegistered: (commandName) ->
    unless @registeredCommands[commandName]
      @addDOMListener(@rootNode, commandName)
      @registeredCommands[commandName] = true

  addDOMListener: (node, commandName) ->
    node?.addEventListener(commandName, @handleCommandEvent, true)
    $(node).on commandName, @handleJQueryCommandEvent

  removeDOMListener: (node, commandName) ->
    node?.removeEventListener(commandName, @handleCommandEvent, true)
    $(node).off commandName, @handleJQueryCommandEvent

class SelectorBasedListener
  enabled: true

  constructor: (@selector, @callback) ->
    @specificity = (SpecificityCache[@selector] ?= specificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber

class InlineListener
  enabled: true

  constructor: (@callback) ->
