import React from 'react';
import PropTypes from 'prop-types';

import ModelObserver from '../models/model-observer';

export default class ObserveModel extends React.Component {
  static propTypes = {
    model: PropTypes.shape({
      onDidUpdate: PropTypes.func.isRequired,
    }),
    fetchData: PropTypes.func.isRequired,
    fetchParams: PropTypes.arrayOf(PropTypes.any),
    children: PropTypes.func.isRequired,
  }

  static defaultProps = {
    fetchParams: [],
  }

  constructor(props, context) {
    super(props, context);

    this.state = {data: null};
    this.modelObserver = new ModelObserver({fetchData: this.fetchData, didUpdate: this.didUpdate});
  }

  componentDidMount() {
    this.mounted = true;
    this.modelObserver.setActiveModel(this.props.model);
  }

  componentDidUpdate(prevProps) {
    this.modelObserver.setActiveModel(this.props.model);

    if (
      !this.modelObserver.hasPendingUpdate() &&
      prevProps.fetchParams.length !== this.props.fetchParams.length ||
      prevProps.fetchParams.some((prevParam, i) => prevParam !== this.props.fetchParams[i])
    ) {
      this.modelObserver.refreshModelData();
    }
  }

  fetchData = model => this.props.fetchData(model, ...this.props.fetchParams);

  didUpdate = () => {
    if (this.mounted) {
      const data = this.modelObserver.getActiveModelData();
      this.setState({data});
    }
  }

  render() {
    return this.props.children(this.state.data);
  }

  componentWillUnmount() {
    this.mounted = false;
    this.modelObserver.destroy();
  }
}
