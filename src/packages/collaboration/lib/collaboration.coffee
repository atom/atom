Presence = require './presence'
SharingSession = require './sharing-session'
BuddyList = require './buddy-list'
JoinPromptView = require './join-prompt-view'

module.exports =
  activate: ->
    presence = new Presence()
    sharingSession = new SharingSession()
    buddyList = null

    rootView.command 'collaboration:toggle-buddy-list', ->
      buddyList ?= new BuddyList(presence, sharingSession)
      buddyList.toggle()

    rootView.command 'collaboration:copy-session-id', ->
      sessionId = sharingSession.getId()
      pasteboard.write(sessionId) if sessionId

    rootView.command 'collaboration:start-session', ->
      if sessionId = sharingSession.start()
        pasteboard.write(sessionId)

    rootView.command 'collaboration:join-session', ->
      new JoinPromptView (id) ->
        windowSettings =
          bootstrapScript: require.resolve('collaboration/lib/bootstrap')
          resourcePath: window.resourcePath
          sessionId: id
        atom.openWindow(windowSettings)

    rootView.trigger 'collaboration:toggle-buddy-list' # TEMP
