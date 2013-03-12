_ = nodeRequire 'underscore'

module.exports =
class Event
  events: {}

  on: (name, callback) ->
    @events[name] ?= []
    @events[name].push callback

  off: (name, callback) ->
    delete @events[name][_.indexOf callback] if @events[name]

  trigger: (name, data...) ->
    if name.match /^app:/
      OSX.NSApp.triggerGlobalAtomEvent_data name, data
      return

    _.each @events[name], (callback) => callback data...
    null
