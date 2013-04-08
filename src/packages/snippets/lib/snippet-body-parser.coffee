PEG = require 'pegjs'
fsUtils = require 'fs-utils'
grammarSrc = fsUtils.read(require.resolve('./snippet-body.pegjs'))
module.exports = PEG.buildParser(grammarSrc, trackLineAndColumn: true)
