$ = require 'jquery'

module.exports =
  eventLog: {}
  commandLoggerView: null
  originalTrigger: null

  activate: (state) ->
    @eventLog = state.eventLog ? {}
    rootView.command 'command-logger:clear-data', => @eventLog = {}
    rootView.command 'command-logger:toggle', => @createView().toggle(@eventLog)

    registerTriggeredEvent = (eventName) =>
      eventNameLog = @eventLog[eventName]
      unless eventNameLog
        eventNameLog =
          count: 0
          name: eventName
        @eventLog[eventName] = eventNameLog
      eventNameLog.count++
      eventNameLog.lastRun = new Date().getTime()
    trigger = $.fn.trigger
    @originalTrigger = trigger
    $.fn.trigger = (event) ->
      eventName = event.type ? event
      registerTriggeredEvent(eventName) if $(this).events()[eventName]
      trigger.apply(this, arguments)

  deactivate: ->
    $.fn.trigger = @originalTrigger if @originalTrigger?
    @commandLoggerView = null
    @eventLog = {}

  serialize: ->
    {@eventLog}

  createView: ->
    unless @commandLoggerView?
      CommandLoggerView = require './command-logger-view'
      @commandLoggerView = new CommandLoggerView
    @commandLoggerView
