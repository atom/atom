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
    if @context is 'atom-text-editor'
      for styleElement in @children
        @upgradeDeprecatedSelectors(styleElement)
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
    styleElementClone.sourcePath = styleElement.sourcePath
    styleElementClone.context = styleElement.context
    styleElementClone.priority = styleElement.priority
    @styleElementClonesByOriginalElement.set(styleElement, styleElementClone)

    priority = styleElement.priority
    if priority?
      for child in @children
        if child.priority > priority
          insertBefore = child
          break

    @insertBefore(styleElementClone, insertBefore)

    if @context is 'atom-text-editor'
      @upgradeDeprecatedSelectors(styleElementClone)

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

  upgradeDeprecatedSelectors: (styleElement) ->
    return unless styleElement.sheet?

    upgradedSelectors = []

    for rule in styleElement.sheet.cssRules
      continue unless rule.selectorText?
      continue if /\:host/.test(rule.selectorText)

      inputSelector = rule.selectorText
      outputSelector = rule.selectorText
        .replace(/\.editor-colors($|[ >])/g, ':host$1')
        .replace(/\.editor([:.][^ ,>]+)/g, ':host($1)')
        .replace(/\.editor($|[ ,>])/g, ':host$1')

      unless inputSelector is outputSelector
        rule.selectorText = outputSelector
        upgradedSelectors.push({inputSelector, outputSelector})

    if upgradedSelectors.length > 0
      warning = "Upgraded the following syntax theme selectors in `#{styleElement.sourcePath}` for shadow DOM compatibility:\n\n"
      for {inputSelector, outputSelector} in upgradedSelectors
        warning += "`#{inputSelector}` => `#{outputSelector}`\n"

      warning += "\nSee the upgrade guide for information on removing this warning."
      console.warn(warning)

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
