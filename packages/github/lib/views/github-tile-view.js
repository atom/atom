import React from 'react';
import PropTypes from 'prop-types';
import Octicon from '../atom/octicon';

import {addEvent} from '../reporter-proxy';
import {autobind} from '../helpers';

export default class GithubTileView extends React.Component {
  static propTypes = {
    didClick: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);
    autobind(this, 'handleClick');
  }

  handleClick() {
    addEvent('click', {package: 'github', component: 'GithubTileView'});
    this.props.didClick();
  }

  render() {
    return (
      <button
        className="github-StatusBarTile inline-block"
        onClick={this.handleClick}>
        <Octicon icon="mark-github" />
        GitHub
      </button>
    );
  }
}
