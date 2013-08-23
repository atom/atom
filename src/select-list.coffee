$ = require 'jquery'
{ View } = require 'space-pen'
Editor = require 'editor'
fuzzyFilter = require 'fuzzy-filter'

# Public: Provides a widget for users to make a selection from a list of
# choices.
module.exports =
class SelectList extends View

  # Private:
  @content: ->
    @div class: @viewClass(), =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group highlight-selected', outlet: 'list'

  # Private:
  @viewClass: -> 'select-list'

  maxItems: Infinity
  scheduleTimeout: null
  inputThrottle: 50
  cancelling: false

  # Public:
  initialize: ->
    @miniEditor.getBuffer().on 'changed', => @schedulePopulateList()
    @miniEditor.on 'focusout', => @cancel() unless @cancelling
    @on 'core:move-up', => @selectPreviousItem()
    @on 'core:move-down', => @selectNextItem()
    @on 'core:move-to-top', =>
      @selectItem(@list.find('li:first'))
      @list.scrollToTop()
      false
    @on 'core:move-to-bottom', =>
      @selectItem(@list.find('li:last'))
      @list.scrollToBottom()
      false
    @on 'core:confirm', => @confirmSelection()
    @on 'core:cancel', => @cancel()

    @list.on 'mousedown', 'li', (e) =>
      @selectItem($(e.target).closest('li'))
      e.preventDefault()

    @list.on 'mouseup', 'li', (e) =>
      @confirmSelection() if $(e.target).closest('li').hasClass('selected')
      e.preventDefault()

  # Private:
  schedulePopulateList: ->
    clearTimeout(@scheduleTimeout)
    populateCallback = =>
      @populateList() if @isOnDom()
    @scheduleTimeout = setTimeout(populateCallback,  @inputThrottle)

  # Public:
  setArray: (@array) ->
    @populateList()
    @setLoading()

  # Public:
  setError: (message='') ->
    if message.length is 0
      @error.text('').hide()
    else
      @setLoading()
      @error.text(message).show()

  # Public:
  setLoading: (message='') ->
    if message.length is 0
      @loading.text("")
      @loadingBadge.text("")
      @loadingArea.hide()
    else
      @setError()
      @loading.text(message)
      @loadingArea.show()

  # Public:
  getFilterQuery: ->
    @miniEditor.getText()

  # Public:
  populateList: ->
    return unless @array?

    filterQuery = @getFilterQuery()
    if filterQuery.length
      filteredArray = fuzzyFilter(@array, filterQuery, key: @filterKey)
    else
      filteredArray = @array

    @list.empty()
    if filteredArray.length
      @setError(null)

      for i in [0...Math.min(filteredArray.length, @maxItems)]
        element = filteredArray[i]
        item = @itemForElement(element)
        item.data('select-list-element', element)
        @list.append(item)

      @selectItem(@list.find('li:first'))
    else
      @setError(@getEmptyMessage(@array.length, filteredArray.length))

  # Public:
  getEmptyMessage: (itemCount, filteredItemCount) -> 'No matches found'

  # Private:
  selectPreviousItem: ->
    item = @getSelectedItem().prev()
    item = @list.find('li:last') unless item.length
    @selectItem(item)

  # Private:
  selectNextItem: ->
    item = @getSelectedItem().next()
    item = @list.find('li:first') unless item.length
    @selectItem(item)

  # Public:
  selectItem: (item) ->
    return unless item.length
    @list.find('.selected').removeClass('selected')
    item.addClass 'selected'
    @scrollToItem(item)

  # Public:
  scrollToItem: (item) ->
    scrollTop = @list.scrollTop()
    desiredTop = item.position().top + scrollTop
    desiredBottom = desiredTop + item.outerHeight()

    if desiredTop < scrollTop
      @list.scrollTop(desiredTop)
    else if desiredBottom > @list.scrollBottom()
      @list.scrollBottom(desiredBottom)

  # Public:
  getSelectedItem: ->
    @list.find('li.selected')

  # Public:
  getSelectedElement: ->
    @getSelectedItem().data('select-list-element')

  # Public:
  confirmSelection: ->
    element = @getSelectedElement()
    if element?
      @confirmed(element)
    else
      @cancel()

  # Private:
  attach: ->
    @storeFocusedElement()

  # Private:
  storeFocusedElement: ->
    @previouslyFocusedElement = $(':focus')

  # Private:
  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      rootView.focus()

  # Public:
  cancelled: ->
    @miniEditor.setText('')
    @miniEditor.updateDisplay()

  # Public:
  cancel: ->
    @list.empty()
    @cancelling = true
    miniEditorFocused = @miniEditor.isFocused
    @cancelled()
    @detach()
    @restoreFocus() if miniEditorFocused
    @cancelling = false
    clearTimeout(@scheduleTimeout)
