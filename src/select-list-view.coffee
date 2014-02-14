{$, View} = require './space-pen-extensions'
EditorView = require './editor-view'
fuzzyFilter = require('fuzzaldrin').filter

# Public: Provides a widget for users to make a selection from a list of
# choices.
#
# Subclasses must implement the following methods:
#
# * viewForItem(item) - Returns a DOM element, jQuery object, or {View}. This
#                       is called when an item is being rendered in the list.
#                       The item parameter will always be one of the items
#                       passed to {.setItems}.
#
# ## Requiring in packages
#
# ```coffee
#   {SelectListView} = require 'atom'
# ```
module.exports =
class SelectListView extends View
  @content: ->
    @div class: @viewClass(), =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

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
    @miniEditor.getEditor().getBuffer().on 'changed', => @schedulePopulateList()
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

  schedulePopulateList: ->
    clearTimeout(@scheduleTimeout)
    populateCallback = =>
      @populateList() if @isOnDom()
    @scheduleTimeout = setTimeout(populateCallback,  @inputThrottle)

  # Public: Set the array of items to display in the list.
  #
  # This should be model items not actual views.  `viewForItem(item)` will be
  # called to render the item when it is being appended to the list view.
  #
  # items - The {Array} of model items to display in the list.
  setItems: (@items=[]) ->
    @populateList()
    @setLoading()

  # Public: Set the error message to display.
  #
  # message - The {String} error message (default: '').
  setError: (message='') ->
    if message.length is 0
      @error.text('').hide()
    else
      @setLoading()
      @error.text(message).show()

  # Public: Set the loading message to display.
  #
  # message - The {String} loading message (default: '').
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
    @miniEditor.getEditor().getText()

  # Public: Build the DOM elements using the array from the last call to
  # {.setItems}.
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
        item = @viewForItem(item)
        item.data('select-list-element', element)
        @list.append(item)

      @selectItem(@list.find('li:first'))
    else
      @setError(@getEmptyMessage(@array.length, filteredArray.length))

  # Public: Get the message to display when there are no items.
  #
  # Subclasses may override this method to customize the message.
  #
  # itemCount - The {Number} of items in the array specified to {.setItems}
  # filteredItemCount - The {Number} of items that pass the fuzzy filter test.
  getEmptyMessage: (itemCount, filteredItemCount) -> 'No matches found'
g
  selectPreviousItem: ->
    item = @getSelectedItem().prev()
    item = @list.find('li:last') unless item.length
    @selectItem(item)

  selectNextItem: ->
    item = @getSelectedItem().next()
    item = @list.find('li:first') unless item.length
    @selectItem(item)

  selectItem: (item) ->
    return unless item.length
    @list.find('.selected').removeClass('selected')
    item.addClass 'selected'
    @scrollToItem(item)

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
  # element - The selected model element.
  confirmed: (element) ->

  attach: ->
    @storeFocusedElement()

  storeFocusedElement: ->
    @previouslyFocusedElement = $(':focus')

  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.workspaceView.focus()

  cancelled: ->
    @miniEditor.getEditor().setText('')
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
