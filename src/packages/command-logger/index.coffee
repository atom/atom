DeferredAtomPackage = require 'deferred-atom-package'
$ = require 'jquery'

module.exports =
class CommandLogger extends DeferredAtomPackage

  loadEvents: ['command-logger:toggle']

  instanceClass: 'command-logger/src/command-logger-view'

  activate: (rootView, state={})->
    super

    @eventLog = state.eventLog ? {}
    rootView.command 'command-logger:clear-data', => @eventLog = {}

    registerTriggeredEvent = (eventName) =>
      eventNameLog = @eventLog[eventName]
      unless eventNameLog
        eventNameLog =
          count: 0
          name: eventName
        @eventLog[eventName] = eventNameLog
      eventNameLog.count++
      eventNameLog.lastRun = new Date().getTime()
    originalTrigger = $.fn.trigger
    $.fn.trigger = (eventName) ->
      eventName = eventName.type if eventName.type
      registerTriggeredEvent(eventName) if $(this).events()[eventName]
      originalTrigger.apply(this, arguments)

  onLoadEvent: (event, instance) -> instance.toggle(@eventLog)
