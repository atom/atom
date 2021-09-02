const TitleBar = require('../src/title-bar');
const temp = require('temp').track();

describe('TitleBar', () => {
  it('updates its title when document.title changes', () => {
    const titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate
    });
    expect(titleBar.element.querySelector('.title').textContent).toBe(
      document.title
    );

    const paneItem = new FakePaneItem('Title 1');
    atom.workspace.getActivePane().activateItem(paneItem);
    expect(document.title).toMatch('Title 1');
    expect(titleBar.element.querySelector('.title').textContent).toBe(
      document.title
    );

    paneItem.setTitle('Title 2');
    expect(document.title).toMatch('Title 2');
    expect(titleBar.element.querySelector('.title').textContent).toBe(
      document.title
    );

    atom.project.setPaths([temp.mkdirSync('project-1')]);
    expect(document.title).toMatch('project-1');
    expect(titleBar.element.querySelector('.title').textContent).toBe(
      document.title
    );
  });

  it('can update the sheet offset for the current window based on its height', () => {
    const titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate
    });
    expect(() => titleBar.updateWindowSheetOffset()).not.toThrow();
  });
});

class FakePaneItem {
  constructor(title) {
    this.title = title;
  }

  getTitle() {
    return this.title;
  }

  onDidChangeTitle(callback) {
    this.didChangeTitleCallback = callback;
    return {
      dispose: () => {
        this.didChangeTitleCallback = null;
      }
    };
  }

  setTitle(title) {
    this.title = title;
    if (this.didChangeTitleCallback) this.didChangeTitleCallback(title);
  }
}
