module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    coffeelint:
      options:
        max_line_length:
          level: 'ignore'

      src: ['src/**/*.coffee']
      test: [
        'spec/*.coffee'
        'spec/app/**/*.coffee'
        'spec/stdlib/**/*.coffee'
      ]

    csslint:
      options:
        'adjoining-classes': false
        'fallback-colors': false
      src: ['themes/**/*.css', 'src/**/*.css']

  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-contrib-csslint')

  grunt.registerTask('lint', ['coffeelint:src', 'coffeelint:test', 'csslint:src'])
  grunt.registerTask('default', 'lint')
