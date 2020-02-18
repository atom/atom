import React from 'react';
import PropTypes from 'prop-types';
import {Disposable} from 'event-kit';

export default class Accumulator extends React.Component {
  static propTypes = {
    // Relay props
    relay: PropTypes.shape({
      hasMore: PropTypes.func.isRequired,
      loadMore: PropTypes.func.isRequired,
      isLoading: PropTypes.func.isRequired,
    }).isRequired,
    resultBatch: PropTypes.arrayOf(PropTypes.any).isRequired,

    // Control props
    pageSize: PropTypes.number.isRequired,
    waitTimeMs: PropTypes.number.isRequired,

    // Render prop. Called with (error, full result list, loading) each time more results arrive. Return value is
    // rendered as a child element.
    children: PropTypes.func,

    // Called right after refetch happens
    onDidRefetch: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.refetchSub = new Disposable();
    this.loadMoreSub = new Disposable();
    this.nextUpdateSub = new Disposable();

    this.nextUpdateID = null;
    this.state = {error: null};
  }

  componentDidMount() {
    this.refetchSub = this.props.onDidRefetch(this.attemptToLoadMore);
    this.attemptToLoadMore();
  }

  componentWillUnmount() {
    this.refetchSub.dispose();
    this.loadMoreSub.dispose();
    this.nextUpdateSub.dispose();
  }

  render() {
    return this.props.children(this.state.error, this.props.resultBatch, this.props.relay.hasMore());
  }

  attemptToLoadMore = () => {
    this.loadMoreSub.dispose();
    this.nextUpdateID = null;

    /* istanbul ignore if */
    if (!this.props.relay.hasMore() || this.props.relay.isLoading()) {
      return;
    }

    this.loadMoreSub = this.props.relay.loadMore(this.props.pageSize, this.accumulate);
  }

  accumulate = error => {
    if (error) {
      this.setState({error});
    } else {
      if (this.props.waitTimeMs > 0 && this.nextUpdateID === null) {
        this.nextUpdateID = setTimeout(this.attemptToLoadMore, this.props.waitTimeMs);
        this.nextUpdateSub = new Disposable(() => {
          clearTimeout(this.nextUpdateID);
          this.nextUpdateID = null;
        });
      } else {
        this.attemptToLoadMore();
      }
    }
  }
}
