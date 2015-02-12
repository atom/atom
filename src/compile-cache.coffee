path = require 'path'
CSON = require 'season'
CoffeeCache = require 'coffee-cash'
to5 = require './6to5'

# This file is required directly by apm so that files can be cached during
# package install so that the first package load in Atom doesn't have to
# compile anything.
exports.addPathToCache = (filePath, atomHome) ->
  atomHome ?= process.env.ATOM_HOME
  cacheDir = path.join(atomHome, 'compile-cache')
  # Use separate compile cache when sudo'ing as root to avoid permission issues
  if process.env.USER is 'root' and process.env.SUDO_USER and process.env.SUDO_USER isnt process.env.USER
    cacheDir = path.join(cacheDir, 'root')

  CoffeeCache.setCacheDirectory(path.join(cacheDir, 'coffee'))
  CSON.setCacheDir(path.join(cacheDir, 'cson'))
  to5.setCacheDirectory(path.join(cacheDir, 'js', '6to5'))

  switch path.extname(filePath)
    when '.coffee'
      CoffeeCache.addPathToCache(filePath)
    when '.cson'
      CSON.readFileSync(filePath)
    when '.js'
      to5.addPathToCache(filePath)
