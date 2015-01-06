autoUpdater = null
_ = require 'underscore-plus'
{EventEmitter} = require 'events'
path = require 'path'

IdleState = 'idle'
CheckingState = 'checking'
DownladingState = 'downloading'
UpdateAvailableState = 'update-available'
NoUpdateAvailableState = 'no-update-available'
UnsupportedState = 'unsupported'
ErrorState = 'error'

module.exports =
class AutoUpdateManager
  _.extend @prototype, EventEmitter.prototype

  constructor: (@version) ->
    @state = IdleState
    if process.platform is 'win32'
      # Squirrel for Windows can't handle query params
      # https://github.com/Squirrel/Squirrel.Windows/issues/132
      @feedUrl = 'https://atom.io/api/updates'
    else
      @feedUrl = "https://atom.io/api/updates?version=#{@version}"

    process.nextTick => @setupAutoUpdater()

  setupAutoUpdater: ->
    if process.platform is 'win32'
      autoUpdater = require './auto-updater-win32'
    else
      autoUpdater = require 'auto-updater'

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
    @check(hidePopups: true) unless /\w{7}/.test(@version)

    switch process.platform
      when 'win32'
        @setState(UnsupportedState) unless autoUpdater.supportsUpdates()
      when 'linux'
        @setState(UnsupportedState)

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion? and @releaseNotes
    for atomWindow in windows
      atomWindow.sendMessage('update-available', {@releaseVersion, @releaseNotes})

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
    dialog.showMessageBox
      type: 'info'
      buttons: ['OK']
      icon: path.join(process.resourcesPath, 'app', 'atom.png')
      message: 'No update available.'
      title: 'No Update Available'
      detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog = require 'dialog'
    dialog.showMessageBox
      type: 'warning'
      buttons: ['OK']
      icon: path.join(process.resourcesPath, 'app', 'atom.png')
      message: 'There was an error checking for updates.'
      title: 'Update Error'
      detail: message

  getWindows: ->
    global.atomApplication.windows
