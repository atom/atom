import React, {Fragment} from 'react';
import PropTypes from 'prop-types';

import {autobind} from '../helpers';

export default class Accordion extends React.Component {
  static propTypes = {
    leftTitle: PropTypes.string.isRequired,
    rightTitle: PropTypes.string,
    results: PropTypes.arrayOf(PropTypes.any).isRequired,
    total: PropTypes.number.isRequired,
    isLoading: PropTypes.bool.isRequired,
    loadingComponent: PropTypes.func,
    emptyComponent: PropTypes.func,
    moreComponent: PropTypes.func,
    reviewsButton: PropTypes.func,
    onClickItem: PropTypes.func,
    children: PropTypes.func.isRequired,
  };

  static defaultProps = {
    loadingComponent: () => null,
    emptyComponent: () => null,
    moreComponent: () => null,
    onClickItem: () => {},
    reviewsButton: () => null,
  };

  constructor(props) {
    super(props);
    autobind(this, 'toggle');

    this.state = {
      expanded: true,
    };
  }

  render() {
    return (
      <details className="github-Accordion" open={this.state.expanded}>
        <summary className="github-Accordion-header" onClick={this.toggle}>
          {this.renderHeader()}
        </summary>
        <main className="github-Accordion-content">
          {this.renderContent()}
        </main>
      </details>
    );
  }

  renderHeader() {
    return (
      <Fragment>
        <span className="github-Accordion--leftTitle">
          {this.props.leftTitle}
        </span>
        {this.props.rightTitle && (
          <span className="github-Accordion--rightTitle">
            {this.props.rightTitle}
          </span>
        )}
        {this.props.reviewsButton()}
      </Fragment>
    );
  }

  renderContent() {
    if (this.props.isLoading) {
      const Loading = this.props.loadingComponent;
      return <Loading />;
    }

    if (this.props.results.length === 0) {
      const Empty = this.props.emptyComponent;
      return <Empty />;
    }

    if (!this.state.expanded) {
      return null;
    }

    const More = this.props.moreComponent;

    return (
      <Fragment>
        <ul className="github-Accordion-list">
          {this.props.results.map((item, index) => {
            const key = item.key !== undefined ? item.key : index;
            return (
              <li className="github-Accordion-listItem" key={key} onClick={() => this.props.onClickItem(item)}>
                {this.props.children(item)}
              </li>
            );
          })}
        </ul>
        {this.props.results.length < this.props.total && <More />}
      </Fragment>
    );
  }

  toggle(e) {
    e.preventDefault();
    return new Promise(resolve => {
      this.setState(prevState => ({expanded: !prevState.expanded}), resolve);
    });
  }
}
