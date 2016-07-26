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
  require('time-grunt')(grunt)

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

  # Options
  [defaultChannel, releaseBranch] = getDefaultChannelAndReleaseBranch(packageJson.version)
  installDir = grunt.option('install-dir')
  buildDir = path.resolve(grunt.option('build-dir') ? 'out')
  channel = grunt.option('channel') ? defaultChannel

  metadata = packageJson
  appName = packageJson.productName
  appFileName = packageJson.name
  apmFileName = 'apm'

  if channel is 'beta'
    appName += ' Beta'
    appFileName += '-beta'
    apmFileName += '-beta'

  appName += '.app' if process.platform is 'darwin'
  shellAppDir = path.join(buildDir, appName)
  symbolsDir = path.join(buildDir, 'Atom.breakpad.syms')

  if process.platform is 'win32'
    homeDir = process.env.USERPROFILE
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= path.join(process.env.LOCALAPPDATA, appName, 'app-dev')
    killCommand = 'taskkill /F /IM atom.exe'
  else if process.platform is 'darwin'
    homeDir = process.env.HOME
    contentsDir = path.join(shellAppDir, 'Contents')
    appDir = path.join(contentsDir, 'Resources', 'app')
    installDir ?= path.join('/Applications', appName)
    killCommand = 'pkill -9 Atom'
  else
    homeDir = process.env.HOME
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    installDir ?= process.env.INSTALL_PREFIX ? '/usr/local'
    killCommand ='pkill -9 atom'

  installDir = path.resolve(installDir)
  electronDownloadDir = path.join(homeDir, '.atom', 'electron')

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
    options:
      cachePath: path.join(homeDir, '.atom', 'compile-cache', 'prebuild-less', require('less-cache/package.json').version)
    src: [
      'static/**/*.less'
    ]

  csonConfig =
    options:
      rootObject: true
      cachePath: path.join(homeDir, '.atom', 'compile-cache', 'grunt-cson')

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

  for jsFile in glob.sync("src/**/*.js")
    if usesBabel(jsFile)
      babelConfig.dist.files.push({
        src: [jsFile]
        dest: path.join(appDir, jsFile)
      })

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

  windowsInstallerConfig =

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {
      appName, channel, metadata, releaseBranch,
      appFileName, apmFileName,
      appDir, buildDir, contentsDir, installDir, shellAppDir, symbolsDir,
    }

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
        'apm/src/**/*.coffee'
      ]
      build: [
        'build/tasks/**/*.coffee'
        'build/Gruntfile.coffee'
      ]
      test: [
        'spec/*.coffee'
        'apm/spec/*.coffee'
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
      rebuild: true  # rebuild native modules after electron is updated
      token: process.env.ATOM_ACCESS_TOKEN ? 'da809a6077bb1b0aa7c5623f7b2d5f1fec2faae4'

    'create-windows-installer':
      installer:
        appDirectory: shellAppDir
        outputDirectory: path.join(buildDir, 'installer')
        authors: 'GitHub Inc.'
        loadingGif: path.resolve(__dirname, '..', 'resources', 'win', 'loading.gif')
        iconUrl: "https://raw.githubusercontent.com/atom/atom/master/resources/app-icons/#{channel}/atom.ico"
        setupIcon: path.resolve(__dirname, '..', 'resources', 'app-icons', channel, 'atom.ico')
        remoteReleases: "https://atom.io/api/updates?version=#{metadata.version}"

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

  ciTasks = []
  ciTasks.push('output-disk-space') unless process.env.CI
  ciTasks.push('download-electron')
  ciTasks.push('download-electron-chromedriver')
  ciTasks.push('build')
  ciTasks.push('fingerprint')
  ciTasks.push('dump-symbols') if process.platform is 'darwin'
  ciTasks.push('set-version', 'check-licenses', 'lint', 'generate-asar')
  ciTasks.push('mkdeb') if process.platform is 'linux'
  ciTasks.push('mktar') if process.platform is 'linux'
  ciTasks.push('test') if process.platform is 'darwin'
  ciTasks.push('codesign:app') if process.platform is 'darwin' and not process.env.CI
  if process.platform is 'win32'
    ciTasks.push('codesign:exe') if process.env.JANKY_SIGNTOOL
    ciTasks.push('codesign:installer-deferred') if not process.env.JANKY_SIGNTOOL
    ciTasks.push('create-windows-installer:installer')
    ciTasks.push('codesign:installer') if process.env.JANKY_SIGNTOOL
    ciTasks.push('codesign:cleanup')

  if process.env.ATOM_PUBLISH_REPO or not process.env.CI
    ciTasks.push('publish-build')

  grunt.registerTask('ci', ciTasks)

  defaultTasks = ['download-electron', 'download-electron-chromedriver', 'build', 'set-version', 'generate-asar']
  unless process.platform is 'linux' or grunt.option('no-install')
    defaultTasks.push 'install'
  grunt.registerTask('default', defaultTasks)
  grunt.registerTask('build-and-sign', ['download-electron', 'download-electron-chromedriver', 'build', 'set-version', 'generate-asar', 'codesign:app', 'install'])

getDefaultChannelAndReleaseBranch = (version) ->
  if version.match(/dev/) or isBuildingPR()
    channel = 'dev'
    releaseBranch = null
  else
    if version.match(/beta/)
      channel = 'beta'
    else
      channel = 'stable'

    minorVersion = version.match(/^\d\.\d/)[0]
    releaseBranch = "#{minorVersion}-releases"
  [channel, releaseBranch]

isBuildingPR = ->
  process.env.APPVEYOR_PULL_REQUEST_NUMBER? or process.env.TRAVIS_PULL_REQUEST?
