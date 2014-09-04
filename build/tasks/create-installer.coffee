fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'create-installer', 'Create the Windows installer', ->
    if process.platform is not 'win32'
      return

    done = @async()

    buildDir = grunt.config.get('atom.buildDir')
    atomDir = path.join(buildDir, 'Atom')

    cmd = 'build/windows/nuget.exe'
    args = ['pack', './build/windows/atom.nuspec', '-BasePath', atomDir, '-OutputDirectory', buildDir]

    spawn {cmd, args}, (error, result, code) ->
      console.log("Callback!")
      if error?
        console.log("Bail!")
        done(error)
        return

      pkgs = pkg for pkg in fs.readdirSync(buildDir) when pkg.match /.nupkg$/i

      console.log("Updating! ")

      console.log(pkgs)
      console.log(buildDir)

      cmd = 'build/windows/update.com'
      args = ['--releasify', path.join(buildDir, pkgs), '-r', path.join(buildDir, 'Releases')]

      console.log(args)

      spawn {cmd, args}, (error, result, code) -> done(error)
