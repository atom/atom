{CompositeDisposable} = require 'event-kit'

class StylesElement extends HTMLElement
  attachedCallback: ->
    @subscriptions = new CompositeDisposable
    @styleElementClonesByOriginalElement = new WeakMap
    @subscriptions.add atom.styles.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add atom.styles.onDidRemoveStyleElement(@styleElementRemoved.bind(this))

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

  styleElementRemoved: (styleElement) ->
    @styleElementClonesByOriginalElement.get(styleElement).remove()

  detachedCallback: ->
    @subscriptions.dispose()

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
