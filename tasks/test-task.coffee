path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'test', 'Run the specs', ->
    done = @async()
    commands = []
    commands.push (callback) ->
      spawn cmd: 'pkill', args: ['Atom'], -> callback()
    commands.push (callback) ->
      atomBinary = path.join(grunt.config.get('atom.contentsDir'), 'MacOS', 'Atom')
      resourcePath = path.resolve(__dirname, '..')
      spawn cmd: atomBinary, args: ['--test', "--resource-path=#{resourcePath}"], (error) ->  callback(error)
    grunt.util.async.waterfall commands, (error) -> done(error)
