{isTheme, isPackageSet, isPackage} = require '../src/metadata-helpers'

describe 'Metadata Helpers', ->
  [metadata] = []
  beforeEach ->
    metadata = null

  describe 'when the metadata is a legacy package', ->
    beforeEach ->
      metadata =
        name: "test-package"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a package', ->
      expect(isPackage(metadata)).toBe(true)
      expect(isTheme(metadata)).toBe(false)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata is from a current package', ->
    beforeEach ->
      metadata =
        name: "test-package"
        type: "package"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a package', ->
      expect(isPackage(metadata)).toBe(true)
      expect(isTheme(metadata)).toBe(false)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata is from a legacy theme', ->
    beforeEach ->
      metadata =
        name: "test-package"
        theme: true
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a theme', ->
      expect(isPackage(metadata)).toBe(false)
      expect(isTheme(metadata)).toBe(true)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata is from a current ui theme', ->
    beforeEach ->
      metadata =
        name: "test-package"
        type: "ui-theme"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a theme', ->
      expect(isPackage(metadata)).toBe(false)
      expect(isTheme(metadata)).toBe(true)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata is from a current syntax theme', ->
    beforeEach ->
      metadata =
        name: "test-package"
        type: "syntax-theme"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a theme', ->
      expect(isPackage(metadata)).toBe(false)
      expect(isTheme(metadata)).toBe(true)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata has an unknown package type', ->
    beforeEach ->
      metadata =
        name: "test-package"
        type: "unknown-type"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a package', ->
      expect(isPackage(metadata)).toBe(true)
      expect(isTheme(metadata)).toBe(false)
      expect(isPackageSet(metadata)).toBe(false)

  describe 'when the metadata is from a package set', ->
    beforeEach ->
      metadata =
        name: "test-package"
        type: "package-set"
        version: "1.0.0",
        description: "Test package."

    it 'classifies the package as a package', ->
      expect(isPackage(metadata)).toBe(false)
      expect(isTheme(metadata)).toBe(false)
      expect(isPackageSet(metadata)).toBe(true)
