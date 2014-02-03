path = require 'path'

optimist = require 'optimist'

Command = require './command'
fs = require './fs'

module.exports =
class Init extends Command
  @commandNames: ['init']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage:
        apm init -p <package-name>
        apm init -t <theme-name>
        apm init -t <theme-name> --convert ~/Downloads/Dawn.thTheme

      Generates code scaffolding for either a theme or package depending
      on option selected.
    """
    options.alias('p', 'package').string('package').describe('package', 'Generates a basic package')
    options.alias('t', 'theme').string('theme').describe('theme', 'Generates a basic theme')
    options.alias('c', 'convert').string('convert').describe('convert', 'Path to TextMate theme to convert')
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    if options.argv.convert
      sourcePath = path.resolve(options.argv.convert)
      @convertTheme(sourcePath, options.argv.theme, callback)
    else if options.argv.package?
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
      callback('You must specify either --package or --theme to `apm init`')

  convertTheme: (sourcePath, destinationPath, callback) ->
    unless fs.isFileSync(sourcePath)
      callback("TextMate theme file not found: #{sourcePath}")
      return

    if destinationPath
      destinationPath = path.resolve(destinationPath)
    else
      callback("Specify directory to create theme in using --theme")
      return

    templatePath = path.resolve(__dirname, '..', 'templates', 'theme')
    @generateFromTemplate(destinationPath, templatePath)

    fs.removeSync(path.join(destinationPath, 'stylesheets'))

    TextMateTheme = require './text-mate-Theme'
    theme = new TextMateTheme(sourcePath)
    fs.writeFileSync(path.join(destinationPath, 'index.less'), theme.getStylesheet())
    callback()

  generateFromTemplate: (packagePath, templatePath) ->
    packageName = path.basename(packagePath)

    fs.makeTreeSync(packagePath)

    for childPath in fs.listRecursive(templatePath)
      templateChildPath = path.resolve(templatePath, childPath)
      relativePath = templateChildPath.replace(templatePath, "")
      relativePath = relativePath.replace(/^\//, '')
      relativePath = relativePath.replace(/\.template$/, '')
      relativePath = @replacePackageNamePlaceholders(relativePath, packageName)

      sourcePath = path.join(packagePath, relativePath)
      if fs.isDirectorySync(templateChildPath)
        fs.makeTreeSync(sourcePath)
      else if fs.isFileSync(templateChildPath)
        fs.makeTreeSync(path.dirname(sourcePath))
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
