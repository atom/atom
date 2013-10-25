fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {cp, isAtomPackage, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'build', 'Build the application', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    buildDir = grunt.config.get('atom.buildDir')
    appDir = grunt.config.get('atom.appDir')

    rm shellAppDir
    mkdir path.dirname(buildDir)
    cp 'atom-shell/Atom.app', shellAppDir

    mkdir appDir

    cp 'atom.sh', path.join(appDir, 'atom.sh')
    cp 'package.json', path.join(appDir, 'package.json')

    packageDirectories = []
    nonPackageDirectories = [
      'benchmark'
      'dot-atom'
      'vendor'
    ]

    {devDependencies} = grunt.file.readJSON('package.json')
    for child in fs.readdirSync('node_modules')
      directory = path.join('node_modules', child)
      if isAtomPackage(directory)
        packageDirectories.push(directory)
      else
        nonPackageDirectories.push(directory)

    ignoredPaths = [
      path.join('git-utils', 'deps')
      path.join('oniguruma', 'deps')
      path.join('vendor', 'apm')
      path.join('vendor', 'bootstrap', 'docs')
    ]
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"
    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    for directory in nonPackageDirectories
      cp directory, path.join(appDir, directory), filter: nodeModulesFilter
    for directory in packageDirectories
      cp directory, path.join(appDir, directory), filter: /.+\.(cson|coffee)$/

    cp 'spec', path.join(appDir, 'spec')
    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee)$/
    cp 'static', path.join(appDir, 'static')

    grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
      unless /.+\.plist/.test(sourcePath)
        grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    grunt.task.run('compile', 'copy-info-plist')
