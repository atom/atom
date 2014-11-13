ChildProcess = require 'child_process'
{EventEmitter} = require 'events'
fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
shellAutoUpdater = require 'auto-updater'

class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  setFeedUrl: (@updateUrl) ->
    if @updateUrl
      # Schedule an update when the feed URL is set
      process.nextTick => @checkForUpdates()

  quitAndInstall: ->
    updateDotExe = @getUpdateExePath()

    unless fs.existsSync(updateDotExe)
      shellAutoUpdater.quitAndInstall()
      return

    args = ['--update', @updateUrl]
    ChildProcess.execFile updateDotExe, args, (error) ->
      return if error?

      args = ['--processStart', 'atom.exe']
      ChildProcess.execFile updateDotExe, args, ->
        shellAutoUpdater.quitAndInstall()

  getUpdateExePath: ->
    path.resolve(path.dirname(process.execPath), '..', 'Update.exe')

  checkForUpdates: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    updateDotExe = @getUpdateExePath()

    unless fs.existsSync(updateDotExe)
      console.log 'Running developer or Chocolatey version of Atom, skipping'
      @emit 'update-not-available'
      return

    args = ['--update', @updateUrl]
    ChildProcess.execFile updateDotExe, args, (error, stdout) =>
      if error?
        console.log "Failed to update: #{error.code} - #{stdout}"
        @emit 'update-not-available'
        return

      try
        # Last line of output is the JSON details about the release
        [json] = stdout.split('\n').reverse()
        latestRelease = JSON.parse(json)?.releasesToApply?.pop?()
      catch error
        console.log "Update output isn't valid: #{stdout}"
        @emit 'update-not-available'
        return

      if latestRelease?
        @emit 'update-available'
        @emit 'update-downloaded', {}, latestRelease.releaseNotes, latestRelease.version, new Date(), 'https://atom.io', => @quitAndInstall()
      else
        console.log "You're on the latest version!"
        @emit 'update-not-available'

module.exports = new AutoUpdater()
