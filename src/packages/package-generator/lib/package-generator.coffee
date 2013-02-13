PackageGeneratorView = require 'package-generator/lib/package-generator-view'

module.exports =
  view: null

  activate: (state) ->
    @view = new PackageGeneratorView()
