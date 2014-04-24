keytar = require 'keytar'

module.exports =
  # Get the Atom.io API token from the keychain.
  #
  # callback - A function to call with an error as the first argument and a
  #            string token as the second argument.
  getToken: (callback) ->
    if token = process.env.ATOM_ACCESS_TOKEN
      callback(null, token)
      return

    if token = keytar.findPassword('Atom.io API Token')
      callback(null, token)
      return

    callback """
      No Atom.io API token in keychain
      Run `apm login` or set the `ATOM_ACCESS_TOKEN` environment variable.
    """
