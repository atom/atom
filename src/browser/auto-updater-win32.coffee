_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs'

{EventEmitter} = require 'events'
{BufferedProcess} = require 'atom'

module.exports =
class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  setFeedUrl: (url) ->
    @updateUrl = url

  quitAndInstall: ->
    console.log 'quitAndInstall'

  checkForUpdates: ->
    throw new Error("Update URL is not set") unless @updateUrl

    emit 'checking-for-update'

    updateDotExe = path.join(path.dirName(process.execPath), '..', 'update.exe')
    unless fs.existsSync(updateDotExe)
      console.log 'Running developer or Chocolatey version of Atom, skipping'
      emit 'update-not-available'
      return

    args = ['--update', @updateUrl]
    updateOutput = ""

    ps = new BufferedProcess
      command: updateDotExe,
      args,
      stdout: (output) -> updateOutput += output
      exit: (exitCode) ->
        unless exitCode is 0
          console.log 'Failed to update: ' + exitCode + ' - ' + updateJson
          emit 'update-not-available'
          return

        updateInfo = null
        try
          # NB: Update.exe spits out the progress as ints until it completes,
          # then the JSON is the last line of the output. We don't support progress
          # so just drop the last lines
          json = updateOutput.split("\n").reverse()[0]

          updateInfo = JSON.parse json
        catch ex
          console.log "Update output isn't valid: " + updateOutput
          emit 'update-not-available'
          return

        unless updateInfo and updateInfo.releasesToApply.length > 0
          console.log "You're on the latest version!"
          emit 'update-not-available'
          return

        # We don't have separate "check for update" and "download" in Squirrel,
        # we always just download
        emit 'update-available'
        emit 'update-downloaded', {}
