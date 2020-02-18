import {TextBuffer} from 'atom';
import {Emitter, CompositeDisposable} from 'event-kit';
import {remote} from 'electron';
const {dialog} = remote;
import React from 'react';
import ReactDom from 'react-dom';
import PropTypes from 'prop-types';
import memoize from 'lodash.memoize';
import fs from 'fs-extra';

import Octicon from '../atom/octicon';
import {autobind} from '../helpers';

const genArray = memoize(function genArray(interval, count) {
  const arr = [];
  for (let i = 1; i <= count; i++) {
    arr.push(interval * i);
  }
  return arr;
}, (interval, count) => `${interval}:${count}`);

class Marker {
  static deserialize(data) {
    const marker = new Marker(data.label, () => {});
    marker.end = data.end;
    marker.markers = data.markers;
    return marker;
  }

  constructor(label, didUpdate) {
    this.label = label;
    this.didUpdate = didUpdate;
    this.end = null;
    this.markers = [];
  }

  getStart() {
    return this.markers.length ? this.markers[0].start : null;
  }

  getEnd() {
    return this.end;
  }

  mark(sectionName, start) {
    this.markers.push({name: sectionName, start: start || performance.now()});
  }

  finalize() {
    this.end = performance.now();
    this.didUpdate();
  }

  getTimings() {
    return this.markers.map((timing, idx, ary) => {
      const next = ary[idx + 1];
      const end = next ? next.start : this.getEnd();
      return {...timing, end};
    });
  }

  serialize() {
    return {
      label: this.label,
      end: this.end,
      markers: this.markers.slice(),
    };
  }
}


class MarkerTooltip extends React.Component {
  static propTypes = {
    marker: PropTypes.instanceOf(Marker).isRequired,
  }

  render() {
    const {marker} = this.props;
    const timings = marker.getTimings();

    return (
      <div style={{textAlign: 'left', maxWidth: 300, whiteSpace: 'initial'}}>
        <strong><tt>{marker.label}</tt></strong>
        <ul style={{paddingLeft: 20, marginTop: 10}}>
          {timings.map(({name, start, end}) => {
            const duration = end - start;
            return <li key={name}>{name}: {Math.floor(duration * 100) / 100}ms</li>;
          })}
        </ul>
      </div>
    );
  }
}

const COLORS = {
  queued: 'red',
  prepare: 'cyan',
  nexttick: 'yellow',
  execute: 'green',
  ipc: 'pink',
};
class MarkerSpan extends React.Component {
  static propTypes = {
    marker: PropTypes.instanceOf(Marker).isRequired,
  }

  constructor(props) {
    super(props);
    autobind(this, 'handleMouseOver', 'handleMouseOut');
  }

  render() {
    const {marker, ...others} = this.props;
    const timings = marker.getTimings();
    const totalTime = marker.getEnd() - marker.getStart();
    const percentages = timings.map(({name, start, end}) => {
      const duration = end - start;
      return {color: COLORS[name], percent: duration / totalTime * 100};
    });
    return (
      <span
        {...others}
        ref={c => { this.element = c; }}
        onMouseOver={this.handleMouseOver}
        onMouseOut={this.handleMouseOut}>
        {percentages.map(({color, percent}, i) => {
          const style = {
            width: `${percent}%`,
            background: color,
          };
          return <span className="waterfall-marker-section" key={i} style={style} />;
        })}
      </span>
    );
  }

  handleMouseOver(e) {
    const elem = document.createElement('div');
    ReactDom.render(<MarkerTooltip marker={this.props.marker} />, elem);
    this.tooltipDisposable = atom.tooltips.add(this.element, {
      item: elem,
      placement: 'auto bottom',
      trigger: 'manual',
    });
  }

  closeTooltip() {
    this.tooltipDisposable && this.tooltipDisposable.dispose();
    this.tooltipDisposable = null;
  }

  handleMouseOut(e) {
    this.closeTooltip();
  }

  componentWillUnmount() {
    this.closeTooltip();
  }
}


