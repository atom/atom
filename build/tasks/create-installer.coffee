fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {spawn, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'create-installer', 'Create the Windows installer', ->
    return unless process.platform is 'win32'

    done = @async()

    buildDir = grunt.config.get('atom.buildDir')
    atomDir = path.join(buildDir, 'Atom')
    releasesDir = path.join(buildDir, 'Releases')
    atomGitHubToken = process.env.ATOM_ACCESS_TOKEN

    packageInfo = grunt.file.readJSON(path.join(atomDir, 'resources', 'app', 'package.json'))
    inputTemplate = grunt.file.read(path.join('build', 'windows', 'atom.nuspec.erb'))

    # NB: Build server has some sort of stamp on the version number
    packageInfo.version = packageInfo.version.replace(/-.*$/, '')

    targetNuspecPath = path.join(buildDir, 'atom.nuspec')
    grunt.file.write(targetNuspecPath, _.template(inputTemplate, packageInfo))

    # We use the previous releases to build deltas for the current release,
    # sync down the existing releases directory by rolling through GitHub releases
    cmd = 'build/windows/SyncGitHubReleases.exe'
    args = ['-r', releasesDir, '-u', 'https://github.com/atom/atom', '-t', atomGitHubToken]

    spawn {cmd, args}, (error, result, code) ->
      if error?
        grunt.log.error "ATOM_ACCESS_TOKEN environment variable not set or invalid, can't download old releases; continuing anyways"

      cmd = 'build/windows/nuget.exe'
      args = ['pack', targetNuspecPath, '-BasePath', atomDir, '-OutputDirectory', buildDir]

      spawn {cmd, args}, (error, result, code) ->
        return done(error) if error?

        pkgs = pkg for pkg in fs.readdirSync(buildDir) when path.extname(pkg) is '.nupkg'

        cmd = 'build/windows/update.com'
        args = ['--releasify', path.join(buildDir, pkgs), '-r', releasesDir, '-g', 'build/windows/install-spinner.gif']
        spawn {cmd, args}, (error, result, code) -> done(error)
