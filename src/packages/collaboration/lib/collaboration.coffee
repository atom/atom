GuestView = require './guest-view'
HostView = require './host-view'
HostSession = require './host-session'
JoinPromptView = require './join-prompt-view'
{getSessionUrl} = require './session-utils'

module.exports =
  activate: ->
    hostView = null

    if atom.getLoadSettings().sessionId
      new GuestView(atom.guestSession)
    else
      hostSession = new HostSession()

      copySession = ->
        sessionId = hostSession.getId()
        pasteboard.write(getSessionUrl(sessionId)) if sessionId

      rootView.command 'collaboration:copy-session-id', copySession

      rootView.command 'collaboration:start-session', ->
        hostView ?= new HostView(hostSession)
        copySession() if hostSession.start()

      rootView.command 'collaboration:join-session', ->
        new JoinPromptView (id) ->
          return unless id
          windowSettings =
            bootstrapScript: require.resolve('collaboration/lib/bootstrap')
            resourcePath: window.resourcePath
            sessionId: id
          atom.openWindow(windowSettings)
