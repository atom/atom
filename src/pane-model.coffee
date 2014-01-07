{Model} = require 'theorist'

module.exports =
class PaneModel extends Model
  activeItem: null

  constructor: ({@items}) ->
