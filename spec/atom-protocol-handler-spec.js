describe('"atom" protocol URL', () =>
  it('sends the file relative in the package as response', function() {
    let called = false;
    const request = new XMLHttpRequest();
    request.addEventListener('load', () => (called = true));
    request.open('GET', 'atom://async/package.json', true);
    request.send();

    waitsFor('request to be done', () => called === true);
  }));
