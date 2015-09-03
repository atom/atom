{$, $$, View} = require '../src/space-pen-extensions'
Q = require 'q'
path = require 'path'
temp = require 'temp'
TextEditorView = require '../src/text-editor-view'
PaneView = require '../src/pane-view'
Workspace = require '../src/workspace'

describe "WorkspaceView", ->
  pathToOpen = null

  beforeEach ->
    jasmine.snapshotDeprecations()

    atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('dir')])
    pathToOpen = atom.project.getDirectories()[0]?.resolve('a')
    atom.workspace = new Workspace
    atom.workspaceView = atom.views.getView(atom.workspace).__spacePenView
    atom.workspaceView.enableKeymap()
    atom.workspaceView.focus()

    waitsForPromise ->
      atom.workspace.open(pathToOpen)

  afterEach ->
    jasmine.restoreDeprecationsSnapshot()
