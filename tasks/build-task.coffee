fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

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

    directories = [
      'benchmark'
      'dot-atom'
      'spec'
      'vendor'
    ]

    {devDependencies, dependencies} = grunt.file.readJSON('package.json')
    for child in fs.readdirSync('node_modules')
      directory = path.join('node_modules', child)
      try
        {name} = grunt.file.readJSON(path.join(directory, 'package.json'))
        if not devDependencies[name]? or dependencies[name]?
          directories.push(directory)
      catch e
        directories.push(directory)

    ignoredPaths = [
      path.join('git-utils', 'deps')
      path.join('oniguruma', 'deps')
      path.join('vendor', 'apm')
      path.join('vendor', 'bootstrap', 'docs')
    ]
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"
    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    for directory in directories
      cp directory, path.join(appDir, directory), filter: nodeModulesFilter

    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee|less)$/
    cp 'static', path.join(appDir, 'static'), filter: /.+\.less$/
    cp 'themes', path.join(appDir, 'themes'), filter: /.+\.(cson|less)$/

    grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
      unless /.+\.plist/.test(sourcePath)
        grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    grunt.task.run('compile', 'copy-info-plist')
