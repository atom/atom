{Point, Range} = require 'text-buffer'
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
  module.exports.TextEditorView = require '../src/text-editor-view'
  module.exports.ScrollView = require '../src/scroll-view'
  module.exports.SelectListView = require '../src/select-list-view'
  module.exports.Task = require '../src/task'
  module.exports.WorkspaceView = require '../src/workspace-view'
  module.exports.Workspace = require '../src/workspace'

  {$, $$, $$$, View} = require '../src/space-pen-extensions'
  Object.defineProperty module.exports, '$', get: ->
    deprecate "Please require `jquery` instead: `$ = require 'jquery'`. Add `\"jquery\": \"^2\"` to your package dependencies."
    $

  Object.defineProperty module.exports, '$$', get: ->
    deprecate "Please require `space-pen` instead: `{$$} = require 'space-pen'`. Add `\"space-pen\": \"^3\"` to your package dependencies."
    $$

  Object.defineProperty module.exports, '$$$', get: ->
    deprecate "Please require `space-pen` instead: `{$$$} = require 'space-pen'`. Add `\"space-pen\": \"^3\"` to your package dependencies."
    $$$

  Object.defineProperty module.exports, 'View', get: ->
    deprecate "Please require `space-pen` instead: `{View} = require 'space-pen'`. Add `\"space-pen\": \"^3\"` to your package dependencies."
    View

  Object.defineProperty module.exports, 'React', get: ->
    deprecate "Please require `react-atom-fork` instead: `React = require 'react-atom-fork'`. Add `\"react-atom-fork\": \"^0.11\"` to your package dependencies."
    require 'react-atom-fork'

  Object.defineProperty module.exports, 'Reactionary', get: ->
    deprecate "Please require `reactionary` instead: `Reactionary = require 'reactionary'`. Add `\"reactionary\": \"^0.9\"` to your package dependencies."
    require 'reactionary'

Object.defineProperty module.exports, 'Git', get: ->
  deprecate "Please require `GitRepository` instead of `Git`: `{GitRepository} = require 'atom'`"
  module.exports.GitRepository

Object.defineProperty module.exports, 'EditorView', get: ->
  deprecate "Please require `TextEditorView` instead of `EditorView`: `{TextEditorView} = require 'atom'`"
  module.exports.TextEditorView
