{EventEmitter} = require 'events'
SquirrelUpdate = require './squirrel-update'

class AutoUpdater
  Object.assign @prototype, EventEmitter.prototype

  setFeedURL: (@updateUrl) ->

  quitAndInstall: ->
    if SquirrelUpdate.existsSync()
      SquirrelUpdate.restartAtom(require('electron').app)
    else
      require('electron').autoUpdater.quitAndInstall()

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

  supportsUpdates: ->
    SquirrelUpdate.existsSync()

  checkForUpdates: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    unless SquirrelUpdate.existsSync()
      @emit 'update-not-available'
      return

    @downloadUpdate (error, update) =>
      if error?
        @emit 'update-not-available'
        return

      unless update?
        @emit 'update-not-available'
        return

      @emit 'update-available'

      @installUpdate (error) =>
        if error?
          @emit 'update-not-available'
          return

        @emit 'update-downloaded', {}, update.releaseNotes, update.version, new Date(), 'https://atom.io', => @quitAndInstall()

module.exports = new AutoUpdater()
