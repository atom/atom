fs = require 'fs'
path = require 'path'
os = require 'os'

fm = require 'json-front-matter'
_ = require 'underscore-plus'

packageJson = require './package.json'

# OAuth token for atom-bot
# TODO Remove once all repositories are public
process.env.ATOM_ACCESS_TOKEN ?= '362295be4c5258d3f7b967bbabae662a455ca2a7'

# Shim harmony collections in case grunt was invoked without harmony
# collections enabled
_.extend(global, require('harmony-collections')) unless global.WeakMap?

module.exports = (grunt) ->
  if not grunt.option('verbose')
    grunt.log.writeln = (args...) -> grunt.log
    grunt.log.write = (args...) -> grunt.log

  [major, minor, patch] = packageJson.version.split('.')
  if process.platform is 'win32'
    appName = 'Atom'
    tmpDir = os.tmpdir()
    installRoot = process.env.ProgramFiles
    buildDir = grunt.option('build-dir') ? path.join(tmpDir, 'atom-build')
    shellAppDir = path.join(buildDir, appName)
    contentsDir = shellAppDir
    appDir = path.join(shellAppDir, 'resources', 'app')
    atomShellDownloadDir = path.join(os.tmpdir(), 'atom-cached-atom-shells')
  else
    appName = 'Atom.app'
    tmpDir = '/tmp'
    installRoot = '/Applications'
    buildDir = grunt.option('build-dir') ? path.join(tmpDir, 'atom-build')
    shellAppDir = path.join(buildDir, appName)
    contentsDir = path.join(shellAppDir, 'Contents')
    appDir = path.join(contentsDir, 'Resources', 'app')
    atomShellDownloadDir = '/tmp/atom-cached-atom-shells'

  installDir = path.join(installRoot, appName)

  coffeeConfig =
    options:
      sourceMap: true
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
    glob_to_multiple:
      expand: true
      src: [
        'menus/*.cson'
        'keymaps/*.cson'
        'static/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  for child in fs.readdirSync('node_modules') when child isnt '.bin'
    directory = path.join('node_modules', child)
    {engines, theme} = grunt.file.readJSON(path.join(directory, 'package.json'))
    if engines?.atom?
      coffeeConfig.glob_to_multiple.src.push("#{directory}/**/*.coffee")
      lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
      prebuildLessConfig.src.push("#{directory}/**/*.less") unless theme
      csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {appDir, appName, buildDir, contentsDir, installDir, shellAppDir}

    coffee: coffeeConfig

    less: lessConfig

    'prebuild-less': prebuildLessConfig

    cson: csonConfig

    coffeelint:
      options:
        no_empty_param_list:
          level: 'error'
        max_line_length:
          level: 'ignore'
        indentation:
          level: 'ignore'
      src: [
        'dot-atom/**/*.coffee'
        'exports/**/*.coffee'
        'src/**/*.coffee'
        'tasks/**/*.coffee'
        'Gruntfile.coffee'
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

    markdown:
      guides:
        files: [
          expand: true
          cwd: 'docs'
          src: '**/*.md'
          dest: 'docs/output/'
          ext: '.html'
        ]
        options:
          template: 'docs/template.jst'
          templateContext:
            tag: "v#{major}.#{minor}"
          markdownOptions:
            gfm: true
          preCompile: (src, context) ->
            parsed = fm.parse(src)
            _.extend(context, parsed.attributes)
            parsed.body

    'download-atom-shell':
      version: packageJson.atomShellVersion
      outputDir: 'atom-shell'
      downloadDir: atomShellDownloadDir
      rebuild: true  # rebuild native modules after atom-shell is updated

    shell:
      'kill-atom':
        command: 'pkill -9 Atom'
        options:
          stdout: false
          stderr: false
          failOnError: false

  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-markdown')
  grunt.loadNpmTasks('grunt-download-atom-shell')
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadTasks('tasks')

  grunt.registerTask('compile', ['coffee', 'prebuild-less', 'cson'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('test', ['shell:kill-atom', 'run-specs'])
  grunt.registerTask('ci', ['download-atom-shell', 'build', 'set-development-version', 'lint', 'test'])
  grunt.registerTask('deploy', ['partial-clean', 'download-atom-shell', 'build', 'codesign'])
  grunt.registerTask('docs', ['markdown:guides', 'build-docs'])
  grunt.registerTask('default', ['download-atom-shell', 'build', 'set-development-version', 'install'])
