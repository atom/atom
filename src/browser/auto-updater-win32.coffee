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

  spawnUpdate: (args, callback) ->
    stdout = ''
    error = null
    updateProcess = ChildProcess.spawn(@updateDotExe, args)
    updateProcess.stdout.on 'data', (data) -> stdout += data
    updateProcess.on 'error', (processError) -> error ?= processError
    updateProcess.on 'close', (code, signal) ->
      error ?= new Error("Command failed: #{signal}") if code isnt 0
      error?.code ?= code
      error?.stdout ?= stdout
      callback(error, stdout)
    undefined

  quitAndInstall: ->
    unless fs.existsSync(@updateDotExe)
      shellAutoUpdater.quitAndInstall()
      return

    @spawn ['--update', @updateUrl], (error) =>
      return if error?

      @spawn ['--processStart', 'atom.exe'], ->
        shellAutoUpdater.quitAndInstall()

  downloadUpdate: (callback) ->
    @spawn ['--download', @updateUrl], (error, stdout) ->
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
    @spawn(['--update', @updateUrl], callback)

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

        console.log "Updated to #{update.version}"

        @emit 'update-available'
        @emit 'update-downloaded', {}, update.releaseNotes, update.version, new Date(), 'https://atom.io', => @quitAndInstall()

module.exports = new AutoUpdater()
