Session = require './session'
JoinPromptView = require './join-prompt-view'
HostStatusBar = require './host-status-bar'
GuestStatusBar = require './guest-status-bar'
ParticipantView = require './participant-view'

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
      participantViews[participant.clientId] = view

    session.on 'participant-exited', (participant) =>
      view = participantViews[participant.clientId]
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
