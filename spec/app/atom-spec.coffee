RootView = require 'root-view'

describe "the `atom` global", ->
  describe ".loadPackage(name)", ->
    extension = null

    beforeEach ->
      rootView = new RootView
      extension = require "package-with-module"

    it "requires and activates the package's main module if it exists", ->
      spyOn(rootView, 'activatePackage').andCallThrough()
      atom.loadPackage("package-with-module")
      expect(rootView.activatePackage).toHaveBeenCalledWith(extension)
