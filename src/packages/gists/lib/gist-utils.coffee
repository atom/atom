path = require 'path'
request = require 'request'
keytar = require 'keytar'
GitHub = require 'github'
fsUtils = require 'fs-utils'

gistsDir = path.join(config.configDirPath, '.gists')

logError = (message, error) ->
  console.error(message, error.stack ? error)

createClient = (token) ->
  client = new GitHub(version: '3.0.0')
  if token = keytar.getPassword('github.com', 'github')
    client.authenticate({type: 'oauth', token})
  client

openGistFile = (gist, file) ->
  request file.raw_url, (error, response, body) =>
    if error?
      logError("Error fetching Gist file contents", error)
      return

    gistFilePath = path.join(gistsDir, gist.id, file.filename)
    fsUtils.writeAsync gistFilePath, body, (error) =>
      if error?
        logError("Error writing to #{gistFilePath}", error)
      else
        rootView.open(gistFilePath)

createPageIterator = (client, callback) ->
  (error, gists) ->
    if error?
      callback(error)
    else
      hasMorePages = client.hasNextPage(gists)
      callback(null, gists, hasMorePages)
      client.getNextPage(gists, getNextPage) if hasMorePages

getAllGists = (callback) ->
  client = createClient()
  client.gists.getAll({per_page: 100}, createPageIterator(client, callback))

getStarredGists = (callback) ->
  client = createClient()
  client.gists.starred({per_page: 100}, createPageIterator(client, callback))

createGist = (gist, callback) ->
  createClient().gists.create(gist, callback)

module.exports = {openGistFile, getAllGists, getStarredGists, createGist}
