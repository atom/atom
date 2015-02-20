{Model} = require 'theorist'
{Emitter, CompositeDisposable} = require 'event-kit'
{flatten} = require 'underscore-plus'
Serializable = require 'serializable'

module.exports =
class PaneAxis extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  parent: null
  container: null
  orientation: null

  constructor: ({@container, @orientation, children}) ->
    @emitter = new Emitter
    @subscriptionsByChild = new WeakMap
    @subscriptions = new CompositeDisposable
    @children = []
    if children?
      @addChild(child) for child in children

  deserializeParams: (params) ->
    {container} = params
    params.children = params.children.map (childState) -> atom.deserializers.deserialize(childState, {container})
    params

  serializeParams: ->
    children: @children.map (child) -> child.serialize()
    orientation: @orientation

  getParent: -> @parent

  setParent: (@parent) -> @parent

  getContainer: -> @container

  setContainer: (@container) -> @container

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

  addChild: (child, index=@children.length) ->
    child.setParent(this)
    child.setContainer(@container)

    @subscribeToChild(child)

    @children.splice(index, 0, child)
    @emitter.emit 'did-add-child', {child, index}

  removeChild: (child, replacing=false) ->
    index = @children.indexOf(child)
    throw new Error("Removing non-existent child") if index is -1

    @unsubscribeFromChild(child)

    @children.splice(index, 1)
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
    @parent.replaceChild(this, @children[0])
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
