# Using the DOM event system, and copying the JQuery Event API
# https://developer.mozilla.org/en/DOM/Creating_and_triggering_events

module.exports =
class Event
  events: {}

  on: (name, callback) ->
    window.document.addEventListener name, callback
    callback

  off: (name, callback) ->
    window.document.removeEventListener name, callback

  trigger: (name, data, bubbleToApp=true) ->
    if bubbleToApp and name.match /^app:/
      OSX.NSApp.triggerGlobalEvent_data name, data
      return

    event = @events[name]
    if not event
      event = window.document.createEvent "CustomEvent"
      event.initCustomEvent name, true, true, null
      @events[name] = event

    event.details = data
    window.document.dispatchEvent event
    null
