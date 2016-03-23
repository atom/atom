path = require 'path'

module.exports = (grunt) ->
  {spawn, fillTemplate} = require('./task-helpers')(grunt)

  grunt.registerTask 'mktar', 'Create an archive', ->
    done = @async()

    appFileName = grunt.config.get('atom.appFileName')
    buildDir = grunt.config.get('atom.buildDir')
    shellAppDir = grunt.config.get('atom.shellAppDir')
    {version, description} = grunt.config.get('atom.metadata')

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    iconPath = path.join(shellAppDir, 'resources', 'app.asar.unpacked', 'resources', 'atom.png')

    cmd = path.join('script', 'mktar')
    args = [appFileName, version, arch, iconPath, buildDir]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created " + path.join(buildDir, "#{appFileName}-#{version}-#{arch}.tar.gz")
        done()
