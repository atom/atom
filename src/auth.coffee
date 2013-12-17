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

    for tokenName in ['Atom GitHub API Token', 'GitHub API Token']
      if token = keytar.findPassword(tokenName)
        callback(null, token)
        return

    callback """
      No GitHub API token in keychain
      Set the `ATOM_ACCESS_TOKEN` environment variable or sign in to GitHub in Atom
    """
