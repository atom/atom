Point = require 'point'

module.exports =
class EditSession
  cursorScreenPosition: new Point(0, 0)
  scrollTop: 0
  scrollLeft: 0

