autoUpdater = null
_ = require 'underscore-plus'
Config = require '../config'
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

  constructor: (@version, @testMode, resourcePath) ->
    @state = IdleState
    @iconPath = path.resolve(__dirname, '..', '..', 'resources', 'atom.png')
    @feedUrl = "https://atom.io/api/updates?version=#{@version}"
    @config = new Config({configDirPath: process.env.ATOM_HOME, resourcePath, enablePersistence: true})
    @config.setSchema null, {type: 'object', properties: _.clone(require('../config-schema'))}
    @config.load()
    process.nextTick => @setupAutoUpdater()

  setupAutoUpdater: ->
    if process.platform is 'win32'
      autoUpdater = require './auto-updater-win32'
    else
      autoUpdater = require 'auto-updater'

    autoUpdater.on 'error', (event, message) =>
      @setState(ErrorState)
      console.error "Error Downloading Update: #{message}"

    autoUpdater.setFeedUrl @feedUrl

    autoUpdater.on 'checking-for-update', =>
      @setState(CheckingState)

    autoUpdater.on 'update-not-available', =>
      @setState(NoUpdateAvailableState)

    autoUpdater.on 'update-available', =>
      @setState(DownladingState)

    autoUpdater.on 'update-downloaded', (event, releaseNotes, @releaseVersion) =>
      @setState(UpdateAvailableState)
      @emitUpdateAvailableEvent(@getWindows()...)

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

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion?
    for atomWindow in windows
      atomWindow.sendMessage('update-available', {@releaseVersion})
    return

  setState: (state) ->
    return if @state is state
    @state = state
    @emit 'state-changed', @state

  getState: ->
    @state

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
    dialog = require 'dialog'
    dialog.showMessageBox
      type: 'info'
      buttons: ['OK']
      icon: @iconPath
      message: 'No update available.'
      title: 'No Update Available'
      detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog = require 'dialog'
    dialog.showMessageBox
      type: 'warning'
      buttons: ['OK']
      icon: @iconPath
      message: 'There was an error checking for updates.'
      title: 'Update Error'
      detail: message

  getWindows: ->
    global.atomApplication.windows
