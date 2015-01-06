fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {cp, isAtomPackage, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'build', 'Build the application', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    buildDir = grunt.config.get('atom.buildDir')
    appDir = grunt.config.get('atom.appDir')

    rm shellAppDir
    rm path.join(buildDir, 'installer')
    mkdir path.dirname(buildDir)

    if process.platform is 'darwin'
      cp 'atom-shell/Atom.app', shellAppDir, filter: /default_app/
    else
      cp 'atom-shell', shellAppDir, filter: /default_app/

    mkdir appDir

    if process.platform isnt 'win32'
      cp 'atom.sh', path.join(appDir, 'atom.sh')

    cp 'package.json', path.join(appDir, 'package.json')
    cp path.join('resources', 'atom.png'), path.join(appDir, 'atom.png')

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
      path.join('bootstrap', 'docs')
      path.join('bootstrap', '_config.yml')
      path.join('bootstrap', '_includes')
      path.join('bootstrap', '_layouts')
      path.join('npm', 'doc')
      path.join('npm', 'html')
      path.join('npm', 'man')
      path.join('npm', 'node_modules', '.bin', 'beep')
      path.join('npm', 'node_modules', '.bin', 'clear')
      path.join('npm', 'node_modules', '.bin', 'starwars')
      path.join('pegjs', 'examples')
      path.join('jasmine-reporters', 'ext')
      path.join('jasmine-node', 'node_modules', 'gaze')
      path.join('jasmine-node', 'spec')
      path.join('node_modules', 'nan')
      path.join('build', 'binding.Makefile')
      path.join('build', 'config.gypi')
      path.join('build', 'gyp-mac-tool')
      path.join('build', 'Makefile')
      path.join('build', 'Release', 'obj.target')
      path.join('build', 'Release', 'obj')
      path.join('build', 'Release', '.deps')
      path.join('vendor', 'apm')
      path.join('resources', 'mac')
      path.join('resources', 'win')

      # These are only require in dev mode when the grammar isn't precompiled
      path.join('atom-keymap', 'node_modules', 'loophole')
      path.join('atom-keymap', 'node_modules', 'pegjs')
      path.join('atom-keymap', 'node_modules', '.bin', 'pegjs')
      path.join('snippets', 'node_modules', 'loophole')
      path.join('snippets', 'node_modules', 'pegjs')
      path.join('snippets', 'node_modules', '.bin', 'pegjs')

      '.DS_Store'
      '.jshintrc'
      '.npmignore'
      '.pairs'
      '.travis.yml'
    ]
    ignoredPaths = ignoredPaths.map (ignoredPath) -> _.escapeRegExp(ignoredPath)

    # Add .* to avoid matching hunspell_dictionaries.
    ignoredPaths.push "#{_.escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell') + path.sep)}.*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('build', 'Release') + path.sep)}.*\\.pdb"

    # Ignore *.cc and *.h files from native modules
    ignoredPaths.push "#{_.escapeRegExp(path.join('ctags', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('git-utils', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('keytar', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('nslog', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('oniguruma', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('pathwatcher', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('runas', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('scrollbar-style', 'src') + path.sep)}.*\\.(cc|h)*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('spellchecker', 'src') + path.sep)}.*\\.(cc|h)*"

    # Ignore build files
    ignoredPaths.push "#{_.escapeRegExp(path.sep)}binding\\.gyp$"
    ignoredPaths.push "#{_.escapeRegExp(path.sep)}.+\\.target.mk$"
    ignoredPaths.push "#{_.escapeRegExp(path.sep)}linker\\.lock$"
    ignoredPaths.push "#{_.escapeRegExp(path.join('build', 'Release') + path.sep)}.+\\.node\\.dSYM"

    # Hunspell dictionaries are only not needed on OS X.
    if process.platform is 'darwin'
      ignoredPaths.push path.join('spellchecker', 'vendor', 'hunspell_dictionaries')
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"

    testFolderPattern = new RegExp("#{_.escapeRegExp(path.sep)}te?sts?#{_.escapeRegExp(path.sep)}")
    exampleFolderPattern = new RegExp("#{_.escapeRegExp(path.sep)}examples?#{_.escapeRegExp(path.sep)}")
    benchmarkFolderPattern = new RegExp("#{_.escapeRegExp(path.sep)}benchmarks?#{_.escapeRegExp(path.sep)}")

    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    filterNodeModule = (pathToCopy) ->
      return true if benchmarkFolderPattern.test(pathToCopy)

      pathToCopy = path.resolve(pathToCopy)
      nodeModulesFilter.test(pathToCopy) or testFolderPattern.test(pathToCopy) or exampleFolderPattern.test(pathToCopy)

    packageFilter = new RegExp("(#{ignoredPaths.join('|')})|(.+\\.(cson|coffee)$)")
    filterPackage = (pathToCopy) ->
      return true if benchmarkFolderPattern.test(pathToCopy)

      pathToCopy = path.resolve(pathToCopy)
      packageFilter.test(pathToCopy) or testFolderPattern.test(pathToCopy) or exampleFolderPattern.test(pathToCopy)

    for directory in nonPackageDirectories
      cp directory, path.join(appDir, directory), filter: filterNodeModule

    for directory in packageDirectories
      cp directory, path.join(appDir, directory), filter: filterPackage

    cp 'spec', path.join(appDir, 'spec')
    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee)$/
    cp 'static', path.join(appDir, 'static')
    cp 'apm', path.join(appDir, 'apm'), filter: filterNodeModule

    if process.platform is 'darwin'
      grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
        unless /.+\.plist/.test(sourcePath)
          grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    if process.platform is 'win32'
      cp path.join('resources', 'win', 'atom.cmd'), path.join(shellAppDir, 'resources', 'cli', 'atom.cmd')
      cp path.join('resources', 'win', 'atom.sh'), path.join(shellAppDir, 'resources', 'cli', 'atom.sh')
      cp path.join('resources', 'win', 'atom.js'), path.join(shellAppDir, 'resources', 'cli', 'atom.js')
      cp path.join('resources', 'win', 'apm.sh'), path.join(shellAppDir, 'resources', 'cli', 'apm.sh')

    dependencies = ['compile', 'generate-license:save', 'generate-module-cache', 'compile-packages-slug']
    dependencies.push('copy-info-plist') if process.platform is 'darwin'
    dependencies.push('set-exe-icon') if process.platform is 'win32'
    grunt.task.run(dependencies...)
