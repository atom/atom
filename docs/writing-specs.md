# Writing specs

Atom uses [Jasmine](http://jasmine.github.io/2.0/introduction.html) as its spec framework. Any new functionality should have specs to guard against regressions.

## Create a new spec

[Atom specs](https://github.com/atom/atom/tree/master/spec) and [package specs](https://github.com/atom/markdown-preview/tree/master/spec) are added to their respective `spec` directory. The example below creates a spec for Atom core.

0. Create a spec file

  Spec files **must** end with `-spec` so add `sample-spec.coffee` to `atom/spec`.

0. Add one or more `describe` methods

  The `describe` method takes two arguments, a description and a function. If the description explains a behavior it typically begins with `when` if it is more like a unit test it begins with the method name.

  ```coffee
  describe "when a test is written", ->
    # contents
  ```

  or

  ```coffee
  describe "Editor::moveUp", ->
    # contents
  ```

0. Add one or more `it` method

  The `it` method also takes two arguments, a description and a function. Try and make the description flow with the `it` method. For example, a description of `this should work` doesn't read well as `it this should work`. But a description of `should work` sounds great as `it should work`.

  ```coffee
  describe "when a test is written", ->
    it "has some expectations that should pass", ->
      # Expectations
  ```

0. Add one or more expectations

  The best way to learn about expectations is to read the [jasmine documentation](http://jasmine.github.io/1.3/introduction.html#section-Expectations) about them. Below is a simple example.

  ```coffee
  describe "when a test is written", ->
    it "has some expectations that should pass", ->
      expect("apples").toEqual("apples")
      expect("oranges").not.toEqual("apples")
  ```

## Asynchronous specs

Writing Asynchronous specs can be tricky at first. Some examples.

0. Promises

  Working with promises is rather easy in Atom. You can use our `waitsForPromise` function.

  ```coffee
    describe "when we open a file", ->
      it "should be opened in an editor", ->
        waitsForPromise ->
          atom.workspace.open('c.coffee').then (editor) ->
            expect(editor.getPath()).toContain 'c.coffee'
  ```

  This method can be used in the `describe`, `it`, `beforeEach` and `afterEach` functions.

  ```coffee
  describe "when we open a file", ->
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open 'c.coffee'

    it "should be opened in an editor", ->
      expect(atom.workspace.getActiveTextEditor().getPath()).toContain 'c.coffee'

  ```

  If you need to wait for multiple promises use a new `waitsForPromise` function for each promise. (Caution: Without `beforeEach` this example will fail!)

  ```coffee
  describe "waiting for the packages to load", ->

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js')
      waitsForPromise ->
        atom.packages.activatePackage('tabs')
      waitsForPromise ->
        atom.packages.activatePackage('tree-view')

    it 'should have waited long enough', ->
      expect(atom.packages.isPackageActive('tabs')).toBe true
      expect(atom.packages.isPackageActive('tree-view')).toBe true
  ```

0. Asynchronous functions with callbacks

  Specs for asynchronous functions can be done using the `waitsFor` and `runs` functions. A simple example.

  ```coffee
  describe "fs.readdir(path, cb)", ->
    it "is async", ->
      spy = jasmine.createSpy('fs.readdirSpy')

      fs.readdir('/tmp/example', spy)
      waitsFor ->
        spy.callCount > 0
      runs ->
        exp = [null, ['example.coffee']]
        expect(spy.mostRecentCall.args).toEqual exp
        expect(spy).toHaveBeenCalledWith(null, ['example.coffee'])
  ```

For a more detailed documentation on asynchronous tests please visit the [jasmine documentation](http://jasmine.github.io/1.3/introduction.html#section-Asynchronous_Support).


## Running specs

Most of the time you'll want to run specs by triggering the `window:run-package-specs` command. This command is not only to run package specs, it is also for Atom core specs. This will run all the specs in the current project's spec directory. If you want to run the Atom core specs and **all** the default package specs trigger the `window:run-all-specs` command.

To run a limited subset of specs use the `fdescribe` or `fit` methods. You can use those to focus a single spec or several specs. In the example above, focusing an individual spec looks like this:

```coffee
describe "when a test is written", ->
  fit "has some expectations that should pass", ->
    expect("apples").toEqual("apples")
    expect("oranges").not.toEqual("apples")
```

### Running on CI

It is now easy to run the specs in a CI environment like Travis and AppVeyor. See the
[Travis CI For Your Packages](http://blog.atom.io/2014/04/25/ci-for-your-packages.html)
and [AppVeyor CI For Your Packages](http://blog.atom.io/2014/07/28/windows-ci-for-your-packages.html)
posts for more details.
