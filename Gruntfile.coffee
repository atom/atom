fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  appName = 'Atom.app'
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
        'static/**/*.coffee'
      ]
      dest: appDir
      ext: '.js'

  lessConfig =
    options:
      paths: [
        'static'
        'vendor'
      ]
    glob_to_multiple:
      expand: true
      src: [
        'src/**/*.less'
        'static/**/*.less'
        'themes/**/*.less'
      ]
      dest: appDir
      ext: '.css'

  csonConfig =
    options:
      rootObject: true
    glob_to_multiple:
      expand: true
      src: [
        'keymaps/*.cson'
        'src/**/*.cson'
        'static/**/*.cson'
        'themes/**/*.cson'
      ]
      dest: appDir
      ext: '.json'

  for child in fs.readdirSync('node_modules') when child isnt '.bin'
    directory = path.join('node_modules', child)
    {engines} = grunt.file.readJSON(path.join(directory, 'package.json'))
    if engines?.atom?
      coffeeConfig.glob_to_multiple.src.push("#{directory}/**/*.coffee")
      lessConfig.glob_to_multiple.src.push("#{directory}/**/*.less")
      csonConfig.glob_to_multiple.src.push("#{directory}/**/*.cson")

  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    atom: {appDir, appName, buildDir, contentsDir, installDir, shellAppDir}

    coffee: coffeeConfig

    less: lessConfig

    cson: csonConfig

    coffeelint:
      options:
        no_empty_param_list:
          level: 'error'
        max_line_length:
          level: 'ignore'
      src: [
        'dot-atom/**/*.coffee'
        'src/**/*.coffee'
      ]
      test: [
        'spec/*.coffee'
        'spec/app/**/*.coffee'
        'spec/stdlib/**/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
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
        'src/**/*.css',
        'static/**/*.css'
        'themes/**/*.css'
      ]

    lesslint:
      src: [
        'src/**/*.less',
        'static/**/*.less'
        'themes/**/*.less'
      ]

    markdown:
      guides:
        files: [
          expand: true,
          cwd: 'docs'
          src: '**/*.md',
          dest: 'docs/guides/',
          ext: '.html'
        ]
        markdownOptions:
          gfm: true

  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-lesslint')
  grunt.loadNpmTasks('grunt-cson')
  grunt.loadNpmTasks('grunt-contrib-csslint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-markdown')
  grunt.loadTasks('tasks')

  grunt.registerTask('compile', ['coffee', 'less', 'cson'])
  grunt.registerTask('lint', ['coffeelint', 'csslint', 'lesslint'])
  grunt.registerTask('ci', ['lint', 'partial-clean', 'update-atom-shell', 'build', 'set-development-version', 'test'])
  grunt.registerTask('deploy', ['partial-clean', 'update-atom-shell', 'build', 'codesign'])
  grunt.registerTask('docs', ['markdown:guides', 'build-docs'])
  grunt.registerTask('default', ['update-atom-shell', 'build', 'set-development-version', 'install'])
