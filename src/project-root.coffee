# A root folder of {Project}.
#
module.exports =
class ProjectRoot
  constructor: (@directory, @repo) ->

  # Public: Returns the {Directory} that corresponds to the project root.
  getDirectory: -> @directory

  # Public: Returns the {GitRepository} for the project root or {null}.
  getRepository: -> @repo

  destroy: ->
    @directory.off()
    @destroyRepo()

  destroyRepo: ->
    if @repo
      @repo.destroy()
      @repo = null
