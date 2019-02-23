Grim = require 'grim'
path = require 'path'
_ = require 'underscore-plus'
etch = require 'etch'

describe "DeprecationCopView", ->
  [deprecationCopView, workspaceElement] = []

  beforeEach ->
    spyOn(_, 'debounce').andCallFake (func) ->
      -> func.apply(this, arguments)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    jasmine.snapshotDeprecations()
    Grim.clearDeprecations()
    deprecatedMethod = -> Grim.deprecate("A test deprecation. This isn't used")
    deprecatedMethod()

    spyOn(Grim, 'deprecate') # Don't fail tests if when using deprecated APIs in deprecation cop's activation
    activationPromise = atom.packages.activatePackage('deprecation-cop')

    atom.commands.dispatch workspaceElement, 'deprecation-cop:view'

    waitsForPromise ->
      activationPromise

    waitsFor -> deprecationCopView = atom.workspace.getActivePane().getActiveItem()

    runs ->
      jasmine.unspy(Grim, 'deprecate')

  afterEach ->
    jasmine.restoreDeprecationsSnapshot()

  it "displays deprecated methods", ->
    expect(deprecationCopView.element.textContent).toMatch /Deprecated calls/
    expect(deprecationCopView.element.textContent).toMatch /This isn't used/

  # TODO: Remove conditional when the new StyleManager deprecation APIs reach stable.
  if atom.styles.getDeprecations?
    it "displays deprecated selectors", ->
      atom.styles.addStyleSheet("atom-text-editor::shadow { color: red }", sourcePath: path.join('some-dir', 'packages', 'package-1', 'file-1.css'))
      atom.styles.addStyleSheet("atom-text-editor::shadow { color: yellow }", context: 'atom-text-editor', sourcePath: path.join('some-dir', 'packages', 'package-1', 'file-2.css'))
      atom.styles.addStyleSheet('atom-text-editor::shadow { color: blue }', sourcePath: path.join('another-dir', 'packages', 'package-2', 'file-3.css'))
      atom.styles.addStyleSheet('atom-text-editor::shadow { color: gray }', sourcePath: path.join('another-dir', 'node_modules', 'package-3', 'file-4.css'))

      promise = etch.getScheduler().getNextUpdatePromise()
      waitsForPromise -> promise

      runs ->
        packageItems = deprecationCopView.element.querySelectorAll("ul.selectors > li")
        expect(packageItems.length).toBe(3)
        expect(packageItems[0].textContent).toMatch /package-1/
        expect(packageItems[1].textContent).toMatch /package-2/
        expect(packageItems[2].textContent).toMatch /Other/

        packageDeprecationItems = packageItems[0].querySelectorAll("li.source-file")
        expect(packageDeprecationItems.length).toBe(2)
        expect(packageDeprecationItems[0].textContent).toMatch /atom-text-editor/
        expect(packageDeprecationItems[0].querySelector("a").href).toMatch('some-dir/packages/package-1/file-1.css')
        expect(packageDeprecationItems[1].textContent).toMatch /:host/
        expect(packageDeprecationItems[1].querySelector("a").href).toMatch('some-dir/packages/package-1/file-2.css')

  it 'skips stack entries which go through node_modules/ files when determining package name', ->
    stack = [
      {
        "functionName": "function0"
        "location": path.normalize "/Users/user/.atom/packages/package1/node_modules/atom-space-pen-viewslib/space-pen.js:55:66"
        "fileName": path.normalize "/Users/user/.atom/packages/package1/node_modules/atom-space-pen-views/lib/space-pen.js"
      }
      {
        "functionName": "function1"
        "location": path.normalize "/Users/user/.atom/packages/package1/node_modules/atom-space-pen-viewslib/space-pen.js:15:16"
        "fileName": path.normalize "/Users/user/.atom/packages/package1/node_modules/atom-space-pen-views/lib/space-pen.js"
      }
      {
        "functionName": "function2"
        "location": path.normalize "/Users/user/.atom/packages/package2/lib/module.js:13:14"
        "fileName": path.normalize "/Users/user/.atom/packages/package2/lib/module.js"
      }
    ]

    packagePathsByPackageName = new Map([
      ['package1', path.normalize("/Users/user/.atom/packages/package1")],
      ['package2', path.normalize("/Users/user/.atom/packages/package2")]
    ])

    spyOn(deprecationCopView, 'getPackagePathsByPackageName').andReturn(packagePathsByPackageName)

    packageName = deprecationCopView.getPackageName(stack)
    expect(packageName).toBe("package2")
