{Emitter, CompositeDisposable} = require 'event-kit'

class StylesElement extends HTMLElement
  subscriptions: null
  context: null

  onDidAddStyleElement: (callback) ->
    @emitter.on 'did-add-style-element', callback

  onDidRemoveStyleElement: (callback) ->
    @emitter.on 'did-remove-style-element', callback

  onDidUpdateStyleElement: (callback) ->
    @emitter.on 'did-update-style-element', callback

  createdCallback: ->
    @emitter = new Emitter
    @styleElementClonesByOriginalElement = new WeakMap

  attachedCallback: ->
    @initialize()

  detachedCallback: ->
    @subscriptions.dispose()
    @subscriptions = null

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    @contextChanged() if attrName is 'context'

  initialize: ->
    return if @subscriptions?

    @subscriptions = new CompositeDisposable
    @context = @getAttribute('context') ? undefined

    @subscriptions.add atom.styles.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add atom.styles.onDidRemoveStyleElement(@styleElementRemoved.bind(this))
    @subscriptions.add atom.styles.onDidUpdateStyleElement(@styleElementUpdated.bind(this))

  contextChanged: ->
    return unless @subscriptions?

    @styleElementRemoved(child) for child in Array::slice.call(@children)
    @context = @getAttribute('context')
    @styleElementAdded(styleElement) for styleElement in atom.styles.getStyleElements()

  styleElementAdded: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = styleElement.cloneNode(true)
    styleElementClone.context = styleElement.context
    @styleElementClonesByOriginalElement.set(styleElement, styleElementClone)

    group = styleElement.getAttribute('group')
    if group?
      for child in @children
        if child.getAttribute('group') is group and child.nextSibling?.getAttribute('group') isnt group
          insertBefore = child.nextSibling
          break

    @insertBefore(styleElementClone, insertBefore)
    @emitter.emit 'did-add-style-element', styleElementClone

  styleElementRemoved: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement) ? styleElement
    styleElementClone.remove()
    @emitter.emit 'did-remove-style-element', styleElementClone

  styleElementUpdated: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement)
    styleElementClone.textContent = styleElement.textContent
    @emitter.emit 'did-update-style-element', styleElementClone

  styleElementMatchesContext: (styleElement) ->
    not @context? or styleElement.context is @context

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
