import {CompositeDisposable} from 'event-kit';
import React from 'react';
import PropTypes from 'prop-types';
import compareSets from 'compare-sets';

import Commands, {Command} from '../atom/commands';
import Conflict from '../models/conflicts/conflict';
import ConflictController from './conflict-controller';
import {OURS, THEIRS, BASE} from '../models/conflicts/source';
import {autobind} from '../helpers';

/**
 * Render a `ConflictController` for each conflict marker within an open TextEditor.
 */
export default class EditorConflictController extends React.Component {
  static propTypes = {
    editor: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    resolutionProgress: PropTypes.object.isRequired,
    isRebase: PropTypes.bool.isRequired,
    refreshResolutionProgress: PropTypes.func.isRequired,
  }

  constructor(props, context) {
    super(props, context);
    autobind(this, 'resolveAsCurrent', 'revertConflictModifications', 'dismissCurrent');

    // this.layer = props.editor.addMarkerLayer({
    //   maintainHistory: true,
    //   persistent: false,
    // });

    this.layer = props.editor.getDefaultMarkerLayer();

    this.state = {
      conflicts: new Set(Conflict.allFromEditor(props.editor, this.layer, props.isRebase)),
    };

    this.subscriptions = new CompositeDisposable();

    this.updateMarkerCount();
  }

  componentDidMount() {
    const buffer = this.props.editor.getBuffer();

    this.subscriptions.add(
      this.props.editor.onDidDestroy(() => this.props.refreshResolutionProgress(this.props.editor.getPath())),
      buffer.onDidReload(() => this.reparseConflicts()),
    );
  }

  render() {
    this.updateMarkerCount();

    return (
      <div>
        {this.state.conflicts.size > 0 && (
          <Commands registry={this.props.commands} target="atom-text-editor">
            <Command command="github:resolve-as-ours" callback={this.getResolverUsing([OURS])} />
            <Command command="github:resolve-as-theirs" callback={this.getResolverUsing([THEIRS])} />
            <Command command="github:resolve-as-base" callback={this.getResolverUsing([BASE])} />
            <Command command="github:resolve-as-ours-then-theirs" callback={this.getResolverUsing([OURS, THEIRS])} />
            <Command command="github:resolve-as-theirs-then-ours" callback={this.getResolverUsing([THEIRS, OURS])} />
            <Command command="github:resolve-as-current" callback={this.resolveAsCurrent} />
            <Command command="github:revert-conflict-modifications" callback={this.revertConflictModifications} />
            <Command command="github:dismiss-conflict" callback={this.dismissCurrent} />
          </Commands>
        )}
        {Array.from(this.state.conflicts, c => (
          <ConflictController
            key={c.getKey()}
            editor={this.props.editor}
            conflict={c}
            resolveAsSequence={sources => this.resolveAsSequence(c, sources)}
            dismiss={() => this.dismissConflicts([c])}
          />
        ))}
      </div>
    );
  }

  componentWillUnmount() {
    // this.layer.destroy();
    this.subscriptions.dispose();
  }

  /*
   * Return an Array containing `Conflict` objects whose marked regions include any cursor position in the current
   * `TextEditor` and the `Sides` that contain a cursor within each.
   *
   * This method is written to have linear complexity with respect to the number of cursors and the number of
   * conflicts, to gracefully handle files with large numbers of both.
   */
  getCurrentConflicts() {
    const cursorPositions = this.props.editor.getCursorBufferPositions();
    cursorPositions.sort((a, b) => a.compare(b));
    const cursorIterator = cursorPositions[Symbol.iterator]();

    const conflictIterator = this.state.conflicts.keys();

    let currentCursor = cursorIterator.next();
    let currentConflict = conflictIterator.next();
    const activeConflicts = [];

    while (!currentCursor.done && !currentConflict.done) {
      // Advance currentCursor to the first cursor beyond the earliest conflict.
      const earliestConflictPosition = currentConflict.value.getRange().start;
      while (!currentCursor.done && currentCursor.value.isLessThan(earliestConflictPosition)) {
        currentCursor = cursorIterator.next();
      }

      // Advance currentConflict until the first conflict that begins at a position after the current cursor.
      // Compare each to the current cursor, and add it to activeConflicts if it contains it.
      while (!currentConflict.done && !currentCursor.done &&
          currentConflict.value.getRange().start.isLessThan(currentCursor.value)) {
        if (currentConflict.value.includesPoint(currentCursor.value)) {
          // Hit; determine which sides of this conflict contain cursors.
          const conflict = currentConflict.value;
          const endPosition = conflict.getRange().end;
          const sides = new Set();
          while (!currentCursor.done && currentCursor.value.isLessThan(endPosition)) {
            const side = conflict.getSideContaining(currentCursor.value);
            if (side) {
              sides.add(side);
            }
            currentCursor = cursorIterator.next();
          }

          activeConflicts.push({conflict, sides});
        }

        currentConflict = conflictIterator.next();
      }
    }

    return activeConflicts;
  }

  getResolverUsing(sequence) {
    return () => {
      this.getCurrentConflicts().forEach(match => this.resolveAsSequence(match.conflict, sequence));
    };
  }

  resolveAsCurrent() {
    this.getCurrentConflicts().forEach(match => {
      if (match.sides.size === 1) {
        const side = match.sides.keys().next().value;
        this.resolveAs(match.conflict, side.getSource());
      }
    });
  }

  revertConflictModifications() {
    this.getCurrentConflicts().forEach(match => {
      match.sides.forEach(side => {
        side.isModified() && side.revert();
        side.isBannerModified() && side.revertBanner();
      });
    });
  }

  dismissCurrent() {
    this.dismissConflicts(this.getCurrentConflicts().map(match => match.conflict));
  }

  dismissConflicts(conflicts) {
    this.setState(prevState => {
      const {added} = compareSets(new Set(conflicts), prevState.conflicts);
      return {conflicts: added};
    });
  }

  resolveAsSequence(conflict, sources) {
    const [firstSide, ...restOfSides] = sources
      .map(source => conflict.getSide(source))
      .filter(side => side);

    const textToAppend = restOfSides.map(side => side.getText()).join('');

    this.props.editor.transact(() => {
      // Append text from all but the first Side to the first Side. Adjust the following DisplayMarker so that only that
      // Side's marker includes the appended text, not the next one.
      const appendedRange = firstSide.appendText(textToAppend);
      const nextMarker = conflict.markerAfter(firstSide.getPosition());
      if (nextMarker) {
        nextMarker.setTailBufferPosition(appendedRange.end);
      }

      this.innerResolveAs(conflict, sources[0]);
    });
  }

  resolveAs(conflict, source) {
    this.props.editor.transact(() => {
      this.innerResolveAs(conflict, source);
    });
  }

  innerResolveAs(conflict, source) {
    conflict.resolveAs(source);

    const chosenSide = conflict.getChosenSide();
    if (!chosenSide.isBannerModified()) {
      chosenSide.deleteBanner();
    }

    const separator = conflict.getSeparator();
    if (!separator.isModified()) {
      separator.delete();
    }

    conflict.getUnchosenSides().forEach(side => {
      side.deleteBanner();
      side.delete();
    });

    this.updateMarkerCount();
  }

  reparseConflicts() {
    const newConflicts = new Set(Conflict.allFromEditor(this.props.editor, this.layer, this.props.isRebase));
    this.setState({conflicts: newConflicts});
  }

  updateMarkerCount() {
    this.props.resolutionProgress.reportMarkerCount(
      this.props.editor.getPath(),
      Array.from(this.state.conflicts, c => !c.isResolved()).filter(b => b).length,
    );
  }
}
