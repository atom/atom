fs = require 'fs'
{exec} = require 'child_process'

inputFile = process.argv[2]
unless inputFile?.length > 0
  console.error("Input file must be first argument")
  process.exit(1)

outputFile = process.argv[3]
unless outputFile?.length > 0
  console.error("Output file must be second arguments")
  process.exit(1)

contents = fs.readFileSync(inputFile)?.toString() ? ''
exec "node_modules/.bin/coffee -bcp #{inputFile}", (error, stdout, stderr) ->
  if error
    console.error(error)
    process.exit(1)
  json = eval(stdout.toString()) ? {}
  if json isnt Object(json)
    console.error("CSON file does not contain valid JSON")
    process.exit(1)
  fs.writeFileSync(outputFile, JSON.stringify(json, null, 2))
