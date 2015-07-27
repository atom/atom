{EventEmitter} = require 'events'
_ = require 'underscore-plus'
ChildProcess = require 'child_process'
app = require 'app'

distros = {
  ubuntu: /(\S*ubuntu)/i,
  debian: /(debian)/i,
  redhat: /(red(\s?)hat)/i,
  centos: /(centos)/i,
  fedora: /(fedora)/i,
}

spawn = (command, args, callback) ->
  stdout = ''

  try
    spawnedProcess = ChildProcess.spawn(command, args)
  catch error
    # Spawn can throw an error
    process.nextTick -> callback?(error, stdout)
    return

  spawnedProcess.stdout.on 'data', (data) ->
    stdout += data

  error = null
  spawnedProcess.on 'error', (processError) -> error ?= processError
  spawnedProcess.on 'close', (code, signal) ->
    error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
    error?.code ?= code
    error?.stdout ?= stdout
    callback?(error, stdout)

class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  stdout = ChildProcess.execSync('cat /etc/issue').toString().replace(/\\./g, "");

  if distros.ubuntu.test(stdout) | distros.debian.test(stdout)
    @pkg = 'atom-amd64.deb'
    @pkgType = 'deb'
    @installCmd = 'dpkg --install -y'
  if distros.redhat.test(stdout) | distros.centos.test(stdout)
    @pkg = 'atom.x86_64.rpm'
    @pkgType = 'rpm'
    @installCmd = 'yum localinstall -y'
  if distros.fedora.test(stdout)
    @pkg = 'atom.x86_64.rpm'
    @pkgType = 'rpm'
    @installCmd = 'dnf install -y'
  else distro = 'unsupported'

  setFeedUrl: (@updateUrl) ->

  quitAndInstall: ->
    if @supportsUpdates()
      app.once 'will-quit', -> spawn 'sudo', [installCmd, @pkg, '&&',
        'rm', '-rf', @pkg, '&&', 'atom']
      app.quit()
    else
      # What am I supposed to do with this?
      require('auto-updater').quitAndInstall()

  downloadUpdate: (callback) ->
    spawn 'curl', ['-L', @updateUrl], (error, stdout) ->
      return callback(error) if error?

      try
        update = JSON.parse(stdout)

        spawn 'atom', ['--version'], (error, stdout) ->
          return callback(error) if error?

          if update.name != stdout.trim().split('\n')
            callback(null, update)

          else callback()
      catch error
        error.stdout = stdout
        return callback(error)

  installUpdate: (callback) ->
    spawn 'curl', ['-L', "https://atom.io/download/#{@pkgType}"], (error) ->
      return callback(error) if error?
      callback()

  supportsUpdates: ->
    return true unless @distro == 'unsupported'

  checkForUpdates: ->
    throw new Error('Update URL is not set') unless @updateUrl

    @emit 'checking-for-update'

    unless @supportsUpdates()
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

        @emit 'update-downloaded', {}, update.notes, update.name, new Date(), 'https://atom.io', => @quitAndInstall()

module.exports = new AutoUpdater()
