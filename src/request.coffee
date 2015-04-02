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

    # Bump request timeout on CI to 30 minutes
    requestOptions.timeout = 30 * 60 * 1000 if process.env.JANKY_SHA1

    userAgent = npm.config.get('user-agent') ? "AtomApm/#{require('../package.json').version}"
    requestOptions.headers ?= {}
    requestOptions.headers['User-Agent'] ?= userAgent
    callback()

module.exports =
  get: (requestOptions, callback) ->
    configureRequest requestOptions, ->
      retryCount = requestOptions.retries ? 0
      requestsMade = 0
      tryRequest = ->
        requestsMade++
        request.get requestOptions, (error, response, body) ->
          if retryCount > 0 and error?.code in ['ETIMEDOUT', 'ECONNRESET']
            retryCount--
            tryRequest()
          else
            if error?.message and requestsMade > 1
              error.message += " (#{requestsMade} attempts)"

            callback(error, response, body)
      tryRequest()

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
