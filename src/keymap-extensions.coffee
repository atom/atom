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

  @emit 'bundled-keymaps-loaded' if Grim.includeDeprecatedAPIs
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

dispatchKeyboardEvent = (target, eventArgs...) ->
  e = document.createEvent('KeyboardEvent')
  e.initKeyboardEvent(eventArgs...)

  # Sending '\r' (as vim-mode does) wasn't working for me here. It doesn't seem
  # too bad to special case it - we can add a map of humanized names to keycodes
  # if we run into more keys like this
  if eventArgs[4] is 'enter'
    Object.defineProperty(e, 'keyCode', get: -> 13)

  # 0 is the default, and it's valid ASCII, but it's wrong.
  Object.defineProperty(e, 'keyCode', get: -> undefined) if e.keyCode is 0
  target.dispatchEvent e

# Public: Simulate keypresses on a DOM node.
#
# This can be useful in tests, when you want to simulate keyboard input that is
# not bound to a command in the CommandRegistry.
#
# * `target` The DOM node at which to start bubbling the key events
# * `key` {String} indicating the key to press.
# * `modifierKeys` {Object} indicating which modifier keys are pressed. Possible
#    keys are `ctrl`, `shift`, `alt`, `meta`
KeymapManager::dispatch = (target, key, {ctrl, shift, alt, meta}) ->
  key = "U+#{key.charCodeAt(0).toString(16)}" unless key is 'escape' or key is 'enter'
  target ||= document.activeElement
  eventArgs = [
    true, # bubbles
    true, # cancelable
    null, # view
    key,  # key
    0,    # location
    ctrl, alt, shift, meta
  ]
  canceled = not dispatchKeyboardEvent(target, 'keydown', eventArgs...)
  dispatchKeyboardEvent(target, 'keypress', eventArgs...)
  dispatchKeyboardEvent(target, 'keyup', eventArgs...)

# This enables command handlers registered via jQuery to call
# `.abortKeyBinding()` on the `jQuery.Event` object passed to the handler.
jQuery.Event::abortKeyBinding = ->
  @originalEvent?.abortKeyBinding?()

module.exports = KeymapManager
