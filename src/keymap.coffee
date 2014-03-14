path = require 'path'
AtomKeymap = require 'atom-keymap'
season = require 'season'
fs = require 'fs-plus'

# Public: Associates keybindings with commands.
#
# An instance of this class is always available as the `atom.keymap` global.
#
# Keymaps are defined in a CSON/JSON format. A typical keymap looks something
# like this:
#
# ```cson
# 'body':
#   'ctrl-l': 'package:do-something'
# '.someClass':
#   'enter': 'package:confirm'
# ```
#
# As a key, you define the DOM element you want to work on, using CSS notation.
# For that key, you define one or more key:value pairs, associating keystrokes
# with a command to execute.
module.exports =
class Keymap extends AtomKeymap
  constructor: ({@resourcePath, @configDirPath}) ->
    super

  loadBundledKeymaps: ->
    @loadKeyBindings(path.join(@resourcePath, 'keymaps'))
    @emit('bundled-keymaps-loaded')

  getUserKeymapPath: ->
    if userKeymapPath = season.resolve(path.join(@configDirPath, 'keymap'))
      userKeymapPath
    else
      path.join(@configDirPath, 'keymap.cson')

  loadUserKeymap: ->
    userKeymapPath = @getUserKeymapPath()
    if fs.isFileSync(userKeymapPath)
      @loadKeyBindings(userKeymapPath, watch: true, suppressErrors: true)
