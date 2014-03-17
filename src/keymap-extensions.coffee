fs = require 'fs-plus'
path = require 'path'
Keymap = require 'atom-keymap'
CSON = require 'season'

Keymap::loadBundledKeymaps = ->
  @loadKeyBindings(path.join(@resourcePath, 'keymaps'))
  @emit('bundled-keymaps-loaded')

Keymap::getUserKeymapPath = ->
  if userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
    userKeymapPath
  else
    path.join(@configDirPath, 'keymap.cson')

Keymap::loadUserKeymap = ->
  userKeymapPath = @getUserKeymapPath()
  if fs.isFileSync(userKeymapPath)
    @loadKeyBindings(userKeymapPath, watch: true, suppressErrors: true)
