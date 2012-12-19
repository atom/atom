RootView = require 'root-view'

describe "the `atom` global", ->
  describe ".loadPackage(name)", ->
    extension = null

    beforeEach ->
      rootView = new RootView
      extension = require "package-with-extension"

    it "requires and activates the package's main module if it exists", ->
      spyOn(rootView, 'activateExtension').andCallThrough()
      atom.loadPackage("package-with-extension")
      expect(rootView.activateExtension).toHaveBeenCalledWith(extension)
