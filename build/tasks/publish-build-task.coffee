child_process = require 'child_process'
path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
fs = require 'fs-plus'
GitHub = require 'github-releases'
request = require 'request'

grunt = null

commitSha = process.env.JANKY_SHA1
token = process.env.ATOM_ACCESS_TOKEN
defaultHeaders =
  Authorization: "token #{token}"
  'User-Agent': 'Atom'

module.exports = (gruntObject) ->
  grunt = gruntObject
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'publish-build', 'Publish the built app', ->
    return if process.env.JANKY_SHA1 and process.env.JANKY_BRANCH isnt 'master'
    tasks = ['upload-assets']
    tasks.unshift('build-docs', 'prepare-docs') if process.platform is 'darwin'
    grunt.task.run(tasks)

  grunt.registerTask 'prepare-docs', 'Move api.json to atom-api.json', ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    buildDir = grunt.config.get('atom.buildDir')
    cp  path.join(docsOutputDir, 'api.json'), path.join(buildDir, 'atom-api.json')

  grunt.registerTask 'upload-assets', 'Upload the assets to a GitHub release', ->
    done = @async()
    buildDir = grunt.config.get('atom.buildDir')
    assets = getAssets()

    zipAssets buildDir, assets, (error) ->
      return done(error) if error?
      getAtomDraftRelease (error, release) ->
        return done(error) if error?
        assetNames = (asset.assetName for asset in assets)
        deleteExistingAssets release, assetNames, (error) ->
          return done(error) if error?
          uploadAssets(release, buildDir, assets, done)

getAssets = ->
  if process.platform is 'darwin'
    [
      {assetName: 'atom-mac.zip', sourcePath: 'Atom.app'}
      {assetName: 'atom-mac-symbols.zip', sourcePath: 'Atom.breakpad.syms'}
      {assetName: 'atom-api.json', sourcePath: 'atom-api.json'}
    ]
  else
    [
      {assetName: 'atom-windows.zip', sourcePath: 'Atom'}
    ]

logError = (message, error, details) ->
  grunt.log.error(message)
  grunt.log.error(error.message ? error) if error?
  grunt.log.error(details) if details

zipAssets = (buildDir, assets, callback) ->
  zip = (directory, sourcePath, assetName, callback) ->
    if process.platform is 'win32'
      zipCommand = "C:/psmodules/7z.exe a -r #{assetName} #{sourcePath}"
    else
      zipCommand = "zip -r --symlinks #{assetName} #{sourcePath}"
    options = {cwd: directory, maxBuffer: Infinity}
    child_process.exec zipCommand, options, (error, stdout, stderr) ->
      logError("Zipping #{sourcePath} failed", error, stderr) if error?
      callback(error)

  tasks = []
  for {assetName, sourcePath} in assets when path.extname(assetName) is '.zip'
    fs.removeSync(path.join(buildDir, assetName))
    tasks.push(zip.bind(this, buildDir, sourcePath, assetName))
  async.parallel(tasks, callback)

getAtomDraftRelease = (callback) ->
  atomRepo = new GitHub({repo: 'atom/atom', token})
  atomRepo.getReleases (error, releases=[]) ->
    if error?
      logError('Fetching atom/atom releases failed', error, releases)
      callback(error)
    else
      for release in releases when release.draft
        callback(null, release)
        return
      callback(new Error('No draft release in atom/atom repo'))

deleteRelease = (release) ->
  options =
    uri: release.url
    method: 'DELETE'
    headers: defaultHeaders
    json: true
  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 204
      logError('Deleting release failed', error, body)

deleteExistingAssets = (release, assetNames, callback) ->
  [callback, assetNames] = [assetNames, callback] if not callback?

  deleteAsset = (url, callback) ->
    options =
      uri: url
      method: 'DELETE'
      headers: defaultHeaders
    request options, (error, response, body='') ->
      if error? or response.statusCode isnt 204
        logError('Deleting existing release asset failed', error, body)
        callback(error ? new Error(response.statusCode))
      else
        callback()

  tasks = []
  for asset in release.assets when not assetNames? or asset.name in assetNames
    tasks.push(deleteAsset.bind(this, asset.url))
  async.parallel(tasks, callback)

uploadAssets = (release, buildDir, assets, callback) ->
  upload = (release, assetName, assetPath, callback) ->
    options =
      uri: release.upload_url.replace(/\{.*$/, "?name=#{assetName}")
      method: 'POST'
      headers: _.extend({
        'Content-Type': 'application/zip'
        'Content-Length': fs.getSizeSync(assetPath)
        }, defaultHeaders)

    assetRequest = request options, (error, response, body='') ->
      if error? or response.statusCode >= 400
        logError("Upload release asset #{assetName} failed", error, body)
        callback(error ? new Error(response.statusCode))
      else
        callback(null, release)

    fs.createReadStream(assetPath).pipe(assetRequest)

  tasks = []
  for {assetName} in assets
    assetPath = path.join(buildDir, assetName)
    tasks.push(upload.bind(this, release, assetName, assetPath))
  async.parallel(tasks, callback)
