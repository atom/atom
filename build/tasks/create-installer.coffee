fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'create-installer', 'Create the Windows installer', ->
    if process.platform != 'win32'
      return

    done = @async()

    buildDir = grunt.config.get('atom.buildDir')
    atomDir = path.join(buildDir, 'Atom')

    packageInfo = JSON.parse(fs.readFileSync(path.join(atomDir, 'resources', 'app', 'package.json'), {encoding: 'utf8'}))
    inputTemplate = fs.readFileSync(path.join('build', 'windows', 'atom.nuspec.hbs'), {encoding: 'utf8'})

    targetNuspecPath = path.join(buildDir, 'atom.nuspec')
    fs.writeFileSync(targetNuspecPath, inputTemplate.replace(/{{version}}/, packageInfo.version))

    cmd = 'build/windows/nuget.exe'
    args = ['pack', targetNuspecPath, '-BasePath', atomDir, '-OutputDirectory', buildDir]

    spawn {cmd, args}, (error, result, code) ->
      if error?
        done(error)
        return

      pkgs = pkg for pkg in fs.readdirSync(buildDir) when pkg.match /.nupkg$/i

      cmd = 'build/windows/update.com'
      args = ['--releasify', path.join(buildDir, pkgs), '-r', path.join(buildDir, 'Releases')]

      spawn {cmd, args}, (error, result, code) -> done(error)
