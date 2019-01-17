{CompositeDisposable, Disposable} = require 'atom'
_ = require 'underscore-plus'
Grim = require 'grim'

module.exports =
class DeprecationCopStatusBarView
  lastLength: null
  toolTipDisposable: null

  constructor: ->
    @subscriptions = new CompositeDisposable

    @element = document.createElement('div')
    @element.classList.add('deprecation-cop-status', 'inline-block', 'text-warning')
    @element.setAttribute('tabindex', -1)

    @icon = document.createElement('span')
    @icon.classList.add('icon', 'icon-alert')
    @element.appendChild(@icon)

    @deprecationNumber = document.createElement('span')
    @deprecationNumber.classList.add('deprecation-number')
    @deprecationNumber.textContent = '0'
    @element.appendChild(@deprecationNumber)

    clickHandler = ->
      workspaceElement = atom.views.getView(atom.workspace)
      atom.commands.dispatch workspaceElement, 'deprecation-cop:view'
    @element.addEventListener('click', clickHandler)
    @subscriptions.add(new Disposable(=> @element.removeEventListener('click', clickHandler)))

    @update()

    debouncedUpdateDeprecatedSelectorCount = _.debounce(@update, 1000)

    @subscriptions.add Grim.on 'updated', @update
    # TODO: Remove conditional when the new StyleManager deprecation APIs reach stable.
    if atom.styles.onDidUpdateDeprecations?
      @subscriptions.add(atom.styles.onDidUpdateDeprecations(debouncedUpdateDeprecatedSelectorCount))

  destroy: ->
    @subscriptions.dispose()
    @element.remove()

  getDeprecatedCallCount: ->
    Grim.getDeprecations().map((d) -> d.getStackCount()).reduce(((a, b) -> a + b), 0)

  getDeprecatedStyleSheetsCount: ->
    # TODO: Remove conditional when the new StyleManager deprecation APIs reach stable.
    if atom.styles.getDeprecations?
      Object.keys(atom.styles.getDeprecations()).length
    else
      0

  update: =>
    length = @getDeprecatedCallCount() + @getDeprecatedStyleSheetsCount()

    return if @lastLength is length

    @lastLength = length
    @deprecationNumber.textContent = "#{_.pluralize(length, 'deprecation')}"
    @toolTipDisposable?.dispose()
    @toolTipDisposable = atom.tooltips.add @element, title: "#{_.pluralize(length, 'call')} to deprecated methods"

    if length is 0
      @element.style.display = 'none'
    else
      @element.style.display = ''
