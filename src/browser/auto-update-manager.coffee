autoUpdater = require 'auto-updater'
_ = require 'underscore-plus'
{EventEmitter} = require 'events'

IdleState = 'idle'
CheckingState = 'checking'
DownladingState = 'downloading'
UpdateAvailableState = 'update-available'
NoUpdateAvailableState = 'no-update-available'
ErrorState = 'error'

module.exports =
class AutoUpdateManager
  _.extend @prototype, EventEmitter.prototype

  constructor: (@version) ->
    @state = IdleState
    @feedUrl = "https://atom.io/api/updates?version=#{@version}"

    if process.platform is 'win32'
      autoUpdater.checkForUpdates = => @checkForUpdatesShim()

    autoUpdater.setFeedUrl @feedUrl

    autoUpdater.on 'checking-for-update', =>
      @setState(CheckingState)

    autoUpdater.on 'update-not-available', =>
      @setState(NoUpdateAvailableState)

    autoUpdater.on 'update-available', =>
      @setState(DownladingState)

    autoUpdater.on 'error', (event, message) =>
      @setState(ErrorState)
      console.error "Error Downloading Update: #{message}"

    autoUpdater.on 'update-downloaded', (event, @releaseNotes, @releaseVersion) =>
      @setState(UpdateAvailableState)
      @emitUpdateAvailableEvent(@getWindows()...)

    # Only released versions should check for updates.
    unless /\w{7}/.test(@version)
      @check(hidePopups: true)

  # Windows doesn't have an auto-updater, so use this method to shim the events.
  checkForUpdatesShim: ->
    autoUpdater.emit 'checking-for-update'

    # Do this in a next tick since requiring https can be slow the first time
    # and this check shouldn't interfere with startup time.
    process.nextTick =>
      https = require 'https'

      request = https.get @feedUrl, (response) ->
        if response.statusCode == 200
          body = ""
          response.on 'data', (chunk) -> body += chunk
          response.on 'end', ->
            {notes, name} = JSON.parse(body)
            autoUpdater.emit 'update-downloaded', null, notes, name
        else
          autoUpdater.emit 'update-not-available'

      request.on 'error', (error) ->
        autoUpdater.emit 'error', null, error.message

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion? and @releaseNotes
    for atomWindow in windows
      atomWindow.sendCommand('window:update-available', [@releaseVersion, @releaseNotes])

  setState: (state) ->
    return if @state is state
    @state = state
    @emit 'state-changed', @state

  getState: ->
    @state

  check: ({hidePopups}={}) ->
    unless hidePopups
      autoUpdater.once 'update-not-available', @onUpdateNotAvailable
      autoUpdater.once 'error', @onUpdateError

    autoUpdater.checkForUpdates()

  install: ->
    autoUpdater.quitAndInstall()

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    dialog = require 'dialog'
    dialog.showMessageBox type: 'info', buttons: ['OK'], message: 'No update available.', detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog = require 'dialog'
    dialog.showMessageBox type: 'warning', buttons: ['OK'], message: 'There was an error checking for updates.', detail: message

  getWindows: ->
    global.atomApplication.windows
