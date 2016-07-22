child_process = require 'child_process'
path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
fs = require 'fs-plus'
GitHub = require 'github-releases'
request = require 'request'
AWS = require 'aws-sdk'

grunt = null

token = process.env.ATOM_ACCESS_TOKEN
repo = process.env.ATOM_PUBLISH_REPO ? 'atom/atom'
defaultHeaders =
  Authorization: "token #{token}"
  'User-Agent': 'Atom'

module.exports = (gruntObject) ->
  grunt = gruntObject
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'publish-build', 'Publish the built app', ->
    tasks = []
    tasks.push('build-docs', 'prepare-docs') if process.platform is 'darwin'
    tasks.push('upload-assets')
    grunt.task.run(tasks)

  grunt.registerTask 'prepare-docs', 'Move api.json to atom-api.json', ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    buildDir = grunt.config.get('atom.buildDir')
    cp path.join(docsOutputDir, 'api.json'), path.join(buildDir, 'atom-api.json')

  grunt.registerTask 'upload-assets', 'Upload the assets to a GitHub release', ->
    grunt.log.ok("Starting upload-assets to #{repo} repo")
    releaseBranch = grunt.config.get('atom.releaseBranch')
    isPrerelease = grunt.config.get('atom.channel') is 'beta'
    return unless releaseBranch?

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
      getAtomDraftRelease isPrerelease, releaseBranch, (error, release) ->
        return done(error) if error?
        assetNames = (asset.assetName for asset in assets)
        deleteExistingAssets release, assetNames, (error) ->
          return done(error) if error?
          uploadAssets(release, buildDir, assets, done)

getAssets = ->
  {cp} = require('./task-helpers')(grunt)

  {version} = grunt.file.readJSON('package.json')
  buildDir = grunt.config.get('atom.buildDir')
  appName = grunt.config.get('atom.appName')
  appFileName = grunt.config.get('atom.appFileName')

  switch process.platform
    when 'darwin'
      [
        {assetName: 'atom-mac.zip', sourcePath: appName}
        {assetName: 'atom-mac-symbols.zip', sourcePath: 'Atom.breakpad.syms'}
        {assetName: 'atom-api.json', sourcePath: 'atom-api.json'}
      ]
    when 'win32'
      assets = [{assetName: 'atom-windows.zip', sourcePath: appName}]
      for squirrelAsset in ['AtomSetup.exe', 'AtomSetup.msi', 'RELEASES', "atom-#{version}-full.nupkg", "atom-#{version}-delta.nupkg"]
        cp path.join(buildDir, 'installer', squirrelAsset), path.join(buildDir, squirrelAsset)
        assets.push({assetName: squirrelAsset, sourcePath: assetName})
      assets
    when 'linux'
      if process.arch is 'ia32'
        arch = 'i386'
      else
        arch = 'amd64'

      # Check for a Debian build
      sourcePath = path.join(buildDir, "#{appFileName}-#{version}-#{arch}.deb")
      assetName = "atom-#{arch}.deb"

      # Check for a Fedora build
      unless fs.isFileSync(sourcePath)
        rpmName = fs.readdirSync("#{buildDir}/rpm")[0]
        sourcePath = path.join(buildDir, "rpm", rpmName)
        if process.arch is 'ia32'
          arch = 'i386'
        else
          arch = 'x86_64'
        assetName = "atom.#{arch}.rpm"

      cp sourcePath, path.join(buildDir, assetName)
      assets = [{assetName, sourcePath}]

      # Check for an archive build on a debian build machine.
      # We could provide a Fedora version if some libraries are not compatible
      sourcePath = path.join(buildDir, "#{appFileName}-#{version}-#{arch}.tar.gz")
      if fs.isFileSync(sourcePath)
        assetName = "atom-#{arch}.tar.gz"
        cp sourcePath, path.join(buildDir, assetName)
        assets.push({assetName, sourcePath})

      assets

logError = (message, error, details) ->
  grunt.log.error(message)
  grunt.log.error(error.message ? error) if error?
  grunt.log.error(require('util').inspect(details)) if details

