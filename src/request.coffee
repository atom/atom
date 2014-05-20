npm = require 'npm'
request = require 'request'

config = require './config'

loadOptionsFromNpm = (requestOptions, callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()

  npm.load npmOptions, ->
    requestOptions.proxy ?= npm.config.get('https-proxy') or npm.config.get('proxy')
    requestOptions.strictSSL ?= npm.config.get('strict-ssl')
    request.get(requestOptions, callback)

module.exports =
  get: (requestOptions, callback) ->
    loadOptionsFromNpm requestOptions, ->
      request.get(requestOptions, callback)


  del: (requestOptions, callback) ->
    loadOptionsFromNpm requestOptions, ->
      request.del(requestOptions, callback)

  post: (requestOptions, callback) ->
    loadOptionsFromNpm requestOptions, ->
      request.post(requestOptions, callback)
