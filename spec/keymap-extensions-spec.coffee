path = require 'path'
temp = require('temp').track()
CSON = require 'season'
fs = require 'fs-plus'

describe "keymap-extensions", ->

  beforeEach ->
    atom.keymaps.configDirPath = temp.path('atom-spec-keymap-ext')
    fs.writeFileSync(atom.keymaps.getUserKeymapPath(), '#')
    @userKeymapLoaded = ->
    atom.keymaps.onDidLoadUserKeymap => @userKeymapLoaded()

  afterEach ->
    fs.removeSync(atom.keymaps.configDirPath)
    atom.keymaps.destroy()

  describe "did-load-user-keymap", ->

    it  "fires when user keymap is loaded", ->
      spyOn(this, 'userKeymapLoaded')
      atom.keymaps.loadUserKeymap()
      expect(@userKeymapLoaded).toHaveBeenCalled()
