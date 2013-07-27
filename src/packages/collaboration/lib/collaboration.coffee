Session = require './session'
JoinPromptView = require './join-prompt-view'
HostStatusBar = require './host-status-bar'
GuestStatusBar = require './guest-status-bar'
{ParticipantView, ParticipantViewContainer} = require './participant-view'

module.exports =
  activate: ->
    hostView = null
    participantViews = new ParticipantViewContainer().attach()

    if atom.getLoadSettings().sessionId
      session = atom.guestSession
      participantViews.add(session, session.getSelfParticipant())
      for participant in session.getOtherParticipants()
        participantViews.add(session, participant)
    else
      session = new Session(site: window.site)
      @handleEvents(session)
      session.on 'started', (participants) =>
        participantViews.add(session, session.getSelfParticipant())

    session.on 'participant-entered', (participant) =>
      participantViews.add(session, participant)

    session.on 'participant-exited', (participant) =>
      participantViews.remove(participant)

    rootView.eachPane (pane) ->
      setTimeout ->
        buttons = if session.isLeader() then new HostStatusBar(session) else new GuestStatusBar(session)
        buttons.insertAfter(pane.find('.git-branch'))
      , 0

  handleEvents: (session) ->
    rootView.command 'collaboration:copy-session-id', ->
      session.copySessionId()

    rootView.command 'collaboration:start-session', ->
      session.start()
      session.copySessionId()

    rootView.command 'collaboration:join-session', ->
      new JoinPromptView (id) ->
        return unless id
        windowSettings =
          bootstrapScript: require.resolve('collaboration/lib/bootstrap')
          resourcePath: window.resourcePath
          sessionId: id
        atom.openWindow(windowSettings)
