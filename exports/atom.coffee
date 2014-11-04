{Point, Range} = require 'text-buffer'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{deprecate} = require 'grim'

module.exports =
  BufferedNodeProcess: require '../src/buffered-node-process'
  BufferedProcess: require '../src/buffered-process'
  GitRepository: require '../src/git-repository'
  Point: Point
  Range: Range

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  {$, $$, $$$, View} = require '../src/space-pen-extensions'

  module.exports.Emitter = Emitter
  module.exports.Disposable = Disposable
  module.exports.CompositeDisposable = CompositeDisposable

  module.exports.$ = $
  module.exports.$$ = $$
  module.exports.$$$ = $$$
  module.exports.View = View
  module.exports.TextEditorElement = require '../src/text-editor-element'

  module.exports.Task = require '../src/task'
  module.exports.WorkspaceView = require '../src/workspace-view'
  module.exports.Workspace = require '../src/workspace'
  module.exports.React = require 'react-atom-fork'
  module.exports.Reactionary = require 'reactionary-atom-fork'

  # Export deprecated SpacePen views.
  # Adjust their prototype chain to inherit from our extend version of SpacePen
  #
  # We avoid using/assigning a cached module for these classes in order to
  # prevent polluting every required version with these changes. The only
  # versions that should get their prototypes adjusted are the ones exported
  # here.
  uncachedRequire = (id) ->
    modulePath = require.resolve(id)
    delete require.cache[modulePath]
    loadedModule = require(modulePath)
    delete require.cache[modulePath]
    loadedModule

  TextEditorView = uncachedRequire 'atom-space-pen-views/lib/text-editor-view'
  ScrollView = uncachedRequire 'atom-space-pen-views/lib/scroll-view'
  SelectListView = uncachedRequire 'atom-space-pen-views/lib/select-list-view'

  # Make Atom's modified SpacePen View prototype the prototype of the imported View
  TextEditorView.prototype.__proto__.__proto__ = View.prototype
  TextEditorView.prototype.__proto__.useLegacyAttachHooks = true

  module.exports.TextEditorView = TextEditorView
  module.exports.ScrollView = ScrollView
  module.exports.SelectListView = SelectListView


Object.defineProperty module.exports, 'Git', get: ->
  deprecate "Please require `GitRepository` instead of `Git`: `{GitRepository} = require 'atom'`"
  module.exports.GitRepository

Object.defineProperty module.exports, 'EditorView', get: ->
  deprecate "Please require `TextEditorView` instead of `EditorView`: `{TextEditorView} = require 'atom'`"
  module.exports.TextEditorView
