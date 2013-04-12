Git = require 'git'
fsUtils = require 'fs-utils'
Task = require 'task'

describe "Git", ->
  repo = null

  beforeEach ->
    fsUtils.remove('/tmp/.git') if fsUtils.isDirectory('/tmp/.git')

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

  describe ".getHead()", ->
    it "returns a branch name for a non-empty repository", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/master.git'))
      expect(repo.getHead()).toBe 'refs/heads/master'

  describe ".getShortHead()", ->
    it "returns a branch name for a non-empty repository", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/master.git'))
      expect(repo.getShortHead()).toBe 'master'

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, path, newPath, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      newPath = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'new-path.txt')
      originalPathText = fsUtils.read(path)

    afterEach ->
      fsUtils.write(path, originalPathText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(path)).toBeFalsy()

      it "returns true if the path is modified", ->
        fsUtils.write(path, "change")
        expect(repo.isPathModified(path)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fsUtils.remove(path)
        expect(repo.isPathModified(path)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [path, newPath] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      newPath = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'new-path.txt')
      fsUtils.write(newPath, "i'm new here")

    afterEach ->
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(path)).toBeFalsy()

  describe ".checkoutHead(path)", ->
    [path1, path2, originalPath1Text, originalPath2Text] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path1 = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPath1Text = fsUtils.read(path1)
      path2 = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/other.txt')
      originalPath2Text = fsUtils.read(path2)

    afterEach ->
      fsUtils.write(path1, originalPath1Text)
      fsUtils.write(path2, originalPath2Text)

    it "no longer reports a path as modified after checkout", ->
      expect(repo.isPathModified(path1)).toBeFalsy()
      fsUtils.write(path1, '')
      expect(repo.isPathModified(path1)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(repo.isPathModified(path1)).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fsUtils.write(path1, '')
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fsUtils.read(path1)).toBe(originalPath1Text)

    it "only restores the path specified", ->
      fsUtils.write(path2, 'path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fsUtils.read(path2)).toBe('path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()

    it "fires a status-changed event if the checkout completes successfully", ->
      fsUtils.write(path1, '')
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
      expect(-> repo.getHead()).toThrow()

  describe ".getDiffStats(path)", ->
    [path, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPathText = fsUtils.read(path)

    afterEach ->
      fsUtils.write(path, originalPathText)

    it "returns the number of lines added and deleted", ->
      expect(repo.getDiffStats(path)).toEqual {added: 0, deleted: 0}
      fsUtils.write(path, "#{originalPathText} edited line")
      expect(repo.getDiffStats(path)).toEqual {added: 1, deleted: 1}

  describe ".getPathStatus(path)", ->
    [path, originalPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      path = fsUtils.resolveOnLoadPath('fixtures/git/working-dir/file.txt')
      originalPathText = fsUtils.read(path)

    afterEach ->
      fsUtils.write(path, originalPathText)

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.on 'status-changed', statusHandler
      fsUtils.write(path, '')
      status = repo.getPathStatus(path)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [path, status]

      fsUtils.write(path, 'abc')
      status = repo.getPathStatus(path)
      expect(statusHandler.callCount).toBe 1

  describe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, originalModifiedPathText] = []

    beforeEach ->
      repo = new Git(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
      modifiedPath = project.resolve('git/working-dir/file.txt')
      originalModifiedPathText = fsUtils.read(modifiedPath)
      newPath = project.resolve('git/working-dir/untracked.txt')
      cleanPath = project.resolve('git/working-dir/other.txt')
      fsUtils.write(newPath, '')

    afterEach ->
      fsUtils.write(modifiedPath, originalModifiedPathText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    it "returns status information for all new and modified files", ->
      fsUtils.write(modifiedPath, 'making this path modified')
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

    it "only starts a single web worker at a time and schedules a restart if one is already running", =>
      fsUtils.write(modifiedPath, 'making this path modified')
      statusHandler = jasmine.createSpy('statusHandler')
      repo.on 'statuses-changed', statusHandler

      spyOn(Task.prototype, "start").andCallThrough()
      repo.refreshStatus()
      expect(Task.prototype.start.callCount).toBe 1
      repo.refreshStatus()
      expect(Task.prototype.start.callCount).toBe 1
      repo.refreshStatus()
      expect(Task.prototype.start.callCount).toBe 1

      waitsFor ->
        statusHandler.callCount > 0

      runs ->
        expect(Task.prototype.start.callCount).toBe 2
