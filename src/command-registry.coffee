{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{calculateSpecificity, validateSelector} = require 'clear-cut'
_ = require 'underscore-plus'
{$} = require './space-pen-extensions'

SequenceCount = 0

# Public: Associates listener functions with commands in a
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
# Command names must follow the `namespace:action` pattern, where `namespace`
# will typically be the name of your package, and `action` describes the
# behavior of your command. If either part consists of multiple words, these
# must be separated by hyphens. E.g. `awesome-package:turn-it-up-to-eleven`.
# All words should be lowercased.
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
# atom.commands.add 'atom-text-editor',
#   'user:insert-date': (event) ->
#     editor = @getModel()
#     editor.insertText(new Date().toLocaleString())
# ```
module.exports =
class CommandRegistry
  constructor: (@rootNode) ->
    @registeredCommands = {}
    @selectorBasedListenersByCommandName = {}
    @inlineListenersByCommandName = {}
    @emitter = new Emitter

  destroy: ->
    for commandName of @registeredCommands
      window.removeEventListener(commandName, @handleCommandEvent, true)
    return

  # Public: Add one or more command listeners associated with a selector.
  #
  # ## Arguments: Registering One Command
  #
  # * `target` A {String} containing a CSS selector or a DOM element. If you
  #   pass a selector, the command will be globally associated with all matching
  #   elements. The `,` combinator is not currently supported. If you pass a
  #   DOM element, the command will be associated with just that element.
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
  # * `target` A {String} containing a CSS selector or a DOM element. If you
  #   pass a selector, the commands will be globally associated with all
  #   matching elements. The `,` combinator is not currently supported.
  #   If you pass a DOM element, the command will be associated with just that
  #   element.
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

    if typeof callback isnt 'function'
      throw new Error("Can't register a command with non-function callback.")

    if typeof target is 'string'
      validateSelector(target)
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

    new Disposable ->
      listenersForElement.splice(listenersForElement.indexOf(listener), 1)
      listenersForCommand.delete(element) if listenersForElement.length is 0

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
    commandNames = new Set
    commands = []
    currentTarget = target
    loop
      for name, listeners of @inlineListenersByCommandName
        if listeners.has(currentTarget) and not commandNames.has(name)
          commandNames.add(name)
          commands.push({name, displayName: _.humanizeEventName(name)})

      for commandName, listeners of @selectorBasedListenersByCommandName
        for listener in listeners
          if currentTarget.webkitMatchesSelector?(listener.selector)
            unless commandNames.has(commandName)
              commandNames.add(commandName)
              commands.push
                name: commandName
                displayName: _.humanizeEventName(commandName)

      break if currentTarget is window
      currentTarget = currentTarget.parentNode ? window

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
  dispatch: (target, commandName, detail) ->
    event = new CustomEvent(commandName, {bubbles: true, detail})
    eventWithTarget = Object.create {},
      target: value: target
      preventDefault: value: ->
      stopPropagation: value: ->
      stopImmediatePropagation: value: ->
    # In Chrome 43, Object.create doesn't work well with CustomEvent.
    for k, v of event when k not in eventWithTarget
      eventWithTarget[k] = v
    @handleCommandEvent(eventWithTarget)

  # Public: Invoke the given callback before dispatching a command event.
  #
  # * `callback` {Function} to be called before dispatching each command
  #   * `event` The Event that will be dispatched
  onWillDispatch: (callback) ->
    @emitter.on 'will-dispatch', callback

  # Public: Invoke the given callback after dispatching a command event.
  #
  # * `callback` {Function} to be called after dispatching each command
  #   * `event` The Event that was dispatched
  onDidDispatch: (callback) ->
    @emitter.on 'did-dispatch', callback

  getSnapshot: ->
    snapshot = {}
    for commandName, listeners of @selectorBasedListenersByCommandName
      snapshot[commandName] = listeners.slice()
    snapshot

  restoreSnapshot: (snapshot) ->
    @selectorBasedListenersByCommandName = {}
    for commandName, listeners of snapshot
      @selectorBasedListenersByCommandName[commandName] = listeners.slice()
    return

  handleCommandEvent: (originalEvent) =>
    propagationStopped = false
    immediatePropagationStopped = false
    matched = false
    currentTarget = originalEvent.target

    syntheticEvent = Object.create {},
      eventPhase: value: Event.BUBBLING_PHASE
      currentTarget: get: -> currentTarget
      preventDefault: value: ->
        originalEvent.preventDefault()
      stopPropagation: value: ->
        originalEvent.stopPropagation()
        propagationStopped = true
      stopImmediatePropagation: value: ->
        originalEvent.stopImmediatePropagation()
        propagationStopped = true
        immediatePropagationStopped = true
      abortKeyBinding: value: ->
        originalEvent.abortKeyBinding?()
    # In Chrome 43, Object.create doesn't work well with CustomEvent.
    for k, v of originalEvent when k not in syntheticEvent
      syntheticEvent[k] = v

    @emitter.emit 'will-dispatch', syntheticEvent

    loop
      listeners = @inlineListenersByCommandName[originalEvent.type]?.get(currentTarget) ? []
      if currentTarget.webkitMatchesSelector?
        selectorBasedListeners =
          (@selectorBasedListenersByCommandName[originalEvent.type] ? [])
            .filter (listener) -> currentTarget.webkitMatchesSelector(listener.selector)
            .sort (a, b) -> a.compare(b)
        listeners = listeners.concat(selectorBasedListeners)

      matched = true if listeners.length > 0

      for listener in listeners
        break if immediatePropagationStopped
        listener.callback.call(currentTarget, syntheticEvent)

      break if currentTarget is window
      break if propagationStopped
      currentTarget = currentTarget.parentNode ? window

    @emitter.emit 'did-dispatch', syntheticEvent

    matched

  commandRegistered: (commandName) ->
    unless @registeredCommands[commandName]
      window.addEventListener(commandName, @handleCommandEvent, true)
      @registeredCommands[commandName] = true

class SelectorBasedListener
  constructor: (@selector, @callback) ->
    @specificity = calculateSpecificity(@selector)
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber

class InlineListener
  constructor: (@callback) ->
