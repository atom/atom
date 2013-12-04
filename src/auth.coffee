child_process = require 'child_process'

module.exports =
  # Get the GitHub API token from the keychain
  #
  # * callback: A function to call with an error as the first argument and a
  #             string token as the second argument.
  getToken: (callback) ->
    if token = process.env.ATOM_ACCESS_TOKEN
      callback(null, token)
      return

    tokenNames = ['Atom GitHub API Token', 'GitHub API Token']

    getNextToken = ->
      unless tokenNames.length
        return callback """
          No GitHub API token in keychain
          Set the `ATOM_ACCESS_TOKEN` environment variable or sign in to GitHub in Atom
        """

      tokenName = tokenNames.shift()
      getTokenFromKeychain tokenName, (error, token) ->
        if token then callback(null, token) else getNextToken()

    getNextToken()

getTokenFromKeychain = (tokenName, callback) ->
  command = "security -q find-generic-password -ws '#{tokenName}'"
  child_process.exec command, (error, stdout='') ->
    token = stdout.trim()
    callback(error, token)
