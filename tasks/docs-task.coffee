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

  grunt.registerTask 'deploy-docs', 'Publishes latest API docs to atom-docs.githubapp.com', ->
    done = @async()

    pushHeroku = (error, result, code) ->
      sha = String(result).trim()
      cmd = 'git'
      args = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/', 'push', 'heroku', 'master']
      grunt.util.spawn({cmd, args, opts}, done)

    pushOrigin = (error, result, code) ->
      sha = String(result).trim()
      cmd = 'git'
      args = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/', 'push', 'origin', 'master']
      grunt.util.spawn({cmd, args, opts}, pushHeroku)

    commitChanges = (error, result, code) ->
      sha = String(result).trim()
      cmd = 'git'
      args = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/', 'commit', '-a', "-m Update API docs to #{sha}"]
      grunt.util.spawn({cmd, args, opts}, pushOrigin)

    fetchSha = (error, result, code) ->
      cmd = 'git'
      args = ['rev-parse', 'HEAD']
      grunt.util.spawn({cmd, args}, commitChanges)

    cmd = 'cp'
    args = ['-r', 'docs/api', '../atom-docs/public/']
    grunt.util.spawn {cmd, args, opts}, fetchSha
