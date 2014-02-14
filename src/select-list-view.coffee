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
#                       previously passed to {.setItems}.
#
# * confirmed(item)   - Called when an item is selected from the list. The item
#                       parameter will always be one of the items previously
#                       passed to {.setItems}.
#
# ## Requiring in packages
#
# ```coffee
# {SelectListView} = require 'atom'
# ```
module.exports =
class SelectListView extends View
  @content: ->
    @div class: @getViewClasses(), =>
      @subview 'editorView', new EditorView(mini: true)
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

  # Public: Get the CSS classes to set on the root view element.
  #
  # Subclasses may override this method but should call `super` to get the
  # default classes.
  #
  # ### Example
  # ```coffee
  # class MySelectListView extends SelectListView
  #   @getViewClasses: ->
  #     "#{super} my-view-class"
  # ```
  #
  # Return a {String} of space-separated CSS classes.
  @getViewClasses: -> 'select-list'

  maxItems: Infinity
  scheduleTimeout: null
  inputThrottle: 50
  cancelling: false

  # Public: Initialize the select list view.
  #
  # This method can be overridden by subclasses but `super` should always
  # be called.
  initialize: ->
    @editorView.getEditor().getBuffer().on 'changed', => @schedulePopulateList()
    @editorView.hiddenInput.on 'focusout', => @cancel() unless @cancelling

    @on 'core:move-up', =>
      @selectPreviousItemView()
    @on 'core:move-down', =>
      @selectNextItemView()
    @on 'core:move-to-top', =>
      @selectItemView(@list.find('li:first'))
      @list.scrollToTop()
      false
    @on 'core:move-to-bottom', =>
      @selectItemView(@list.find('li:last'))
      @list.scrollToBottom()
      false

    @on 'core:confirm', => @confirmSelection()
    @on 'core:cancel', => @cancel()

    @list.on 'mousedown', 'li', (e) =>
      @selectItemView($(e.target).closest('li'))
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
    @editorView.getEditor().getText()

  # Public: Build the DOM elements using the array from the last call to
  # {.setItems}.
  populateList: ->
    return unless @items?

    filterQuery = @getFilterQuery()
    if filterQuery.length
      filteredItems = fuzzyFilter(@items, filterQuery, key: @getFilterKey())
    else
      filteredItems = @items

    @list.empty()
    if filteredItems.length
      @setError(null)

      for i in [0...Math.min(filteredItems.length, @maxItems)]
        item = filteredItems[i]
        view = @viewForItem(item)
        view.data('select-list-item', item)
        @list.append(item)

      @selectItemView(@list.find('li:first'))
    else
      @setError(@getEmptyMessage(@items.length, filteredItems.length))

  # Public: Get the message to display when there are no items.
  #
  # Subclasses may override this method to customize the message.
  #
  # itemCount - The {Number} of items in the array specified to {.setItems}
  # filteredItemCount - The {Number} of items that pass the fuzzy filter test.
  getEmptyMessage: (itemCount, filteredItemCount) -> 'No matches found'

  # Public: Set the maximum numbers of items to display in the list.
  #
  # maxItems - The maximum {Number} of items to display.
  setMaxItems: (@maxItems) ->

  selectPreviousItemView: ->
    view = @getSelectedItemView().prev()
    view = @list.find('li:last') unless view.length
    @selectItemView(view)

  selectNextItemView: ->
    view = @getSelectedItemView().next()
    view = @list.find('li:first') unless view.length
    @selectItemView(view)

  selectItemView: (view) ->
    return unless view.length
    @list.find('.selected').removeClass('selected')
    view.addClass('selected')
    @scrollToItemView(item)

  scrollToItemView: (view) ->
    scrollTop = @list.scrollTop()
    desiredTop = view.position().top + scrollTop
    desiredBottom = desiredTop + view.outerHeight()

    if desiredTop < scrollTop
      @list.scrollTop(desiredTop)
    else if desiredBottom > @list.scrollBottom()
      @list.scrollBottom(desiredBottom)

  getSelectedItemView: ->
    @list.find('li.selected')

  # Public: Get the model item that is currently selected in the list view.
  #
  # Returns a model item.
  getSelectedItem: ->
    @getSelectedView().data('select-list-item')

  confirmSelection: ->
    element = @getSelectedElement()
    if element?
      @confirmed(element)
    else
      @cancel()

  # Public: Callback function for when an item is selected.
  #
  # This method should be overridden by subclasses.
  #
  # item - The selected model item.
  confirmed: (item) ->

  # Public: Get the property name to use when filtering items.
  #
  # This method may be overridden by classes to allow fuzzy filtering based
  # on a specific property of the item objects.
  #
  # For example if the objects you pass to {.setItems} are of the type
  # `{"id": 3, "name": "Atom"}` then you would return `"name"` from this method
  # to fuzzy filter by that property when text is entered into this view's
  # editor.
  #
  # Returns the property name to fuzzy filter by.
  getFilterKey: ->

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
    @editorView.getEditor().setText('')
    @editorView.updateDisplay()

  # Public: Cancel and close the select list dialog.
  cancel: ->
    @list.empty()
    @cancelling = true
    editorViewFocused = @editorView.isFocused
    @cancelled()
    @detach()
    @restoreFocus() if editorViewFocused
    @cancelling = false
    clearTimeout(@scheduleTimeout)
