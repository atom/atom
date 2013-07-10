require 'atom'
require 'window'

$ = require 'jquery'
{$$} = require 'space-pen'
GuestSession = require './guest-session'

window.setDimensions(width: 350, height: 100)
window.setUpEnvironment('editor')
{sessionId} = atom.getLoadSettings()

loadingView = $$ ->
  @div style: 'margin: 10px; text-align: center', =>
    @div "Joining session #{sessionId}"
$(window.rootViewParentSelector).append(loadingView)
atom.show()

atom.guestSession = new GuestSession(sessionId)
atom.guestSession.on 'started', -> loadingView.remove()
