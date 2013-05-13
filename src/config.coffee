path = require 'path'

module.exports =
  getAtomDirectory: ->
    process.env.ATOM_HOME ? path.join(process.env.HOME, '.atom')

  getResourcePath: ->
    process.env.ATOM_RESOURCE_PATH ? '/Applications/Atom.app/Contents/Frameworks/Atom.framework/Resources'

  getNodeUrl: ->
    process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/cefode2/dist'

  getNodeVersion: ->
    '0.10.3'
