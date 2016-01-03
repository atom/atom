path = require 'path'

module.exports = (grunt) ->
  {spawn, fillTemplate} = require('./task-helpers')(grunt)

  grunt.registerTask 'mkpkg', 'Create archlinux package', ->
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
      arch = 'i686'
    else if process.arch is 'x64'
      arch = 'x86_64'
    else
      return done("Unsupported arch #{process.arch}")

    # Arch versions can't have dashes in them.
    # * https://wiki.archlinux.org/index.php/PKGBUILD#pkgver
    version = version.replace(/-beta/, "_beta")
    version = version.replace(/-dev/, "_dev")

    desktopFilePath = path.join(buildDir, appFileName + '.desktop')
    fillTemplate(
      path.join('resources', 'linux', 'atom.desktop.in'),
      desktopFilePath,
      {appName, appFileName, description, installDir, iconPath: appFileName}
    )

    controlFilePath = path.join(buildDir, 'PKGBUILD')
    fillTemplate(
      path.join('resources', 'linux', 'archlinux', 'PKGBUILD.in'),
      controlFilePath,
      {appFileName, version, arch}
    )

    iconPath = path.join(shellAppDir, 'resources', 'app.asar.unpacked', 'resources', 'atom.png')

    cmd = path.join('script', 'mkpkg')
    args = [appFileName, version, channel, arch, controlFilePath, desktopFilePath, iconPath, buildDir]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created #{buildDir}/#{appFileName}-#{version}-#{arch}.pkg.tar.xz"
        done()
