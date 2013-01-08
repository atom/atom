{View, $$} = require 'space-pen'
SelectList = require 'select-list'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class EventPalette extends SelectList
  @activate: (rootView) ->
    @instance = new EventPalette(rootView)
    rootView.command 'event-palette:toggle', => @instance.attach()

  @viewClass: ->
    "#{super} event-palette"

  filterKey: 'eventDescription'

  previouslyFocusedElement: null
  keyBindings: null

  initialize: (@rootView) ->
    @command 'event-palette:toggle', =>
      @cancel()
      false
    super

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @keyBindings = _.losslessInvert(keymap.bindingsForElement(@previouslyFocusedElement))

    events = []
    for eventName, eventDescription of _.extend($(window).events(), @previouslyFocusedElement.events())
      events.push({eventName, eventDescription}) if eventDescription

    events = _.sortBy events, (e) -> e.eventDescription

    @setArray(events)
    @appendTo(@rootView)
    @miniEditor.setText('')
    @miniEditor.focus()

  itemForElement: ({eventName, eventDescription}) ->
    keyBindings = @keyBindings
    $$ ->
      @li class: 'event', 'data-event-name': eventName, =>
        @div eventDescription, class: 'event-description'
        @div class: 'right', =>
          @div eventName, class: 'event-name'
          for binding in keyBindings[eventName] ? []
            @div binding, class: 'key-binding'
        @div class: 'clear-float'

  confirmed: ({eventName}) ->
    @cancel()
    @previouslyFocusedElement.trigger(eventName)

  cancelled: ->
    @previouslyFocusedElement.focus() if @miniEditor.isFocused
