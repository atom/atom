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

  describe 'panel containers', ->
    workspaceElement = null
    beforeEach ->
      workspaceElement = atom.views.getView(atom.workspace)

    it 'inserts panel container elements in the correct places in the DOM', ->
      leftContainer = workspaceElement.querySelector('atom-panel-container.left')
      rightContainer = workspaceElement.querySelector('atom-panel-container.right')
      expect(leftContainer.nextSibling).toBe workspaceElement.verticalAxis
      expect(rightContainer.previousSibling).toBe workspaceElement.verticalAxis

      topContainer = workspaceElement.querySelector('atom-panel-container.top')
      bottomContainer = workspaceElement.querySelector('atom-panel-container.bottom')
      expect(topContainer.nextSibling).toBe workspaceElement.paneContainer
      expect(bottomContainer.previousSibling).toBe workspaceElement.paneContainer

      modalContainer = workspaceElement.querySelector('atom-panel-container.modal')
      expect(modalContainer.parentNode).toBe workspaceElement
