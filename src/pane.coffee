{Model} = require 'telepath'

module.exports =
class Pane extends Model
  @properties
    parentId: null

  @hasMany 'items'