class Waterfall extends React.Component {
  static propTypes = {
    markers: PropTypes.arrayOf(PropTypes.instanceOf(Marker)).isRequired,
    zoomFactor: PropTypes.number.isRequired,
  }

  constructor(props, context) {
    super(props, context);
    autobind(this, 'renderMarker');
    this.state = this.getNextState(props);
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this.getNextState(nextProps));
  }

  getNextState(props) {
    const {markers} = props;
    const firstMarker = markers[0];
    const lastMarker = markers[markers.length - 1];

    const startTime = firstMarker.getStart();
    const endTime = lastMarker.getEnd();
    const totalDuration = endTime - startTime;
    let timelineMarkInterval = null;
    if (props.zoomFactor <= 0.15) {
      timelineMarkInterval = 1000;
    } else if (props.zoomFactor <= 0.3) {
      timelineMarkInterval = 500;
    } else if (props.zoomFactor <= 0.6) {
      timelineMarkInterval = 250;
    } else {
      timelineMarkInterval = 100;
    }
    const timelineMarks = genArray(timelineMarkInterval, Math.ceil(totalDuration / timelineMarkInterval));

    return {firstMarker, lastMarker, startTime, endTime, totalDuration, timelineMarks};
  }

  render() {
    return (
      <div className="waterfall-scroller">
        <div className="waterfall-container">
          {this.renderTimeMarkers()}
          {this.renderTimeline()}
          {this.props.markers.map(this.renderMarker)}
        </div>
      </div>
    );
  }

  renderTimeline() {
    return (
      <div className="waterfall-timeline">
        &nbsp;
        {this.state.timelineMarks.map(time => {
          const leftPos = time * this.props.zoomFactor;
          const style = {
            left: leftPos,
          };
          return <span className="waterfall-timeline-label" style={style} key={`tl:${time}`}>{time}ms</span>;
        })}
      </div>
    );
  }

  renderTimeMarkers() {
    return (
      <div className="waterfall-time-markers">
        {this.state.timelineMarks.map(time => {
          const leftPos = time * this.props.zoomFactor;
          const style = {
            left: leftPos,
          };
          return <span className="waterfall-time-marker" style={style} key={`tm:${time}`} />;
        })}
      </div>
    );
  }

  renderMarker(marker, i) {
    if (marker.getStart() === null || marker.getEnd() === null) { return <div key={i} />; }

    const startOffset = marker.getStart() - this.state.startTime;
    const duration = marker.getEnd() - marker.getStart();
    const markerStyle = {
      left: startOffset * this.props.zoomFactor,
      width: duration * this.props.zoomFactor,
    };

    return (
      <div className="waterfall-row" key={i}>
        <span
          className="waterfall-row-label"
          style={{paddingLeft: markerStyle.left + markerStyle.width}}>{marker.label}</span>
        <MarkerSpan className="waterfall-marker" style={markerStyle} marker={marker} />
      </div>
    );
  }
}


class WaterfallWidget extends React.Component {
  static propTypes = {
    markers: PropTypes.arrayOf(PropTypes.instanceOf(Marker)).isRequired,
  }

  constructor(props, context) {
    super(props, context);
    autobind(this, 'handleZoomFactorChange', 'handleCollapseClick', 'handleExportClick');
    this.state = {
      zoomFactor: 0.3,
      collapsed: false,
    };
  }

  render() {
    const {markers} = this.props;
    const firstMarker = markers[0];
    const lastMarker = markers[markers.length - 1];

    const startTime = firstMarker.getStart();
    const endTime = lastMarker.getEnd();
    const duration = endTime - startTime;

    return (
      <div className="waterfall-widget inset-pannel">
        <div className="waterfall-header">
          <div className="waterfall-header-text">
            <span onClick={this.handleCollapseClick} className="collapse-toggle">
              {this.state.collapsed ? '\u25b6' : '\u25bc'}
            </span>
            {this.props.markers.length} event(s) over {Math.floor(duration)}ms
          </div>
          <div className="waterfall-header-controls">
            <button
              className="waterfall-export-button btn btn-sm"
              onClick={this.handleExportClick}>Export</button>
            <Octicon icon="search" />
            <input
              type="range"
              className="input-range"
              min={0.1}
              max={1}
              step={0.01}
              value={this.state.zoomFactor}
              onChange={this.handleZoomFactorChange}
            />
          </div>
        </div>
        {this.state.collapsed ? null : <Waterfall markers={this.props.markers} zoomFactor={this.state.zoomFactor} />}
      </div>
    );
  }

