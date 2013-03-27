# Hack since the vendored less is in browser mode
global.window = {}
global.document =
  getElementsByTagName: -> []
global.location =
  port: 80

{less} = require '../vendor/less'
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
(new less.Parser).parse contents, (e, tree) ->
  console.error(e.stack or e) if e
  process.exit(1) if e
  fs.writeFileSync(outputFile, tree.toCSS())
