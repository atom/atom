import React from 'react';
import PropTypes from 'prop-types';
import DonutChart from './donut-chart';

import {unusedProps} from '../helpers';

export default class StatusDonutChart extends React.Component {
  static propTypes = {
    pending: PropTypes.number,
    failure: PropTypes.number,
    success: PropTypes.number,
  }

  render() {
    const slices = ['pending', 'failure', 'success'].reduce((acc, type) => {
      const count = this.props[type];
      if (count > 0) {
        acc.push({type, className: type, count});
      }
      return acc;
    }, []);

    return <DonutChart {...unusedProps(this.props, this.constructor.propTypes)} slices={slices} />;
  }
}
