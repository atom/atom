$ = require 'jquery'
{ View } = require 'space-pen'
Editor = require 'editor'
fuzzyFilter = require 'fuzzy-filter'
_ = require 'underscore'

module.exports =
class SelectList extends View
  @content: ->
    @div class: @viewClass(), =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'error', outlet: 'error'
      @div class: 'loading', outlet: 'loading'
      @ol outlet: 'list'

  @viewClass: -> 'select-list'

  maxItems: Infinity
  inputThrottle: 200
  filteredArray: null
  cancelling: false

  initialize: ->
    requireStylesheet 'select-list.css'

    @miniEditor.getBuffer().on 'change', _.debounce((=> @populateList()), @inputThrottle)
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
    @setLoading()

  setError: (message) ->
    if not message or message.length == ""
      @error.text("").hide()
      @removeClass("error")
    else
      @error.text(message).show()
      @addClass("error")

  setLoading: (message) ->
    if not message or message.length == ""
      @loading.text("").hide()
    else
      @setError()
      @loading.text(message).show()

  populateList: ->
    return unless @hasParent()
    filterQuery = @miniEditor.getText()
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
      @setError("No matches found")

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
    @list.empty()
    @cancelling = true
    @cancelled()
    @detach()
    @cancelling = false

