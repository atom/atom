import React from 'react';
import {shallow} from 'enzyme';

import Octicon from '../../lib/atom/octicon';

describe('Octicon', function() {
  it('defaults to rendering an octicon span', function() {
    const wrapper = shallow(<Octicon icon="octoface" />);
    assert.isTrue(wrapper.exists('span.icon.icon-octoface'));
  });

  it('renders SVG overrides', function() {
    const wrapper = shallow(<Octicon icon="unlock" />);

    assert.strictEqual(wrapper.find('svg').prop('viewBox'), '0 0 24 16');
  });
});
