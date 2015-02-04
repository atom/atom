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
    tasks = []
    tasks.push('build-docs', 'prepare-docs') if process.platform is 'darwin'
    tasks.push('upload-assets') if process.env.JANKY_SHA1 and process.env.JANKY_BRANCH is 'master'
    grunt.task.run(tasks)

  grunt.registerTask 'prepare-docs', 'Move api.json to atom-api.json', ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    buildDir = grunt.config.get('atom.buildDir')
    cp path.join(docsOutputDir, 'api.json'), path.join(buildDir, 'atom-api.json')

  grunt.registerTask 'upload-assets', 'Upload the assets to a GitHub release', ->
    doneCallback = @async()
    startTime = Date.now()
    done = (args...) ->
      elapsedTime = Math.round((Date.now() - startTime) / 100) / 10
      grunt.log.ok("Upload time: #{elapsedTime}s")
      doneCallback(args...)

    unless token
      return done(new Error('ATOM_ACCESS_TOKEN environment variable not set'))

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
  {cp} = require('./task-helpers')(grunt)

  {version} = grunt.file.readJSON('package.json')
  buildDir = grunt.config.get('atom.buildDir')

  switch process.platform
    when 'darwin'
      [
        {assetName: 'atom-mac.zip', sourcePath: 'Atom.app'}
        {assetName: 'atom-mac-symbols.zip', sourcePath: 'Atom.breakpad.syms'}
        {assetName: 'atom-api.json', sourcePath: 'atom-api.json'}
      ]
    when 'win32'
      assets = [{assetName: 'atom-windows.zip', sourcePath: 'Atom'}]
      for squirrelAsset in ['AtomSetup.exe', 'RELEASES', "atom-#{version}-full.nupkg", "atom-#{version}-delta.nupkg"]
        cp path.join(buildDir, 'installer', squirrelAsset), path.join(buildDir, squirrelAsset)
        assets.push({assetName: squirrelAsset, sourcePath: assetName})
      assets
    when 'linux'
      if process.arch is 'ia32'
        arch = 'i386'
      else
        arch = 'amd64'

      # Check for a Debian build
      sourcePath = "#{buildDir}/atom-#{version}-#{arch}.deb"
      assetName = "atom-#{arch}.deb"

      # Check for a Fedora build
      unless fs.isFileSync(sourcePath)
        rpmName = fs.readdirSync("#{buildDir}/rpm")[0]
        sourcePath = "#{buildDir}/rpm/#{rpmName}"
        if process.arch is 'ia32'
          arch = 'i386'
        else
          arch = 'x86_64'
        assetName = "atom.#{arch}.rpm"

      cp sourcePath, path.join(buildDir, assetName)

      [
        {assetName, sourcePath}
      ]

logError = (message, error, details) ->
  grunt.log.error(message)
  grunt.log.error(error.message ? error) if error?
  grunt.log.error(require('util').inspect(details)) if details

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
      [firstDraft] = releases.filter ({draft}) -> draft
      if firstDraft?
        options =
          uri: firstDraft.assets_url
          method: 'GET'
          headers: defaultHeaders
          json: true
        request options, (error, response, assets=[]) ->
          if error? or response.statusCode isnt 200
            logError('Fetching draft release assets failed', error, assets)
            callback(error ? new Error(response.statusCode))
          else
            firstDraft.assets = assets
            callback(null, firstDraft)
      else
        createAtomDraftRelease(callback)

createAtomDraftRelease = (callback) ->
  {version} = require('../../package.json')
  options =
    uri: 'https://api.github.com/repos/atom/atom/releases'
    method: 'POST'
    headers: defaultHeaders
    json:
      tag_name: "v#{version}"
      name: version
      draft: true
      body: """
        ### Notable Changes

        * Something new
      """

  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 201
      logError("Creating atom/atom draft release failed", error, body)
      callback(error ? new Error(response.statusCode))
    else
      callback(null, body)

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
