CollaborationView = require './collaboration-view'
SharingSession = require './sharing-session'
JoinPromptView = require './join-prompt-view'

module.exports =
  activate: ->
    sharingSession = new SharingSession()

    rootView.command 'collaboration:copy-session-id', ->
      sessionId = sharingSession.getId()
      pasteboard.write(sessionId) if sessionId

    rootView.command 'collaboration:start-session', ->
      new CollaborationView(sharingSession)
      if sessionId = sharingSession.start()
        pasteboard.write(sessionId)

    rootView.command 'collaboration:join-session', ->
      new JoinPromptView (id) ->
        windowSettings =
          bootstrapScript: require.resolve('collaboration/lib/bootstrap')
          resourcePath: window.resourcePath
          sessionId: id
        atom.openWindow(windowSettings)
