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

  filterKey: 'eventDescription'

  initialize: (@rootView) ->
    @on 'event-palette:toggle', => @cancel()
    super

  attach: ->
    @previouslyFocusedElement = $(':focus')
    events = []
    for eventName, eventDescription of @previouslyFocusedElement.events()
      events.push({eventName, eventDescription}) if eventDescription
    @setArray(events)
    @appendTo(@rootView)
    @miniEditor.setText('')
    @miniEditor.focus()

  itemForElement: ({eventName, eventDescription}) ->
    $$ ->
      @li class: 'event', 'data-event-name': eventName, =>
        @div eventDescription, class: 'event-description'
        @div eventName, class: 'event-name'
        @div class: 'clear-float'

  confirmed: ({eventName}) ->
    @cancel()
    @previouslyFocusedElement.trigger(eventName)

  cancelled: ->
    @previouslyFocusedElement.focus() if @miniEditor.isFocused

