/* ***** BEGIN LICENSE BLOCK *****
 * The Original Code is Ajax.org Code Editor (ACE).
 *
 * Contributor(s):
 *      John DeSoi, Ph.D. <desoi AT pgedit DOT com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK *****
 *
 */


define(function(require, exports, module) {

var oop = require("ace/lib/oop");
var lang = require("ace/lib/lang");
var DocCommentHighlightRules = require("./doc_comment_highlight_rules").DocCommentHighlightRules;
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;
// Supporting perl and python for now -- both in pg core and ace
var PerlHighlightRules = require("./perl_highlight_rules").PerlHighlightRules;
var PythonHighlightRules = require("./python_highlight_rules").PythonHighlightRules;

var PgsqlHighlightRules = function() {
    
    // Keywords, functions, operators last updated for pg 9.1.
    var keywords = lang.arrayToMap(
        ("abort|absolute|abstime|access|aclitem|action|add|admin|after|aggregate|all|also|alter|always|" +
        "analyse|analyze|and|any|anyarray|anyelement|anyenum|anynonarray|array|as|asc|assertion|" +
        "assignment|asymmetric|at|attribute|authorization|backward|before|begin|between|bigint|" +
        "binary|bit|bool|boolean|both|box|bpchar|by|bytea|cache|called|cascade|cascaded|case|cast|" +
        "catalog|chain|char|character|characteristics|check|checkpoint|cid|cidr|circle|class|close|" +
        "cluster|coalesce|collate|collation|column|comment|comments|commit|committed|concurrently|" +
        "configuration|connection|constraint|constraints|content|continue|conversion|copy|cost|" +
        "create|cross|cstring|csv|current|current_catalog|current_date|current_role|" +
        "current_schema|current_time|current_timestamp|current_user|cursor|cycle|data|database|" +
        "date|day|deallocate|dec|decimal|declare|default|defaults|deferrable|deferred|definer|delete|" +
        "delimiter|delimiters|desc|dictionary|disable|discard|distinct|do|document|domain|double|" +
        "drop|each|else|enable|encoding|encrypted|end|enum|escape|except|exclude|excluding|exclusive|" +
        "execute|exists|explain|extension|external|extract|false|family|fdw_handler|fetch|first|" +
        "float|float4|float8|following|for|force|foreign|forward|freeze|from|full|function|functions|" +
        "global|grant|granted|greatest|group|gtsvector|handler|having|header|hold|hour|identity|if|" +
        "ilike|immediate|immutable|implicit|in|including|increment|index|indexes|inet|inherit|" +
        "inherits|initially|inline|inner|inout|input|insensitive|insert|instead|int|int2|int2vector|" +
        "int4|int8|integer|internal|intersect|interval|into|invoker|is|isnull|isolation|join|key|label|" +
        "language|language_handler|large|last|lc_collate|lc_ctype|leading|least|left|level|like|" +
        "limit|line|listen|load|local|localtime|localtimestamp|location|lock|lseg|macaddr|mapping|" +
        "match|maxvalue|minute|minvalue|mode|money|month|move|name|names|national|natural|nchar|next|no|" +
        "none|not|nothing|notify|notnull|nowait|null|nullif|nulls|numeric|object|of|off|offset|oid|oids|" +
        "oidvector|on|only|opaque|operator|option|options|or|order|out|outer|over|overlaps|overlay|" +
        "owned|owner|parser|partial|partition|passing|password|path|pg_attribute|pg_auth_members|" +
        "pg_authid|pg_class|pg_database|pg_node_tree|pg_proc|pg_type|placing|plans|point|polygon|" +
        "position|preceding|precision|prepare|prepared|preserve|primary|prior|privileges|" +
        "procedural|procedure|quote|range|read|real|reassign|recheck|record|recursive|ref|refcursor|" +
        "references|regclass|regconfig|regdictionary|regoper|regoperator|regproc|regprocedure|" +
        "regtype|reindex|relative|release|reltime|rename|repeatable|replace|replica|reset|restart|" +
        "restrict|returning|returns|revoke|right|role|rollback|row|rows|rule|savepoint|schema|scroll|" +
        "search|second|security|select|sequence|sequences|serializable|server|session|session_user|" +
        "set|setof|share|show|similar|simple|smallint|smgr|some|stable|standalone|start|statement|" +
        "statistics|stdin|stdout|storage|strict|strip|substring|symmetric|sysid|system|table|tables|" +
        "tablespace|temp|template|temporary|text|then|tid|time|timestamp|timestamptz|timetz|" +
        "tinterval|to|trailing|transaction|treat|trigger|trim|true|truncate|trusted|tsquery|tsvector|" +
        "txid_snapshot|type|unbounded|uncommitted|unencrypted|union|unique|unknown|unlisten|" +
        "unlogged|until|update|user|using|uuid|vacuum|valid|validate|validator|value|values|varbit|" +
        "varchar|variadic|varying|verbose|version|view|void|volatile|when|where|whitespace|window|" +
        "with|without|work|wrapper|write|xid|xml|xmlattributes|xmlconcat|xmlelement|xmlexists|" +
        "xmlforest|xmlparse|xmlpi|xmlroot|xmlserialize|year|yes|zone").split("|")
    );
    
    
    var builtinFunctions = lang.arrayToMap(
        ("RI_FKey_cascade_del|RI_FKey_cascade_upd|RI_FKey_check_ins|RI_FKey_check_upd|" +
        "RI_FKey_noaction_del|RI_FKey_noaction_upd|RI_FKey_restrict_del|RI_FKey_restrict_upd|" +
        "RI_FKey_setdefault_del|RI_FKey_setdefault_upd|RI_FKey_setnull_del|" +
        "RI_FKey_setnull_upd|abbrev|abs|abstime|abstimeeq|abstimege|abstimegt|abstimein|abstimele|" +
        "abstimelt|abstimene|abstimeout|abstimerecv|abstimesend|aclcontains|aclexplode|aclinsert|" +
        "aclitemeq|aclitemin|aclitemout|aclremove|acos|age|any_in|any_out|anyarray_in|anyarray_out|" +
        "anyarray_recv|anyarray_send|anyelement_in|anyelement_out|anyenum_in|anyenum_out|" +
        "anynonarray_in|anynonarray_out|anytextcat|area|areajoinsel|areasel|array_agg|" +
        "array_agg_finalfn|array_agg_transfn|array_append|array_cat|array_dims|array_eq|" +
        "array_fill|array_ge|array_gt|array_in|array_larger|array_le|array_length|array_lower|" +
        "array_lt|array_ndims|array_ne|array_out|array_prepend|array_recv|array_send|" +
        "array_smaller|array_to_string|array_upper|arraycontained|arraycontains|arrayoverlap|" +
        "ascii|ascii_to_mic|ascii_to_utf8|asin|atan|atan2|avg|big5_to_euc_tw|big5_to_mic|" +
        "big5_to_utf8|bit_and|bit_in|bit_length|bit_or|bit_out|bit_recv|bit_send|bitand|bitcat|" +
        "bitcmp|biteq|bitge|bitgt|bitle|bitlt|bitne|bitnot|bitor|bitshiftleft|bitshiftright|" +
        "bittypmodin|bittypmodout|bitxor|bool|bool_and|bool_or|booland_statefunc|booleq|boolge|" +
        "boolgt|boolin|boolle|boollt|boolne|boolor_statefunc|boolout|boolrecv|boolsend|box|" +
        "box_above|box_above_eq|box_add|box_below|box_below_eq|box_center|box_contain|" +
        "box_contain_pt|box_contained|box_distance|box_div|box_eq|box_ge|box_gt|box_in|" +
        "box_intersect|box_le|box_left|box_lt|box_mul|box_out|box_overabove|box_overbelow|" +
        "box_overlap|box_overleft|box_overright|box_recv|box_right|box_same|box_send|box_sub|" +
        "bpchar_larger|bpchar_pattern_ge|bpchar_pattern_gt|bpchar_pattern_le|" +
        "bpchar_pattern_lt|bpchar_smaller|bpcharcmp|bpchareq|bpcharge|bpchargt|bpchariclike|" +
        "bpcharicnlike|bpcharicregexeq|bpcharicregexne|bpcharin|bpcharle|bpcharlike|bpcharlt|" +
        "bpcharne|bpcharnlike|bpcharout|bpcharrecv|bpcharregexeq|bpcharregexne|bpcharsend|" +
        "bpchartypmodin|bpchartypmodout|broadcast|btabstimecmp|btarraycmp|btbeginscan|btboolcmp|" +
        "btbpchar_pattern_cmp|btbuild|btbuildempty|btbulkdelete|btcharcmp|btcostestimate|" +
        "btendscan|btfloat48cmp|btfloat4cmp|btfloat84cmp|btfloat8cmp|btgetbitmap|btgettuple|" +
        "btinsert|btint24cmp|btint28cmp|btint2cmp|btint42cmp|btint48cmp|btint4cmp|btint82cmp|" +
        "btint84cmp|btint8cmp|btmarkpos|btnamecmp|btoidcmp|btoidvectorcmp|btoptions|btrecordcmp|" +
        "btreltimecmp|btrescan|btrestrpos|btrim|bttext_pattern_cmp|bttextcmp|bttidcmp|" +
        "bttintervalcmp|btvacuumcleanup|byteacat|byteacmp|byteaeq|byteage|byteagt|byteain|byteale|" +
        "bytealike|bytealt|byteane|byteanlike|byteaout|bytearecv|byteasend|cash_cmp|cash_div_cash|" +
        "cash_div_flt4|cash_div_flt8|cash_div_int2|cash_div_int4|cash_eq|cash_ge|cash_gt|cash_in|" +
        "cash_le|cash_lt|cash_mi|cash_mul_flt4|cash_mul_flt8|cash_mul_int2|cash_mul_int4|cash_ne|" +
        "cash_out|cash_pl|cash_recv|cash_send|cash_words|cashlarger|cashsmaller|cbrt|ceil|ceiling|" +
        "center|char|char_length|character_length|chareq|charge|chargt|charin|charle|charlt|charne|" +
        "charout|charrecv|charsend|chr|cideq|cidin|cidout|cidr|cidr_in|cidr_out|cidr_recv|cidr_send|" +
        "cidrecv|cidsend|circle|circle_above|circle_add_pt|circle_below|circle_center|" +
        "circle_contain|circle_contain_pt|circle_contained|circle_distance|circle_div_pt|" +
        "circle_eq|circle_ge|circle_gt|circle_in|circle_le|circle_left|circle_lt|circle_mul_pt|" +
        "circle_ne|circle_out|circle_overabove|circle_overbelow|circle_overlap|circle_overleft|" +
        "circle_overright|circle_recv|circle_right|circle_same|circle_send|circle_sub_pt|" +
        "clock_timestamp|close_lb|close_ls|close_lseg|close_pb|close_pl|close_ps|close_sb|" +
        "close_sl|col_description|concat|concat_ws|contjoinsel|contsel|convert|convert_from|" +
        "convert_to|corr|cos|cot|count|covar_pop|covar_samp|cstring_in|cstring_out|cstring_recv|" +
        "cstring_send|cume_dist|current_database|current_query|current_schema|current_schemas|" +
        "current_setting|current_user|currtid|currtid2|currval|cursor_to_xml|" +
        "cursor_to_xmlschema|database_to_xml|database_to_xml_and_xmlschema|" +
        "database_to_xmlschema|date|date_cmp|date_cmp_timestamp|date_cmp_timestamptz|date_eq|" +
        "date_eq_timestamp|date_eq_timestamptz|date_ge|date_ge_timestamp|date_ge_timestamptz|" +
        "date_gt|date_gt_timestamp|date_gt_timestamptz|date_in|date_larger|date_le|" +
        "date_le_timestamp|date_le_timestamptz|date_lt|date_lt_timestamp|date_lt_timestamptz|" +
        "date_mi|date_mi_interval|date_mii|date_ne|date_ne_timestamp|date_ne_timestamptz|" +
        "date_out|date_part|date_pl_interval|date_pli|date_recv|date_send|date_smaller|" +
        "date_trunc|datetime_pl|datetimetz_pl|dcbrt|decode|degrees|dense_rank|dexp|diagonal|" +
        "diameter|dispell_init|dispell_lexize|dist_cpoly|dist_lb|dist_pb|dist_pc|dist_pl|" +
        "dist_ppath|dist_ps|dist_sb|dist_sl|div|dlog1|dlog10|domain_in|domain_recv|dpow|dround|" +
        "dsimple_init|dsimple_lexize|dsnowball_init|dsnowball_lexize|dsqrt|dsynonym_init|" +
        "dsynonym_lexize|dtrunc|encode|enum_cmp|enum_eq|enum_first|enum_ge|enum_gt|enum_in|" +
        "enum_larger|enum_last|enum_le|enum_lt|enum_ne|enum_out|enum_range|enum_recv|enum_send|" +
        "enum_smaller|eqjoinsel|eqsel|euc_cn_to_mic|euc_cn_to_utf8|" +
        "euc_jis_2004_to_shift_jis_2004|euc_jis_2004_to_utf8|euc_jp_to_mic|euc_jp_to_sjis|" +
        "euc_jp_to_utf8|euc_kr_to_mic|euc_kr_to_utf8|euc_tw_to_big5|euc_tw_to_mic|" +
        "euc_tw_to_utf8|every|exp|factorial|family|fdw_handler_in|fdw_handler_out|first_value|" +
        "float4|float48div|float48eq|float48ge|float48gt|float48le|float48lt|float48mi|float48mul|" +
        "float48ne|float48pl|float4_accum|float4abs|float4div|float4eq|float4ge|float4gt|float4in|" +
        "float4larger|float4le|float4lt|float4mi|float4mul|float4ne|float4out|float4pl|float4recv|" +
        "float4send|float4smaller|float4um|float4up|float8|float84div|float84eq|float84ge|" +
        "float84gt|float84le|float84lt|float84mi|float84mul|float84ne|float84pl|float8_accum|" +
        "float8_avg|float8_corr|float8_covar_pop|float8_covar_samp|float8_regr_accum|" +
        "float8_regr_avgx|float8_regr_avgy|float8_regr_intercept|float8_regr_r2|" +
        "float8_regr_slope|float8_regr_sxx|float8_regr_sxy|float8_regr_syy|float8_stddev_pop|" +
        "float8_stddev_samp|float8_var_pop|float8_var_samp|float8abs|float8div|float8eq|" +
        "float8ge|float8gt|float8in|float8larger|float8le|float8lt|float8mi|float8mul|float8ne|" +
        "float8out|float8pl|float8recv|float8send|float8smaller|float8um|float8up|floor|" +
        "flt4_mul_cash|flt8_mul_cash|fmgr_c_validator|fmgr_internal_validator|" +
        "fmgr_sql_validator|format|format_type|gb18030_to_utf8|gbk_to_utf8|generate_series|" +
        "generate_subscripts|get_bit|get_byte|get_current_ts_config|getdatabaseencoding|" +
        "getpgusername|gin_cmp_prefix|gin_cmp_tslexeme|gin_extract_tsquery|" +
        "gin_extract_tsvector|gin_tsquery_consistent|ginarrayconsistent|ginarrayextract|" +
        "ginbeginscan|ginbuild|ginbuildempty|ginbulkdelete|gincostestimate|ginendscan|" +
        "gingetbitmap|gininsert|ginmarkpos|ginoptions|ginqueryarrayextract|ginrescan|" +
        "ginrestrpos|ginvacuumcleanup|gist_box_compress|gist_box_consistent|" +
        "gist_box_decompress|gist_box_penalty|gist_box_picksplit|gist_box_same|gist_box_union|" +
        "gist_circle_compress|gist_circle_consistent|gist_point_compress|" +
        "gist_point_consistent|gist_point_distance|gist_poly_compress|gist_poly_consistent|" +
        "gistbeginscan|gistbuild|gistbuildempty|gistbulkdelete|gistcostestimate|gistendscan|" +
        "gistgetbitmap|gistgettuple|gistinsert|gistmarkpos|gistoptions|gistrescan|gistrestrpos|" +
        "gistvacuumcleanup|gtsquery_compress|gtsquery_consistent|gtsquery_decompress|" +
        "gtsquery_penalty|gtsquery_picksplit|gtsquery_same|gtsquery_union|gtsvector_compress|" +
        "gtsvector_consistent|gtsvector_decompress|gtsvector_penalty|gtsvector_picksplit|" +
        "gtsvector_same|gtsvector_union|gtsvectorin|gtsvectorout|has_any_column_privilege|" +
        "has_column_privilege|has_database_privilege|has_foreign_data_wrapper_privilege|" +
        "has_function_privilege|has_language_privilege|has_schema_privilege|" +
        "has_sequence_privilege|has_server_privilege|has_table_privilege|" +
        "has_tablespace_privilege|hash_aclitem|hash_array|hash_numeric|hashbeginscan|" +
        "hashbpchar|hashbuild|hashbuildempty|hashbulkdelete|hashchar|hashcostestimate|" +
        "hashendscan|hashenum|hashfloat4|hashfloat8|hashgetbitmap|hashgettuple|hashinet|" +
        "hashinsert|hashint2|hashint2vector|hashint4|hashint8|hashmacaddr|hashmarkpos|hashname|" +
        "hashoid|hashoidvector|hashoptions|hashrescan|hashrestrpos|hashtext|hashvacuumcleanup|" +
        "hashvarlena|height|host|hostmask|iclikejoinsel|iclikesel|icnlikejoinsel|icnlikesel|" +
        "icregexeqjoinsel|icregexeqsel|icregexnejoinsel|icregexnesel|inet_client_addr|" +
        "inet_client_port|inet_in|inet_out|inet_recv|inet_send|inet_server_addr|" +
        "inet_server_port|inetand|inetmi|inetmi_int8|inetnot|inetor|inetpl|initcap|int2|int24div|" +
        "int24eq|int24ge|int24gt|int24le|int24lt|int24mi|int24mul|int24ne|int24pl|int28div|int28eq|" +
        "int28ge|int28gt|int28le|int28lt|int28mi|int28mul|int28ne|int28pl|int2_accum|" +
        "int2_avg_accum|int2_mul_cash|int2_sum|int2abs|int2and|int2div|int2eq|int2ge|int2gt|int2in|" +
        "int2larger|int2le|int2lt|int2mi|int2mod|int2mul|int2ne|int2not|int2or|int2out|int2pl|" +
        "int2recv|int2send|int2shl|int2shr|int2smaller|int2um|int2up|int2vectoreq|int2vectorin|" +
        "int2vectorout|int2vectorrecv|int2vectorsend|int2xor|int4|int42div|int42eq|int42ge|" +
        "int42gt|int42le|int42lt|int42mi|int42mul|int42ne|int42pl|int48div|int48eq|int48ge|int48gt|" +
        "int48le|int48lt|int48mi|int48mul|int48ne|int48pl|int4_accum|int4_avg_accum|int4_mul_cash|" +
        "int4_sum|int4abs|int4and|int4div|int4eq|int4ge|int4gt|int4in|int4inc|int4larger|int4le|" +
        "int4lt|int4mi|int4mod|int4mul|int4ne|int4not|int4or|int4out|int4pl|int4recv|int4send|" +
        "int4shl|int4shr|int4smaller|int4um|int4up|int4xor|int8|int82div|int82eq|int82ge|int82gt|" +
        "int82le|int82lt|int82mi|int82mul|int82ne|int82pl|int84div|int84eq|int84ge|int84gt|int84le|" +
        "int84lt|int84mi|int84mul|int84ne|int84pl|int8_accum|int8_avg|int8_avg_accum|int8_sum|" +
        "int8abs|int8and|int8div|int8eq|int8ge|int8gt|int8in|int8inc|int8inc_any|" +
        "int8inc_float8_float8|int8larger|int8le|int8lt|int8mi|int8mod|int8mul|int8ne|int8not|" +
        "int8or|int8out|int8pl|int8pl_inet|int8recv|int8send|int8shl|int8shr|int8smaller|int8um|" +
        "int8up|int8xor|integer_pl_date|inter_lb|inter_sb|inter_sl|internal_in|internal_out|" +
        "interval_accum|interval_avg|interval_cmp|interval_div|interval_eq|interval_ge|" +
        "interval_gt|interval_hash|interval_in|interval_larger|interval_le|interval_lt|" +
        "interval_mi|interval_mul|interval_ne|interval_out|interval_pl|interval_pl_date|" +
        "interval_pl_time|interval_pl_timestamp|interval_pl_timestamptz|interval_pl_timetz|" +
        "interval_recv|interval_send|interval_smaller|interval_um|intervaltypmodin|" +
        "intervaltypmodout|intinterval|isclosed|isfinite|ishorizontal|iso8859_1_to_utf8|" +
        "iso8859_to_utf8|iso_to_koi8r|iso_to_mic|iso_to_win1251|iso_to_win866|isopen|isparallel|" +
        "isperp|isvertical|johab_to_utf8|justify_days|justify_hours|justify_interval|" +
        "koi8r_to_iso|koi8r_to_mic|koi8r_to_utf8|koi8r_to_win1251|koi8r_to_win866|" +
        "koi8u_to_utf8|lag|language_handler_in|language_handler_out|last_value|lastval|" +
        "latin1_to_mic|latin2_to_mic|latin2_to_win1250|latin3_to_mic|latin4_to_mic|lead|left|" +
        "length|like|like_escape|likejoinsel|likesel|line|line_distance|line_eq|line_horizontal|" +
        "line_in|line_interpt|line_intersect|line_out|line_parallel|line_perp|line_recv|" +
        "line_send|line_vertical|ln|lo_close|lo_creat|lo_create|lo_export|lo_import|lo_lseek|" +
        "lo_open|lo_tell|lo_truncate|lo_unlink|log|loread|lower|lowrite|lpad|lseg|lseg_center|" +
        "lseg_distance|lseg_eq|lseg_ge|lseg_gt|lseg_horizontal|lseg_in|lseg_interpt|" +
        "lseg_intersect|lseg_le|lseg_length|lseg_lt|lseg_ne|lseg_out|lseg_parallel|lseg_perp|" +
        "lseg_recv|lseg_send|lseg_vertical|ltrim|macaddr_cmp|macaddr_eq|macaddr_ge|macaddr_gt|" +
        "macaddr_in|macaddr_le|macaddr_lt|macaddr_ne|macaddr_out|macaddr_recv|macaddr_send|" +
        "makeaclitem|masklen|max|md5|mic_to_ascii|mic_to_big5|mic_to_euc_cn|mic_to_euc_jp|" +
        "mic_to_euc_kr|mic_to_euc_tw|mic_to_iso|mic_to_koi8r|mic_to_latin1|mic_to_latin2|" +
        "mic_to_latin3|mic_to_latin4|mic_to_sjis|mic_to_win1250|mic_to_win1251|mic_to_win866|" +
        "min|mktinterval|mod|money|mul_d_interval|name|nameeq|namege|namegt|nameiclike|nameicnlike|" +
        "nameicregexeq|nameicregexne|namein|namele|namelike|namelt|namene|namenlike|nameout|" +
        "namerecv|nameregexeq|nameregexne|namesend|neqjoinsel|neqsel|netmask|network|network_cmp|" +
        "network_eq|network_ge|network_gt|network_le|network_lt|network_ne|network_sub|" +
        "network_subeq|network_sup|network_supeq|nextval|nlikejoinsel|nlikesel|notlike|now|" +
        "npoints|nth_value|ntile|numeric_abs|numeric_accum|numeric_add|numeric_avg|" +
        "numeric_avg_accum|numeric_cmp|numeric_div|numeric_div_trunc|numeric_eq|numeric_exp|" +
        "numeric_fac|numeric_ge|numeric_gt|numeric_in|numeric_inc|numeric_larger|numeric_le|" +
        "numeric_ln|numeric_log|numeric_lt|numeric_mod|numeric_mul|numeric_ne|numeric_out|" +
        "numeric_power|numeric_recv|numeric_send|numeric_smaller|numeric_sqrt|" +
        "numeric_stddev_pop|numeric_stddev_samp|numeric_sub|numeric_uminus|numeric_uplus|" +
        "numeric_var_pop|numeric_var_samp|numerictypmodin|numerictypmodout|numnode|" +
        "obj_description|octet_length|oid|oideq|oidge|oidgt|oidin|oidlarger|oidle|oidlt|oidne|oidout|" +
        "oidrecv|oidsend|oidsmaller|oidvectoreq|oidvectorge|oidvectorgt|oidvectorin|oidvectorle|" +
        "oidvectorlt|oidvectorne|oidvectorout|oidvectorrecv|oidvectorsend|oidvectortypes|on_pb|" +
        "on_pl|on_ppath|on_ps|on_sb|on_sl|opaque_in|opaque_out|overlaps|overlay|path|path_add|" +
        "path_add_pt|path_center|path_contain_pt|path_distance|path_div_pt|path_in|path_inter|" +
        "path_length|path_mul_pt|path_n_eq|path_n_ge|path_n_gt|path_n_le|path_n_lt|path_npoints|" +
        "path_out|path_recv|path_send|path_sub_pt|pclose|percent_rank|pg_advisory_lock|" +
        "pg_advisory_lock_shared|pg_advisory_unlock|pg_advisory_unlock_all|" +
        "pg_advisory_unlock_shared|pg_advisory_xact_lock|pg_advisory_xact_lock_shared|" +
        "pg_available_extension_versions|pg_available_extensions|pg_backend_pid|" +
        "pg_cancel_backend|pg_char_to_encoding|pg_client_encoding|pg_collation_is_visible|" +
        "pg_column_size|pg_conf_load_time|pg_conversion_is_visible|pg_create_restore_point|" +
        "pg_current_xlog_insert_location|pg_current_xlog_location|pg_cursor|pg_database_size|" +
        "pg_describe_object|pg_encoding_max_length|pg_encoding_to_char|" +
        "pg_extension_config_dump|pg_extension_update_paths|pg_function_is_visible|" +
        "pg_get_constraintdef|pg_get_expr|pg_get_function_arguments|" +
        "pg_get_function_identity_arguments|pg_get_function_result|pg_get_functiondef|" +
        "pg_get_indexdef|pg_get_keywords|pg_get_ruledef|pg_get_serial_sequence|" +
        "pg_get_triggerdef|pg_get_userbyid|pg_get_viewdef|pg_has_role|pg_indexes_size|" +
        "pg_is_in_recovery|pg_is_other_temp_schema|pg_is_xlog_replay_paused|" +
        "pg_last_xact_replay_timestamp|pg_last_xlog_receive_location|" +
        "pg_last_xlog_replay_location|pg_listening_channels|pg_lock_status|pg_ls_dir|" +
        "pg_my_temp_schema|pg_node_tree_in|pg_node_tree_out|pg_node_tree_recv|" +
        "pg_node_tree_send|pg_notify|pg_opclass_is_visible|pg_operator_is_visible|" +
        "pg_options_to_table|pg_postmaster_start_time|pg_prepared_statement|pg_prepared_xact|" +
        "pg_read_binary_file|pg_read_file|pg_relation_filenode|pg_relation_filepath|" +
        "pg_relation_size|pg_reload_conf|pg_rotate_logfile|pg_sequence_parameters|" +
        "pg_show_all_settings|pg_size_pretty|pg_sleep|pg_start_backup|pg_stat_clear_snapshot|" +
        "pg_stat_file|pg_stat_get_activity|pg_stat_get_analyze_count|" +
        "pg_stat_get_autoanalyze_count|pg_stat_get_autovacuum_count|" +
        "pg_stat_get_backend_activity|pg_stat_get_backend_activity_start|" +
        "pg_stat_get_backend_client_addr|pg_stat_get_backend_client_port|" +
        "pg_stat_get_backend_dbid|pg_stat_get_backend_idset|pg_stat_get_backend_pid|" +
        "pg_stat_get_backend_start|pg_stat_get_backend_userid|pg_stat_get_backend_waiting|" +
        "pg_stat_get_backend_xact_start|pg_stat_get_bgwriter_buf_written_checkpoints|" +
        "pg_stat_get_bgwriter_buf_written_clean|pg_stat_get_bgwriter_maxwritten_clean|" +
        "pg_stat_get_bgwriter_requested_checkpoints|pg_stat_get_bgwriter_stat_reset_time|" +
        "pg_stat_get_bgwriter_timed_checkpoints|pg_stat_get_blocks_fetched|" +
        "pg_stat_get_blocks_hit|pg_stat_get_buf_alloc|pg_stat_get_buf_fsync_backend|" +
        "pg_stat_get_buf_written_backend|pg_stat_get_db_blocks_fetched|" +
        "pg_stat_get_db_blocks_hit|pg_stat_get_db_conflict_all|" +
        "pg_stat_get_db_conflict_bufferpin|pg_stat_get_db_conflict_lock|" +
        "pg_stat_get_db_conflict_snapshot|pg_stat_get_db_conflict_startup_deadlock|" +
        "pg_stat_get_db_conflict_tablespace|pg_stat_get_db_numbackends|" +
        "pg_stat_get_db_stat_reset_time|pg_stat_get_db_tuples_deleted|" +
        "pg_stat_get_db_tuples_fetched|pg_stat_get_db_tuples_inserted|" +
        "pg_stat_get_db_tuples_returned|pg_stat_get_db_tuples_updated|" +
        "pg_stat_get_db_xact_commit|pg_stat_get_db_xact_rollback|pg_stat_get_dead_tuples|" +
        "pg_stat_get_function_calls|pg_stat_get_function_self_time|" +
        "pg_stat_get_function_time|pg_stat_get_last_analyze_time|" +
        "pg_stat_get_last_autoanalyze_time|pg_stat_get_last_autovacuum_time|" +
        "pg_stat_get_last_vacuum_time|pg_stat_get_live_tuples|pg_stat_get_numscans|" +
        "pg_stat_get_tuples_deleted|pg_stat_get_tuples_fetched|" +
        "pg_stat_get_tuples_hot_updated|pg_stat_get_tuples_inserted|" +
        "pg_stat_get_tuples_returned|pg_stat_get_tuples_updated|pg_stat_get_vacuum_count|" +
        "pg_stat_get_wal_senders|pg_stat_get_xact_blocks_fetched|" +
        "pg_stat_get_xact_blocks_hit|pg_stat_get_xact_function_calls|" +
        "pg_stat_get_xact_function_self_time|pg_stat_get_xact_function_time|" +
        "pg_stat_get_xact_numscans|pg_stat_get_xact_tuples_deleted|" +
        "pg_stat_get_xact_tuples_fetched|pg_stat_get_xact_tuples_hot_updated|" +
        "pg_stat_get_xact_tuples_inserted|pg_stat_get_xact_tuples_returned|" +
        "pg_stat_get_xact_tuples_updated|pg_stat_reset|pg_stat_reset_shared|" +
        "pg_stat_reset_single_function_counters|pg_stat_reset_single_table_counters|" +
        "pg_stop_backup|pg_switch_xlog|pg_table_is_visible|pg_table_size|" +
        "pg_tablespace_databases|pg_tablespace_size|pg_terminate_backend|pg_timezone_abbrevs|" +
        "pg_timezone_names|pg_total_relation_size|pg_try_advisory_lock|" +
        "pg_try_advisory_lock_shared|pg_try_advisory_xact_lock|" +
        "pg_try_advisory_xact_lock_shared|pg_ts_config_is_visible|pg_ts_dict_is_visible|" +
        "pg_ts_parser_is_visible|pg_ts_template_is_visible|pg_type_is_visible|pg_typeof|" +
        "pg_xlog_replay_pause|pg_xlog_replay_resume|pg_xlogfile_name|pg_xlogfile_name_offset|" +
        "pi|plainto_tsquery|plpgsql_call_handler|plpgsql_inline_handler|plpgsql_validator|" +
        "point|point_above|point_add|point_below|point_distance|point_div|point_eq|point_horiz|" +
        "point_in|point_left|point_mul|point_ne|point_out|point_recv|point_right|point_send|" +
        "point_sub|point_vert|poly_above|poly_below|poly_center|poly_contain|poly_contain_pt|" +
        "poly_contained|poly_distance|poly_in|poly_left|poly_npoints|poly_out|poly_overabove|" +
        "poly_overbelow|poly_overlap|poly_overleft|poly_overright|poly_recv|poly_right|" +
        "poly_same|poly_send|polygon|popen|position|positionjoinsel|positionsel|" +
        "postgresql_fdw_validator|pow|power|prsd_end|prsd_headline|prsd_lextype|prsd_nexttoken|" +
        "prsd_start|pt_contained_circle|pt_contained_poly|query_to_xml|" +
        "query_to_xml_and_xmlschema|query_to_xmlschema|querytree|quote_ident|quote_literal|" +
        "quote_nullable|radians|radius|random|rank|record_eq|record_ge|record_gt|record_in|" +
        "record_le|record_lt|record_ne|record_out|record_recv|record_send|regclass|regclassin|" +
        "regclassout|regclassrecv|regclasssend|regconfigin|regconfigout|regconfigrecv|" +
        "regconfigsend|regdictionaryin|regdictionaryout|regdictionaryrecv|regdictionarysend|" +
        "regexeqjoinsel|regexeqsel|regexnejoinsel|regexnesel|regexp_matches|regexp_replace|" +
        "regexp_split_to_array|regexp_split_to_table|regoperatorin|regoperatorout|" +
        "regoperatorrecv|regoperatorsend|regoperin|regoperout|regoperrecv|regopersend|" +
        "regprocedurein|regprocedureout|regprocedurerecv|regproceduresend|regprocin|regprocout|" +
        "regprocrecv|regprocsend|regr_avgx|regr_avgy|regr_count|regr_intercept|regr_r2|" +
        "regr_slope|regr_sxx|regr_sxy|regr_syy|regtypein|regtypeout|regtyperecv|regtypesend|" +
        "reltime|reltimeeq|reltimege|reltimegt|reltimein|reltimele|reltimelt|reltimene|reltimeout|" +
        "reltimerecv|reltimesend|repeat|replace|reverse|right|round|row_number|rpad|rtrim|" +
        "scalargtjoinsel|scalargtsel|scalarltjoinsel|scalarltsel|schema_to_xml|" +
        "schema_to_xml_and_xmlschema|schema_to_xmlschema|session_user|set_bit|set_byte|" +
        "set_config|set_masklen|setseed|setval|setweight|shell_in|shell_out|" +
        "shift_jis_2004_to_euc_jis_2004|shift_jis_2004_to_utf8|shobj_description|sign|" +
        "similar_escape|sin|sjis_to_euc_jp|sjis_to_mic|sjis_to_utf8|slope|smgreq|smgrin|smgrne|" +
        "smgrout|split_part|sqrt|statement_timestamp|stddev|stddev_pop|stddev_samp|string_agg|" +
        "string_agg_finalfn|string_agg_transfn|string_to_array|strip|strpos|substr|substring|sum|" +
        "suppress_redundant_updates_trigger|table_to_xml|table_to_xml_and_xmlschema|" +
        "table_to_xmlschema|tan|text|text_ge|text_gt|text_larger|text_le|text_lt|text_pattern_ge|" +
        "text_pattern_gt|text_pattern_le|text_pattern_lt|text_smaller|textanycat|textcat|texteq|" +
        "texticlike|texticnlike|texticregexeq|texticregexne|textin|textlen|textlike|textne|" +
        "textnlike|textout|textrecv|textregexeq|textregexne|textsend|thesaurus_init|" +
        "thesaurus_lexize|tideq|tidge|tidgt|tidin|tidlarger|tidle|tidlt|tidne|tidout|tidrecv|tidsend|" +
        "tidsmaller|time_cmp|time_eq|time_ge|time_gt|time_hash|time_in|time_larger|time_le|time_lt|" +
        "time_mi_interval|time_mi_time|time_ne|time_out|time_pl_interval|time_recv|time_send|" +
        "time_smaller|timedate_pl|timemi|timenow|timeofday|timepl|timestamp_cmp|" +
        "timestamp_cmp_date|timestamp_cmp_timestamptz|timestamp_eq|timestamp_eq_date|" +
        "timestamp_eq_timestamptz|timestamp_ge|timestamp_ge_date|timestamp_ge_timestamptz|" +
        "timestamp_gt|timestamp_gt_date|timestamp_gt_timestamptz|timestamp_hash|timestamp_in|" +
        "timestamp_larger|timestamp_le|timestamp_le_date|timestamp_le_timestamptz|" +
        "timestamp_lt|timestamp_lt_date|timestamp_lt_timestamptz|timestamp_mi|" +
        "timestamp_mi_interval|timestamp_ne|timestamp_ne_date|timestamp_ne_timestamptz|" +
        "timestamp_out|timestamp_pl_interval|timestamp_recv|timestamp_send|timestamp_smaller|" +
        "timestamptypmodin|timestamptypmodout|timestamptz_cmp|timestamptz_cmp_date|" +
        "timestamptz_cmp_timestamp|timestamptz_eq|timestamptz_eq_date|" +
        "timestamptz_eq_timestamp|timestamptz_ge|timestamptz_ge_date|" +
        "timestamptz_ge_timestamp|timestamptz_gt|timestamptz_gt_date|" +
        "timestamptz_gt_timestamp|timestamptz_in|timestamptz_larger|timestamptz_le|" +
        "timestamptz_le_date|timestamptz_le_timestamp|timestamptz_lt|timestamptz_lt_date|" +
        "timestamptz_lt_timestamp|timestamptz_mi|timestamptz_mi_interval|timestamptz_ne|" +
        "timestamptz_ne_date|timestamptz_ne_timestamp|timestamptz_out|" +
        "timestamptz_pl_interval|timestamptz_recv|timestamptz_send|timestamptz_smaller|" +
        "timestamptztypmodin|timestamptztypmodout|timetypmodin|timetypmodout|timetz_cmp|" +
        "timetz_eq|timetz_ge|timetz_gt|timetz_hash|timetz_in|timetz_larger|timetz_le|timetz_lt|" +
        "timetz_mi_interval|timetz_ne|timetz_out|timetz_pl_interval|timetz_recv|timetz_send|" +
        "timetz_smaller|timetzdate_pl|timetztypmodin|timetztypmodout|timezone|tinterval|" +
        "tintervalct|tintervalend|tintervaleq|tintervalge|tintervalgt|tintervalin|tintervalle|" +
        "tintervalleneq|tintervallenge|tintervallengt|tintervallenle|tintervallenlt|" +
        "tintervallenne|tintervallt|tintervalne|tintervalout|tintervalov|tintervalrecv|" +
        "tintervalrel|tintervalsame|tintervalsend|tintervalstart|to_ascii|to_char|to_date|to_hex|" +
        "to_number|to_timestamp|to_tsquery|to_tsvector|transaction_timestamp|translate|" +
        "trigger_in|trigger_out|trunc|ts_debug|ts_headline|ts_lexize|ts_match_qv|ts_match_tq|" +
        "ts_match_tt|ts_match_vq|ts_parse|ts_rank|ts_rank_cd|ts_rewrite|ts_stat|ts_token_type|" +
        "ts_typanalyze|tsmatchjoinsel|tsmatchsel|tsq_mcontained|tsq_mcontains|tsquery_and|" +
        "tsquery_cmp|tsquery_eq|tsquery_ge|tsquery_gt|tsquery_le|tsquery_lt|tsquery_ne|" +
        "tsquery_not|tsquery_or|tsqueryin|tsqueryout|tsqueryrecv|tsquerysend|tsvector_cmp|" +
        "tsvector_concat|tsvector_eq|tsvector_ge|tsvector_gt|tsvector_le|tsvector_lt|" +
        "tsvector_ne|tsvector_update_trigger|tsvector_update_trigger_column|tsvectorin|" +
        "tsvectorout|tsvectorrecv|tsvectorsend|txid_current|txid_current_snapshot|" +
        "txid_snapshot_in|txid_snapshot_out|txid_snapshot_recv|txid_snapshot_send|" +
        "txid_snapshot_xip|txid_snapshot_xmax|txid_snapshot_xmin|txid_visible_in_snapshot|" +
        "uhc_to_utf8|unique_key_recheck|unknownin|unknownout|unknownrecv|unknownsend|unnest|" +
        "upper|utf8_to_ascii|utf8_to_big5|utf8_to_euc_cn|utf8_to_euc_jis_2004|utf8_to_euc_jp|" +
        "utf8_to_euc_kr|utf8_to_euc_tw|utf8_to_gb18030|utf8_to_gbk|utf8_to_iso8859|" +
        "utf8_to_iso8859_1|utf8_to_johab|utf8_to_koi8r|utf8_to_koi8u|utf8_to_shift_jis_2004|" +
        "utf8_to_sjis|utf8_to_uhc|utf8_to_win|uuid_cmp|uuid_eq|uuid_ge|uuid_gt|uuid_hash|uuid_in|" +
        "uuid_le|uuid_lt|uuid_ne|uuid_out|uuid_recv|uuid_send|var_pop|var_samp|varbit_in|" +
        "varbit_out|varbit_recv|varbit_send|varbitcmp|varbiteq|varbitge|varbitgt|varbitle|" +
        "varbitlt|varbitne|varbittypmodin|varbittypmodout|varcharin|varcharout|varcharrecv|" +
        "varcharsend|varchartypmodin|varchartypmodout|variance|version|void_in|void_out|" +
        "void_recv|void_send|width|width_bucket|win1250_to_latin2|win1250_to_mic|win1251_to_iso|" +
        "win1251_to_koi8r|win1251_to_mic|win1251_to_win866|win866_to_iso|win866_to_koi8r|" +
        "win866_to_mic|win866_to_win1251|win_to_utf8|xideq|xideqint4|xidin|xidout|xidrecv|xidsend|" +
        "xml|xml_in|xml_is_well_formed|xml_is_well_formed_content|xml_is_well_formed_document|" +
        "xml_out|xml_recv|xml_send|xmlagg|xmlcomment|xmlconcat2|xmlexists|xmlvalidate|xpath|" +
        "xpath_exists").split("|")
    );
    
    var sqlRules = [
        {
            token : "string", // single line string -- assume dollar strings if multi-line for now
            regex : "['](?:(?:\\\\.)|(?:[^'\\\\]))*?[']"
        }, {
            token : "variable.language", // pg identifier
            regex : '".*?"'
        }, {
            token : "constant.numeric", // float
            regex : "[+-]?\\d+(?:(?:\\.\\d*)?(?:[eE][+-]?\\d+)?)?\\b"
        }, {
            token : function(value) {
                value = value.toLowerCase();
                if (keywords.hasOwnProperty(value)) {
                    return "keyword";
                } else if (builtinFunctions.hasOwnProperty(value)) {
                    return "support.function";
                } else {
                    return "identifier";
                }
              },
              regex : "[a-zA-Z_][a-zA-Z0-9_$]*\\b" // TODO - Unicode in identifiers
          }, {
              token : "keyword.operator",
              regex : "!|!!|!~|!~\\*|!~~|!~~\\*|#|##|#<|#<=|#<>|#=|#>|#>=|%|\\&|\\&\\&|\\&<|\\&<\\||\\&>|\\*|\\+|" +
                      "\\-|/|<|<#>|<\\->|<<|<<=|<<\\||<=|<>|<\\?>|<@|<\\^|=|>|>=|>>|>>=|>\\^|\\?#|\\?\\-|\\?\\-\\||" +
                      "\\?\\||\\?\\|\\||@|@\\-@|@>|@@|@@@|\\^|\\||\\|\\&>|\\|/|\\|>>|\\|\\||\\|\\|/|~|~\\*|~<=~|~<~|" +
                      "~=|~>=~|~>~|~~|~~\\*"
          }, {
              token : "lparen.paren",
              regex : "[\\(]"
          }, {
              token : "paren.rparen",
              regex : "[\\)]"
          }, {
              token : "text",
              regex : "\\s+"
          }
    ];
           

    this.$rules = {
        "start" : [
            {
                token : "comment",
                regex : "--.*$"
            }, 
            new DocCommentHighlightRules().getStartRule("doc-start"),
            {
                token : "comment", // multi-line comment
                merge : true,
                regex : "\\/\\*",
                next : "comment"
            },{
                token : "keyword.statementBegin",
                regex : "^[a-zA-Z]+", // Could enumerate starting keywords but this allows things to work when new statements are added.
                next : "statement"
            },{
                token : "support.buildin", // psql directive
                regex : "^\\\\[\\S]+.*$"
            }
        ],
        
        "statement" : [
            {
                token : "comment",
                regex : "--.*$"
            }, {
                token : "comment", // multi-line comment
                merge : true,
                regex : "\\/\\*",
                next : "commentStatement"
            }, {
                token : "statementEnd",
                regex : ";",
                next : "start"
            }, {
                token : "string", // perl, python, tcl are in the pg default dist (no tcl highlighter)
                regex : "\\$perl\\$",
                next : "perl-start"
            }, {
                token : "string",
                regex : "\\$python\\$",
                next : "python-start"
            },{
                token : "string",
                regex : "\\$[\\w_0-9]*\\$$", // dollar quote at the end of a line
                next : "dollarSql"
            }, {
                token : "string",
                regex : "\\$[\\w_0-9]*\\$",
                next : "dollarStatementString"
            }
        ].concat(sqlRules),
        
        "dollarSql" : [
            {
                token : "comment",
                regex : "--.*$"
            }, {
                token : "comment", // multi-line comment
                merge : true,
                regex : "\\/\\*",
                next : "commentDollarSql"
            }, {
                token : "string", // end quoting with dollar at the start of a line
                regex : "^\\$[\\w_0-9]*\\$",
                next : "statement"
            }, {
                token : "string",
                regex : "\\$[\\w_0-9]*\\$",
                next : "dollarSqlString"
            }
        ].concat(sqlRules),
        
        "comment" : [
            {
                token : "comment", // closing comment
                regex : ".*?\\*\\/",
                next : "start"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ],
        
        "commentStatement" : [
            {
                token : "comment", // closing comment
                regex : ".*?\\*\\/",
                next : "statement"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ],
        
        "commentDollarSql" : [
            {
                token : "comment", // closing comment
                regex : ".*?\\*\\/",
                next : "dollarSql"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ],
        
        "dollarStatementString" : [
            {
                token : "string", // closing dollarstring
                regex : ".*?\\$[\\w_0-9]*\\$",
                next : "statement"
            }, {
                token : "string", // dollarstring spanning whole line
                merge : true,
                regex : ".+"
            }
        ],
        
        "dollarSqlString" : [
            {
                token : "string", // closing dollarstring
                regex : ".*?\\$[\\w_0-9]*\\$",
                next : "dollarSql"
            }, {
                token : "string", // dollarstring spanning whole line
                merge : true,
                regex : ".+"
            }
        ]
    };
    
    this.embedRules(DocCommentHighlightRules, "doc-", [ new DocCommentHighlightRules().getEndRule("start") ]);
    this.embedRules(PerlHighlightRules, "perl-", [{token : "string", regex : "\\$perl\\$", next : "statement"}]);
    this.embedRules(PythonHighlightRules, "python-", [{token : "string", regex : "\\$python\\$", next : "statement"}]);
};

oop.inherits(PgsqlHighlightRules, TextHighlightRules);

exports.PgsqlHighlightRules = PgsqlHighlightRules;
});

