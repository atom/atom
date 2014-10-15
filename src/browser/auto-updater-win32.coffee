_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs'
shellAutoUpdater = require 'auto-updater'

{EventEmitter} = require 'events'
{BufferedProcess} = require 'atom'

module.exports =
class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  setFeedUrl: (url) ->
    @updateUrl = url

  quitAndInstall: ->
    updateDotExe = path.join(path.dirName(process.execPath), '..', 'update.exe')
    
    unless fs.existsSync(updateDotExe)
      console.log 'Running developer or Chocolatey version of Atom, skipping'
      return

    updateOutput = ""
    ps = new BufferedProcess
      command: updateDotExe,
      args: ['--update', @updateUrl]
      stdout: (o) -> updateOutput += o
      exit: (exitCode) ->
        unless exitCode is 0
          console.log 'Failed to update: ' + exitCode + ' - ' + updateOutput
          return

        dontcare = new BufferedProcess
          command: updateDotExe,
          args: ['--processStart', 'atom.exe']

        shellAutoUpdater.quitAndInstall()

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
          console.log 'Failed to update: ' + exitCode + ' - ' + updateOutput
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

        latest = updateInfo.releasesToApply[updateInfo.ReleasesToApply.length-1]

        # We don't have separate "check for update" and "download" in Squirrel,
        # we always just download
        emit 'update-available'
        emit 'update-downloaded',
          releaseNotes: latest.releaseNotes,
          releaseName: "Atom " + latest.version,
          releaseDate: "",   # NB: Squirrel doesn't provide this :(
          updateUrl: "https://atom.io",
          quitAndUpdate: @quitAndInstall
