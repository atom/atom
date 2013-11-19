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

    tokenName = 'GitHub API Token'
    command = "security -q find-generic-password -ws '#{tokenName}'"
    child_process.exec command, (error, stdout='', stderr='') ->
      token = stdout.trim()
      if error? or not token
        callback('No GitHub API token in keychain')
      else
        callback(null, token)
