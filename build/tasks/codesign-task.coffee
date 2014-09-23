path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'codesign', 'Codesign the app', ->
    done = @async()

    if process.platform is 'darwin' and process.env.XCODE_KEYCHAIN
      unlockKeychain (error) ->
        if error?
          done(error)
        else
          signApp(done)
    else
      signApp(done)

  unlockKeychain = (callback) ->
    cmd = 'security'
    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN} = process.env
    args = ['unlock-keychain', '-p', XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN]
    spawn {cmd, args}, (error) -> callback(error)

  signApp = (callback) ->
    switch process.platform
      when 'darwin'
        cmd = 'codesign'
        args = ['-f', '-v', '-s', 'Developer ID Application: GitHub', grunt.config.get('atom.shellAppDir')]
        spawn {cmd, args}, (error) -> callback(error)
      when 'win32'
        spawn {cmd: 'taskkill', args: ['/F', '/IM', 'atom.exe']}, ->
          cmd = process.env.JANKY_SIGNTOOL ? 'signtool'
          args = [path.join(grunt.config.get('atom.shellAppDir'), 'atom.exe')]

          spawn {cmd, args}, (error) ->
            return callback(error) if error?

            args = [path.join(grunt.config.get('atom.shellAppDir'), '..', 'Releases', 'setup.exe')]
            spawn {cmd, args}, (error) -> callback(error)
      else
        callback()
