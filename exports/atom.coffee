TextBuffer = require 'text-buffer'
{Point, Range} = TextBuffer
{File, Directory} = require 'pathwatcher'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'

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

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  module.exports.Task = require '../src/task'
  module.exports.TextEditor = require '../src/text-editor'
