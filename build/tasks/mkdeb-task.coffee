path = require 'path'

module.exports = (grunt) ->
  {spawn, fillTemplate} = require('./task-helpers')(grunt)

  grunt.registerTask 'mkdeb', 'Create debian package', ->
    done = @async()

    appName = grunt.config.get('atom.appName')
    appFileName = grunt.config.get('atom.appFileName')
    apmFileName = grunt.config.get('atom.apmFileName')
    buildDir = grunt.config.get('atom.buildDir')
    installDir = '/usr'
    shellAppDir = grunt.config.get('atom.shellAppDir')
    {version, description} = grunt.config.get('atom.metadata')
    channel = grunt.config.get('atom.channel')

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    desktopFilePath = path.join(buildDir, appFileName + '.desktop')
    fillTemplate(
      path.join('resources', 'linux', 'atom.desktop.in'),
      desktopFilePath,
      {appName, appFileName, description, installDir, iconPath: appFileName}
    )

    getInstalledSize shellAppDir, (error, installedSize) ->
      if error?
        return done(error)

      controlFilePath = path.join(buildDir, 'control')
      fillTemplate(
        path.join('resources', 'linux', 'debian', 'control.in'),
        controlFilePath,
        {appFileName, version, arch, installedSize, description}
      )

      iconPath = path.join(shellAppDir, 'resources', 'app.asar.unpacked', 'resources', 'atom.png')

      cmd = path.join('script', 'mkdeb')
      args = [appFileName, version, channel, arch, controlFilePath, desktopFilePath, iconPath, buildDir]
      spawn {cmd, args}, (error) ->
        if error?
          done(error)
        else
          grunt.log.ok "Created #{buildDir}/#{appFileName}-#{version}-#{arch}.deb"
          done()

  getInstalledSize = (directory, callback) ->
    cmd = 'du'
    args = ['-sk', directory]
    spawn {cmd, args}, (error, {stdout}) ->
      installedSize = stdout.split(/\s+/)?[0] or '200000' # default to 200MB
      callback(null, installedSize)
