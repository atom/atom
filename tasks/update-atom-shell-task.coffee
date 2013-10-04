fs = require 'fs'
path = require 'path'

request = require 'request'
formidable = require 'formidable'

module.exports = (grunt) ->
  {spawn, mkdir, rm, cp} = require('./task-helpers')(grunt)

  accessToken = null
  getTokenFromKeychain = (callback) ->
    accessToken ?= process.env['ATOM_ACCESS_TOKEN']
    if accessToken
      callback(null, accessToken)
      return

    spawn {cmd: 'security', args: ['-q', 'find-generic-password', '-ws', 'GitHub API Token']}, (error, result, code) ->
      accessToken = result unless error?
      callback(error, accessToken)

  callAtomShellReposApi = (path, callback) ->
    getTokenFromKeychain (error, accessToken) ->
      if error
        callback(error)
        return

      options =
        url: "https://api.github.com/repos/atom/atom-shell#{path}"
        proxy: process.env.http_proxy || process.env.https_proxy
        headers:
          authorization: "token #{accessToken}"
          accept: 'application/vnd.github.manifold-preview'

      request options, (error, response, body) ->
        if not error?
          body = JSON.parse(body)
          error = new Error(body.message) if response.statusCode != 200
        callback(error, response, body)

  findReleaseIdFromAtomShellVersion = (version, callback) ->
    callAtomShellReposApi '/releases', (error, response, data) ->
      if error?
        grunt.log.error('GitHub API failed to access atom-shell releases')
        callback(error)
      else
        for release in data when release.tag_name is version
          callback(null, release.id)
          return
        grunt.log.error("There is no #{version} release of atom-shell")
        callback(false)

  getAtomShellDownloadUrl = (version, releaseId, callback) ->
    callAtomShellReposApi "/releases/#{releaseId}/assets", (error, response, data) ->
      if error?
        grunt.log.error("Cannot get assets of atom-shell's #{version} release")
        callback(error)
      else
        filename = "atom-shell-#{version}-#{process.platform}.zip"
        for asset in data when asset.name is filename and asset.state is 'uploaded'
          callback(null, asset.url)
          return
        grunt.log.error("Cannot get url of atom-shell's release asset")
        callback(false)

  getAtomShellVersion = ->
    versionPath = path.join('atom-shell', 'version')
    if grunt.file.isFile(versionPath)
      grunt.file.read(versionPath).trim()
    else
      null

  getCachePath = (version) -> "/tmp/atom-cached-atom-shells/#{version}"

  isAtomShellVersionCached = (version) ->
    grunt.file.isFile(getCachePath(version), 'version')

  getDownloadOptions = (version, url, callback) ->
    options =
      url: url
      followRedirect: false
      proxy: process.env.http_proxy || process.env.https_proxy

    # Only set headers for GitHub host, the url could also be a S3 link and
    # setting headers for it would make the request fail.
    if require('url').parse(url).hostname is 'api.github.com'
      getTokenFromKeychain (error, accessToken) ->
        options.headers =
          authorization: "token #{accessToken}"
          accept: 'application/octet-stream'

        callback(error, options)
    else
      callback(null, options)

  downloadAtomShell = (version, url, callback) ->
    getDownloadOptions version, url, (error, options) ->
      if error
        callback(error)
        return

      inputStream = request(options)
      inputStream.on 'response', (response) ->
        if response.statusCode is 302
          # Manually handle redirection so headers would not be sent for S3.
          downloadAtomShell(version, response.headers.location, callback)
        else if response.statusCode is 200
          grunt.log.writeln("Downloading atom-shell version #{version.cyan}")
          cacheDirectory = getCachePath(version)
          rm(cacheDirectory)
          mkdir(cacheDirectory)

          form = new formidable.IncomingForm()
          form.uploadDir = cacheDirectory
          form.maxFieldsSize = 100 * 1024 * 1024
          form.on 'file', (name, file) ->
            cacheFile = path.join(cacheDirectory, 'atom-shell.zip')
            fs.renameSync(file.path, cacheFile)
            callback(null, cacheFile)
          form.parse response, (error) ->
            if error
              grunt.log.error("atom-shell #{version.cyan} failed to download")
        else
          if response.statusCode is 404
            grunt.log.error("atom-shell #{version.cyan} not found")
          else
            grunt.log.error("atom-shell #{version.cyan} request failed")
          callback(false)

  downloadAtomShellOfVersion = (version, callback) ->
    findReleaseIdFromAtomShellVersion version, (error, releaseId) ->
      if error?
        callback(error)
      else
        getAtomShellDownloadUrl version, releaseId, (error, url) ->
          if error?
            callback(error)
          else
            downloadAtomShell version, url, callback

  unzipAtomShell = (zipPath, callback) ->
    grunt.log.writeln('Unzipping atom-shell')
    directoryPath = path.dirname(zipPath)

    spawn {cmd: 'unzip', args: [zipPath, '-d', directoryPath]}, (error) ->
      rm(zipPath)
      callback(error)

  rebuildNativeModules = (previousVersion, callback) ->
    newVersion = getAtomShellVersion()
    if newVersion and newVersion isnt previousVersion
      grunt.log.writeln("Rebuilding native modules for new atom-shell version #{newVersion.cyan}.")
      cmd = path.join('node_modules', '.bin', 'apm')
      spawn {cmd, args: ['rebuild']}, (error) -> callback(error)
    else
      callback()

  installAtomShell = (version) ->
    rm('atom-shell')
    cp(getCachePath(version), 'atom-shell')

  grunt.registerTask 'update-atom-shell', 'Update atom-shell', ->
    done = @async()
    {atomShellVersion} = grunt.file.readJSON('package.json')
    if atomShellVersion
      atomShellVersion = "v#{atomShellVersion}"
      currentAtomShellVersion = getAtomShellVersion()
      if atomShellVersion isnt currentAtomShellVersion
        if isAtomShellVersionCached(atomShellVersion)
          grunt.log.writeln("Installing cached atom-shell #{atomShellVersion.cyan}")
          installAtomShell(atomShellVersion)
          rebuildNativeModules(currentAtomShellVersion, done)
        else
          downloadAtomShellOfVersion atomShellVersion, (error, zipPath) ->
            if error?
              done(error)
            else if zipPath?
              unzipAtomShell zipPath, (error) ->
                if error?
                  done(error)
                else
                  grunt.log.writeln("Installing atom-shell #{atomShellVersion.cyan}")
                  installAtomShell(atomShellVersion)
                  rebuildNativeModules(currentAtomShellVersion, done)
            else
              done(false)
      else
        done()
    else
      grunt.log.error("atom-shell version missing from package.json")
      done(false)
