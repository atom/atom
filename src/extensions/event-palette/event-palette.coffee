{View, $$} = require 'space-pen'
SelectList = require 'select-list'
Editor = require 'editor'
$ = require 'jquery'

module.exports =
class EventPalette extends SelectList
  @activate: (rootView) ->
    requireStylesheet 'event-palette/event-palette.css'
    @instance = new EventPalette(rootView)
    rootView.on 'event-palette:toggle', => @instance.attach()

  @viewClass: ->
    "#{super} event-palette"

  filterKey: 0 # filter on the event name for now

  initialize: (@rootView) ->
    @on 'event-palette:toggle', => @cancel()
    super

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @setArray(@previouslyFocusedElement.events())
    @appendTo(@rootView)
    @miniEditor.focus()

  itemForElement: ([eventName, description]) ->
    $$ ->
      @li class: 'event', =>
        @div eventName, class: 'event-name'
        @div description, class: 'event-description'

  populateEventList: ->
    events = @previouslyFocusedElement.events()
    table = $$ ->
      @table =>
        for [event, description] in events
          @tr class: 'event', =>
            @td event, class: 'event-name'
            @td description if description

    @eventList.html(table)

  confirmed: ([eventName, description]) ->
    @cancel()
    @previouslyFocusedElement.trigger(eventName)

  cancelled: ->
    @previouslyFocusedElement.focus() if @miniEditor.isFocused