zipAssets = (buildDir, assets, callback) ->
  zip = (directory, sourcePath, assetName, callback) ->
    grunt.log.ok("Zipping #{sourcePath} into #{assetName}")
    if process.platform is 'win32'
      sevenZipPath = if process.env.JANKY_SHA1? then "C:/psmodules/" else ""
      zipCommand = "#{sevenZipPath}7z.exe a -r \"#{assetName}\" \"#{sourcePath}\""
    else
      zipCommand = "zip -r --symlinks '#{assetName}' '#{sourcePath}'"
    options = {cwd: directory, maxBuffer: Infinity}
    child_process.exec zipCommand, options, (error, stdout, stderr) ->
      logError("Zipping #{sourcePath} failed", error, stderr) if error?
      callback(error)

  tasks = []
  for {assetName, sourcePath} in assets when path.extname(assetName) is '.zip'
    fs.removeSync(path.join(buildDir, assetName))
    tasks.push(zip.bind(this, buildDir, sourcePath, assetName))
  async.parallel(tasks, callback)

getAtomDraftRelease = (isPrerelease, branchName, callback) ->
  grunt.log.ok("Obtaining GitHub draft release for #{branchName}")
  atomRepo = new GitHub({repo: repo, token})
  atomRepo.getReleases {prerelease: isPrerelease}, (error, releases=[]) ->
    if error?
      logError("Fetching #{repo} #{if isPrerelease then "pre" else "" }releases failed", error, releases)
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
            grunt.log.ok("Using GitHub draft release #{firstDraft.name}")
            firstDraft.assets = assets
            callback(null, firstDraft)
      else
        createAtomDraftRelease(isPrerelease, branchName, callback)

createAtomDraftRelease = (isPrerelease, branchName, callback) ->
  grunt.log.ok("Creating GitHub draft release #{branchName}")
  {version} = require('../../package.json')
  options =
    uri: "https://api.github.com/repos/#{repo}/releases"
    method: 'POST'
    headers: defaultHeaders
    json:
      tag_name: "v#{version}"
      prerelease: isPrerelease
      target_commitish: branchName
      name: version
      draft: true
      body: """
        ### Notable Changes

        * Something new
      """

  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 201
      logError("Creating #{repo} draft release failed", error, body)
      callback(error ? new Error(response.statusCode))
    else
      callback(null, body)

deleteRelease = (release) ->
  grunt.log.ok("Deleting GitHub release #{release}")
  options =
    uri: release.url
    method: 'DELETE'
    headers: defaultHeaders
    json: true
  request options, (error, response, body='') ->
    if error? or response.statusCode isnt 204
      logError('Deleting release failed', error, body)

deleteExistingAssets = (release, assetNames, callback) ->
  grunt.log.ok("Deleting #{assetNames.join(',')} from GitHub release #{release}")
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
  uploadToReleases = (release, assetName, assetPath, callback) ->
    grunt.log.ok("Uploading #{assetName} to GitHub release #{release}")
    options =
      uri: release.upload_url.replace(/\{.*$/, "?name=#{assetName}")
      method: 'POST'
      headers: _.extend({
        'Content-Type': 'application/zip'
        'Content-Length': fs.getSizeSync(assetPath)
        }, defaultHeaders)

    assetRequest = request options, (error, response, body='') ->
      if error? or response.statusCode >= 400
        logError("Upload release asset #{assetName} to Releases failed", error, body)
        callback(error ? new Error(response.statusCode))
      else
        callback(null, release)

    fs.createReadStream(assetPath).pipe(assetRequest)

  uploadToS3 = (release, assetName, assetPath, callback) ->
    s3Key = process.env.BUILD_ATOM_RELEASES_S3_KEY
    s3Secret = process.env.BUILD_ATOM_RELEASES_S3_SECRET
    s3Bucket = process.env.BUILD_ATOM_RELEASES_S3_BUCKET

    unless s3Key and s3Secret and s3Bucket
      callback(new Error('BUILD_ATOM_RELEASES_S3_KEY, BUILD_ATOM_RELEASES_S3_SECRET, and BUILD_ATOM_RELEASES_S3_BUCKET environment variables must be set.'))
      return

    s3Info =
      accessKeyId: s3Key
      secretAccessKey: s3Secret
    s3 = new AWS.S3 s3Info

    key = "releases/#{release.tag_name}/#{assetName}"
    grunt.log.ok("Uploading to S3 #{key}")
    uploadParams =
      Bucket: s3Bucket
      ACL: 'public-read'
      Key: key
      Body: fs.createReadStream(assetPath)
    s3.upload uploadParams, (error, data) ->
      if error?
        logError("Upload release asset #{assetName} to S3 failed", error)
        callback(error)
      else
        callback(null, release)

  tasks = []
  for {assetName} in assets
    assetPath = path.join(buildDir, assetName)
    tasks.push(uploadToReleases.bind(this, release, assetName, assetPath))
    tasks.push(uploadToS3.bind(this, release, assetName, assetPath))
  async.parallel(tasks, callback)
