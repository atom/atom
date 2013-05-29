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


  grunt.loadNpmTasks('grunt-coffeelint')

  grunt.registerTask('lint', ['coffeelint:src', 'coffeelint:test'])
  grunt.registerTask('default', 'lint')
