fs = require 'fs'
path = require 'path'
os = require 'os'

# Add support for obselete APIs of vm module so we can make some third-party
# modules work under node v0.11.x.
require 'vm-compatibility-layer'

_ = require 'underscore-plus'

packageJson = require '../package.json'

# Shim harmony collections in case grunt was invoked without harmony
# collections enabled
_.extend(global, require('harmony-collections')) unless global.WeakMap?

module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadNpmTasks('grunt-download-atom-shell')
  grunt.loadNpmTasks('grunt-atom-shell-installer')
  grunt.loadNpmTasks('grunt-peg')
  grunt.loadTasks('tasks')

  # This allows all subsequent paths to the relative to the root of the repo
  grunt.file.setBase(path.resolve('..'))

  if not grunt.option('verbose')
    grunt.log.writeln = (args...) -> grunt.log
    grunt.log.write = (args...) -> grunt.log

  [major, minor, patch] = packageJson.version.split('.')
  tmpDir = os.tmpdir()
  appName = if process.platform is 'darwin' then 'Atom.app' else 'Atom'
  buildDir = grunt.option('build-dir') ? path.join(tmpDir, 'atom-build')
  buildDir = path.resolve(buildDir)
  installDir = grunt.option('install-dir')

  home = if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME
  atomShellDownloadDir = path.join(home, '.atom', 'atom-shell')

  symbolsDir = path.join(buildDir, 'Atom.breakpad.syms')
  shellAppDir = path.join(buildDir, appName)
  if process.platform is 'win32'
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= path.join(process.env.ProgramFiles, appName)
    killCommand = 'taskkill /F /IM atom.exe'
  else if process.platform is 'darwin'
    contentsDir = path.join(shellAppDir, 'Contents')
    appDir = path.join(contentsDir, 'Resources', 'app')
    installDir ?= path.join('/Applications', appName)
    killCommand = 'pkill -9 Atom'
  else
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= process.env.INSTALL_PREFIX ? '/usr/local'
    killCommand ='pkill -9 atom'

  installDir = path.resolve(installDir)

  coffeeConfig =
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.coffee'
        'exports/**/*.coffee'
        'static/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  lessConfig =
    options:
      paths: [
        'static/variables'
        'static'
      ]
    glob_to_multiple:
      expand: true
      src: [
        'static/**/*.less'
      ]
      dest: appDir
      ext: '.css'

  prebuildLessConfig =
    src: [
      'static/**/*.less'
      'node_modules/bootstrap/less/bootstrap.less'
    ]

  csonConfig =
    options:
      rootObject: true
      cachePath: path.join(home, '.atom', 'compile-cache', 'grunt-cson')

    glob_to_multiple:
      expand: true
      src: [
        'menus/*.cson'
        'keymaps/*.cson'
        'static/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  pegConfig =
    glob_to_multiple:
      expand: true
      src: ['src/**/*.pegjs']
      dest: appDir
      ext: '.js'

  for child in fs.readdirSync('node_modules') when child isnt '.bin'
    directory = path.join('node_modules', child)
    metadataPath = path.join(directory, 'package.json')
    continue unless grunt.file.isFile(metadataPath)

    {engines, theme} = grunt.file.readJSON(metadataPath)
    if engines?.atom?
      coffeeConfig.glob_to_multiple.src.push("#{directory}/**/*.coffee")
      lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
      prebuildLessConfig.src.push("#{directory}/**/*.less") unless theme
      csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")
      pegConfig.glob_to_multiple.src.push("#{directory}/**/*.pegjs")

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {appDir, appName, symbolsDir, buildDir, contentsDir, installDir, shellAppDir}

    docsOutputDir: 'docs/output'

    coffee: coffeeConfig

    less: lessConfig

    'prebuild-less': prebuildLessConfig

    cson: csonConfig

    peg: pegConfig

    coffeelint:
      options:
        configFile: 'coffeelint.json'
      src: [
        'dot-atom/**/*.coffee'
        'exports/**/*.coffee'
        'src/**/*.coffee'
      ]
      build: [
        'build/tasks/**/*.coffee'
        'build/Gruntfile.coffee'
      ]
      test: [
        'spec/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
        'duplicate-background-images': false
        'box-model': false
        'box-sizing': false
        'bulletproof-font-face': false
        'compatible-vendor-prefixes': false
        'display-property-grouping': false
        'fallback-colors': false
        'font-sizes': false
        'gradients': false
        'ids': false
        'important': false
        'known-properties': false
        'outline-none': false
        'overqualified-elements': false
        'qualified-headings': false
        'unique-headings': false
        'universal-selector': false
        'vendor-prefix': false
      src: [
        'static/**/*.css'
      ]

    lesslint:
      src: [
        'static/**/*.less'
      ]

    'download-atom-shell':
      version: packageJson.atomShellVersion
      outputDir: 'atom-shell'
      downloadDir: atomShellDownloadDir
      rebuild: true  # rebuild native modules after atom-shell is updated
      token: process.env.ATOM_ACCESS_TOKEN

    'create-windows-installer':
      appDirectory: shellAppDir
      outputDirectory: path.join(buildDir, 'installer')
      authors: 'GitHub Inc.'
      loadingGif: path.resolve(__dirname, '..', 'resources', 'win', 'loading.gif')
      iconUrl: 'https://raw.githubusercontent.com/atom/atom/master/resources/win/atom.ico'
      setupIcon: path.resolve(__dirname, '..', 'resources', 'win', 'atom.ico')

    shell:
      'kill-atom':
        command: killCommand
        options:
          stdout: false
          stderr: false
          failOnError: false

  grunt.registerTask('compile', ['coffee', 'prebuild-less', 'cson', 'peg'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('test', ['shell:kill-atom', 'run-specs'])
  grunt.registerTask('docs', ['markdown:guides', 'build-docs'])

  ciTasks = ['output-disk-space', 'download-atom-shell', 'build']
  ciTasks.push('dump-symbols') if process.platform isnt 'win32'
  ciTasks.push('set-version', 'check-licenses', 'lint')
  ciTasks.push('mkdeb') if process.platform is 'linux'
  ciTasks.push('create-windows-installer') if process.platform is 'win32'
  ciTasks.push('test') if process.platform is 'darwin'
  ciTasks.push('codesign')
  ciTasks.push('publish-build')
  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-atom-shell', 'build', 'set-version']
  defaultTasks.push 'install' unless process.platform is 'linux'
  grunt.registerTask('default', defaultTasks)
