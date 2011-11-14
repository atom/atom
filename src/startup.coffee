# Like sands through the hourglass, so are the days of our lives.
require 'window'

window.atom = {}

App = require 'app'
Browser = require 'browser'
Editor = require 'editor'
Event = require 'event'
ExtensionManager = require 'extension-manager'
KeyBinder = require 'key-binder'
Native = require 'native'
Project = require 'project'
Resource = require 'resource'
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
atom.extensions = {}
atom.extensionManager = new ExtensionManager

atom.app = new App

window.startup()
