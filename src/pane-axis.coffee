{Model} = require 'telepath'

module.exports =
class PaneAxis extends Model
  @properties
    parent: null
    orientation: null
    children: []