  handleZoomFactorChange(e) {
    this.setState({zoomFactor: parseFloat(e.target.value)});
  }

  handleCollapseClick(e) {
    this.setState(s => ({collapsed: !s.collapsed}));
  }

  handleExportClick(e) {
    e.preventDefault();
    const json = JSON.stringify(this.props.markers.map(m => m.serialize()), null, '  ');
    const buffer = new TextBuffer({text: json});
    dialog.showSaveDialog({
      defaultPath: 'git-timings.json',
    }, filename => {
      if (!filename) { return; }
      buffer.saveAs(filename);
    });
  }
}


let markers = null;
let groupId = 0;
const groups = [];
let lastMarkerTime = null;
let updateTimer = null;

export default class GitTimingsView extends React.Component {

  static uriPattern = 'atom-github://debug/timings';

  static buildURI() {
    return this.uriPattern;
  }

  static emitter = new Emitter();

  static generateMarker(label) {
    const marker = new Marker(label, () => {
      GitTimingsView.scheduleUpdate();
    });
    const now = performance.now();
    if (!markers || (lastMarkerTime && Math.abs(now - lastMarkerTime) >= 5000)) {
      groupId++;
      markers = [];
      groups.unshift({id: groupId, markers});
      if (groups.length > 100) {
        groups.pop();
      }
    }
    lastMarkerTime = now;
    markers.push(marker);
    GitTimingsView.scheduleUpdate();
    return marker;
  }

  static restoreGroup(group) {
    groupId++;
    groups.unshift({id: groupId, markers: group});
    GitTimingsView.scheduleUpdate(true);
  }

  static scheduleUpdate(immediate = false) {
    if (updateTimer) {
      clearTimeout(updateTimer);
    }

    updateTimer = setTimeout(() => {
      GitTimingsView.emitter.emit('did-update');
    }, immediate ? 0 : 1000);
  }

  static onDidUpdate(callback) {
    return GitTimingsView.emitter.on('did-update', callback);
  }

  constructor(props) {
    super(props);
    autobind(this, 'handleImportClick');
  }

  componentDidMount() {
    this.subscriptions = new CompositeDisposable(
      GitTimingsView.onDidUpdate(() => this.forceUpdate()),
    );
  }

  componentWillUnmount() {
    this.subscriptions.dispose();
  }

  render() {
    return (
      <div className="github-GitTimingsView">
        <div className="github-GitTimingsView-header">
          <button className="import-button btn" onClick={this.handleImportClick}>Import</button>
        </div>
        {groups.map((group, idx) => (
          <WaterfallWidget key={group.id} markers={group.markers} />
        ))}
      </div>
    );
  }

  handleImportClick(e) {
    e.preventDefault();
    dialog.showOpenDialog({
      properties: ['openFile'],
    }, async filenames => {
      if (!filenames) { return; }
      const filename = filenames[0];
      try {
        const contents = await fs.readFile(filename, {encoding: 'utf8'});
        const data = JSON.parse(contents);
        const restoredMarkers = data.map(item => Marker.deserialize(item));
        GitTimingsView.restoreGroup(restoredMarkers);
      } catch (_err) {
        atom.notifications.addError(`Could not import timings from ${filename}`);
      }
    });
  }

  serialize() {
    return {
      deserializer: 'GitTimingsView',
    };
  }

  getURI() {
    return this.constructor.buildURI();
  }

  getTitle() {
    return 'GitHub Package Timings View';
  }
}
