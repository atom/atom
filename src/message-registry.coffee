querystring = require 'querystring'
url = require 'url'
{Disposable, CompositeDisposable} = require 'event-kit'

# Public: Associates listener functions with messages from outside the
# application. You can access a global instance of this class via
# `atom.messages`.
#
# The global message registry is similar to the {CommandRegistry} in that it
# maps messages, identified by strings, to listener functions; however, unlike
# commands, messages can originate from outside the application, and thus the
# range of actions that messages can trigger should be more limited.
#
# Message names must follow the `namespace:action` pattern, where `namespace`
# will typically be the name of your package, and `action` describes the
# behavior of your command. If either part consists of multiple words, these
# must be separated by hyphens. E.g. `awesome-package:turn-it-up-to-eleven`. All
# words should be lowercased.
#
# Messages are exposed to applications outside Atom via special URIs that begin
# with `atom://atom/`. For example, a message named `package:show-pane` could
# be triggered by visiting `atom://atom/package:show-pane`. Additional
# parameters can be passed via query string parameters.
#
# Since messages can originate from outside the application, you should avoid
# registering messages for operations that can be destructive to the user's
# environment; for example, a message to open the install page for a package is
# fine, but a message that immediately installs a package is not.
#
# ## Example
#
# Here is a message that could open a specific panel in a package's view:
#
# ```coffee
# atom.messages.add 'package:show-panel', (message, params) ->
#   packageView.showPanel(params.panel)
# ```
#
# Such a message could be triggered by visiting the associated URL:
#
# ```
# atom://atom/package:show-panel?panel=help
# ```
module.exports =
class MessageRegistry
  constructor: ->
    @clear()

  clear: ->
    @listenersByMessageName = {}

  # Public: Add one or more message listeners.
  #
  # ## Arguments: Registering One Message
  #
  # * `messageName` A {String} containing the name of a message you want to
  #   handle such as `package:show-panel`.
  # * `callback` A {Function} to call when the given message is activated.
  #   * `message` An {String} containing the message that triggered this
  #     callback.
  #   * `params` An {Object} containing any key-value pairs passed to the
  #     message via query string parameters. The values will always be {String}s.
  #
  # ## Arguments: Registering Multiple Messages
  #
  # * `messages` An {Object} mapping message names like `package:show-panel`
  #   to listener {Function}s.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added message handler(s).
  add: (messageName, callback) ->
    if typeof messageName is 'object'
      messages = messageName
      disposable = new CompositeDisposable
      for messageName, callback of messages
        disposable.add @add(messageName, callback)
      return disposable

    if typeof callback isnt 'function'
      throw new Error("Can't register a message with a non-function callback")

    @addListener(messageName, callback)

  addListener: (messageName, callback) ->
    messageListeners = @listenersByMessageName[messageName]

    if typeof messageListeners is 'function'
      @listenersByMessageName[messageName] = [
        messageListeners,
        callback
      ]
    else if messageListeners?
      messageListeners.push(callback)
    else
      @listenersByMessageName[messageName] = callback

    new Disposable =>
      @removeListener(messageName, callback)

  removeListener: (messageName, callback) ->
    messageListeners = @listenersByMessageName[messageName]

    if callback? and messageListeners is callback
      delete @listenersByMessageName[messageName]
    else
      messageListeners.splice(messageListeners.indexOf(callback), 1)

  # Public: Simulates the dispatch of a given message URI.
  #
  # This can be useful for testing when you want to simulate a mesasge being
  # passed from outside Atom.
  #
  # * `uri` {String} The URI to dispatch. URIs are expected to be in the form
  #   `atom://atom/package:message?param=value&other=more`, where
  #   `package:message?param=value&other=more` describes the message to
  #   dispatch.
  dispatch: (uri) ->
    parsedUri = url.parse(uri)
    return unless parsedUri.host is 'atom'

    path = parsedUri.pathname or ''
    messageName = path.substr(1)

    listeners = @listenersByMessageName[messageName]
    return unless listeners?

    params = querystring.parse(parsedUri.query)
    if typeof listeners is 'function'
      listeners(messageName, params)
    else
      listeners.forEach (l) -> l(messageName, params)
