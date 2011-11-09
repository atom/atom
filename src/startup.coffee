# Like sands through the hourglass, so are the days of our lives.

App = require 'app'
Event = require 'event'
Native = require 'native'
KeyBinder = require 'key-binder'

window.atom = {}
window.atom.native = new Native
window.atom.event = new Event
window.atom.keybinder = new KeyBinder

window.atom.app = new App
