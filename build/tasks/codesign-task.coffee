path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'codesign:exe', 'Codesign atom.exe', ->
    done = @async()
    spawn {cmd: 'taskkill', args: ['/F', '/IM', 'atom.exe']}, ->
      cmd = process.env.JANKY_SIGNTOOL ? 'signtool'
      args = [path.join(grunt.config.get('atom.shellAppDir'), 'atom.exe')]
      spawn {cmd, args}, (error) -> done(error)

  grunt.registerTask 'codesign:installer', 'Codesign AtomSetup.exe', ->
    done = @async()
    cmd = process.env.JANKY_SIGNTOOL ? 'signtool'
    args = [path.resolve(grunt.config.get('atom.buildDir'), 'installer', 'AtomSetup.exe')]
    spawn {cmd, args}, (error) -> done(error)

  grunt.registerTask 'codesign:app', 'Codesign Atom.app', ->
    done = @async()

    unlockKeychain (error) ->
      return done(error) if error?

      cmd = 'codesign'
      args = ['--deep', '--force', '--verbose', '--sign', 'Developer ID Application: GitHub', grunt.config.get('atom.shellAppDir')]
      spawn {cmd, args}, (error) -> done(error)

  unlockKeychain = (callback) ->
    return callback() unless process.env.XCODE_KEYCHAIN

    cmd = 'security'
    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN} = process.env
    args = ['unlock-keychain', '-p', XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN]
    spawn {cmd, args}, (error) -> callback(error)
