// Load and export possible initial states
export {default as Loading} from './loading';
export {default as LoadingGuess} from './loading-guess';
export {default as Absent} from './absent';
export {default as AbsentGuess} from './absent-guess';

// Load and register remaining states
import './empty';
import './initializing';
import './cloning';
import './present';
import './destroyed';
import './too-large';
