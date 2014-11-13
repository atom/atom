ChildProcess = require 'child_process'
{EventEmitter} = require 'events'
fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
shellAutoUpdater = require 'auto-updater'

class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  constructor: ->
    @updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')

  setFeedUrl: (@updateUrl) ->
    if @updateUrl
      # Schedule an update when the feed URL is set
      process.nextTick => @checkForUpdates()

  quitAndInstall: ->
    unless fs.existsSync(@updateDotExe)
      shellAutoUpdater.quitAndInstall()
      return

    args = ['--update', @updateUrl]
    ChildProcess.execFile @updateDotExe, args, (error) ->
      return if error?

      args = ['--processStart', 'atom.exe']
      ChildProcess.execFile @updateDotExe, args, ->
        shellAutoUpdater.quitAndInstall()

  downloadUpdate: (callback) ->
    args = ['--download', @updateUrl]
    ChildProcess.execFile @updateDotExe, args, (error, stdout) ->
      if error?
        error.stdout = stdout
        return callback(error)

      try
        # Last line of output is the JSON details about the releases
        [json] = stdout.trim().split('\n').reverse()
        update = JSON.parse(json)?.releasesToApply?.pop?()
      catch error
        error.stdout = stdout
        return callback(error)

      callback(null, update)

  installUpdate: (callback) ->
    args = ['--update', @updateUrl]
    ChildProcess.execFile @updateDotExe, args, (error, stdout) ->
      error?.stdout = stdout
      callback(error)

  checkForUpdates: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    unless fs.existsSync(@updateDotExe)
      @emit 'update-not-available'
      return

    @downloadUpdate (error, update) =>
      if error?
        console.log "Failed to download: #{error.message} - #{error.code} - #{error.stdout}"
        @emit 'update-not-available'
        return

      unless update?
        @emit 'update-not-available'
        return

      @installUpdate (error) =>
        if error?
          console.log "Failed to update: #{error.message} - #{error.code} - #{error.stdout}"
          @emit 'update-not-available'
          return

        @emit 'update-available'
        @emit 'update-downloaded', {}, update.releaseNotes, update.version, new Date(), 'https://atom.io', => @quitAndInstall()

module.exports = new AutoUpdater()
