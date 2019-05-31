module.exports = class TitleBar {
  constructor({ workspace, themes, applicationDelegate }) {
    this.dblclickHandler = this.dblclickHandler.bind(this);
    this.workspace = workspace;
    this.themes = themes;
    this.applicationDelegate = applicationDelegate;
    this.element = document.createElement('div');
    this.element.classList.add('title-bar');

    this.titleElement = document.createElement('div');
    this.titleElement.classList.add('title');
    this.element.appendChild(this.titleElement);

    this.element.addEventListener('dblclick', this.dblclickHandler);

    this.workspace.onDidChangeWindowTitle(() => this.updateTitle());
    this.themes.onDidChangeActiveThemes(() => this.updateWindowSheetOffset());

    this.updateTitle();
    this.updateWindowSheetOffset();
  }

  dblclickHandler() {
    // User preference deciding which action to take on a title bar double-click
    switch (
      this.applicationDelegate.getUserDefault(
        'AppleActionOnDoubleClick',
        'string'
      )
    ) {
      case 'Minimize':
        this.applicationDelegate.minimizeWindow();
        break;
      case 'Maximize':
        if (this.applicationDelegate.isWindowMaximized()) {
          this.applicationDelegate.unmaximizeWindow();
        } else {
          this.applicationDelegate.maximizeWindow();
        }
        break;
    }
  }

  updateTitle() {
    this.titleElement.textContent = document.title;
  }

  updateWindowSheetOffset() {
    this.applicationDelegate
      .getCurrentWindow()
      .setSheetOffset(this.element.offsetHeight);
  }
};
