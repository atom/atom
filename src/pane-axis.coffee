{Emitter, CompositeDisposable} = require 'event-kit'
{flatten} = require 'underscore-plus'
Model = require './model'

module.exports =
class PaneAxis extends Model
  parent: null
  container: null
  orientation: null

  @deserialize: (state, {deserializers}) ->
    state.children = state.children.map (childState) ->
      deserializers.deserialize(childState)
    new this(state)

  constructor: ({@orientation, children, flexScale}={}) ->
    @emitter = new Emitter
    @subscriptionsByChild = new WeakMap
    @subscriptions = new CompositeDisposable
    @children = []
    if children?
      @addChild(child) for child in children
    @flexScale = flexScale ? 1

  serialize: ->
    deserializer: 'PaneAxis'
    children: @children.map (child) -> child.serialize()
    orientation: @orientation
    flexScale: @flexScale

  getFlexScale: -> @flexScale

  setFlexScale: (@flexScale) ->
    @emitter.emit 'did-change-flex-scale', @flexScale
    @flexScale

  getParent: -> @parent

  setParent: (@parent) -> @parent

  getContainer: -> @container

  setContainer: (container) ->
    if container and container isnt @container
      @container = container
      child.setContainer(container) for child in @children

  getOrientation: -> @orientation

  getChildren: -> @children.slice()

  getPanes: ->
    flatten(@children.map (child) -> child.getPanes())

  getItems: ->
    flatten(@children.map (child) -> child.getItems())

  onDidAddChild: (fn) ->
    @emitter.on 'did-add-child', fn

  onDidRemoveChild: (fn) ->
    @emitter.on 'did-remove-child', fn

  onDidReplaceChild: (fn) ->
    @emitter.on 'did-replace-child', fn

  onDidDestroy: (fn) ->
    @emitter.on 'did-destroy', fn

  onDidChangeFlexScale: (fn) ->
    @emitter.on 'did-change-flex-scale', fn

  observeFlexScale: (fn) ->
    fn(@flexScale)
    @onDidChangeFlexScale(fn)

  addChild: (child, index=@children.length) ->
    child.setParent(this)
    child.setContainer(@container)

    @subscribeToChild(child)

    @children.splice(index, 0, child)
    @emitter.emit 'did-add-child', {child, index}

  adjustFlexScale: ->
    # get current total flex scale of children
    total = 0
    total += child.getFlexScale() for child in @children

    needTotal = @children.length
    # set every child's flex scale by the ratio
    for child in @children
      child.setFlexScale(needTotal * child.getFlexScale() / total)

  removeChild: (child, replacing=false) ->
    index = @children.indexOf(child)
    throw new Error("Removing non-existent child") if index is -1

    @unsubscribeFromChild(child)

    @children.splice(index, 1)
    @adjustFlexScale()
    @emitter.emit 'did-remove-child', {child, index}
    @reparentLastChild() if not replacing and @children.length < 2

  replaceChild: (oldChild, newChild) ->
    @unsubscribeFromChild(oldChild)
    @subscribeToChild(newChild)

    newChild.setParent(this)
    newChild.setContainer(@container)

    index = @children.indexOf(oldChild)
    @children.splice(index, 1, newChild)
    @emitter.emit 'did-replace-child', {oldChild, newChild, index}

  insertChildBefore: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @addChild(newChild, index)

  insertChildAfter: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @addChild(newChild, index + 1)

  reparentLastChild: ->
    lastChild = @children[0]
    lastChild.setFlexScale(@flexScale)
    @parent.replaceChild(this, lastChild)
    @destroy()

  subscribeToChild: (child) ->
    subscription = child.onDidDestroy => @removeChild(child)
    @subscriptionsByChild.set(child, subscription)
    @subscriptions.add(subscription)

  unsubscribeFromChild: (child) ->
    subscription = @subscriptionsByChild.get(child)
    @subscriptions.remove(subscription)
    subscription.dispose()

  destroyed: ->
    @subscriptions.dispose()
    @emitter.emit 'did-destroy'
    @emitter.dispose()
