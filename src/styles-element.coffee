{CompositeDisposable} = require 'event-kit'

class StylesElement extends HTMLElement
  attachedCallback: ->
    @subscriptions = new CompositeDisposable
    @styleElementClonesByOriginalElement = new WeakMap
    @subscriptions.add atom.styles.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add atom.styles.onDidRemoveStyleElement(@styleElementRemoved.bind(this))

  styleElementAdded: (styleElement) ->
    {group} = styleElement
    styleElementClone = styleElement.cloneNode(true)
    styleElementClone.group = group
    @styleElementClonesByOriginalElement.set(styleElement, styleElementClone)

    if group?
      for child in @children
        if child.group is group and child.nextSibling?.group isnt group
          insertBefore = child.nextSibling
          break

    @insertBefore(styleElementClone, insertBefore)

  styleElementRemoved: (styleElement) ->
    @styleElementClonesByOriginalElement.get(styleElement).remove()

  detachedCallback: ->
    @subscriptions.dispose()

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
