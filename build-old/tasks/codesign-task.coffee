path = require 'path'
fs = require 'fs'
request = require 'request'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  # macOS code signing

  grunt.registerTask 'codesign:app', 'CodeSign Atom.app', ->
    done = @async()
    unlockKeychain (error) ->
      return done(error) if error?

      args = ['--deep', '--force', '--verbose', '--sign', 'Developer ID Application: GitHub', grunt.config.get('atom.shellAppDir')]
      spawn {cmd: 'codesign', args: args}, (error) -> done(error)

  unlockKeychain = (callback) ->
    return callback() unless process.env.XCODE_KEYCHAIN
    {XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN} = process.env
    args = ['unlock-keychain', '-p', XCODE_KEYCHAIN_PASSWORD, XCODE_KEYCHAIN]
    spawn {cmd: 'security', args: args}, (error) -> callback(error)

  # Windows code signing

  grunt.registerTask 'codesign:exe', 'CodeSign Windows binaries', ->
    done = @async()
    atomExePath = path.join(grunt.config.get('atom.shellAppDir'), 'atom.exe')
    signWindowsExecutable atomExePath, (error) ->
      return done(error) if error?
      updateExePath = path.resolve(__dirname, '..', 'node_modules', 'grunt-electron-installer', 'vendor', 'Update.exe')
      signWindowsExecutable updateExePath, (error) -> done(error)

  grunt.registerTask 'codesign:installer', 'CodeSign Windows installer (AtomSetup.exe)', ->
    done = @async()
    atomSetupExePath = path.resolve(grunt.config.get('atom.buildDir'), 'installer', 'AtomSetup.exe')
    signWindowsExecutable atomSetupExePath, (error) -> done(error)

  grunt.registerTask 'codesign:installer-deferred', 'Obtain cert and configure installer to perform CodeSign', ->
    done = @async()
    getCertificate (file, password) ->
      grunt.config('create-windows-installer.installer.certificateFile', file)
      grunt.config('create-windows-installer.installer.certificatePassword', password)
      grunt.log.ok('Certificate ready for create-windows-installer task')
      done()

  grunt.registerTask 'codesign:cleanup', 'Clean up any temporary or downloaded files used for CodeSign', ->
    try fs.unlinkSync(downloadedCertificateFile) catch e then return

  downloadedCertificateFile = path.resolve(__dirname, 'DownloadedCertFile.p12')

  signWindowsExecutable = (exeToSign, callback) ->
    if process.env.JANKY_SIGNTOOL
      signUsingJanky exeToSign, callback
    else
      signUsingWindowsSDK exeToSign, callback

  signUsingJanky = (exeToSign, callback) ->
    grunt.log.ok("Signing #{exeToSign} using Janky SignTool")
    spawn {cmd: process.env.JANKY_SIGNTOOL, args: [exeToSign]}, callback

  signUsingWindowsSDK = (exeToSign, callback) ->
    getCertificate (file, password) ->
      signUsingWindowsSDKTool exeToSign, file, password, callback

  signUsingWindowsSDKTool = (exeToSign, certificateFile, certificatePassword, callback) ->
    grunt.log.ok("Signing '#{exeToSign}' using Windows SDK")
    args = ['sign', '/v', '/p', certificatePassword, '/f', certificateFile, exeToSign]
    spawn {cmd: 'C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\bin\\signtool.exe', args: args}, callback

  getCertificate = (callback) ->
    if process.env.WIN_P12KEY_URL?
      grunt.log.ok("Obtaining certificate file")
      downloadFile process.env.WIN_P12KEY_URL, downloadedCertificateFile, (done) ->
        callback(downloadedCertificateFile, process.env.WIN_P12KEY_PASSWORD ? 'password')
    else
      callback(path.resolve(__dirname, '..', 'certs', 'windows-dev.p12'), process.env.WIN_P12KEY_PASSWORD ? 'password')

  downloadFile = (sourceUrl, targetPath, callback) ->
    options = {
      url: sourceUrl
      headers: {
        'User-Agent': 'Atom Signing Key build task',
        'Accept': 'application/vnd.github.VERSION.raw'
      }
    }
    request(options)
      .pipe(fs.createWriteStream(targetPath))
      .on('finish', callback)
