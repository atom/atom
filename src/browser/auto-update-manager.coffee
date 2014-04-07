autoUpdater = require 'auto-updater'
dialog = require 'dialog'

module.exports =
class AutoUpdateManager
  constructor: ->
    # Only released versions should check for updates.
    return if /\w{7}/.test(@getVersion())

    autoUpdater.setFeedUrl "https://atom.io/api/updates?version=#{@getVersion()}"

    autoUpdater.on 'checking-for-update', =>
      @getMenu().showDownloadingUpdateItem(false)
      @getMenu().showInstallUpdateItem(false)
      @getMenu().showCheckForUpdateItem(false)

    autoUpdater.on 'update-not-available', =>
      @getMenu().showCheckForUpdateItem(true)

    autoUpdater.on 'update-available', =>
      @getMenu().showDownloadingUpdateItem(true)

    autoUpdater.on 'update-downloaded', (event, releaseNotes, releaseVersion, releaseDate, releaseURL) =>
      for atomWindow in @getWindows()
        atomWindow.sendCommand('window:update-available', [releaseVersion, releaseNotes])
      @getMenu().showInstallUpdateItem(true)

    autoUpdater.on 'error', (event, message) =>
      @getMenu().showCheckForUpdateItem(true)

    # Check for update after Atom has fully started and the menus are created
    setTimeout((-> autoUpdater.checkForUpdates()), 5000)

  checkForUpdate: ->
    autoUpdater.once 'update-not-available', @onUpdateNotAvailable
    autoUpdater.once 'error', @onUpdateError
    autoUpdater.checkForUpdates()

  installUpdate: ->
    autoUpdater.quitAndInstall()

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    dialog.showMessageBox type: 'info', buttons: ['OK'], message: 'No update available.', detail: "Version #{@version} is the latest version."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog.showMessageBox type: 'warning', buttons: ['OK'], message: 'There was an error checking for updates.', detail: message

  getMenu: ->
    global.atomApplication.applicationMenu

  getVersion: ->
    global.atomApplication.version

  getWindows: ->
    global.atomApplication.windows
