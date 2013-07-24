require 'atom'
require 'window'

$ = require 'jquery'
{$$} = require 'space-pen'
GuestSession = require './guest-session'

window.setDimensions(width: 350, height: 125)
window.setUpEnvironment('editor')
{sessionId} = atom.getLoadSettings()

loadingView = $$ ->
  @div style: 'margin: 10px', =>
    @h4 style: 'text-align: center', 'Joining Session'
    @div class: 'progress progress-striped active', style: 'margin-bottom: 10px', =>
      @div class: 'progress-bar', style: 'width: 0%'
    @div class: 'progress-bar-message', 'Establishing connection\u2026'
$(window.rootViewParentSelector).append(loadingView)
atom.show()

updateProgressBar = (message, percentDone) ->
  loadingView.find('.progress-bar-message').text("#{message}\u2026")
  loadingView.find('.progress-bar').css('width', "#{percentDone}%")

guestSession = new GuestSession(sessionId)

guestSession.on 'started', ->
  atom.windowState = guestSession.getDocument().get('windowState')
  window.site = guestSession.getSite()
  loadingView.remove()
  window.startEditorWindow()

guestSession.on 'connection-opened', ->
  updateProgressBar('Downloading session data', 25)

guestSession.on 'connection-document-received', ->
  updateProgressBar('Synchronizing repository', 50)

guestSession.start()

operationsDone = -1
guestSession.on 'mirror-progress', (message, command, operationCount) ->
  operationsDone++
  percentDone = Math.round((operationsDone / operationCount) * 50) + 50
  updateProgressBar(message, percentDone)

atom.guestSession = guestSession
