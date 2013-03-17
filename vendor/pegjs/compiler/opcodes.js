/* Bytecode instruction opcodes. */
module.exports = {
  /* Stack Manipulation */
  PUSH:             0,    // PUSH c
  PUSH_CURR_POS:    1,    // PUSH_CURR_POS
  POP:              2,    // POP
  POP_CURR_POS:     3,    // POP_CURR_POS
  POP_N:            4,    // POP_N n
  NIP:              5,    // NIP
  NIP_CURR_POS:     6,    // NIP_CURR_POS
  APPEND:           7,    // APPEND
  WRAP:             8,    // WRAP n
  TEXT:             9,    // TEXT

  /* Conditions and Loops */

  IF:               10,   // IF t, f
  IF_ERROR:         11,   // IF_ERROR t, f
  IF_NOT_ERROR:     12,   // IF_NOT_ERROR t, f
  WHILE_NOT_ERROR:  13,   // WHILE_NOT_ERROR b

  /* Matching */

  MATCH_ANY:        14,   // MATCH_ANY a, f, ...
  MATCH_STRING:     15,   // MATCH_STRING s, a, f, ...
  MATCH_STRING_IC:  16,   // MATCH_STRING_IC s, a, f, ...
  MATCH_REGEXP:     17,   // MATCH_REGEXP r, a, f, ...
  ACCEPT_N:         18,   // ACCEPT_N n
  ACCEPT_STRING:    19,   // ACCEPT_STRING s
  FAIL:             20,   // FAIL e

  /* Calls */

  REPORT_SAVED_POS: 21,   // REPORT_SAVED_POS p
  REPORT_CURR_POS:  22,   // REPORT_CURR_POS
  CALL:             23,   // CALL f, n, pc, p1, p2, ..., pN

  /* Rules */

  RULE:             24,   // RULE r

  /* Failure Reporting */

  SILENT_FAILS_ON:  25,   // SILENT_FAILS_ON
  SILENT_FAILS_OFF: 26    // SILENT_FAILS_FF
};
