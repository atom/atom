ConfigPanel = require 'config-panel'
PackageConfigView = require 'package-config-view'
{$$} = require 'space-pen'
$ = require 'jquery'
{spawn} = require 'child_process'
roaster = require 'roaster'
async = require 'async'

###
# Internal #
###

module.exports =
class AvailablePackagesConfigPanel extends ConfigPanel
  @content: ->
    @div id: 'available-packages', =>
      @legend 'Available Packages'

  initialize: ->
    apm = require.resolve '.bin/apm'
    apmProcess = spawn(apm, ['available', '--json'])
    chunks = []
    apmProcess.stdout.on 'data', (chunk) -> chunks.push(chunk)
    apmProcess.on 'close', (code) =>
      if code is 0
        try
          packages = JSON.parse(Buffer.concat(chunks).toString()) ? []
        catch error
          packages = []
          console.error(error.stack ? error)

        if packages.length > 0
          queue = async.queue (pack, callback) ->
            roaster pack.description, {}, (error, html) ->
              pack.descriptionHtml = html
              roaster pack.readme, {}, (error, html) ->
                pack.readmeHtml = html
                callback()
          queue.push(pack) for pack in packages
          queue.drain =  =>
            for pack in packages
              @append(new PackageConfigView(pack, @operationQueue))
