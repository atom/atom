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
Project = require 'project'
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

# Ignore extensions for now
#atom.extensions = {}
#atom.extensionManager = new ExtensionManager

atom.app = new App
# atom.open, atom.close, etc.
for name, method of atom.app
  atom[name] = atom.app[name]

path = $atomController.path?.toString()
if handler = Document.handler path
  atom.document = new handler path
else
  throw "I DON'T KNOW ABOUT #{path}"

require 'window'
window.startup()
