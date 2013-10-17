temp = require 'temp'
Git = require '../src/git'
{fs} = require 'atom'
path = require 'path'
Task = require '../src/task'

describe "Git", ->
  repo = null

  beforeEach ->
    fs.remove('/tmp/.git') if fs.isDirectorySync('/tmp/.git')

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
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'master.git', 'HEAD'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

    it "returns the repository path for a repository path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'master.git'))
      expect(repo.getPath()).toBe path.join(__dirname, 'fixtures', 'git', 'master.git')

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, filePath, newPath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      newPath = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'new-path.txt')
      originalPathText = fs.read(filePath)

    afterEach ->
      fs.writeSync(filePath, originalPathText)
      fs.remove(newPath) if fs.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(filePath)).toBeFalsy()

      it "returns true if the path is modified", ->
        fs.writeSync(filePath, "change")
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fs.remove(filePath)
        expect(repo.isPathModified(filePath)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [filePath, newPath] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      newPath = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'new-path.txt')
      fs.writeSync(newPath, "i'm new here")

    afterEach ->
      fs.remove(newPath) if fs.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(filePath)).toBeFalsy()

  describe ".checkoutHead(path)", ->
    [path1, path2, originalPath1Text, originalPath2Text] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      path1 = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPath1Text = fs.read(path1)
      path2 = require.resolve('./fixtures/git/working-dir/other.txt')
      originalPath2Text = fs.read(path2)

    afterEach ->
      fs.writeSync(path1, originalPath1Text)
      fs.writeSync(path2, originalPath2Text)

    it "no longer reports a path as modified after checkout", ->
      expect(repo.isPathModified(path1)).toBeFalsy()
      fs.writeSync(path1, '')
      expect(repo.isPathModified(path1)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(repo.isPathModified(path1)).toBeFalsy()

    it "restores the contents of the path to the original text", ->
      fs.writeSync(path1, '')
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fs.read(path1)).toBe(originalPath1Text)

    it "only restores the path specified", ->
      fs.writeSync(path2, 'path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()
      expect(repo.checkoutHead(path1)).toBeTruthy()
      expect(fs.read(path2)).toBe('path 2 is edited')
      expect(repo.isPathModified(path2)).toBeTruthy()

    it "fires a status-changed event if the checkout completes successfully", ->
      fs.writeSync(path1, '')
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
      repo = new Git(require.resolve('./fixtures/git/master.git/HEAD'))
      repo.destroy()
      expect(-> repo.getShortHead()).toThrow()

  describe ".getDiffStats(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPathText = fs.read(filePath)

    afterEach ->
      fs.writeSync(filePath, originalPathText)

    it "returns the number of lines added and deleted", ->
      expect(repo.getDiffStats(filePath)).toEqual {added: 0, deleted: 0}
      fs.writeSync(filePath, "#{originalPathText} edited line")
      expect(repo.getDiffStats(filePath)).toEqual {added: 1, deleted: 1}

  describe ".getPathStatus(path)", ->
    [filePath, originalPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      filePath = require.resolve('./fixtures/git/working-dir/file.txt')
      originalPathText = fs.read(filePath)

    afterEach ->
      fs.writeSync(filePath, originalPathText)

    it "trigger a status-changed event when the new status differs from the last cached one", ->
      statusHandler = jasmine.createSpy("statusHandler")
      repo.on 'status-changed', statusHandler
      fs.writeSync(filePath, '')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler.argsForCall[0][0..1]).toEqual [filePath, status]

      fs.writeSync(filePath, 'abc')
      status = repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe 1

  describe ".refreshStatus()", ->
    [newPath, modifiedPath, cleanPath, originalModifiedPathText] = []

    beforeEach ->
      repo = new Git(path.join(__dirname, 'fixtures', 'git', 'working-dir'))
      modifiedPath = project.resolve('git/working-dir/file.txt')
      originalModifiedPathText = fs.read(modifiedPath)
      newPath = project.resolve('git/working-dir/untracked.txt')
      cleanPath = project.resolve('git/working-dir/other.txt')
      fs.writeSync(newPath, '')

    afterEach ->
      fs.writeSync(modifiedPath, originalModifiedPathText)
      fs.remove(newPath) if fs.exists(newPath)

    it "returns status information for all new and modified files", ->
      fs.writeSync(modifiedPath, 'making this path modified')
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
      fs.writeSync(editSession.getPath(), originalContent)

    it "emits a status-changed event", ->
      editSession = project.openSync('sample.js')
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
      fs.writeSync(editSession.getPath(), originalContent)

    it "emits a status-changed event", ->
      editSession = project.openSync('sample.js')
      originalContent = editSession.getText()
      fs.writeSync(editSession.getPath(), 'changed')

      statusHandler = jasmine.createSpy('statusHandler')
      project.getRepo().on 'status-changed', statusHandler
      editSession.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1
      expect(statusHandler).toHaveBeenCalledWith editSession.getPath(), 256
      editSession.getBuffer().reload()
      expect(statusHandler.callCount).toBe 1

  describe "when a project is deserialized", ->
    [originalContent, buffer, project2] = []

    afterEach ->
      fs.writeSync(buffer.getPath(), originalContent)
      project2?.destroy()

    it "subscribes to all the serialized buffers in the project", ->
      project.openSync('sample.js')
      project2 = deserialize(project.serialize())
      buffer = project2.getBuffers()[0]

      waitsFor ->
        buffer.loaded

      runs ->
        originalContent = buffer.getText()
        buffer.append('changes')

        statusHandler = jasmine.createSpy('statusHandler')
        project2.getRepo().on 'status-changed', statusHandler
        buffer.save()
        expect(statusHandler.callCount).toBe 1
        expect(statusHandler).toHaveBeenCalledWith buffer.getPath(), 256
