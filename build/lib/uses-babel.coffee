fs = require 'fs'

BABEL_PREFIXES = [
  "'use babel'"
  '"use babel"'
  '/** @babel */'
]

PREFIX_LENGTH = Math.max(BABEL_PREFIXES.map((prefix) -> prefix.length)...)

buffer = Buffer(PREFIX_LENGTH)

module.exports = (filename) ->
  file = fs.openSync(filename, 'r')
  fs.readSync(file, buffer, 0, PREFIX_LENGTH)
  fs.closeSync(file)
  BABEL_PREFIXES.some (prefix) ->
    prefix is buffer.toString('utf8', 0, prefix.length)
