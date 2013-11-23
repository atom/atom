{Model} = require 'telepath'

module.exports =
class PaneAxis extends Model
  @properties
    container: null
    orientation: null
    children: []
