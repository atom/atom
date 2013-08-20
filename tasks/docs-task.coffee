path = require 'path'

module.exports = (grunt) ->
  cmd = path.join('node_modules', '.bin', 'coffee')
  commonArgs = [path.join('node_modules', '.bin', 'biscotto'), '--']
  opts =
    stdio: 'inherit'

  grunt.registerTask 'build-docs', 'Builds the API docs in src/app', ->
    done = @async()
    args = [commonArgs..., '-o', 'docs/output/api', 'src/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'lint-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', 'src/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'missing-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', '--missing', 'src/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'deploy-docs', 'Publishes latest API docs to atom-docs.githubapp.com', ->
    done = @async()

    fetchTag = (args..., callback) ->
      cmd = 'git'
      args = ['describe', '--abbrev=0', '--tags']
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, String(result).trim())

    copyApiDocs = (tag, callback) ->
      cmd = 'cp'
      args = ['-r', 'docs/output/', "../atom-docs/public/#{tag}/"]
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, tag)

    docsRepoArgs = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/']

    stageDocs = (tag, callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'add', "public/#{tag}"]
      grunt.util.spawn({cmd, args, opts}, callback)

    fetchSha = (args..., callback) ->
      cmd = 'git'
      args = ['rev-parse', 'HEAD']
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, String(result).trim())

    commitChanges = (sha, callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'commit', "-m Update API docs to #{sha}"]
      grunt.util.spawn({cmd, args, opts}, callback)

    pushOrigin = (args..., callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'push', 'origin', 'master']
      grunt.util.spawn({cmd, args, opts}, callback)

    pushHeroku = (args..., callback) ->
      cmd = 'git'
      args = [docsRepoArgs..., 'push', 'heroku', 'master']
      grunt.util.spawn({cmd, args, opts}, callback)

    grunt.util.async.waterfall [fetchTag, copyApiDocs, stageDocs, fetchSha, commitChanges, pushOrigin, pushHeroku], done
