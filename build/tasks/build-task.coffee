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

    if process.platform is 'darwin'
      cp 'atom-shell/Atom.app', shellAppDir
    else
      cp 'atom-shell', shellAppDir

    mkdir appDir

    cp 'atom.sh', path.join(appDir, 'atom.sh')
    cp 'package.json', path.join(appDir, 'package.json')

    packageDirectories = []
    nonPackageDirectories = [
      'benchmark'
      'dot-atom'
      'vendor'
      'resources'
    ]

    {devDependencies} = grunt.file.readJSON('package.json')
    for child in fs.readdirSync('node_modules')
      directory = path.join('node_modules', child)
      if isAtomPackage(directory)
        packageDirectories.push(directory)
      else
        nonPackageDirectories.push(directory)

    # Put any paths here that shouldn't end up in the built Atom.app
    # so that it doesn't becomes larger than it needs to be.
    ignoredPaths = [
      path.join('git-utils', 'deps')
      path.join('oniguruma', 'deps')
      path.join('less', 'dist')
      path.join('less', 'test')
      path.join('bootstrap', 'docs')
      path.join('bootstrap', 'examples')
      path.join('spellchecker', 'vendor')
      path.join('xmldom', 'test')
      path.join('jasmine-reporters', 'ext')
      path.join('build', 'Release', 'obj.target')
      path.join('build', 'Release', '.deps')
      path.join('vendor', 'apm')
      path.join('resources', 'mac')
      path.join('resources', 'win')
    ]
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"
    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    packageFilter = new RegExp("(#{ignoredPaths.join('|')})|(.+\\.(cson|coffee)$)")
    for directory in nonPackageDirectories
      cp directory, path.join(appDir, directory), filter: nodeModulesFilter
    for directory in packageDirectories
      cp directory, path.join(appDir, directory), filter: packageFilter

    cp 'spec', path.join(appDir, 'spec')
    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee)$/
    cp 'static', path.join(appDir, 'static')
    cp 'apm', path.join(appDir, 'apm'), filter: nodeModulesFilter

    if process.platform is 'darwin'
      grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
        unless /.+\.plist/.test(sourcePath)
          grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    dependencies = ['compile', "generate-license:save"]
    dependencies.push('copy-info-plist') if process.platform is 'darwin'
    dependencies.push('set-exe-icon') if process.platform is 'win32'
    grunt.task.run(dependencies...)
