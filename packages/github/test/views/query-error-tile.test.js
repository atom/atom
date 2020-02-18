import React from 'react';
import {shallow} from 'enzyme';

import QueryErrorTile from '../../lib/views/query-error-tile';

describe('QueryErrorTile', function() {
  beforeEach(function() {
    sinon.stub(console, 'error');
  });

  it('logs the full error information to the console', function() {
    const e = new Error('wat');
    e.rawStack = e.stack;

    shallow(<QueryErrorTile error={e} />);

    // eslint-disable-next-line no-console
    assert.isTrue(console.error.calledWith(sinon.match.string, e));
  });

  it('displays each GraphQL error', function() {
    const e = new Error('wat');
    e.rawStack = e.stack;
    e.errors = [
      {message: 'okay first of all'},
      {message: 'and another thing'},
    ];

    const wrapper = shallow(<QueryErrorTile error={e} />);
    const messages = wrapper.find('.github-QueryErrorTile-message');
    assert.lengthOf(messages, 2);

    assert.strictEqual(messages.at(0).find('Octicon').prop('icon'), 'alert');
    assert.match(messages.at(0).text(), /okay first of all/);

    assert.strictEqual(messages.at(1).find('Octicon').prop('icon'), 'alert');
    assert.match(messages.at(1).text(), /and another thing/);
  });

  it('displays the text of a failed HTTP response', function() {
    const e = new Error('500');
    e.rawStack = e.stack;
    e.response = {};
    e.responseText = 'The server is on fire';

    const wrapper = shallow(<QueryErrorTile error={e} />);
    const message = wrapper.find('.github-QueryErrorTile-message');
    assert.strictEqual(message.find('Octicon').prop('icon'), 'alert');
    assert.match(message.text(), /The server is on fire$/);
  });

  it('displays an offline message', function() {
    const e = new Error('cat pulled out the ethernet cable');
    e.rawStack = e.stack;
    e.network = true;

    const wrapper = shallow(<QueryErrorTile error={e} />);
    const message = wrapper.find('.github-QueryErrorTile-message');
    assert.strictEqual(message.find('Octicon').prop('icon'), 'alignment-unalign');
    assert.match(message.text(), /Offline/);
  });

  it('falls back to displaying the raw error message', function() {
    const e = new TypeError('oh no');
    e.rawStack = e.stack;

    const wrapper = shallow(<QueryErrorTile error={e} />);
    const message = wrapper.find('.github-QueryErrorTile-message');
    assert.strictEqual(message.find('Octicon').prop('icon'), 'alert');
    assert.match(message.text(), /TypeError: oh no/);
  });
});
