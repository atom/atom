{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{specificity} = require 'clear-cut'
_ = require 'underscore-plus'
Grim = require 'grim'
{$} = require './space-pen-extensions'

SequenceCount = 0
SpecificityCache = {}

NativeEventBubbling = {
  'abort': false
  'blur': false
  'error': false
  'focus': false
  'load': false
  'mouseenter': false
  'mouseleave': false
  'resize': false
  'scroll': false
  'unload': false
}


module.exports =

# Public: Associates listener functions with commands in a context-sensitive way
# using CSS selectors. You can access a global instance of this class via
# `atom.commands`, and commands registered there will be presented in the
# command palette.
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
# atom.commands.listen 'atom-text-editor',
#   'user:insert-date': (event) ->
#     editor = $(this).view().getModel()
#     # soon the above above line will be:
#     # editor = @getModel()
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
  listen: (target, commandName, callback, useCapture=false) ->
    if typeof commandName is 'object'
      commands = commandName
      disposable = new CompositeDisposable
      for commandName, callback of commands
        disposable.add @listen(target, commandName, callback, useCapture)
      return disposable

    if typeof target is 'string'
      @addSelectorBasedListener(target, commandName, callback, useCapture)
    else
      @addInlineListener(target, commandName, callback, useCapture)

  add: (target, commandName, callback) ->
    Grim.deprecate("Use CommandRegistry::listen instead")
    @listen(target, commandName, callback)

  capture: (target, commandName, callback) ->
    @listen(target, commandName, callback, true)

  addSelectorBasedListener: (selector, commandName, callback, useCapture) ->
    @selectorBasedListenersByCommandName[commandName] ?= []
    listenersForCommand = @selectorBasedListenersByCommandName[commandName]
    listener = new SelectorBasedListener(selector, callback, useCapture)
    listenersForCommand.push(listener)

    @commandRegistered(commandName)

    new Disposable =>
      listenersForCommand.splice(listenersForCommand.indexOf(listener), 1)
      delete @selectorBasedListenersByCommandName[commandName] if listenersForCommand.length is 0

  addInlineListener: (element, commandName, callback, useCapture) ->
    @inlineListenersByCommandName[commandName] ?= new WeakMap

    listenersForCommand = @inlineListenersByCommandName[commandName]
    unless listenersForElement = listenersForCommand.get(element)
      listenersForElement = []
      listenersForCommand.set(element, listenersForElement)
    listener = new InlineListener(callback, useCapture)
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
    commands = []
    currentTarget = target
    loop
      for commandName, listeners of @selectorBasedListenersByCommandName
        for listener in listeners
          if currentTarget.webkitMatchesSelector?(listener.selector)
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
  # * `event` {String} indicating the name of the command to dispatch or a
  #     DOM event object.
  # * `detail` The detail to associate with the dispatched DOM event. If present
  #     overrides the `detail` of the `event` if it is a DOM event object.
  dispatch: (target, event, detail) ->
    if typeof event is 'string'
      event = new CustomEvent(event, {bubbles: NativeEventBubbling[event] ? true})

    eventWithTarget = Object.create event,
      target: value: target
      detail: value: detail ? event.detail
      preventDefault: value: ->
      stopPropagation: value: ->
      stopImmediatePropagation: value: ->
    @handleCommandEvent(eventWithTarget)

  onWillDispatch: (callback) ->
    @emitter.on 'will-dispatch', callback

  getSnapshot: ->
    snapshot = {}
    for commandName, listeners of @selectorBasedListenersByCommandName
      snapshot[commandName] = listeners.slice()
    snapshot

  restoreSnapshot: (snapshot) ->
    @selectorBasedListenersByCommandName = {}
    for commandName, listeners of snapshot
      @selectorBasedListenersByCommandName[commandName] = listeners.slice()

  handleCommandEvent: (originalEvent) =>
    propagationStopped = false
    immediatePropagationStopped = false
    invokedListener = false
    {target} = originalEvent
    currentTarget = null

    syntheticEvent = Object.create originalEvent,
      eventPhase: get: -> eventPhase
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

    @emitter.emit 'will-dispatch', syntheticEvent

    path = @getBubblePath(target)

    # Capture phase: Invoke listeners registered via {::capture}, starting with
    # the window and moving downward towards the event target.
    eventPhase = Event.CAPTURING_PHASE
    for pathIndex in [(path.length - 1)..0]
      currentTarget = path[pathIndex]
      listeners = @listenersForNode(currentTarget, originalEvent.type)
      for listener in listeners when listener.useCapture
        break if immediatePropagationStopped
        invokedListener = true
        listener.callback.call(currentTarget, syntheticEvent)
      break if propagationStopped

    return invokedListener if propagationStopped

    # Bubble phase: Invoke listeners registered via {::listen}, starting with
    # the event target and moving upward towards the window. If the event's
    # `.bubbles` property is false, we abort after dispatching on the target.
    eventPhase = Event.BUBBLING_PHASE
    for currentTarget in path
      listeners = @listenersForNode(currentTarget, originalEvent.type)
      for listener in listeners when not listener.useCapture
        break if immediatePropagationStopped
        invokedListener = true
        listener.callback.call(currentTarget, syntheticEvent)

      break unless originalEvent.bubbles
      break if propagationStopped

    invokedListener

  commandRegistered: (commandName) ->
    unless @registeredCommands[commandName]
      window.addEventListener(commandName, @handleCommandEvent, true)
      @registeredCommands[commandName] = true

  getBubblePath: (target) ->
    path = []
    currentTarget = target
    loop
      path.push(currentTarget)
      break if currentTarget is window
      currentTarget = currentTarget.parentNode ? window
    path

  listenersForNode: (node, eventType) ->
    listeners = @inlineListenersByCommandName[eventType]?.get(node) ? []
    if node.matches?
      selectorBasedListeners =
        (@selectorBasedListenersByCommandName[eventType] ? [])
          .filter (listener) -> node.matches(listener.selector)
          .sort (a, b) -> a.compare(b)
      listeners = listeners.concat(selectorBasedListeners)
    listeners

class SelectorBasedListener
  constructor: (@selector, @callback, @useCapture) ->
    @specificity = (SpecificityCache[@selector] ?= specificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber

class InlineListener
  constructor: (@callback, @useCapture) ->
