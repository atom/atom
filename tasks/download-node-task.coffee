fs = require 'fs'
zlib = require 'zlib'
path = require 'path'

request = require 'request'
tar = require 'tar'
temp = require 'temp'

temp.track()

downloadFileToLocation = (url, filename, callback) ->
  stream = fs.createWriteStream(filename)
  stream.on('end', callback)
  stream.on('error', callback)
  request(url).pipe(stream)

downloadTarballAndExtract = (url, location, callback) ->
  tempPath = temp.mkdirSync('apm-node-')
  stream = tar.Extract(path: tempPath)
  stream.on('end', callback.bind(this, tempPath))
  stream.on('error', callback)
  request(url).pipe(zlib.createGunzip()).pipe(stream)

copyNodeBinToLocation = (callback, version, targetFilename, fromDirectory) ->
  subDir = "node-#{version}-#{process.platform}-#{process.arch}"
  fromPath = path.join(fromDirectory, subDir, 'bin', 'node')
  fs.rename(fromPath, targetFilename, callback)

module.exports = (grunt) ->
  grunt.registerTask 'node', 'Download node binary', ->
    @requiresConfig("#{@name}.version")
    done = @async()

    {version} = grunt.config(@name)
    if process.platform is 'win32'
      arch = if process.arch is 'x64' then 'x64/' else ''
      downloadURL = "http://nodejs.org/dist/#{version}/#{arch}node.exe"
      filename = path.join('bin', "node_win32_#{process.arch}.exe")
    else
      downloadURL = "http://nodejs.org/dist/#{version}/node-#{version}-#{process.platform}-#{process.arch}.tar.gz"
      filename = path.join('bin', "node_#{process.platform}_#{process.arch}")

    if fs.existsSync(filename)
      done()
      return

    if process.platform is 'win32'
      downloadFileToLocation(downloadURL, filename, done)
    else
      next = copyNodeBinToLocation.bind(this, done, version, filename)
      downloadTarballAndExtract(downloadURL, filename, next)
