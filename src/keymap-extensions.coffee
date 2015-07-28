fs = require 'fs-plus'
path = require 'path'
KeymapManager = require 'atom-keymap'
CSON = require 'season'
{jQuery} = require 'space-pen'
Grim = require 'grim'

bundledKeymaps = require('../package.json')?._atomKeymaps

KeymapManager::onDidLoadBundledKeymaps = (callback) ->
  @emitter.on 'did-load-bundled-keymaps', callback

KeymapManager::loadBundledKeymaps = ->
  keymapsPath = path.join(@resourcePath, 'keymaps')
  if bundledKeymaps?
    for keymapName, keymap of bundledKeymaps
      keymapPath = path.join(keymapsPath, keymapName)
      @add(keymapPath, keymap)
  else
    @loadKeymap(keymapsPath)

  @emitter.emit 'did-load-bundled-keymaps'

KeymapManager::getUserKeymapPath = ->
  if userKeymapPath = CSON.resolve(path.join(@configDirPath, 'keymap'))
    userKeymapPath
  else
    path.join(@configDirPath, 'keymap.cson')

KeymapManager::loadUserKeymap = ->
  userKeymapPath = @getUserKeymapPath()
  return unless fs.isFileSync(userKeymapPath)

  try
    @loadKeymap(userKeymapPath, watch: true, suppressErrors: true)
  catch error
    if error.message.indexOf('Unable to watch path') > -1
      message = """
        Unable to watch path: `#{path.basename(userKeymapPath)}`. Make sure you
        have permission to read `#{userKeymapPath}`.

        On linux there are currently problems with watch sizes. See
        [this document][watches] for more info.
        [watches]:https://github.com/atom/atom/blob/master/docs/build-instructions/linux.md#typeerror-unable-to-watch-path
      """
      atom.notifications.addError(message, {dismissable: true})
    else
      detail = error.path
      stack = error.stack
      atom.notifications.addFatalError(error.message, {detail, stack, dismissable: true})

KeymapManager::subscribeToFileReadFailure = ->
  @onDidFailToReadFile (error) =>
    userKeymapPath = @getUserKeymapPath()
    message = "Failed to load `#{userKeymapPath}`"

    detail = if error.location?
      error.stack
    else
      error.message

    atom.notifications.addError(message, {detail, dismissable: true})

# This enables command handlers registered via jQuery to call
# `.abortKeyBinding()` on the `jQuery.Event` object passed to the handler.
jQuery.Event::abortKeyBinding = ->
  @originalEvent?.abortKeyBinding?()

module.exports = KeymapManager
