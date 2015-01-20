{EventEmitter} = require 'events'
_ = require 'underscore-plus'
shellAutoUpdater = require 'auto-updater'
SquirrelUpdate = require './squirrel-update'

class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  setFeedUrl: (@updateUrl) ->

  quitAndInstall: ->
    unless SquirrelUpdate.existsSync()
      shellAutoUpdater.quitAndInstall()
      return

    @installUpdate (error) ->
      return if error?

      SquirrelUpdate.spawn ['--processStart', 'atom.exe'], ->
        shellAutoUpdater.quitAndInstall()

  downloadUpdate: (callback) ->
    SquirrelUpdate.spawn ['--download', @updateUrl], (error, stdout) ->
      return callback(error) if error?

      try
        # Last line of output is the JSON details about the releases
        json = stdout.trim().split('\n').pop()
        update = JSON.parse(json)?.releasesToApply?.pop?()
      catch error
        error.stdout = stdout
        return callback(error)

      callback(null, update)

  installUpdate: (callback) ->
    SquirrelUpdate.spawn(['--update', @updateUrl], callback)

  checkForUpdates: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    unless SquirrelUpdate.existsSync()
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

        console.log "Updated to #{update.version}"

        @emit 'update-available'
        @emit 'update-downloaded', {}, update.releaseNotes, update.version, new Date(), 'https://atom.io', => @quitAndInstall()

module.exports = new AutoUpdater()
