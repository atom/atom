{Model, Sequence} = require 'theorist'

module.exports =
class PaneAxisModel extends Model
  constructor: (params) ->
    @children = Sequence.fromArray(params?.children ? [])

  addChild: (child, index=@children.length) ->
    @children.splice(index, 0, child)

  removeChild: (child) ->
    index = @children.indexOf(child)
    @children.splice(index, 1) unless index is -1

  insertChildBefore: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index, 0, newChild)

  insertChildAfter: (currentChild, newChild) ->
    index = @children.indexOf(currentChild)
    @children.splice(index + 1, 0, newChild)
