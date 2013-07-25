Session = require './session'
JoinPromptView = require './join-prompt-view'
HostStatusBar = require './host-status-bar'
GuestStatusBar = require './guest-status-bar'
ParticipantView = require './participant-view'
{getSessionUrl} = require './session-utils'

module.exports =
  activate: ->
    hostView = null

    if atom.getLoadSettings().sessionId
      session = atom.guestSession
      for participant in session.getParticipants()
        continue if participant.id == session.getId()
        @createParticipant(session, participant)
    else
      session = new Session(site: window.site)
      @handleEvents(session)

    session.on 'participant-entered', (participant) =>
      @createParticipant(session, participant)

    session.on 'participant-exited', (participant) =>
      console.error "Someone left"

    rootView.eachPane (pane) ->
      setTimeout ->
        buttons = if session.isLeader() then new HostStatusBar(session) else new GuestStatusBar(session)
        buttons.insertAfter(pane.find('.git-branch'))
      , 0

  createParticipant: (session, participant) ->
    view = new ParticipantView(session, participant)
    view.attach()

  handleEvents: (session) ->
    copySessionId = ->
      sessionId = session.getId()
      pasteboard.write(getSessionUrl(sessionId)) if sessionId

    rootView.command 'collaboration:copy-session-id', copySessionId
    rootView.command 'collaboration:start-session', ->
      session.start()
      copySessionId()

    rootView.command 'collaboration:join-session', ->
      new JoinPromptView (id) ->
        return unless id
        windowSettings =
          bootstrapScript: require.resolve('collaboration/lib/bootstrap')
          resourcePath: window.resourcePath
          sessionId: id
        atom.openWindow(windowSettings)
