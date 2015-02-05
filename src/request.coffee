npm = require 'npm'
request = require 'npm/node_modules/request'

config = require './apm'

loadNpm = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load(npmOptions, callback)

configureRequest = (requestOptions, callback) ->
  loadNpm ->
    requestOptions.proxy ?= npm.config.get('https-proxy') or npm.config.get('proxy')
    requestOptions.strictSSL ?= npm.config.get('strict-ssl')
    userAgent = npm.config.get('user-agent') ? "AtomApm/#{require('../package.json').version}"
    requestOptions.headers ?= {}
    requestOptions.headers['User-Agent'] ?= userAgent
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

  getErrorMessage: (response, body) ->
    if response?.statusCode is 503
      'atom.io is temporarily unavailable, please try again later.'
    else
      body?.message ? body?.error ? body

  debug: (debug) ->
    request.debug = debug
