path = require 'path'

optimist = require 'optimist'

Command = require './command'
fs = require './fs'

module.exports =
class Generator extends Command
  @commandNames: ['init']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage:
        apm init -p <package-name>
        apm init -t <theme-name>

      Generates code scaffolding for either a theme or package depending
      on option selected.
    """
    options.alias('p', 'package').describe('package', 'Generates a basic package')
    options.alias('t', 'theme').describe('theme', 'Generates a basic theme')
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    if options.argv.package?
      packagePath = path.resolve(options.argv.package)
      templatePath = path.resolve(__dirname, '..', 'templates', 'package')
      @generateFromTemplate(packagePath, templatePath)
      callback()
    else if options.argv.theme?
      themePath = path.resolve(options.argv.theme)
      templatePath = path.resolve(__dirname, '..', 'templates', 'theme')
      @generateFromTemplate(themePath, templatePath)
      callback()
    else
      callback('Error: You must specify either --package or --theme to `apm init`')

  generateFromTemplate: (packagePath, templatePath) ->
    packageName = path.basename(packagePath)

    fs.mkdir(packagePath)

    for childPath in fs.listRecursive(templatePath)
      templateChildPath = path.resolve(templatePath, childPath)
      relativePath = templateChildPath.replace(templatePath, "")
      relativePath = relativePath.replace(/^\//, '')
      relativePath = relativePath.replace(/\.template$/, '')
      relativePath = @replacePackageNamePlaceholders(relativePath, packageName)

      sourcePath = path.join(packagePath, relativePath)
      if fs.isDirectory(templateChildPath)
        fs.mkdir(sourcePath)
      else if fs.isFile(templateChildPath)
        fs.mkdir(path.dirname(sourcePath))
        contents = fs.readFileSync(templateChildPath).toString()
        content = @replacePackageNamePlaceholders(contents, packageName)
        fs.writeFileSync(sourcePath, content)

  replacePackageNamePlaceholders: (string, packageName) ->
    placeholderRegex = /__(?:(package-name)|([pP]ackageName)|(package_name))__/g
    string = string.replace placeholderRegex, (match, dash, camel, underscore) =>
      if dash
        @dasherize(packageName)
      else if camel
        if /[a-z]/.test(camel[0])
          packageName = packageName[0].toLowerCase() + packageName[1...]
        else if /[A-Z]/.test(camel[0])
          packageName = packageName[0].toUpperCase() + packageName[1...]
        @camelize(packageName)

      else if underscore
        @underscore(packageName)

  dasherize: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(_)/g, (m, letter, underscore) ->
      if letter
        "-" + letter.toLowerCase()
      else
        "-"

  camelize: (string) ->
    string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()

  underscore: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(-)/g, (m, letter, dash) ->
      if letter
        "_" + letter.toLowerCase()
      else
        "_"
