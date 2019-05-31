describe('About', () => {
  let workspaceElement;

  beforeEach(async () => {
    let storage = {};

    spyOn(window.localStorage, 'setItem').andCallFake((key, value) => {
      storage[key] = value;
    });
    spyOn(window.localStorage, 'getItem').andCallFake(key => {
      return storage[key];
    });

    workspaceElement = atom.views.getView(atom.workspace);
    await atom.packages.activatePackage('about');
  });

  it('deserializes correctly', () => {
    let deserializedAboutView = atom.deserializers.deserialize({
      deserializer: 'AboutView',
      uri: 'atom://about'
    });

    expect(deserializedAboutView).toBeTruthy();
  });

  describe('when the about:about-atom command is triggered', () => {
    it('shows the About Atom view', async () => {
      // Attaching the workspaceElement to the DOM is required to allow the
      // `toBeVisible()` matchers to work. Anything testing visibility or focus
      // requires that the workspaceElement is on the DOM. Tests that attach the
      // workspaceElement to the DOM are generally slower than those off DOM.
      jasmine.attachToDOM(workspaceElement);

      expect(workspaceElement.querySelector('.about')).not.toExist();
      await atom.workspace.open('atom://about');

      let aboutElement = workspaceElement.querySelector('.about');
      expect(aboutElement).toBeVisible();
    });
  });

  describe('when the Atom version number is clicked', () => {
    it('copies the version number to the clipboard', async () => {
      await atom.workspace.open('atom://about');

      let aboutElement = workspaceElement.querySelector('.about');
      let versionContainer = aboutElement.querySelector('.atom');
      versionContainer.click();
      expect(atom.clipboard.read()).toBe(atom.getVersion());
    });
  });

  describe('when the show more link is clicked', () => {
    it('expands to show additional version numbers', async () => {
      await atom.workspace.open('atom://about');
      jasmine.attachToDOM(workspaceElement);

      let aboutElement = workspaceElement.querySelector('.about');
      let showMoreElement = aboutElement.querySelector('.show-more-expand');
      let moreInfoElement = workspaceElement.querySelector('.show-more');
      showMoreElement.click();
      expect(moreInfoElement).toBeVisible();
    });
  });

  describe('when the Electron version number is clicked', () => {
    it('copies the version number to the clipboard', async () => {
      await atom.workspace.open('atom://about');

      let aboutElement = workspaceElement.querySelector('.about');
      let versionContainer = aboutElement.querySelector('.electron');
      versionContainer.click();
      expect(atom.clipboard.read()).toBe(process.versions.electron);
    });
  });

  describe('when the Chrome version number is clicked', () => {
    it('copies the version number to the clipboard', async () => {
      await atom.workspace.open('atom://about');

      let aboutElement = workspaceElement.querySelector('.about');
      let versionContainer = aboutElement.querySelector('.chrome');
      versionContainer.click();
      expect(atom.clipboard.read()).toBe(process.versions.chrome);
    });
  });

  describe('when the Node version number is clicked', () => {
    it('copies the version number to the clipboard', async () => {
      await atom.workspace.open('atom://about');

      let aboutElement = workspaceElement.querySelector('.about');
      let versionContainer = aboutElement.querySelector('.node');
      versionContainer.click();
      expect(atom.clipboard.read()).toBe(process.version);
    });
  });
});
