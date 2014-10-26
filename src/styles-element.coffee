{Emitter, CompositeDisposable} = require 'event-kit'

class StylesElement extends HTMLElement
  createdCallback: ->
    @emitter = new Emitter

  onDidAddStyleElement: (callback) ->
    @emitter.on 'did-add-style-element', callback

  onDidRemoveStyleElement: (callback) ->
    @emitter.on 'did-remove-style-element', callback

  onDidUpdateStyleElement: (callback) ->
    @emitter.on 'did-update-style-element', callback

  attachedCallback: ->
    @subscriptions = new CompositeDisposable
    @styleElementClonesByOriginalElement = new WeakMap
    @subscriptions.add atom.styles.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add atom.styles.onDidRemoveStyleElement(@styleElementRemoved.bind(this))
    @subscriptions.add atom.styles.onDidUpdateStyleElement(@styleElementUpdated.bind(this))

  styleElementAdded: (styleElement) ->
    styleElementClone = styleElement.cloneNode(true)
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
    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement)
    styleElementClone.remove()
    @emitter.emit 'did-remove-style-element', styleElementClone

  styleElementUpdated: (styleElement) ->
    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement)
    styleElementClone.textContent = styleElement.textContent
    @emitter.emit 'did-update-style-element', styleElementClone

  detachedCallback: ->
    @subscriptions.dispose()

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
