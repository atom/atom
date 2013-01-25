TextMatePackage = require 'text-mate-package'

module.exports =
  loadPackage: (name) ->
    callTaskMethod('packageLoaded', new TextMatePackage(name).readGrammars())
