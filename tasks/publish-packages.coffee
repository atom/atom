async = require 'async'
request = require 'request'

# Configure and publish all packages in package.json to atom.io
#
# This task should be run whenever you want to be sure that atom.io contains
# all the packages and versions referenced in Atom's package.json file.
module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  baseUrl = "https://www.atom.io/api/packages"

  packageExists = (packageName, token, callback) ->
    requestSettings =
      url: "#{baseUrl}/#{packageName}"
      json: true
      headers:
        authorization: token
    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback(error)
      else
        callback(null, response.statusCode is 404)

  createPackage = (packageName, token, callback) ->
    requestSettings =
      url: baseUrl
      json: true
      headers:
        authorization: token
      method: 'POST'
      body:
        repository: "atom/#{packageName}"

    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback(error)
      else if response.statusCode isnt 201
        message = body.message ? body.error ? body
        callback(new Error("Creating package failed: #{message}"))
      else
        callback()

  createPackageVersion = (packageName, tag, token, callback) ->
    requestSettings =
      url: "#{baseUrl}/#{packageName}/versions"
      json: true
      method: 'POST'
      headers:
        authorization: token
      body:
        tag: tag

    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback(error)
      else if response.statusCode isnt 201
        message = body.message ? body.error ? body
        if message is 'Version exists'
          callback()
        else
          callback(new Error("Creating new version failed: #{message}"))
      else
        callback()

  getToken = (callback) ->
    if token = process.env.ATOM_ACCESS_TOKEN
      callback(null, token)
    else
      spawn {cmd: 'security', args: ['-q', 'find-generic-password', '-ws', 'GitHub API Token']}, (error, result, code) ->
        token = result.toString() unless error?
        callback(error, token)

  grunt.registerTask 'publish-packages', 'Publish all bundled packages', ->
    done = @async()

    getToken (error, token) ->
      unless token
        grunt.log.error('Token not found in keychain or ATOM_ACCESS_TOKEN environment variable')
        done(false)

      {packageDependencies} = grunt.file.readJSON('package.json') ? {}
      tasks = []
      for name, version of packageDependencies
        do (name, version) ->
          tasks.push (callback) ->
            grunt.verbose.writeln("Publishing #{name}@#{version}")
            tag = "v#{version}"
            packageExists name, token, (error, exists) ->
              if error?
                callback(error)
                return

              if exists
                createPackage name, token, (error) ->
                  if error?
                    callback(error)
                  else
                    createPackageVersion(name, tag, token, callback)
              else
                createPackageVersion(name, tag, token, callback)

      async.waterfall tasks, (error) ->
        if error?
          grunt.log.error(error.message)
          done(false)
        else
          done()
