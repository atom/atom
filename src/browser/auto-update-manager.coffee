autoUpdater = require 'auto-updater'
dialog = require 'dialog'
_ = require 'underscore-plus'
{EventEmitter} = require 'events'

IDLE_STATE='idle'
CHECKING_STATE='checking'
DOWNLOADING_STATE='downloading'
UPDATE_AVAILABLE_STATE='update-available'
NO_UPDATE_AVAILABLE_STATE='no-update-available'
ERROR_STATE='error'

module.exports =
class AutoUpdateManager
  _.extend @prototype, EventEmitter.prototype

  constructor: (@version) ->
    @state = IDLE_STATE

    # Only released versions should check for updates.
    return if /\w{7}/.test(@version)

    autoUpdater.setFeedUrl "https://atom.io/api/updates?version=#{@version}"

    autoUpdater.on 'checking-for-update', =>
      @setState(CHECKING_STATE)

    autoUpdater.on 'update-not-available', =>
      @setState(NO_UPDATE_AVAILABLE_STATE)

    autoUpdater.on 'update-available', =>
      @setState(DOWNLOADING_STATE)

    autoUpdater.on 'error', (event, message) =>
      @setState(ERROR_STATE)
      console.error "Error Downloading Update: #{message}"

    autoUpdater.on 'update-downloaded', (event, @releaseNotes, @releaseVersion) =>
      @setState(UPDATE_AVAILABLE_STATE)
      @emitUpdateAvailableEvent(@getWindows()...)

    @check(hidePopups: true)

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion? and @releaseNotes
    for atomWindow in windows
      atomWindow.sendCommand('window:update-available', [@releaseVersion, @releaseNotes])

  setState: (state) ->
    return unless @state != state
    @state = state
    @emit 'state-changed', @state

  getState: ->
    @state

  check: ({hidePopups}={})->
    unless hidePopups
      autoUpdater.once 'update-not-available', @onUpdateNotAvailable
      autoUpdater.once 'error', @onUpdateError

    autoUpdater.checkForUpdates()

  install: ->
    autoUpdater.quitAndInstall()

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    dialog.showMessageBox type: 'info', buttons: ['OK'], message: 'No update available.', detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog.showMessageBox type: 'warning', buttons: ['OK'], message: 'There was an error checking for updates.', detail: message

  getWindows: ->
    global.atomApplication.windows
