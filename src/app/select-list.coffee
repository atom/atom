$ = require 'jquery'
{ View } = require 'space-pen'
Editor = require 'editor'
fuzzyFilter = require 'fuzzy-filter'

module.exports =
class SelectList extends View
  @content: ->
    @div class: @viewClass(), =>
      @subview 'miniEditor', new Editor(mini: true)
      @ol outlet: 'list'

  @viewClass: -> 'select-list'

  maxItems: Infinity
  filteredArray: null
  cancelling: false

  initialize: ->
    requireStylesheet 'select-list.css'

    @miniEditor.getBuffer().on 'change', => @populateList()
    @miniEditor.on 'focusout', => @cancel() unless @cancelling
    @on 'core:move-up', => @selectPreviousItem()
    @on 'core:move-down', => @selectNextItem()
    @on 'core:confirm', => @confirmSelection()
    @on 'core:cancel', => @cancel()

    @list.on 'mousedown', 'li', (e) =>
      @selectItem($(e.target).closest('li'))
      e.preventDefault()

    @list.on 'mouseup', 'li', (e) =>
      @confirmSelection() if $(e.target).closest('li').hasClass('selected')
      e.preventDefault()

  setArray: (@array) ->
    @populateList()
    @selectItem(@list.find('li:first'))

  populateList: ->
    filterQuery = @miniEditor.getText()
    if filterQuery.length
      filteredArray = fuzzyFilter(@array, filterQuery, key: @filterKey)
    else
      filteredArray = @array

    @list.empty()
    for i in [0...Math.min(filteredArray.length, @maxItems)]
      element = filteredArray[i]
      item = @itemForElement(element)
      item.data('select-list-element', element)
      @list.append(item)

    @selectItem(@list.find('li:first'))

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
    desiredBottom = desiredTop + item.height()

    if desiredTop < scrollTop
      @list.scrollTop(desiredTop)
    else if desiredBottom > @list.scrollBottom()
      @list.scrollBottom(desiredBottom)

  getSelectedItem: ->
    @list.find('li.selected')

  confirmSelection: ->
    element = @getSelectedItem().data('select-list-element')
    @confirmed(element) if element?

  cancel: ->
    @cancelling = true
    @cancelled()
    @detach()
    @cancelling = false

