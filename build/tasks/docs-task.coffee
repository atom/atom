path = require 'path'

async = require 'async'
fs = require 'fs-plus'
request = require 'request'
_ = require 'underscore-plus'

donna = require 'donna'
tello = require 'tello'

module.exports = (grunt) ->
  {rm} = require('./task-helpers')(grunt)

  opts = stdio: 'inherit'

  getClassesToInclude = ->
    modulesPath = path.resolve(__dirname, '..', '..', 'node_modules')
    classes = {}
    fs.traverseTreeSync modulesPath, (modulePath) ->
      return true unless path.basename(modulePath) is 'package.json' and fs.isFileSync(modulePath)

      apiPath = path.join(path.dirname(modulePath), 'api.json')
      if fs.isFileSync(apiPath)
        _.extend(classes, grunt.file.readJSON(apiPath).classes)
      true
    classes

  grunt.registerTask 'build-docs', 'Builds the API docs in src', ->
    done = @async()
    docsOutputDir = grunt.config.get('docsOutputDir')
    downloadIncludes (error, includedModules) ->
      metadata = donna.generateMetadata(['.'].concat(includedModules))
      telloJson = _.extend(tello.digest(metadata), getClassesToInclude())

      files = [{
        filePath: path.join(docsOutputDir, 'donna.json')
        contents: JSON.stringify(metadata, null, '  ')
      }, {
        filePath: path.join(docsOutputDir, 'tello.json')
        contents: JSON.stringify(telloJson, null, '  ')
      }]

      writeFile = ({filePath, contents}, callback) ->
        fs.writeFile filePath, contents, (error) ->
          callback(error)

      async.map files, writeFile, -> done()

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

downloadFileFromRepo = ({repo, file}, callback) ->
  uri = "https://raw.github.com/atom/#{repo}/master/#{file}"
  request uri, (error, response, contents) ->
    return callback(error) if error?
    downloadPath = path.join('docs', 'includes', repo, file)
    fs.writeFile downloadPath, contents, (error) ->
      callback(error, downloadPath)



downloadIncludes = (callback) ->
  includes = [
    {repo: 'first-mate',  file: 'src/grammar.coffee'}
    {repo: 'first-mate',  file: 'src/grammar-registry.coffee'}
    {repo: 'first-mate',  file: 'package.json'}
    {repo: 'node-pathwatcher', file: 'src/directory.coffee'}
    {repo: 'node-pathwatcher', file: 'src/file.coffee'}
    {repo: 'node-pathwatcher', file: 'package.json'}
    {repo: 'space-pen',   file: 'src/space-pen.coffee'}
    {repo: 'space-pen',   file: 'package.json'}
    {repo: 'text-buffer', file: 'src/marker.coffee'}
    {repo: 'text-buffer', file: 'src/point.coffee'}
    {repo: 'text-buffer', file: 'src/range.coffee'}
    {repo: 'text-buffer', file: 'src/text-buffer.coffee'}
    {repo: 'text-buffer', file: 'package.json'}
    {repo: 'theorist',    file: 'src/model.coffee'}
    {repo: 'theorist',    file: 'package.json'}
  ]

  async.map includes, downloadFileFromRepo, (error, allPaths) ->
    includeDirectories = null
    if allPaths?
      includeDirectories = _.unique allPaths.map (dir) -> /^docs\/includes\/[a-z-]+/.exec(dir)[0]
    callback(error, includeDirectories)
