{View, $$, $$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class CommandLogger extends ScrollView
  @activate: (rootView, state) ->
    @instance = new CommandLogger(rootView, state?.eventLog)

  @content: (rootView) ->
    @ol class: 'command-logger', tabindex: -1

  @serialize: ->
    @instance.serialize()

  eventLog: null

  initialize: (@rootView, @eventLog={}) ->
    super

    requireStylesheet 'command-logger.css'

    @rootView.command 'command-logger:toggle', => @toggle()
    @rootView.command 'command-logger:clear-data', => @eventLog = {}
    @command 'core:cancel', => @detach()

    registerEvent = (eventName) =>
      eventNameLog = @eventLog[eventName]
      unless eventNameLog
        eventNameLog = count: 0, name: eventName
        @eventLog[eventName] = eventNameLog
      eventNameLog.count++
      eventNameLog.lastRun = new Date().getTime()

    originalTrigger = $.fn.trigger
    $.fn.trigger = (eventName) ->
      eventName = eventName.type if eventName.type
      registerEvent(eventName) if $(this).events()[eventName]
      originalTrigger.apply(this, arguments)

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  getHtml: ->
    sorted = _.sortBy(@eventLog, (event) => -event.count)
    $$$ ->
      for eventName, details of sorted
        @li =>
          @span "#{details.count}", class: 'event-count'
          @span "#{_.humanizeEventName(details.name)}", class: 'event-description'
          @span "Last run on #{new Date(details.lastRun).toString()}", class: 'event-last-run'

  attach: ->
    @rootView.append(this)
    @html(@getHtml())
    @focus()

  detach: ->
    super()
    @rootView.focus()

  serialize: ->
    eventLog: @eventLog
