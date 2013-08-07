require 'window'

measure 'spec suite require time', ->
  fsUtils = require 'fs-utils'
  path = require 'path'
  require 'spec-helper'

  # Run core specs
  for specPath in fsUtils.listTreeSync(fsUtils.resolveOnLoadPath("spec")) when /-spec\.coffee$/.test specPath
    require specPath

  spec.coreSpec = true for spec in jasmine.getEnv().currentRunner().specs()

  # Run extension specs
  for packageDirPath in config.packageDirPaths
    for packagePath in fsUtils.listSync(packageDirPath)
      for specPath in fsUtils.listTreeSync(path.join(packagePath, "spec")) when /-spec\.coffee$/.test specPath
        require specPath
