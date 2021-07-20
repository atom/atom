const { createStylesElement } = require('../src/styles-element');

describe('StylesElement', function() {
  let [
    element,
    addedStyleElements,
    removedStyleElements,
    updatedStyleElements
  ] = [];

  beforeEach(function() {
    element = createStylesElement();
    element.initialize(atom.styles);
    document.querySelector('#jasmine-content').appendChild(element);
    addedStyleElements = [];
    removedStyleElements = [];
    updatedStyleElements = [];
    element.onDidAddStyleElement(element => addedStyleElements.push(element));
    element.onDidRemoveStyleElement(element =>
      removedStyleElements.push(element)
    );
    element.onDidUpdateStyleElement(element =>
      updatedStyleElements.push(element)
    );
  });

  it('renders a style tag for all currently active stylesheets in the style manager', function() {
    const initialChildCount = element.children.length;

    const disposable1 = atom.styles.addStyleSheet('a {color: red;}');
    expect(element.children.length).toBe(initialChildCount + 1);
    expect(element.children[initialChildCount].textContent).toBe(
      'a {color: red;}'
    );
    expect(addedStyleElements).toEqual([element.children[initialChildCount]]);

    atom.styles.addStyleSheet('a {color: blue;}');
    expect(element.children.length).toBe(initialChildCount + 2);
    expect(element.children[initialChildCount + 1].textContent).toBe(
      'a {color: blue;}'
    );
    expect(addedStyleElements).toEqual([
      element.children[initialChildCount],
      element.children[initialChildCount + 1]
    ]);

    disposable1.dispose();
    expect(element.children.length).toBe(initialChildCount + 1);
    expect(element.children[initialChildCount].textContent).toBe(
      'a {color: blue;}'
    );
    expect(removedStyleElements).toEqual([addedStyleElements[0]]);
  });

  it('orders style elements by priority', function() {
    const initialChildCount = element.children.length;

    atom.styles.addStyleSheet('a {color: red}', { priority: 1 });
    atom.styles.addStyleSheet('a {color: blue}', { priority: 0 });
    atom.styles.addStyleSheet('a {color: green}', { priority: 2 });
    atom.styles.addStyleSheet('a {color: yellow}', { priority: 1 });

    expect(element.children[initialChildCount].textContent).toBe(
      'a {color: blue}'
    );
    expect(element.children[initialChildCount + 1].textContent).toBe(
      'a {color: red}'
    );
    expect(element.children[initialChildCount + 2].textContent).toBe(
      'a {color: yellow}'
    );
    expect(element.children[initialChildCount + 3].textContent).toBe(
      'a {color: green}'
    );
  });

  it('updates existing style nodes when style elements are updated', function() {
    const initialChildCount = element.children.length;

    atom.styles.addStyleSheet('a {color: red;}', { sourcePath: '/foo/bar' });
    atom.styles.addStyleSheet('a {color: blue;}', { sourcePath: '/foo/bar' });

    expect(element.children.length).toBe(initialChildCount + 1);
    expect(element.children[initialChildCount].textContent).toBe(
      'a {color: blue;}'
    );
    expect(updatedStyleElements).toEqual([element.children[initialChildCount]]);
  });

  it("only includes style elements matching the 'context' attribute", function() {
    const initialChildCount = element.children.length;

    atom.styles.addStyleSheet('a {color: red;}', { context: 'test-context' });
    atom.styles.addStyleSheet('a {color: green;}');

    expect(element.children.length).toBe(initialChildCount + 2);
    expect(element.children[initialChildCount].textContent).toBe(
      'a {color: red;}'
    );
    expect(element.children[initialChildCount + 1].textContent).toBe(
      'a {color: green;}'
    );

    element.setAttribute('context', 'test-context');

    expect(element.children.length).toBe(1);
    expect(element.children[0].textContent).toBe('a {color: red;}');

    atom.styles.addStyleSheet('a {color: blue;}', { context: 'test-context' });
    atom.styles.addStyleSheet('a {color: yellow;}');

    expect(element.children.length).toBe(2);
    expect(element.children[0].textContent).toBe('a {color: red;}');
    expect(element.children[1].textContent).toBe('a {color: blue;}');
  });
});
