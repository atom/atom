path = require 'path'
Grim = require 'grim'
DeprecationCopView = require '../lib/deprecation-cop-view'
_ = require 'underscore-plus'

describe "DeprecationCopStatusBarView", ->
  [deprecatedMethod, statusBarView, workspaceElement] = []

  beforeEach ->
    # jasmine.Clock.useMock() cannot mock _.debounce
    # http://stackoverflow.com/questions/13707047/spec-for-async-functions-using-jasmine
    spyOn(_, 'debounce').andCallFake (func) ->
      -> func.apply(this, arguments)

    jasmine.snapshotDeprecations()

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
    waitsForPromise -> atom.packages.activatePackage('status-bar')
    waitsForPromise -> atom.packages.activatePackage('deprecation-cop')

    waitsFor ->
      statusBarView = workspaceElement.querySelector('.deprecation-cop-status')

  afterEach ->
    jasmine.restoreDeprecationsSnapshot()

  it "adds the status bar view when activated", ->
    expect(statusBarView).toExist()
    expect(statusBarView.textContent).toBe '0 deprecations'
    expect(statusBarView).not.toShow()

  it "increments when there are deprecated methods", ->
    deprecatedMethod = -> Grim.deprecate("This isn't used")
    anotherDeprecatedMethod = -> Grim.deprecate("This either")
    expect(statusBarView.style.display).toBe 'none'
    expect(statusBarView.offsetHeight).toBe(0)

    deprecatedMethod()
    expect(statusBarView.textContent).toBe '1 deprecation'
    expect(statusBarView.offsetHeight).toBeGreaterThan(0)

    deprecatedMethod()
    expect(statusBarView.textContent).toBe '2 deprecations'
    expect(statusBarView.offsetHeight).toBeGreaterThan(0)

    anotherDeprecatedMethod()
    expect(statusBarView.textContent).toBe '3 deprecations'
    expect(statusBarView.offsetHeight).toBeGreaterThan(0)

  # TODO: Remove conditional when the new StyleManager deprecation APIs reach stable.
  if atom.styles.getDeprecations?
    it "increments when there are deprecated selectors", ->
      atom.styles.addStyleSheet("""
      atom-text-editor::shadow { color: red; }
      """, sourcePath: 'file-1')
      expect(statusBarView.textContent).toBe '1 deprecation'
      expect(statusBarView).toBeVisible()
      atom.styles.addStyleSheet("""
      atom-text-editor::shadow { color: blue; }
      """, sourcePath: 'file-2')
      expect(statusBarView.textContent).toBe '2 deprecations'
      expect(statusBarView).toBeVisible()

  it 'opens deprecation cop tab when clicked', ->
    expect(atom.workspace.getActivePane().getActiveItem()).not.toExist()

    waitsFor (done) ->
      atom.workspace.onDidOpen ({item}) ->
        expect(item instanceof DeprecationCopView).toBe true
        done()
      statusBarView.click()
