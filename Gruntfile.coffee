fs = require 'fs'
path = require 'path'

fm = require 'json-front-matter'
_ = require 'underscore'

packageJson = require './package.json'

module.exports = (grunt) ->
  appName = 'Atom.app'
  [major, minor, patch] = packageJson.version.split('.')
  buildDir = grunt.option('build-dir') ? '/tmp/atom-build'
  shellAppDir = path.join(buildDir, appName)
  contentsDir = path.join(shellAppDir, 'Contents')
  appDir = path.join(contentsDir, 'Resources', 'app')
  installDir = path.join('/Applications', appName)

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
  grunt.loadNpmTasks('grunt-shell')
  grunt.loadTasks('tasks')

  grunt.registerTask('compile', ['coffee', 'prebuild-less', 'cson'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('test', ['shell:kill-atom', 'run-core-specs', 'run-specs'])
  grunt.registerTask('ci', ['lint', 'update-atom-shell', 'build', 'set-development-version', 'test'])
  grunt.registerTask('deploy', ['partial-clean', 'update-atom-shell', 'build', 'codesign'])
  grunt.registerTask('docs', ['markdown:guides', 'build-docs'])
  grunt.registerTask('default', ['update-atom-shell', 'build', 'set-development-version', 'install'])
