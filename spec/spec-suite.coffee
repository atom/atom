fs = require 'fs-plus'
specDirectory = atom.getLoadSettings().specDirectory

for specFilePath in fs.listTreeSync(specDirectory)
  require(specFilePath) if /-spec\.(coffee|js)$/.test(specFilePath)
