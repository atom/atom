{Model} = require 'telepath'

module.exports =
class FocusManager extends Model
  @property 'focusedDocument', null
