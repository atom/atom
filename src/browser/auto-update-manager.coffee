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

  constructor: (@version, @testMode, resourcePath, @config) ->
    @state = IdleState
    @iconPath = path.resolve(__dirname, '..', '..', 'resources', 'atom.png')
    @feedUrl = "https://atom.io/api/updates?version=#{@version}"
    process.nextTick => @setupAutoUpdater()

  setupAutoUpdater: ->
    if process.platform is 'win32'
      autoUpdater = require './auto-updater-win32'
    else
      {autoUpdater} = require 'electron'

    autoUpdater.on 'error', (event, message) =>
      @setState(ErrorState, message)
      @emitWindowEvent('update-error')
      console.error "Error Downloading Update: #{message}"

    autoUpdater.setFeedURL @feedUrl

    autoUpdater.on 'checking-for-update', =>
      @setState(CheckingState)
      @emitWindowEvent('checking-for-update')

    autoUpdater.on 'update-not-available', =>
      @setState(NoUpdateAvailableState)
      @emitWindowEvent('update-not-available')

    autoUpdater.on 'update-available', =>
      @setState(DownladingState)
      # We use sendMessage to send an event called 'update-available' in 'update-downloaded'
      # once the update download is complete. This mismatch between the electron
      # autoUpdater events is unfortunate but in the interest of not changing the
      # one existing event handled by applicationDelegate
      @emitWindowEvent('did-begin-downloading-update')
      @emit('did-begin-download')

    autoUpdater.on 'update-downloaded', (event, releaseNotes, @releaseVersion) =>
      @setState(UpdateAvailableState)
      @emitUpdateAvailableEvent()

    @config.onDidChange 'core.automaticallyUpdate', ({newValue}) =>
      if newValue
        @scheduleUpdateCheck()
      else
        @cancelScheduledUpdateCheck()

    @scheduleUpdateCheck() if @config.get 'core.automaticallyUpdate'

    switch process.platform
      when 'win32'
        @setState(UnsupportedState) unless autoUpdater.supportsUpdates()
      when 'linux'
        @setState(UnsupportedState)

  emitUpdateAvailableEvent: ->
    return unless @releaseVersion?
    @emitWindowEvent('update-available', {@releaseVersion})
    return

  emitWindowEvent: (eventName, payload) ->
    for atomWindow in @getWindows()
      atomWindow.sendMessage(eventName, payload)
    return

  setState: (state, errorMessage) ->
    return if @state is state
    @state = state
    @errorMessage = errorMessage
    @emit 'state-changed', @state

  getState: ->
    @state

  getErrorMessage: ->
    @errorMessage

  scheduleUpdateCheck: ->
    # Only schedule update check periodically if running in release version and
    # and there is no existing scheduled update check.
    unless /\w{7}/.test(@version) or @checkForUpdatesIntervalID
      checkForUpdates = => @check(hidePopups: true)
      fourHours = 1000 * 60 * 60 * 4
      @checkForUpdatesIntervalID = setInterval(checkForUpdates, fourHours)
      checkForUpdates()

  cancelScheduledUpdateCheck: ->
    if @checkForUpdatesIntervalID
      clearInterval(@checkForUpdatesIntervalID)
      @checkForUpdatesIntervalID = null

  check: ({hidePopups}={}) ->
    unless hidePopups
      autoUpdater.once 'update-not-available', @onUpdateNotAvailable
      autoUpdater.once 'error', @onUpdateError

    autoUpdater.checkForUpdates() unless @testMode

  install: ->
    autoUpdater.quitAndInstall() unless @testMode

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    {dialog} = require 'electron'
    dialog.showMessageBox
      type: 'info'
      buttons: ['OK']
      icon: @iconPath
      message: 'No update available.'
      title: 'No Update Available'
      detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    {dialog} = require 'electron'
    dialog.showMessageBox
      type: 'warning'
      buttons: ['OK']
      icon: @iconPath
      message: 'There was an error checking for updates.'
      title: 'Update Error'
      detail: message

  getWindows: ->
    global.atomApplication.windows
