# Like sands through the hourglass, so are the days of our lives.
window.atom = {}

App = require 'app'
Browser = require 'browser'
Document = require 'document'
Editor = require 'editor'
Event = require 'event'
ExtensionManager = require 'extension-manager'
KeyBinder = require 'key-binder'
Native = require 'native'
Settings = require 'settings'
Storage = require 'storage'

atom.event = new Event
# atom.on, atom.off, etc.
for name, method of atom.event
  atom[name] = atom.event[name]

atom.native = new Native
atom.storage = new Storage
atom.keybinder = new KeyBinder
atom.settings = new Settings
atom.extensions = {}
atom.extensionManager = new ExtensionManager

atom.app = new App
# atom.open, atom.close, etc.
for name, method of atom.app
  atom[name] = atom.app[name]

atom.path = $atomController.path.toString()
atom.document = Document.handler atom.path
atom.document ?= new Editor

require 'window'
window.startup()
