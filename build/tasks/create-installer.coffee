fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'
rimraf = require 'rimraf'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'create-installer', 'Create the Windows installer', ->
    if process.platform != 'win32'
      return

    done = @async()

    buildDir = grunt.config.get('atom.buildDir')
    atomDir = path.join(buildDir, 'Atom')

    packageInfo = JSON.parse(fs.readFileSync(path.join(atomDir, 'resources', 'app', 'package.json'), {encoding: 'utf8'}))
    inputTemplate = fs.readFileSync(path.join('build', 'windows', 'atom.nuspec.erb'), {encoding: 'utf8'})

    ## NB: Build server has some sort of stamp on the version number
    packageInfo.version = packageInfo.version.replace(/-.*$/, '')

    targetNuspecPath = path.join(buildDir, 'atom.nuspec')
    fs.writeFileSync(targetNuspecPath, _.template(inputTemplate, packageInfo))

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
      rimraf.sync(releasesDir)

      cmd = 'build/windows/update.com'
      args = ['--releasify', path.join(buildDir, pkgs), '-r', releasesDir]
      spawn {cmd, args}, (error, result, code) -> done(error)
