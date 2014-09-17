npm = require 'npm'
request = require 'request'

config = require './config'

loadNpm = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load(npmOptions, callback)

configureRequest = (requestOptions, callback) ->
  loadNpm ->
    requestOptions.proxy ?= npm.config.get('https-proxy') or npm.config.get('proxy')
    requestOptions.strictSSL ?= npm.config.get('strict-ssl')
    callback()

module.exports =
  get: (requestOptions, callback) ->
    configureRequest requestOptions, ->
      request.get(requestOptions, callback)

  del: (requestOptions, callback) ->
    configureRequest requestOptions, ->
      request.del(requestOptions, callback)

  post: (requestOptions, callback) ->
    configureRequest requestOptions, ->
      request.post(requestOptions, callback)

  createReadStream: (requestOptions, callback) ->
    configureRequest requestOptions, ->
      callback(request.get(requestOptions))
