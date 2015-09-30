path = require 'path'

module.exports = (grunt) ->
  {spawn, fillTemplate, rm, mkdir} = require('./task-helpers')(grunt)

  grunt.registerTask 'mkrpm', 'Create rpm package', ->
    done = @async()

    appName = grunt.config.get('atom.appName')
    appFileName = grunt.config.get('atom.appFileName')
    apmFileName = grunt.config.get('atom.apmFileName')
    buildDir = grunt.config.get('atom.buildDir')
    installDir = '/usr'
    {version, description} = grunt.config.get('atom.metadata')

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

    # RPM versions can't have dashes in them.
    # * http://www.rpm.org/max-rpm/ch-rpm-file-format.html
    # * https://github.com/mojombo/semver/issues/145
    version = version.replace(/-beta/, "~beta")
    version = version.replace(/-dev/, "~dev")

    specFilePath = path.join(buildDir, appFileName + '.spec')
    fillTemplate(
      path.join('resources', 'linux', 'redhat', 'atom.spec.in'),
      specFilePath,
      {appName, appFileName, apmFileName, installDir, version, description}
    )

    rpmDir = path.join(buildDir, 'rpm')
    rm rpmDir
    mkdir rpmDir

    cmd = path.join('script', 'mkrpm')
    args = [appName, appFileName, specFilePath, desktopFilePath, buildDir]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created rpm package in #{rpmDir}"
        done()
