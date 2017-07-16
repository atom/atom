/**
 * Class containing the actions and settings for the TitleBar of the application
 */
module.exports = class TitleBar {
  constructor ({workspace, themes, applicationDelegate}) {
    this.dblclickHandler = this.dblclickHandler.bind(this)
    this.workspace = workspace
    this.themes = themes
    this.applicationDelegate = applicationDelegate;
    this.element = document.createElement('div')
    this.element.classList.add('title-bar')

    this.titleElement = document.createElement('div')
    this.titleElement.classList.add('title')
    this.element.appendChild(this.titleElement)

    this.element.addEventListener('dblclick', this.dblclickHandler)

    this.workspace.onDidChangeWindowTitle(() => this.updateTitle())
    this.themes.onDidChangeActiveThemes(() => this.updateWindowSheetOffset())

    this.updateTitle()
    this.updateWindowSheetOffset()
  }

  /**
   * Handles window sizing on double click based on set user preferences
   */
  dblclickHandler() {
    switch (this.applicationDelegate.getUserDefault('AppleActionOnDoubleClick', 'string')) {
      case 'Minimize':
        this.applicationDelegate.minimizeWindow()
        break;
      case 'Maximize':
        this.applicationDelegate.isWindowMaximized() ?
          this.applicationDelegate.unmaximizeWindow() :
          this.applicationDelegate.maximizeWindow()
        break;
    }
  }

  /**
   * Sets the title bar text to the title of the current document
   */
  updateTitle() {
    this.titleElement.textContent = document.title
  }

  /**
   * Sets the visual offset amount based on the offset of the current element
   */
  updateWindowSheetOffset() {
    this.applicationDelegate.getCurrentWindow().setSheetOffset(this.element.offsetHeight)
  }
}
