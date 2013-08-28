path = require 'path'

module.exports =
  getHomeDirectory: ->
    if process.platform is 'win32' then process.env.USERPROFILE else process.env.HOME

  getAtomDirectory: ->
    process.env.ATOM_HOME ? path.join(@getHomeDirectory(), '.atom')

  getResourcePath: ->
    process.env.ATOM_RESOURCE_PATH ? '/Applications/Atom.app/Contents/Resources/app'

  getNodeUrl: ->
    process.env.ATOM_NODE_URL ? 'https://gh-contractor-zcbenz.s3.amazonaws.com/atom-shell/dist'

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? 'http://atom.iriscouch.com/registry/_design/apm/_view/atom_packages'

  getNodeVersion: ->
    process.env.ATOM_NODE_VERSION ? '0.10.15'

  getUserConfigPath: ->
    path.resolve(__dirname, '..', '.apmrc')

  isWin32: ->
    !!process.platform.match(/^win/)
