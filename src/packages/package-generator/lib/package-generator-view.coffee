{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fsUtils = require 'fs-utils'
path = require 'path'

module.exports =
class PackageGeneratorView extends View
  previouslyFocusedElement: null

  @content: ->
    @div class: 'package-generator overlay from-top', =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'error', outlet: 'error'
      @div class: 'message', outlet: 'message'

  initialize: ->
    rootView.command "package-generator:generate", => @attach()
    @miniEditor.on 'focusout', => @detach()
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @message.text("Enter package path")
    placeholderName = "package-name"
    @miniEditor.setText(path.join(config.userPackagesDirPath, placeholderName))
    pathLength = @miniEditor.getText().length
    @miniEditor.setSelectedBufferRange([[0, pathLength - placeholderName.length], [0, pathLength]])

    rootView.append(this)
    @miniEditor.focus()

  detach: ->
    return unless @hasParent()
    @previouslyFocusedElement?.focus()
    super

  confirm: ->
    if @validPackagePath()
      @createPackageFiles()
      atom.open(@getPackagePath())
      @detach()

  getPackagePath: ->
    packagePath = @miniEditor.getText()
    packageName = _.dasherize(path.basename(packagePath))
    path.join(path.dirname(packagePath), packageName)

  validPackagePath: ->
    if fsUtils.exists(@getPackagePath())
      @error.text("Path already exists at '#{@getPackagePath()}'")
      @error.show()
      false
    else
      true

  createPackageFiles: ->
    templatePath = fsUtils.resolveOnLoadPath(path.join("package-generator", "template"))
    packageName = path.basename(@getPackagePath())

    for templateChildPath in fsUtils.listTree(templatePath)
      relativePath = templateChildPath.replace(templatePath, "")
      relativePath = relativePath.replace(/^\//, '')
      relativePath = relativePath.replace(/\.template$/, '')
      relativePath = @replacePackageNamePlaceholders(relativePath, packageName)

      sourcePath = path.join(@getPackagePath(), relativePath)
      if fsUtils.isDirectorySync(templateChildPath)
        fsUtils.makeTree(sourcePath)
      if fsUtils.isFile(templateChildPath)
        fsUtils.makeTree(path.dirname(sourcePath))
        content = @replacePackageNamePlaceholders(fsUtils.read(templateChildPath), packageName)
        fsUtils.write(sourcePath, content)

  replacePackageNamePlaceholders: (string, packageName) ->
    placeholderRegex = /__(?:(package-name)|([pP]ackageName)|(package_name))__/g
    string = string.replace placeholderRegex, (match, dash, camel, underscore) ->
      if dash
        _.dasherize(packageName)
      else if camel
        if /[a-z]/.test(camel[0])
          packageName = packageName[0].toLowerCase() + packageName[1...]
        else if /[A-Z]/.test(camel[0])
          packageName = packageName[0].toUpperCase() + packageName[1...]
        _.camelize(packageName)

      else if underscore
        _.underscore(packageName)
