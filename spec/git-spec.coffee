Git = require 'git'
fsUtils = require 'fs-utils'
path = require 'path'
Task = require 'task'

describe "Git", ->
  repo = null

  beforeEach ->
    fsUtils.remove('/tmp/.git') if fsUtils.isDirectorySync('/tmp/.git')

  afterEach ->
    repo.destroy() if repo?.repo?

  describe "@open(path)", ->
    it "returns null when no repository is found", ->
      expect(Git.open('/tmp/nogit.txt')).toBeNull()

  describe "new Git(path)", ->
    it "throws an exception when no repository is found", ->
      expect(-> new Git('/tmp/nogit.txt')).toThrow()

  describe ".getPath()", ->
    it "returns the repository path for a .git directory path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/master.git/HEAD'))
      expect(repo.getPath()).toBe fsUtils.resolveOnLoadPath('fixtures/git/master.git')

    it "returns the repository path for a repository path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/master.git'))
      expect(repo.getPath()).toBe fsUtils.resolveOnLoadPath('fixtures/git/master.git')

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, filePath, newPath, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      filePath = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      newPath = path.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'new-path.txt')
      originalPathText = fsUtils.read(filePath)

    afterEach ->
      fsUtils.writeSync(filePath, originalPathText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(filePath)).toBeFalsy()

      it "returns true if the path is modified", ->
        fsUtils.writeSync(filePath, "change")
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fsUtils.remove(filePath)
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [filePath, newPath] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      filePath = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      newPath = path.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'new-path.txt')
      fsUtils.writeSync(newPath, "i'm new here")

    afterEach ->
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(filePath)).toBeFalsy()

  describe ".checkoutHead(path)", ->
    [path1, path2, originalPath1Text, originalPath2Text] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path1 = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPath1Text = fsUtils.read(path1)
      path2 = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/other.txt')
      originalPath2Text = fsUtils.read(path2)

    afterEach ->
      fsUtils.writeSync(path1, originalPath1Text)
      fsUtils.writeSync(path2, originalPath2Text)

    it "no longer reports a path as modified after checkout", ->
      expect(repo.isPathModified(path1)).toBeFalsy()
      fsUtils.writeSync(path1, '')
      expect(repo.isPathModified(path1)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(repo.isPathModified(path1)).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fsUtils.writeSync(path1, '')
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fsUtils.read(path1)).toBe(originalPath1Text)

    it "only restores the path specified", ->
      fsUtils.writeSync(path2, 'path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fsUtils.read(path2)).toBe('path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()

    it "fires a status-changed event if the checkout completes successfully", ->
      fsUtils.writeSync(path1, '')
      repo.getPathStatus(path1)
      statusHandler = jasmine.createSpy('statusHandler')
      repo.on 'status-changed', statusHandler
      repo.checkoutHead(path1)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [path1, 0]

      repo.checkoutHead(path1)
      expect(statusHandler.callCount).toBe 1

  describe ".destroy()", ->
    it "throws an exception when any method is called after it is called", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/master.git/HEAD'))
      repo.destroy()
      expect(-> repo.getShortHead()).toThrow()

  describe ".getDiffStats(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      filePath = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPathText = fsUtils.read(filePath)

    afterEach ->
      fsUtils.writeSync(filePath, originalPathText)

    it "returns the number of lines added and deleted", ->
      expect(repo.getDiffStats(filePath)).toEqual {added: 0, deleted: 0}
      fsUtils.writeSync(filePath, "#{originalPathText} edited line")
      expect(repo.getDiffStats(filePath)).toEqual {added: 1, deleted: 1}

  describe ".getPathStatus(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      filePath = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPathText = fsUtils.read(filePath)

    afterEach ->
      fsUtils.writeSync(filePath, originalPathText)

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.on 'status-changed', statusHandler
      fsUtils.writeSync(filePath, '')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [filePath, status]

      fsUtils.writeSync(filePath, 'abc')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1

  describe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, originalModifiedPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      modifiedPath = project.resolve('git/working-dir/file.txt')
      originalModifiedPathText = fsUtils.read(modifiedPath)
      newPath = project.resolve('git/working-dir/untracked.txt')
      cleanPath = project.resolve('git/working-dir/other.txt')
      fsUtils.writeSync(newPath, '')

    afterEach ->
      fsUtils.writeSync(modifiedPath, originalModifiedPathText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    it "returns status information for all new and modified files", ->
      fsUtils.writeSync(modifiedPath, 'making this path modified')
      statusHandler = jasmine.createSpy('statusHandler')
      repo.on 'statuses-changed', statusHandler
      repo.refreshStatus()

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        statuses = repo.statuses
        expect(statuses[cleanPath]).toBeUndefined()
        expect(repo.isStatusNew(statuses[newPath])).toBeTruthy()
        expect(repo.isStatusModified(statuses[modifiedPath])).toBeTruthy()

  describe "when a buffer is changed and then saved", ->
    [originalContent, editSession] = []

    afterEach ->
      fsUtils.writeSync(editSession.getPath(), originalContent)

    it "emits a status-changed event", ->
      editSession = project.open('sample.js')
      originalContent = editSession.getText()
      editSession.insertNewline()

      statusHandler = jasmine.createSpy('statusHandler')
      project.getRepo().on 'status-changed', statusHandler
      editSession.save()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editSession.getPath(), 256

  describe "when a buffer is reloaded and has been changed", ->
    [originalContent, editSession] = []

    afterEach ->
      fsUtils.writeSync(editSession.getPath(), originalContent)

    it "emits a status-changed event", ->
      editSession = project.open('sample.js')
      originalContent = editSession.getText()
      fsUtils.writeSync(editSession.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      project.getRepo().on 'status-changed', statusHandler
      editSession.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editSession.getPath(), 256
      editSession.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1
