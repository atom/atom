RootView = require 'root-view'

describe "the `atom` global", ->
  describe ".loadPackage(name)", ->
    [extension, stylesheetPath] = []

    beforeEach ->
      rootView = new RootView
      extension = require "package-with-module"
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")

    afterEach ->
      removeStylesheet(stylesheetPath)

    it "requires and activates the package's main module if it exists", ->
      spyOn(rootView, 'activatePackage').andCallThrough()
      atom.loadPackage("package-with-module")
      expect(rootView.activatePackage).toHaveBeenCalledWith(extension)

    it "loads stylesheets associated with the package", ->
      stylesheetPath = require.resolve("fixtures/packages/package-with-module/stylesheets/styles.css")
      expect(stylesheetElementForId(stylesheetPath).length).toBe 0
      atom.loadPackage("package-with-module")
      expect(stylesheetElementForId(stylesheetPath).length).toBe 1
