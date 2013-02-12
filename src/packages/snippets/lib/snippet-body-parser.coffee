PEG = require 'pegjs'
fs = require 'fs'
grammarSrc = fs.read(require.resolve('./snippet-body.pegjs'))
module.exports = PEG.buildParser(grammarSrc, trackLineAndColumn: true)
