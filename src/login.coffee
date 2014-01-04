_ = require 'underscore-plus'
keytar = require 'keytar'
optimist = require 'optimist'
Q = require 'q'
read = require 'read'
request = require 'request'

Command = require './command'

module.exports =
class Login extends Command
  @commandNames: ['login']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm login

      Create and save a GitHub OAuth2 token to the keychain. This token will
      be used to identify yourself when publishing packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('u', 'user').describe('user', 'GitHub username')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    Q(user: options.argv.user)
      .then(@getUser)
      .then(@getPassword)
      .then(@getTwoFactorCode)
      .then(@createToken)
      .then(@saveToken)
      .catch(callback)

  prompt: (options) ->
    readPromise = Q.denodeify(read)
    readPromise(options)

  getUserAgent: ->
    "AtomPackageManager/#{require('../package.json').version}"

  getUser: (state) =>
    return Q(state) if state.user

    @prompt({prompt: 'Username>', edit: true})
      .spread (user) ->
        state.user = user
        Q(state)

  getPassword: (state) =>
    return Q(state) if state.password

    @prompt({prompt: 'Password>', edit: true, silent: true})
      .spread (password) ->
        state.password = password
        Q(state)

  getTwoFactorCode: (state) =>
    {user, password} = state
    requestOptions = _.extend {}, @defaultRequestOptions,
      uri: 'https://api.github.com/user'
      method: 'GET'
      auth:
        user: user
        password: password
        sendImmediately: true
      json: true
      headers:
        'User-Agent': @getUserAgent()

    deferred = Q.defer()
    request requestOptions, (error, {headers, statusCode}={}, {message}={}) =>
      if statusCode is 200
        deferred.resolve(state)
      else if statusCode is 401 and headers['x-github-otp']
        @prompt({prompt: 'Authentication Code>', edit: true})
          .spread (authCode) ->
            state.authCode = authCode
            deferred.resolve(state)
      else
        message ?= error.message ? error.code if error
        deferred.reject(new Error(message))
    deferred.promise

  createToken: (state) =>
    {user, password, authCode} = state
    requestOptions =
      uri: 'https://api.github.com/authorizations'
      method: 'POST'
      auth:
        user: user
        password: password
        sendImmediately: true
      json:
        scopes: ['user', 'repo', 'gist']
        note: 'GitHub Atom'
        note_url: 'https://github.com/github/atom'
      headers:
        'User-Agent': @getUserAgent()

    requestOptions.headers['x-github-otp'] = authCode if authCode

    deferred = Q.defer()
    request requestOptions, (error, {headers, statusCode}={}, {token, message}={}) =>
      if statusCode is 201
        state.token = token
        deferred.resolve(state)
      else
        message ?= error.message ? error.code if error
        deferred.reject(new Error(message))
    deferred.promise

  saveToken: ({token}) =>
    keytar.replacePassword('Atom GitHub API Token', 'github', token)
