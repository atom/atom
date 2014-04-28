# Notice: You should also commit the compiled script/download-node.js if you
# have changed this file.
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
  arch = if process.arch == 'ia32' then 'x86' else process.arch
  subDir = "node-#{version}-#{process.platform}-#{arch}"
  fromPath = path.join(fromDirectory, subDir, 'bin', 'node')
  fs.rename(fromPath, targetFilename, callback)

downloadNode = (version, done) ->
  if process.platform is 'win32'
    arch = if process.arch is 'x64' then 'x64/' else ''
    downloadURL = "http://nodejs.org/dist/#{version}/#{arch}node.exe"
    filename = path.join('bin', "node.exe")
  else
    arch = if process.arch == 'ia32' then 'x86' else process.arch
    downloadURL = "http://nodejs.org/dist/#{version}/node-#{version}-#{process.platform}-#{arch}.tar.gz"
    filename = path.join('bin', "node")

  if fs.existsSync(filename)
    done()
    return

  if process.platform is 'win32'
    downloadFileToLocation(downloadURL, filename, done)
  else
    next = copyNodeBinToLocation.bind(this, done, version, filename)
    downloadTarballAndExtract(downloadURL, filename, next)

downloadNode 'v0.10.26', (error) ->
  if error?
    console.error('Failed to download node', error)
    process.exit(1)
  else
    process.exit(0)
