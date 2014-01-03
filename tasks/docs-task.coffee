path = require 'path'
fs = require 'fs'

module.exports = (grunt) ->
  cmd = path.join('node_modules', '.bin', 'coffee')
  commonArgs = [path.join('node_modules', '.bin', 'biscotto'), '--']
  opts =
    stdio: 'inherit'

  grunt.registerTask 'build-docs', 'Builds the API docs in src/app', ->
    done = @async()
    args = [commonArgs..., '--title', 'Atom API Documentation', '-o', 'docs/output/api', 'src/', '../text-buffer/src/range.coffee', '../text-buffer/src/point.coffee', '../text-buffer/src/marker.coffee']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'lint-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', 'src/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'missing-docs', 'Generate stats about the doc coverage', ->
    done = @async()
    args = [commonArgs..., '--noOutput', '--missing', 'src/']
    grunt.util.spawn({cmd, args, opts}, done)

  grunt.registerTask 'copy-docs', 'Copies over latest API docs to atom-docs', ->
    done = @async()

    fetchTag = (args..., callback) ->
      cmd = 'git'
      args = ['describe', '--abbrev=0', '--tags']
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, String(result).trim())

    copyDocs = (tag, callback) ->
      cmd = 'cp'
      args = ['-r', 'docs/output/', "../atom.io/public/docs/api/#{tag}/"]

      fs.exists "../atom.io/public/docs/api/", (exists) ->
        if exists
          grunt.util.spawn {cmd, args}, (error, result) ->
            if error?
              callback(error)
            else
              callback(null, tag)
        else
          grunt.log.error "../atom.io/public/docs/api/ doesn't exist"
          return false

    grunt.util.async.waterfall [fetchTag, copyDocs], done

  grunt.registerTask 'deploy-docs', 'Publishes latest API docs to atom-docs.githubapp.com', ->
    done = @async()
    docsRepoArgs = ['--work-tree=../atom-docs/', '--git-dir=../atom-docs/.git/']

    fetchTag = (args..., callback) ->
      cmd = 'git'
      args = ['describe', '--abbrev=0', '--tags']
      grunt.util.spawn {cmd, args}, (error, result) ->
        if error?
          callback(error)
        else
          callback(null, String(result).trim().split('.')[0..1].join('.'))

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

    grunt.util.async.waterfall [fetchTag, stageDocs, fetchSha, commitChanges, pushOrigin, pushHeroku], done
