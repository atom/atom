{View, $$} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'

module.exports =
class EventPalette extends View
  @activate: (rootView) ->
    requireStylesheet 'event-palette/event-palette.css'
    @instance = new EventPalette(rootView)
    rootView.on 'event-palette:show', => @instance.attach()

  @content: ->
    @div class: 'event-palette', =>
      @div class: 'select-list', outlet: 'eventList'
      @subview 'miniEditor', new Editor(mini: true)

  initialize: (@rootView) ->
    @on 'move-up', => @selectPrevious()
    @on 'move-down', => @selectNext()
    @on 'event-palette:cancel', => @detach()

  selectPrevious: ->
    current = @getSelectedItem()
    previous = @getSelectedItem().prev()
    if previous.length
      current.removeClass('selected')
      previous.addClass('selected')
      @scrollToItem(previous)

  selectNext: ->
    current = @getSelectedItem()
    next = @getSelectedItem().next()
    if next.length
      current.removeClass('selected')
      next.addClass('selected')
      @scrollToItem(next)

  scrollToItem: (item) ->
    scrollTop = @eventList.prop('scrollTop')
    desiredTop = item.position().top + scrollTop
    desiredBottom = desiredTop + item.height()

    if desiredTop < scrollTop
      @eventList.scrollTop(desiredTop)
    else if desiredBottom > @eventList.scrollBottom()
      @eventList.scrollBottom(desiredBottom)

  getSelectedItem: ->
    @eventList.find('.selected')

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @populateEventList()
    @eventList.find('.event:first').addClass('selected')
    @appendTo(@rootView)
    @miniEditor.focus()

  populateEventList: ->
    events = @previouslyFocusedElement.events()
    table = $$ ->
      @table =>
        for [event, description] in events
          @tr class: 'event', =>
            @td event
            @td description if description

    @eventList.html(table)
