_ = require 'underscore-plus'
keytar = require 'keytar'
optimist = require 'optimist'
Q = require 'q'
read = require 'read'
request = require 'request'
open = require 'open'

Command = require './command'

module.exports =
class Login extends Command
  @commandNames: ['login']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm login

      Create and save an API token to the keychain. This token will
      be used to identify you when publishing packages to atom.io.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('u', 'user').string('user').describe('user', 'GitHub username or email')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    Q(user: options.argv.user)
      .then(@welcomeMessage)
      .then(@openURL)
      .then(@getToken)
      .then(@saveToken)
      .then (token) -> callback(null, token)
      .catch(callback)

  prompt: (options) ->
    readPromise = Q.denodeify(read)
    readPromise(options)

  getUserAgent: ->
    "AtomPackageManager/#{require('../package.json').version}"

  welcomeMessage: (state) =>
    welcome =
       """Welcome to Atom! Before you can publish packages, you'll need an API token.
       Visit your account page on Atom.io (https://atom.io/account), copy the token
       and paste it below when prompted.

       """
    console.log welcome

    @prompt({prompt: "Press [Enter] to open your account page on Atom.io."})

  openURL: ->
    open('https://atom.io/account')

  getToken: (state) =>
    return Q(state) if state.token

    @prompt({prompt: 'Token>', edit: true})
      .spread (token) ->
        state.token = token
        Q(state)

  saveToken: ({token}) =>
    process.stdout.write('Saving token to Keychain ')
    keytar.replacePassword('Atom.io API Token', 'atom.io', token)
    process.stdout.write '\u2713\n'.green
    Q(token)
