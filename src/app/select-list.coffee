$ = require 'jquery'
{ View } = require 'space-pen'
Editor = require 'editor'
fuzzyFilter = require 'fuzzy-filter'

module.exports =
class SelectList extends View
  @content: ->
    @div class: 'select-list', =>
      @subview 'miniEditor', new Editor(mini: true)
      @ol outlet: 'list'

  maxItems: Infinity
  filteredArray: null

  initialize: ->
    requireStylesheet 'select-list.css'
    @miniEditor.getBuffer().on 'change', => @populateList()
    @on 'move-up', => @selectPreviousItem()
    @on 'move-down', => @selectNextItem()
    @on 'core:confirm', => @confirmSelection()
    @on 'core:cancel', => @cancelled()

  setArray: (@array) ->
    @populateList()
    @selectItem(@list.find('li:first'))

  populateList: ->
    filterQuery = @miniEditor.getText()
    if filterQuery.length
      @filteredArray = fuzzyFilter(@array, filterQuery, key: @filterKey)
    else
      @filteredArray = @array

    @list.empty()
    for i in [0...Math.min(@filteredArray.length, @maxItems)]
      item = @itemForElement(@filteredArray[i])
      item.data('select-list-index', i)
      @list.append(item)

  selectPreviousItem: ->
    @selectItem(@getSelectedItem().prev())

  selectNextItem: ->
    @selectItem(@getSelectedItem().next())

  selectItem: (item) ->
    if item.length
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
    index = @getSelectedItem().data('select-list-index')
    @selected(@filteredArray[index])
