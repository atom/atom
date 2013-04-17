# Hack since the vendored less is in browser mode
global.window = {}
global.document =
  getElementsByTagName: -> []
global.location =
  port: 80

less = require 'less'
fs = require 'fs'

inputFile = process.argv[2]
unless inputFile?.length > 0
  console.error("Input file must be first argument")
  process.exit(1)

outputFile = process.argv[3]
unless outputFile?.length > 0
  console.error("Output file must be second argument")
  process.exit(1)

contents = fs.readFileSync(inputFile)?.toString() ? ''

parser = new less.Parser
  syncImport: true
  paths: [fs.realpathSync("#{__dirname}/../static"), fs.realpathSync("#{__dirname}/../vendor")]
  filename: inputFile

logErrorAndExit = (e) ->
  console.error("Error compiling less file '#{inputFile}':", e.message)
  process.exit(1)

parser.parse contents, (e, tree) ->
  logErrorAndExit(e) if e
  try
    fs.writeFileSync(outputFile, tree.toCSS())
  catch e
    logErrorAndExit(e)
