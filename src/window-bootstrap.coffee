# Like sands through the hourglass, so are the days of our lives.
startTime = new Date().getTime()

#FIXME remove once all packages have been updated
{Emitter} = require 'emissary'
Emitter::trigger = (args...) => @emit(args...)
Emitter::subscriptionCount = (args...) => @getSubscriptionCount(args...)

require './window'

Atom = require './atom'
window.atom = new Atom()
window.setUpEnvironment('editor')
window.startEditorWindow()
console.log "Window load time: #{new Date().getTime() - startTime}ms"
