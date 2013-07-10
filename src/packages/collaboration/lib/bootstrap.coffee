remote = require 'remote'
path = require 'path'
url = require 'url'
require 'atom'
require 'window'
$ = require 'jquery'
{$$} = require 'space-pen'
GuestSession = require './guest-session'

window.setDimensions(width: 350, height: 100)
window.setUpEnvironment('editor')
{sessionId} = atom.getLoadSettings()

loadingView = $$ ->
  @div style: 'margin: 10px; text-align: center', =>
    @div "Joining session #{sessionId}"
$(window.rootViewParentSelector).append(loadingView)
atom.show()

syncRepositoryState = ->
  repoUrl = atom.guestSession.repository.get('url')
  [repoName] = url.parse(repoUrl).path.split('/')[-1..]
  repoName = repoName.replace(/\.git$/, '')
  repoPath = path.join(remote.require('app').getHomeDir(), 'github', repoName)

  # clone if missing
  # abort if working directory is unclean
  # apply bundle of unpushed changes from host
  # prompt for branch name if branch already exists and is cannot be fast-forwarded
  # checkout branch
  # sync modified and untracked files from host session

  atom.getLoadSettings().initialPath = repoPath

atom.guestSession = new GuestSession(sessionId)
atom.guestSession.on 'started', ->
  syncRepositoryState()
  loadingView.remove()
  window.startEditorWindow()
