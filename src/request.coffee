npm = require 'npm'
request = require 'request'

config = require './config'

module.exports =
  get: (requestOptions, callback) ->
    npmOptions =
      userconfig: config.getUserConfigPath()
      globalconfig: config.getGlobalConfigPath()

    npm.load npmOptions, ->
      requestOptions.proxy ?= npm.config.get('https-proxy') or npm.config.get('proxy')
      requestOptions.strictSSL ?= npm.config.get('strict-ssl')
      request.get(requestOptions, callback)
