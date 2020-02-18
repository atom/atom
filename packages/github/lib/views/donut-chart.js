import React from 'react';
import PropTypes from 'prop-types';

import {autobind} from '../helpers';

export default class DonutChart extends React.Component {
  static propTypes = {
    baseOffset: PropTypes.number,
    slices: PropTypes.arrayOf(
      PropTypes.shape({
        type: PropTypes.string,
        className: PropTypes.string,
        count: PropTypes.number,
      }),
    ),
  }

  static defaultProps = {
    baseOffset: 25,
  }

  constructor(props) {
    super(props);
    autobind(this, 'renderArc');
  }

  render() {
    const {slices, baseOffset, ...others} = this.props; // eslint-disable-line no-unused-vars
    const arcs = this.calculateArcs(slices);

    return (
      <svg {...others}>
        {arcs.map(this.renderArc)}
      </svg>
    );
  }

  calculateArcs(slices) {
    const total = slices.reduce((acc, item) => acc + item.count, 0);
    let lengthSoFar = 0;

    return slices.map(({count, ...others}) => {
      const piece = {
        length: count / total * 100,
        position: lengthSoFar,
        ...others,
      };
      lengthSoFar += piece.length;
      return piece;
    });
  }

  renderArc({length, position, type, className}) {
    return (
      <circle
        key={type}
        cx="21"
        cy="21"
        r="15.91549430918954"
        fill="transparent"
        className={`donut-ring-${type}`}
        pathLength="100"
        strokeWidth="3"
        strokeDasharray={`${length} ${100 - length}`}
        strokeDashoffset={`${100 - position + this.props.baseOffset}`}
      />
    );
  }
}
