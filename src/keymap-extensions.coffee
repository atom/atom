fs = require 'fs-plus'
path = require 'path'
KeymapManager = require 'atom-keymap'
CSON = require 'season'
{jQuery} = require 'space-pen'

KeymapManager::onDidLoadBundledKeymaps = (callback) ->
  @emitter.on 'did-load-bundled-keymaps', callback

KeymapManager::loadBundledKeymaps = ->
  @loadKeymap(path.join(@resourcePath, 'keymaps'))
  @emit 'bundled-keymaps-loaded'
  @emitter.emit 'did-load-bundled-keymaps'

KeymapManager::getUserKeymapPath = ->
  if userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
    userKeymapPath
  else
    path.join(@configDirPath, 'keymap.cson')

KeymapManager::loadUserKeymap = ->
  userKeymapPath = @getUserKeymapPath()
  if fs.isFileSync(userKeymapPath)
    @loadKeymap(userKeymapPath, watch: true, suppressErrors: true)

KeymapManager::subscribeToFileReadFailure = ->
  this.onDidFailToReadFile (error) ->
    atom.notifications.addError('Failed to load keymap.cson', {detail: error.stack, closable: true})

# This enables command handlers registered via jQuery to call
# `.abortKeyBinding()` on the `jQuery.Event` object passed to the handler.
jQuery.Event::abortKeyBinding = ->
  @originalEvent?.abortKeyBinding?()

module.exports = KeymapManager
