GuestView = require './guest-view'
HostView = require './host-view'
HostSession = require './host-session'
JoinPromptView = require './join-prompt-view'

module.exports =
  activate: ->
    hostView = null

    if atom.getLoadSettings().sessionId
      new GuestView(atom.guestSession)
    else
      hostSession = new HostSession()

      rootView.command 'collaboration:copy-session-id', ->
        sessionId = hostSession.getId()
        pasteboard.write(sessionId) if sessionId

      rootView.command 'collaboration:start-session', ->
        hostView ?= new HostView(hostSession)
        if sessionId = hostSession.start()
          pasteboard.write(sessionId)

      rootView.command 'collaboration:join-session', ->
        new JoinPromptView (id) ->
          windowSettings =
            bootstrapScript: require.resolve('collaboration/lib/bootstrap')
            resourcePath: window.resourcePath
            sessionId: id
          atom.openWindow(windowSettings)
