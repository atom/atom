module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  grunt.registerTask 'output-disk-space', 'Print diskspace available', ->
    return unless process.platform is 'darwin'

    done = @async()

    cmd = 'df'
    args = ['-Hl']
    spawn {cmd, args}, (error, result, code) ->
      return done(error) if error?

      lines = result.stdout.split("\n")

      for line in lines[1..]
        [filesystem, size, used, avail, capacity, extra] = line.split(/\s+/)
        capacity = parseInt(capacity)

        if capacity > 90
          grunt.log.error("#{filesystem} is at #{capacity}% capacity!")
        else if capacity > 80
          grunt.log.ok("#{filesystem} is at #{capacity}% capacity.")

      done()
