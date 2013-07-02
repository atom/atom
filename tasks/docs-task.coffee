path = require 'path'

module.exports = (grunt) ->
  cmd = path.join('node_modules', '.bin', 'coffee')
  commonArgs = [path.join('node_modules', '.bin', 'biscotto'), '--']
  opts =
    stdio: 'inherit'

  grunt.registerTask 'build-docs', 'Builds the API docs in src/app', ->
    done = @async()
    args = [commonArgs..., '-o', 'docs/api', 'src/app/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'lint-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', 'src/app/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'missing-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', '--missing', 'src/app/']
    grunt.util.spawn({cmd, args, opts}, done)
