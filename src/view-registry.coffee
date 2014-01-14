{remove} = require 'underscore-plus'

module.exports =
class ViewRegistry
  constructor: ->
    @viewClassesByName = {}
    @viewsByModel = new WeakMap

  register: (viewClass) ->
    @viewClassesByName[viewClass.name] = viewClass

  getViewClass: (model) ->
    @viewClassesByName[model.constructor.name + 'View'] ? model.getViewClass()

  create: (model) ->
    throw new Error("Cannot create view for undefined model") unless model?

    if viewClass = @getViewClass(model)
      view = new viewClass(model)
      @viewsByModel.set(model, []) unless @viewsByModel.has(model)
      @viewsByModel.get(model).push(view)
      view
    else
      throw new Error("No view found for model of class #{model.constructor.name}")

  find: (model) ->
    @viewsByModel.get(model)?[0] if model?

  findOrCreate: (model, context) ->
    if model?
      @find(model) ? @create(model)

  remove: (model, view) ->
    if viewsForModel = @viewsByModel.get(model)
      remove(viewsForModel, view)

  # Deprecated: Associates an arbitrary model with an arbitrary view. Used for
  # supporting deprecated API paths where a manually-created view needs to blend
  # in with code that uses the view registry.
  associate: (model, view) ->
    @viewsByModel.set(model, []) unless @viewsByModel.has(model)
    @viewsByModel.get(model).push(view)
