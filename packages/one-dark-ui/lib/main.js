const root = document.documentElement;
const themeName = 'one-dark-ui';

module.exports = {
  activate(state) {
    atom.config.observe(`${themeName}.fontSize`, setFontSize);
    atom.config.observe(`${themeName}.tabSizing`, setTabSizing);
    atom.config.observe(`${themeName}.tabCloseButton`, setTabCloseButton);
    atom.config.observe(`${themeName}.hideDockButtons`, setHideDockButtons);
    atom.config.observe(`${themeName}.stickyHeaders`, setStickyHeaders);
  },

  deactivate() {
    unsetFontSize();
    unsetTabSizing();
    unsetTabCloseButton();
    unsetHideDockButtons();
    unsetStickyHeaders();
  }
};

// Font Size -----------------------

function setFontSize(currentFontSize) {
  root.style.fontSize = `${currentFontSize}px`;
}

function unsetFontSize() {
  root.style.fontSize = '';
}

// Tab Sizing -----------------------

function setTabSizing(tabSizing) {
  root.setAttribute(`theme-${themeName}-tabsizing`, tabSizing.toLowerCase());
}

function unsetTabSizing() {
  root.removeAttribute(`theme-${themeName}-tabsizing`);
}

// Tab Close Button -----------------------

function setTabCloseButton(tabCloseButton) {
  if (tabCloseButton === 'Left') {
    root.setAttribute(`theme-${themeName}-tab-close-button`, 'left');
  } else {
    unsetTabCloseButton();
  }
}

function unsetTabCloseButton() {
  root.removeAttribute(`theme-${themeName}-tab-close-button`);
}

// Dock Buttons -----------------------

function setHideDockButtons(hideDockButtons) {
  if (hideDockButtons) {
    root.setAttribute(`theme-${themeName}-dock-buttons`, 'hidden');
  } else {
    unsetHideDockButtons();
  }
}

function unsetHideDockButtons() {
  root.removeAttribute(`theme-${themeName}-dock-buttons`);
}

// Sticky Headers -----------------------

function setStickyHeaders(stickyHeaders) {
  if (stickyHeaders) {
    root.setAttribute(`theme-${themeName}-sticky-headers`, 'sticky');
  } else {
    unsetStickyHeaders();
  }
}

function unsetStickyHeaders() {
  root.removeAttribute(`theme-${themeName}-sticky-headers`);
}
