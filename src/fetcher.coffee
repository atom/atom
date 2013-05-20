request = require 'request'
npmconf = require 'npmconf'
config = require './config'
tree = require './tree'
semver = require 'semver'

module.exports =
class Fetcher
  getAvailablePackages: (callback) ->
    npmconf.load config.getUserConfigPath(), (error, userConfig) ->
      if error?
        callback(error)
      else
        requestSettings =
          url: config.getAtomPackagesUrl()
          json: true
          auth:
            username: userConfig.get('username', 'builtin')
            password: userConfig.get('_password', 'builtin')
            sendImmediately: true
        request.get requestSettings, (error, response, body={}) ->
          if error?
            callback(error)
          else
            packages = body.rows ? []
            callback(null, packages)

  run: (options) ->
    @getAvailablePackages (error, packages) ->
      if error?
        options.callback(error)
      else
        console.log "Available Atom packages (#{packages.length})"
        tree packages, (pack) ->
          highestVersion = null
          for version, metadata of pack.value.releases
            if highestVersion
              highestVersion = version if semver.gt(version, highestVersion)
            else
              highestVersion = version
          "#{pack.id}@#{highestVersion}"
        options.callback()
