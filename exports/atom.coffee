TextBuffer = require 'text-buffer'
{Point, Range} = TextBuffer
{File, Directory} = require 'pathwatcher'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'

module.exports =
  BufferedNodeProcess: require '../src/buffered-node-process'
  BufferedProcess: require '../src/buffered-process'
  GitRepository: require '../src/git-repository'
  Notification: require '../src/notification'
  TextBuffer: TextBuffer
  Point: Point
  Range: Range
  File: File
  Directory: Directory
  Emitter: Emitter
  Disposable: Disposable
  CompositeDisposable: CompositeDisposable

# Shell integration is required by both Squirrel and Settings-View
if process.platform is 'win32'
  Object.defineProperty module.exports, 'WinShell',
    enumerable: true
    get: -> require '../src/main-process/win-shell'

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  module.exports.Task = require '../src/task'

  TextEditor = (params) ->
    atom.workspace.buildTextEditor(params)

  TextEditor.prototype = require('../src/text-editor').prototype

  Object.defineProperty module.exports, 'TextEditor',
    enumerable: true
    get: ->
      Grim.deprecate """
        The `TextEditor` constructor is no longer public.

        To construct a text editor, use `atom.workspace.buildTextEditor()`.
        To check if an object is a text editor, use `atom.workspace.isTextEditor(object)`.
      """
      TextEditor
