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
    if viewClass = @getViewClass(model)
      view = new viewClass(model)
      @viewsByModel.set(model, []) unless @viewsByModel.has(model)
      @viewsByModel.get(model).push(view)
      view
    else
      throw new Error("No view found for model of class #{model.constructor.name}")

  find: (model) ->
    @viewsByModel.get(model)?[0]

  findOrCreate: (model, context) ->
    @find(model) ? @create(model)

  remove: (model, view) ->
    if viewsForModel = @viewsByModel.get(model)
      remove(viewsForModel, view)
