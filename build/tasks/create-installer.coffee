fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'create-installer', 'Create the Windows installer', ->
    if process.platform != 'win32'
      return

    done = @async()

    buildDir = grunt.config.get('atom.buildDir')
    atomDir = path.join(buildDir, 'Atom')

    packageInfo = JSON.parse(fs.readFileSync(path.join(atomDir, 'resources', 'app', 'package.json'), {encoding: 'utf8'}))
    inputTemplate = grunt.file.read(path.join('build', 'windows', 'atom.nuspec.erb'))

    ## NB: Build server has some sort of stamp on the version number
    packageInfo.version = packageInfo.version.replace(/-.*$/, '')

    targetNuspecPath = path.join(buildDir, 'atom.nuspec')
    grunt.file.write(targetNuspecPath, _.template(inputTemplate, packageInfo))

    cmd = 'build/windows/nuget.exe'
    args = ['pack', targetNuspecPath, '-BasePath', atomDir, '-OutputDirectory', buildDir]

    spawn {cmd, args}, (error, result, code) ->
      if error?
        done(error)
        return

      pkgs = pkg for pkg in fs.readdirSync(buildDir) when pkg.match /.nupkg$/i

      releasesDir = path.join(buildDir, 'Releases')

      ## NB: Gonna clear Releases for now, in the future we need to pull down
      ## the existing version
      rm(releasesDir)

      cmd = 'build/windows/update.com'
      args = ['--releasify', path.join(buildDir, pkgs), '-r', releasesDir]
      spawn {cmd, args}, (error, result, code) -> done(error)
