# Like sands through the hourglass, so are the days of our lives.
require 'window'
window.atom = {}

Layout = require 'layout'
App = require 'app'
Event = require 'event'
ExtensionManager = require 'extension-manager'
KeyBinder = require 'key-binder'
Native = require 'native'
Router = require 'router'
Settings = require 'settings'
Storage = require 'storage'

atom.layout = Layout.attach()
atom.event = new Event
# atom.on, atom.off, etc.
for name, method of atom.event
  atom[name] = atom.event[name]

atom.native = new Native
atom.storage = new Storage
atom.keybinder = new KeyBinder
atom.router = new Router
atom.settings = new Settings

Browser = require 'browser'
Editor = require 'editor'
Project = require 'project'

atom.extensions = {}
atom.extensionManager = new ExtensionManager

atom.app = new App

window.startup()
