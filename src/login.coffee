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
      be used to identify yourself when publishing packages to atom.io.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('u', 'user').string('user').describe('user', 'GitHub username or email')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    Q(user: options.argv.user)
      .then(@getUser)
      .then(@getPassword)
      .then(@getTwoFactorCode)
      .then(@getExistingToken)
      .then(@createToken)
      .then(@saveToken)
      .then (token) -> callback(null, token)
      .catch(callback)

  prompt: (options) ->
    readPromise = Q.denodeify(read)
    readPromise(options)

  getUserAgent: ->
    "AtomPackageManager/#{require('../package.json').version}"

  getUser: (state) =>
    return Q(state) if state.user

    @prompt({prompt: 'GitHub Username or Email>', edit: true})
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
    requestOptions =
      uri: 'https://api.github.com/user'
      method: 'GET'
      auth:
        user: user
        password: password
        sendImmediately: true
      json: true
      proxy: process.env.http_proxy || process.env.https_proxy
      headers:
        'User-Agent': @getUserAgent()

    deferred = Q.defer()
    request requestOptions, (error, {headers, statusCode}={}, {message}={}) =>
      if statusCode is 200
        deferred.resolve(state)
      else if statusCode is 401 and headers['x-github-otp']
        @prompt({prompt: 'Two-Factor Authentication Code>', edit: true})
          .spread (authCode) ->
            state.authCode = authCode
            deferred.resolve(state)
      else
        message ?= error.message ? error.code if error
        deferred.reject(new Error(message))
    deferred.promise

  getExistingToken: (state) =>
    {user, password, authCode} = state
    targetAuthorization = @getAuthorization()
    deferred = Q.defer()

    getAuthorizations = (uri) =>
      requestOptions =
        uri: uri
        method: 'GET'
        auth:
          user: user
          password: password
          sendImmediately: true
        json: true
        proxy: process.env.http_proxy || process.env.https_proxy
        headers:
          'User-Agent': @getUserAgent()
      requestOptions.headers['x-github-otp'] = authCode if authCode

      request requestOptions, (error, {headers, statusCode}={}, body={}) ->
        if statusCode is 200
          for authorization in body
            {token} = authorization
            authorization = _.pick(authorization, Object.keys(targetAuthorization)...)
            if _.isEqual(authorization, targetAuthorization)
              state.token = token
              deferred.resolve(state)
              return

          {link} = headers
          if nextPage = link?.match(/<([^>]+)>;\s*rel\s*=\s*"next"/)?[1]
            getAuthorizations(nextPage)
          else
            deferred.resolve(state)
        else
          {message} = body
          message ?= error.message ? error.code if error
          deferred.reject(new Error(message))

    getAuthorizations('https://api.github.com/authorizations?per_page=100')
    deferred.promise

  getAuthorization: ->
    scopes: ['user', 'repo', 'gist']
    note: 'Atom Editor'
    note_url: 'https://atom.io'

  createToken: (state) =>
    {user, password, authCode, token} = state
    return Q(state) if token

    requestOptions =
      uri: 'https://api.github.com/authorizations'
      method: 'POST'
      auth:
        user: user
        password: password
        sendImmediately: true
      json: @getAuthorization()
      proxy: process.env.http_proxy || process.env.https_proxy
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
    process.stdout.write('Saving token to Keychain ')
    keytar.replacePassword('Atom GitHub API Token', 'github', token)
    process.stdout.write '\u2713\n'.green
    Q(token)
