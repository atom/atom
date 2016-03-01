{Emitter, Disposable} = require 'event-kit'

# This global registry tracks registered `TextEditors`.
#
# Packages that provide extra functionality to `TextEditors`, such as
# autocompletion, can observe this registry to find applicable editors.
module.exports =
class TextEditorRegistry
  constructor: ->
    @editors = new Set
    @emitter = new Emitter

  # Register a `TextEditor`.
  #
  # * `editor` The editor to register.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added editor. To avoid any memory leaks this should be called when the
  # editor is destroyed.
  add: (editor) ->
    @editors.add(editor)
    @emitter.emit 'did-add-editor', editor
    new Disposable => @editors.delete(editor)

  # Invoke the given callback with all the current and future registered
  # `TextEditors`.
  #
  # * `callback` {Function} to be called with current and future text editors.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observe: (callback) ->
    @editors.forEach (editor) -> callback(editor)
    @emitter.on 'did-add-editor', callback
