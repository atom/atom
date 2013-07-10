require 'atom'
require 'window'

{exec} = require 'child_process'
fs = require 'fs'
remote = require 'remote'
path = require 'path'
url = require 'url'
$ = require 'jquery'
temp = require 'temp'
{$$} = require 'space-pen'
Git = require 'git'
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
  branch = atom.guestSession.repository.get('branch')
  [repoName] = url.parse(repoUrl).path.split('/')[-1..]
  repoName = repoName.replace(/\.git$/, '')
  repoPath = path.join(remote.require('app').getHomeDir(), 'github', repoName)
  git = new Git(repoPath)

  # clone or fetch
  # abort if working directory is unclean

  # apply bundle of unpushed changes from host
  {unpushedChanges, head} = atom.guestSession.repositoryDelta
  if unpushedChanges
    tempFile = temp.path(suffix: '.bundle')
    fs.writeFileSync(tempFile, new Buffer(atom.guestSession.repositoryDelta.unpushedChanges, 'base64'))
    command = "git bundle unbundle #{tempFile}"
    exec command, {cwd: repoPath}, (error, stdout, stderr) ->
      if error?
        console.error error
        return

      if git.hasBranch(branch)
        if git.getAheadBehindCount(branch).ahead is 0
          command = "git checkout #{branch} && git reset --hard #{head}"
          exec command, {cwd: repoPath}, (error, stdout, stderr) ->
            if error?
              console.error error
              return
        else
          # prompt for new branch name
          # create branch at head
      else
        # create branch at head

  # create branch if it doesn't exist
  # prompt for branch name if branch already exists and it cannot be fast-forwarded
  # checkout branch
  # sync modified and untracked files from host session

  atom.getLoadSettings().initialPath = repoPath

atom.guestSession = new GuestSession(sessionId)
atom.guestSession.on 'started', ->
  syncRepositoryState()
  loadingView.remove()
  window.startEditorWindow()
