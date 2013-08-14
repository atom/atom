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

    copyDocs = (args..., callback) ->
      cmd = 'cp'
      args = ['-r', 'docs/api', '../atom-docs/public/']
      grunt.util.spawn({cmd, args, opts}, callback)

    fetchSha = (args..., callback) ->
      cmd = 'git'
      args = ['rev-parse', 'HEAD']
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, String(result).trim())

    docsRepoArgs = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/']

    commitChanges = (sha, callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'commit', '-a', "-m Update API docs to #{sha}"]
      grunt.util.spawn({cmd, args, opts}, callback)

    pushOrigin = (args..., callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'push', 'origin', 'master']
      grunt.util.spawn({cmd, args, opts}, callback)

    pushHeroku = (args..., callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'push', 'heroku', 'master']
      grunt.util.spawn({cmd, args, opts}, callback)

    grunt.util.async.waterfall [copyDocs, fetchSha, commitChanges, pushOrigin, pushHeroku], done
