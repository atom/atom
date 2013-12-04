{$, View} = require './space-pen-extensions'
EditorView = require './editor-view'
fuzzyFilter = require('fuzzaldrin').filter

# Public: Provides a widget for users to make a selection from a list of
# choices.
module.exports =
class SelectList extends View

  # Private:
  @content: ->
    @div class: @viewClass(), =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

  # Private:
  @viewClass: -> 'select-list'

  maxItems: Infinity
  scheduleTimeout: null
  inputThrottle: 50
  cancelling: false

  # Public: Initialize the select list view.
  #
  # This method can be overridden by subclasses but `super` should always
  # be called.
  initialize: ->
    @miniEditor.getBuffer().on 'changed', => @schedulePopulateList()
    @miniEditor.hiddenInput.on 'focusout', => @cancel() unless @cancelling
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

  # Public: Set the array of items to display in the list.
  #
  # * array: The array of model elements to display in the list.
  setArray: (@array=[]) ->
    @populateList()
    @setLoading()

  # Public: Set the error message to display.
  #
  # * message: The error message.
  setError: (message='') ->
    if message.length is 0
      @error.text('').hide()
    else
      @setLoading()
      @error.text(message).show()

  # Public: Set the loading message to display.
  #
  # * message: The loading message.
  setLoading: (message='') ->
    if message.length is 0
      @loading.text("")
      @loadingBadge.text("")
      @loadingArea.hide()
    else
      @setError()
      @loading.text(message)
      @loadingArea.show()

  # Public: Get the filter query to use when fuzzy filtering the visible
  # elements.
  #
  # By default this method returns the text in the mini editor but it can be
  # overridden by subclasses if needed.
  #
  # Returns a {String} to use when fuzzy filtering the elements to display.
  getFilterQuery: ->
    @miniEditor.getText()

  # Public: Build the DOM elements using the array from the last call to
  # {.setArray}.
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

  # Public: Get the message to display when there are no items.
  #
  # Subclasses may override this method to customize the message.
  #
  # * itemCount: The number of items in the array specified to {.setArray}
  # * filteredItemCount: The number of items that pass the fuzzy filter test.
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

  # Private:
  selectItem: (item) ->
    return unless item.length
    @list.find('.selected').removeClass('selected')
    item.addClass 'selected'
    @scrollToItem(item)

  # Private:
  scrollToItem: (item) ->
    scrollTop = @list.scrollTop()
    desiredTop = item.position().top + scrollTop
    desiredBottom = desiredTop + item.outerHeight()

    if desiredTop < scrollTop
      @list.scrollTop(desiredTop)
    else if desiredBottom > @list.scrollBottom()
      @list.scrollBottom(desiredBottom)

  # Public: Get the selected DOM element.
  #
  # Call {.getSelectedElement} to get the selected model element.
  getSelectedItem: ->
    @list.find('li.selected')

  # Public: Get the selected model element.
  #
  # Call {.getSelectedItem} to get the selected DOM element.
  getSelectedElement: ->
    @getSelectedItem().data('select-list-element')

  # Private:
  confirmSelection: ->
    element = @getSelectedElement()
    if element?
      @confirmed(element)
    else
      @cancel()

  # Public: Callback function for when a selection is made.
  #
  # This method should be overridden by subclasses.
  #
  # * element: The selected model element.
  confirmed: (element) ->

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
      atom.workspaceView.focus()

  # Private:
  cancelled: ->
    @miniEditor.setText('')
    @miniEditor.updateDisplay()

  # Public: Cancel and close the select list dialog.
  cancel: ->
    @list.empty()
    @cancelling = true
    miniEditorFocused = @miniEditor.isFocused
    @cancelled()
    @detach()
    @restoreFocus() if miniEditorFocused
    @cancelling = false
    clearTimeout(@scheduleTimeout)
