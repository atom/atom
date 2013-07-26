Session = require './session'
JoinPromptView = require './join-prompt-view'
HostStatusBar = require './host-status-bar'
GuestStatusBar = require './guest-status-bar'
ParticipantView = require './participant-view'
{getSessionUrl} = require './session-utils'

module.exports =
  activate: ->
    hostView = null
    participantViews = {}

    if atom.getLoadSettings().sessionId
      session = atom.guestSession
      for participant in session.getOtherParticipants()
        @createParticipant(session, participant)
    else
      session = new Session(site: window.site)
      @handleEvents(session)

    session.on 'participant-entered', (participant) =>
      view = @createParticipant(session, participant)
      participantViews[participant.id] = view

    session.on 'participant-exited', (participant) =>
      view = participantViews[participant.id]
      view.detach()

    rootView.eachPane (pane) ->
      setTimeout ->
        buttons = if session.isLeader() then new HostStatusBar(session) else new GuestStatusBar(session)
        buttons.insertAfter(pane.find('.git-branch'))
      , 0

  createParticipant: (session, participant) ->
    view = new ParticipantView(session, participant)
    view.attach()
    view

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
