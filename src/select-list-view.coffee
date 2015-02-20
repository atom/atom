{$, View} = require './space-pen-extensions'
TextEditorView = require './text-editor-view'
fuzzyFilter = require('fuzzaldrin').filter

# Deprecated: Provides a view that renders a list of items with an editor that
# filters the items. Used by many packages such as the fuzzy-finder,
# command-palette, symbols-view and autocomplete.
#
# Subclasses must implement the following methods:
#
# * {::viewForItem}
# * {::confirmed}
#
# ## Requiring in packages
#
# ```coffee
# {SelectListView} = require 'atom'
#
# class MySelectListView extends SelectListView
#   initialize: ->
#     super
#     @addClass('overlay from-top')
#     @setItems(['Hello', 'World'])
#     atom.workspaceView.append(this)
#     @focusFilterEditor()
#
#   viewForItem: (item) ->
#     "<li>#{item}</li>"
#
#   confirmed: (item) ->
#     console.log("#{item} was selected")
# ```
module.exports =
class SelectListView extends View
  @content: ->
    @div class: 'select-list', =>
      @subview 'filterEditorView', new TextEditorView(mini: true)
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

  maxItems: Infinity
  scheduleTimeout: null
  inputThrottle: 50
  cancelling: false

  ###
  Section: Construction
  ###

  # Essential: Initialize the select list view.
  #
  # This method can be overridden by subclasses but `super` should always
  # be called.
  initialize: ->
    @filterEditorView.getEditor().getBuffer().onDidChange =>
      @schedulePopulateList()
    @filterEditorView.on 'blur', =>
      @cancel() unless @cancelling

    # This prevents the focusout event from firing on the filter editor view
    # when the list is scrolled by clicking the scrollbar and dragging.
    @list.on 'mousedown', ({target}) =>
      false if target is @list[0]

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

  ###
  Section: Methods that must be overridden
  ###

  # Essential: Create a view for the given model item.
  #
  # This method must be overridden by subclasses.
  #
  # This is called when the item is about to appended to the list view.
  #
  # * `item` The model item being rendered. This will always be one of the items
  #   previously passed to {::setItems}.
  #
  # Returns a String of HTML, DOM element, jQuery object, or View.
  viewForItem: (item) ->
    throw new Error("Subclass must implement a viewForItem(item) method")

  # Essential: Callback function for when an item is selected.
  #
  # This method must be overridden by subclasses.
  #
  # * `item` The selected model item. This will always be one of the items
  #   previously passed to {::setItems}.
  #
  # Returns a DOM element, jQuery object, or {View}.
  confirmed: (item) ->
    throw new Error("Subclass must implement a confirmed(item) method")

  ###
  Section: Managing the list of items
  ###

  # Essential: Set the array of items to display in the list.
  #
  # This should be model items not actual views. {::viewForItem} will be
  # called to render the item when it is being appended to the list view.
  #
  # * `items` The {Array} of model items to display in the list (default: []).
  setItems: (@items=[]) ->
    @populateList()
    @setLoading()

  # Essential: Get the model item that is currently selected in the list view.
  #
  # Returns a model item.
  getSelectedItem: ->
    @getSelectedItemView().data('select-list-item')

  # Extended: Get the property name to use when filtering items.
  #
  # This method may be overridden by classes to allow fuzzy filtering based
  # on a specific property of the item objects.
  #
  # For example if the objects you pass to {::setItems} are of the type
  # `{"id": 3, "name": "Atom"}` then you would return `"name"` from this method
  # to fuzzy filter by that property when text is entered into this view's
  # editor.
  #
  # Returns the property name to fuzzy filter by.
  getFilterKey: ->

  # Extended: Get the filter query to use when fuzzy filtering the visible
  # elements.
  #
  # By default this method returns the text in the mini editor but it can be
  # overridden by subclasses if needed.
  #
  # Returns a {String} to use when fuzzy filtering the elements to display.
  getFilterQuery: ->
    @filterEditorView.getEditor().getText()

  # Extended: Set the maximum numbers of items to display in the list.
  #
  # * `maxItems` The maximum {Number} of items to display.
  setMaxItems: (@maxItems) ->

  # Extended: Populate the list view with the model items previously set by
  # calling {::setItems}.
  #
  # Subclasses may override this method but should always call `super`.
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
        itemView = $(@viewForItem(item))
        itemView.data('select-list-item', item)
        @list.append(itemView)

      @selectItemView(@list.find('li:first'))
    else
      @setError(@getEmptyMessage(@items.length, filteredItems.length))

  ###
  Section: Messages to the user
  ###

  # Essential: Set the error message to display.
  #
  # * `message` The {String} error message (default: '').
  setError: (message='') ->
    if message.length is 0
      @error.text('').hide()
    else
      @setLoading()
      @error.text(message).show()

  # Essential: Set the loading message to display.
  #
  # * `message` The {String} loading message (default: '').
  setLoading: (message='') ->
    if message.length is 0
      @loading.text("")
      @loadingBadge.text("")
      @loadingArea.hide()
    else
      @setError()
      @loading.text(message)
      @loadingArea.show()

  # Extended: Get the message to display when there are no items.
  #
  # Subclasses may override this method to customize the message.
  #
  # * `itemCount` The {Number} of items in the array specified to {::setItems}
  # * `filteredItemCount` The {Number} of items that pass the fuzzy filter test.
  #
  # Returns a {String} message (default: 'No matches found').
  getEmptyMessage: (itemCount, filteredItemCount) -> 'No matches found'

  ###
  Section: View Actions
  ###

  # Essential: Cancel and close this select list view.
  #
  # This restores focus to the previously focused element if
  # {::storeFocusedElement} was called prior to this view being attached.
  cancel: ->
    @list.empty()
    @cancelling = true
    filterEditorViewFocused = @filterEditorView.isFocused
    @cancelled()
    @detach()
    @restoreFocus() if filterEditorViewFocused
    @cancelling = false
    clearTimeout(@scheduleTimeout)

  # Extended: Focus the fuzzy filter editor view.
  focusFilterEditor: ->
    @filterEditorView.focus()

  # Extended: Store the currently focused element. This element will be given
  # back focus when {::cancel} is called.
  storeFocusedElement: ->
    @previouslyFocusedElement = $(document.activeElement)

  ###
  Section: Private
  ###

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
    @scrollToItemView(view)

  scrollToItemView: (view) ->
    scrollTop = @list.scrollTop()
    desiredTop = view.position().top + scrollTop
    desiredBottom = desiredTop + view.outerHeight()

    if desiredTop < scrollTop
      @list.scrollTop(desiredTop)
    else if desiredBottom > @list.scrollBottom()
      @list.scrollBottom(desiredBottom)

  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.workspaceView.focus()

  cancelled: ->
    @filterEditorView.getEditor().setText('')

  getSelectedItemView: ->
    @list.find('li.selected')

  confirmSelection: ->
    item = @getSelectedItem()
    if item?
      @confirmed(item)
    else
      @cancel()

  schedulePopulateList: ->
    clearTimeout(@scheduleTimeout)
    populateCallback = =>
      @populateList() if @isOnDom()
    @scheduleTimeout = setTimeout(populateCallback,  @inputThrottle)
