path = require 'path'
{Site} = require 'telepath'
{fs} = require 'atom'
Project = require '../src/project'

module.exports =
class Environment
  constructor: ({@site, @state, siteId, projectPath}={}) ->
    @site ?= new Site(siteId ? 1)
    if @state?
      @run => @project = deserialize(@state.get('project'))
    else
      @state = @site.createDocument({})
      @project = new Project(projectPath ? path.join(__dirname, 'fixtures'))
      @state.set(project: @project.getState())

  clone: (params) ->
    site = new Site(params.siteId)
    new Environment(site: site, state: @state.clone(site))

  destroy: ->
    @project.destroy()

  getState: -> @state

  run: (fn) ->
    uninstall = @install()
    fn()
    uninstall()

  install: ->
    oldSite = window.site
    oldProject = window.project
    window.site = @site
    window.project = @project
    ->
      window.site = oldSite
      window.project = oldProject

  connect: (otherEnv) ->
    new EnvironmentConnection(this, otherEnv)


  connectDocuments: (docA, docB, envB) ->

class EnvironmentConnection
  constructor: (@envA, @envB) ->
    @envA.getState().connect(@envB.getState())

  connect: (docA, docB) ->
    unless docA.site is @envA.site
      throw new Error("Document and environment sites do not match (doc: site #{docA.site.id}, env: site #{@envA.site.id})")
    unless docB.site is @envB.site
      throw new Error("Document and environment sites do not match (doc: site #{docB.site.id}, env: site #{@envB.site.id})")

    connection = docA.connect(docB)
    connection.abFilter = (fn) => @envB.run(fn)
    connection.baFilter = (fn) => @envA.run(fn)
    connection
