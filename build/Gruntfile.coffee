fs = require 'fs'
path = require 'path'
os = require 'os'
glob = require 'glob'
usesBabel = require './lib/uses-babel'
babelOptions = require '../static/babelrc'

# Add support for obselete APIs of vm module so we can make some third-party
# modules work under node v0.11.x.
require 'vm-compatibility-layer'

_ = require 'underscore-plus'

packageJson = require '../package.json'

module.exports = (grunt) ->
  grunt.loadNpmTasks('grunt-babel')
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-standard')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadNpmTasks('grunt-download-electron')
  grunt.loadNpmTasks('grunt-electron-installer')
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
  electronDownloadDir = path.join(home, '.atom', 'electron')

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
        'spec/*.coffee'
        '!spec/*-spec.coffee'
        'exports/**/*.coffee'
        'static/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  babelConfig =
    options: babelOptions
    dist:
      files: []

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
      'node_modules/atom-space-pen-views/stylesheets/**/*.less'
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
      coffeeConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.coffee")

      lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
      lessConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.less")

      unless theme
        prebuildLessConfig.src.push("#{directory}/**/*.less")
        prebuildLessConfig.src.push("!#{directory}/spec/**/*.less")

      csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")
      csonConfig.glob_to_multiple.src.push("!#{directory}/spec/**/*.cson")

      pegConfig.glob_to_multiple.src.push("#{directory}/lib/*.pegjs")

      for jsFile in glob.sync("#{directory}/lib/**/*.js")
        if usesBabel(jsFile)
          babelConfig.dist.files.push({
            src: [jsFile]
            dest: path.join(appDir, jsFile)
          })

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {appDir, appName, symbolsDir, buildDir, contentsDir, installDir, shellAppDir}

    docsOutputDir: 'docs/output'

    babel: babelConfig

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

    standard:
      src: [
        'src/**/*.js'
        'static/*.js'
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

    'download-electron':
      version: packageJson.electronVersion
      outputDir: 'electron'
      downloadDir: electronDownloadDir
      rebuild: true  # rebuild native modules after atom-shell is updated
      token: process.env.ATOM_ACCESS_TOKEN

    'create-windows-installer':
      installer:
        appDirectory: shellAppDir
        outputDirectory: path.join(buildDir, 'installer')
        authors: 'GitHub Inc.'
        loadingGif: path.resolve(__dirname, '..', 'resources', 'win', 'loading.gif')
        iconUrl: 'https://raw.githubusercontent.com/atom/atom/master/resources/win/atom.ico'
        setupIcon: path.resolve(__dirname, '..', 'resources', 'win', 'atom.ico')
        remoteReleases: 'https://atom.io/api/updates'

    shell:
      'kill-atom':
        command: killCommand
        options:
          stdout: false
          stderr: false
          failOnError: false

  grunt.registerTask('compile', ['babel', 'coffee', 'prebuild-less', 'cson', 'peg'])
  grunt.registerTask('lint', ['standard', 'coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('test', ['shell:kill-atom', 'run-specs'])

  ciTasks = ['output-disk-space', 'download-electron', 'download-electron-chromedriver', 'build']
  ciTasks.push('dump-symbols') if process.platform isnt 'win32'
  ciTasks.push('set-version', 'check-licenses', 'lint', 'generate-asar')
  ciTasks.push('mkdeb') if process.platform is 'linux'
  ciTasks.push('codesign:exe') if process.platform is 'win32' and not process.env.TRAVIS
  ciTasks.push('create-windows-installer:installer') if process.platform is 'win32'
  ciTasks.push('test') if process.platform is 'darwin'
  ciTasks.push('codesign:installer') if process.platform is 'win32' and not process.env.TRAVIS
  ciTasks.push('codesign:app') if process.platform is 'darwin' and not process.env.TRAVIS
  ciTasks.push('publish-build') unless process.env.TRAVIS
  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-electron', 'download-electron-chromedriver', 'build', 'set-version', 'generate-asar']
  defaultTasks.push 'install' unless process.platform is 'linux'
  grunt.registerTask('default', defaultTasks)
