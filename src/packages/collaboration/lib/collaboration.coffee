Session = require './session'
JoinPromptView = require './join-prompt-view'
HostStatusBar = require './host-status-bar'
GuestStatusBar = require './guest-status-bar'
ParticipantView = require './participant-view'
{getSessionUrl} = require './session-utils'

module.exports =
  activate: ->
    hostView = null
    loadedParticipants = {}

    if atom.getLoadSettings().sessionId
      session = atom.guestSession
    else
      session = new Session(site: window.site)
      @handleEvents(session)

    session.on 'participants-changed', (participants) =>
      console.log 'participant', participants
      for participant in participants
        continue if participant.id == session.getId()
        continue if participant.id of loadedParticipants
        console.log 'adding', participant.id, participant
        loadedParticipants[participant.id] = new ParticipantView(session, participant)
        loadedParticipants[participant.id].attach()

    rootView.eachPane (pane) ->
      setTimeout ->
        buttons = if session.isHost() then new HostStatusBar(session) else new GuestStatusBar(session)
        buttons.insertAfter(pane.find('.git-branch'))
      , 0

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
