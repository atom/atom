# Like sands through the hourglass, so are the days of our lives.

App = require 'app'
Event = require 'event'
Native = require 'native'

window.atom = {}
window.atom.native = new Native
window.atom.event = new Event
window.atom.app = new App
