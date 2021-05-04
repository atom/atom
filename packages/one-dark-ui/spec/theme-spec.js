const themeName = 'one-dark-ui';

describe(`${themeName} theme`, () => {
  beforeEach(() => {
    waitsForPromise(() => atom.packages.activatePackage(themeName));
  });

  it('allows the font size to be set via config', () => {
    expect(document.documentElement.style.fontSize).toBe('12px');

    atom.config.set(`${themeName}.fontSize`, '10');
    expect(document.documentElement.style.fontSize).toBe('10px');
  });

  it('allows the tab sizing to be set via config', () => {
    atom.config.set(`${themeName}.tabSizing`, 'Maximum');
    expect(
      document.documentElement.getAttribute(`theme-${themeName}-tabsizing`)
    ).toBe('maximum');
  });

  it('allows the tab sizing to be set via config', () => {
    atom.config.set(`${themeName}.tabSizing`, 'Minimum');
    expect(
      document.documentElement.getAttribute(`theme-${themeName}-tabsizing`)
    ).toBe('minimum');
  });

  it('allows the tab close button to be shown on the left via config', () => {
    atom.config.set(`${themeName}.tabCloseButton`, 'Left');
    expect(
      document.documentElement.getAttribute(
        `theme-${themeName}-tab-close-button`
      )
    ).toBe('left');
  });

  it('allows the dock toggle buttons to be hidden via config', () => {
    atom.config.set(`${themeName}.hideDockButtons`, true);
    expect(
      document.documentElement.getAttribute(`theme-${themeName}-dock-buttons`)
    ).toBe('hidden');
  });

  it('allows the tree-view headers to be sticky via config', () => {
    atom.config.set(`${themeName}.stickyHeaders`, true);
    expect(
      document.documentElement.getAttribute(`theme-${themeName}-sticky-headers`)
    ).toBe('sticky');
  });

  it('allows the tree-view headers to not be sticky via config', () => {
    atom.config.set(`${themeName}.stickyHeaders`, false);
    expect(
      document.documentElement.getAttribute(`theme-${themeName}-sticky-headers`)
    ).toBe(null);
  });
});
