{Document, Point, Range, Site} = require 'telepath'
_ = require 'underscore-plus'

#TODO Remove once all packages have been updated
_.nextTick = setImmediate

module.exports =
  _: _
  BufferedNodeProcess: require '../src/buffered-node-process'
  BufferedProcess: require '../src/buffered-process'
  Directory: require '../src/directory'
  Document: Document
  File: require '../src/file'
  fs: require '../src/fs-utils'
  Git: require '../src/git'
  Point: Point
  Range: Range
  Site: Site
  stringscore: require '../vendor/stringscore'

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  {$, $$, $$$, View} = require '../src/space-pen-extensions'

  module.exports.$ = $
  module.exports.$$ = $$
  module.exports.$$$ = $$$
  module.exports.Editor = require '../src/editor'
  module.exports.pathForRepositoryUrl = require('../src/project').pathForRepositoryUrl
  module.exports.RootView = require '../src/root-view'
  module.exports.SelectList = require '../src/select-list'
  module.exports.ScrollView = require '../src/scroll-view'
  module.exports.Task = require '../src/task'
  module.exports.View = View
