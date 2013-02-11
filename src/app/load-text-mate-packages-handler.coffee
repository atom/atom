TextMatePackage = require 'text-mate-package'

module.exports =
  loadPackage: (path) ->
    callTaskMethod('packageLoaded', new TextMatePackage(path).readGrammars())
