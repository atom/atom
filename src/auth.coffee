child_process = require 'child_process'
keytar = require 'keytar'

module.exports =
  # Get the GitHub API token from the keychain
  #
  # * callback: A function to call with an error as the first argument and a
  #             string token as the second argument.
  getToken: (callback) ->
    if token = process.env.ATOM_ACCESS_TOKEN
      callback(null, token)
      return

    tokenName = 'GitHub API Token'
    token = keytar.findPassword(tokenName)

    if error? or not token
      callback('No "GitHub API Token" in keychain')
    else
      callback(null, token)
