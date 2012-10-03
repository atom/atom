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
    @on 'event-palette:select', => @triggerSelectedEvent()
    @on 'mousedown', '.event', (e) => @selectItem($(e.target).closest('.event'))
    @on 'mouseup', '.event', => @triggerSelectedEvent()

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
            @td event, class: 'event-name'
            @td description if description

    @eventList.html(table)

  selectPrevious: ->
    @selectItem(@getSelectedItem().prev())

  selectNext: ->
    @selectItem(@getSelectedItem().next())

  selectItem: (item) ->
    return unless item.length
    @eventList.find('.selected').removeClass('selected')
    item.addClass('selected')
    @scrollToItem(item)

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

  getSelectedEventName: ->
    @getSelectedItem().find('.event-name').text()

  triggerSelectedEvent: ->
    @previouslyFocusedElement.focus()
    @previouslyFocusedElement.trigger(@getSelectedEventName())
    @detach()

  detach: ->
    @rootView.focus() if @miniEditor.isFocused
    super
