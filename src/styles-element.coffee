{Emitter, CompositeDisposable} = require 'event-kit'
selectorProcessor = require 'postcss-selector-parser'
SPATIAL_DECORATIONS = new Set([
  'invisible-character', 'hard-tab', 'leading-whitespace',
  'trailing-whitespace', 'eol', 'indent-guide', 'fold-marker'
])

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
    @subscriptions = new CompositeDisposable
    @emitter = new Emitter
    @styleElementClonesByOriginalElement = new WeakMap

  attachedCallback: ->
    for styleElement in @children
      @upgradeDeprecatedSelectors(styleElement)

    @context = @getAttribute('context') ? undefined

  detachedCallback: ->
    @subscriptions.dispose()
    @subscriptions = new CompositeDisposable

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    @contextChanged() if attrName is 'context'

  initialize: (@styleManager) ->
    throw new Error("Must pass a styleManager parameter when initializing a StylesElement") unless @styleManager?

    @subscriptions.add @styleManager.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add @styleManager.onDidRemoveStyleElement(@styleElementRemoved.bind(this))
    @subscriptions.add @styleManager.onDidUpdateStyleElement(@styleElementUpdated.bind(this))

  contextChanged: ->
    return unless @subscriptions?

    @styleElementRemoved(child) for child in Array::slice.call(@children)
    @context = @getAttribute('context')
    @styleElementAdded(styleElement) for styleElement in @styleManager.getStyleElements()
    return

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

    transformDeprecatedShadowSelectors = (selectors) ->
      selectors.each (selector) ->
        isSyntaxSelector = not selector.some((node) ->
          (node.type is 'tag' and node.value is 'atom-text-editor') or
          (node.type is 'class' and node.value is 'region') or
          (node.type is 'class' and node.value is 'wrap-guide') or
          (node.type is 'class' and /spell-check/.test(node.value))
        )
        previousNode = null
        selector.each (node) ->
          isShadowPseudoClass = node.type is 'pseudo' and node.value is '::shadow'
          isHostPseudoClass = node.type is 'pseudo' and node.value is ':host'
          if isHostPseudoClass and not previousNode?
            newNode = selectorProcessor.tag({value: 'atom-text-editor'})
            node.replaceWith(newNode)
            previousNode = newNode
          else if isShadowPseudoClass and previousNode?.type is 'tag' and previousNode?.value is 'atom-text-editor'
            selector.removeChild(node)
          else
            if styleElement.context is 'atom-text-editor' and node.type is 'class'
              if (isSyntaxSelector and not node.value.startsWith('syntax--')) or SPATIAL_DECORATIONS.has(node.value)
                node.value = 'syntax--' + node.value
            previousNode = node

    upgradedSelectors = []
    for rule in styleElement.sheet.cssRules when rule.selectorText?
      inputSelector = rule.selectorText
      outputSelector = rule.selectorText
      outputSelector = selectorProcessor(transformDeprecatedShadowSelectors).process(outputSelector).result
      if inputSelector isnt outputSelector
        rule.selectorText = outputSelector
        upgradedSelectors.push({inputSelector, outputSelector})

    if upgradedSelectors.length > 0
      upgradedSelectorsText = upgradedSelectors.map(({inputSelector, outputSelector}) -> "`#{inputSelector}` => `#{outputSelector}`").join('\n')
      console.warn("""
      Shadow DOM for `atom-text-editor` elements has been removed. This means
      should stop using :host and ::shadow pseudo-selectors, and prepend all
      your syntax selectors with `syntax--`. To prevent breakage with existing
      stylesheets, we have automatically upgraded the following selectors in
      `#{styleElement.sourcePath}`:

      #{upgradedSelectorsText}
      """)

module.exports = StylesElement = document.registerElement 'atom-styles', prototype: StylesElement.prototype
