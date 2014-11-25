{Point, Range} = require 'text-buffer'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{deprecate} = require 'grim'

module.exports =
  BufferedNodeProcess: require '../src/buffered-node-process'
  BufferedProcess: require '../src/buffered-process'
  GitRepository: require '../src/git-repository'
  Notification: require '../src/notification'
  Point: Point
  Range: Range
  Emitter: Emitter
  Disposable: Disposable
  CompositeDisposable: CompositeDisposable

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  module.exports.Task = require '../src/task'
  module.exports.TextEditor = require '../src/text-editor'

  {$, $$, $$$, View} = require '../src/space-pen-extensions'

  Object.defineProperty module.exports, 'Workspace', get: ->
    deprecate """
      Requiring `Workspace` from `atom` is no longer supported.
      If you need this, please open an issue on
      https://github.com/atom/atom/issues/new
      And let us know what you are using it for.
    """
    require '../src/workspace'

  Object.defineProperty module.exports, 'WorkspaceView', get: ->
    deprecate """
      Requiring `WorkspaceView` from `atom` is no longer supported.
      Use `atom.views.getView(atom.workspace)` instead.
    """
    require '../src/workspace-view'

  Object.defineProperty module.exports, '$', get: ->
    deprecate """
      Requiring `$` from `atom` is no longer supported.
      If you are using `space-pen`, please require `$` from `space-pen`. Otherwise require `jquery` instead:
        `{$} = require 'space-pen'`
        or
        `$ = require 'jquery'`
      Add `"space-pen": "^4"` to your package dependencies.
      Or add `"jquery": "^2"` to your package dependencies.
    """
    $

  Object.defineProperty module.exports, '$$', get: ->
    deprecate """
      Requiring `$$` from `atom` is no longer supported.
      Please require `space-pen` instead:
        `{$$} = require 'space-pen'`
      Add `"space-pen": "^4"` to your package dependencies.
    """
    $$

  Object.defineProperty module.exports, '$$$', get: ->
    deprecate """
      Requiring `$$$` from `atom` is no longer supported.
      Please require `space-pen` instead:
        `{$$$} = require 'space-pen'`
      Add `"space-pen": "^4"` to your package dependencies.
    """
    $$$

  Object.defineProperty module.exports, 'View', get: ->
    deprecate """
      Requiring `View` from `atom` is no longer supported.
      Please require `space-pen` instead:
        `{View} = require 'space-pen'`
      Add `"space-pen": "^4"` to your package dependencies.
    """
    View

  Object.defineProperty module.exports, 'EditorView', get: ->
    deprecate """
      Requiring `EditorView` from `atom` is no longer supported.
      Please require `TextEditorView` from `atom-space-pen-view` instead:
        `{TextEditorView} = require 'atom-space-pen-views'`
      Add `"atom-space-pen-views": "^0"` to your package dependencies.
    """
    require '../src/text-editor-view'

  Object.defineProperty module.exports, 'TextEditorView', get: ->
    deprecate """
      Requiring `TextEditorView` from `atom` is no longer supported.
      Please require `TextEditorView` from `atom-space-pen-view` instead:
        `{TextEditorView} = require 'atom-space-pen-views'`
      Add `"atom-space-pen-views": "^0"` to your package dependencies.
    """
    require '../src/text-editor-view'

  Object.defineProperty module.exports, 'ScrollView', get: ->
    deprecate """
      Requiring `ScrollView` from `atom` is no longer supported.
      Please require `ScrollView` from `atom-space-pen-view` instead:
        `{ScrollView} = require 'atom-space-pen-views'`
      Note that the API has changed slightly! Please read the docs at https://github.com/atom/atom-space-pen-views
      Add `"atom-space-pen-views": "^0"` to your package dependencies.
    """
    require '../src/scroll-view'

  Object.defineProperty module.exports, 'SelectListView', get: ->
    deprecate """
      Requiring `SelectListView` from `atom` is no longer supported.
      Please require `SelectListView` from `atom-space-pen-view` instead:
        `{SelectListView} = require 'atom-space-pen-views'`
      Note that the API has changed slightly! Please read the docs at https://github.com/atom/atom-space-pen-views
      Add `"atom-space-pen-views": "^0"` to your package dependencies.
    """
    require '../src/select-list-view'

  Object.defineProperty module.exports, 'React', get: ->
    deprecate "Please require `react-atom-fork` instead: `React = require 'react-atom-fork'`. Add `\"react-atom-fork\": \"^0.11\"` to your package dependencies."
    require 'react-atom-fork'

  Object.defineProperty module.exports, 'Reactionary', get: ->
    deprecate "Please require `reactionary-atom-fork` instead: `Reactionary = require 'reactionary-atom-fork'`. Add `\"reactionary-atom-fork\": \"^0.9\"` to your package dependencies."
    require 'reactionary-atom-fork'

Object.defineProperty module.exports, 'Git', get: ->
  deprecate "Please require `GitRepository` instead of `Git`: `{GitRepository} = require 'atom'`"
  module.exports.GitRepository
