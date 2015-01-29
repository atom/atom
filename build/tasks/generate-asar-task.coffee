asar = require 'asar'
path = require 'path'

module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'generate-asar', 'Generate asar archive for the app', ->
    done = @async()

    appDir = grunt.config.get('atom.appDir')
    asar.createPackage appDir, path.resolve(appDir, '..', 'app.asar'), (err) ->
      return done(err) if err?
      rm appDir
      done()
