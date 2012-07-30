// CocoaOniguruma is copyrighted free software by Satoshi Nakagawa <psychs AT limechat DOT net>.
// You can redistribute it and/or modify it under the new BSD license.

#import <Foundation/Foundation.h>
#import "oniguruma.h"
#import "OnigRegexpUtility.h"


@class OnigResult;

typedef enum {
    OnigOptionNone = ONIG_OPTION_NONE,
    OnigOptionIgnorecase = ONIG_OPTION_IGNORECASE,
    OnigOptionExtend = ONIG_OPTION_EXTEND,
    OnigOptionMultiline = ONIG_OPTION_MULTILINE,
    OnigOptionSingleline = ONIG_OPTION_SINGLELINE,
    OnigOptionFindLongest = ONIG_OPTION_FIND_LONGEST,
    OnigOptionFindNotEmpty = ONIG_OPTION_FIND_NOT_EMPTY,
    OnigOptionNegateSingleLine = ONIG_OPTION_NEGATE_SINGLELINE,
    OnigOptionDontCaptureGroup = ONIG_OPTION_DONT_CAPTURE_GROUP,
    OnigOptionCaptureGroup = ONIG_OPTION_CAPTURE_GROUP,
    
    /* options (search time) */
    OnigOptionNotbol = ONIG_OPTION_NOTBOL,
    OnigOptionNoteol = ONIG_OPTION_NOTEOL,
    OnigOptionPosixRegion = ONIG_OPTION_POSIX_REGION,
    OnigOptionMaxbit = ONIG_OPTION_MAXBIT
} OnigOption;

@interface OnigRegexp : NSObject
{
    regex_t* _entity;
    NSString* _expression;
}

+ (OnigRegexp*)compile:(NSString*)expression;
+ (OnigRegexp*)compile:(NSString*)expression error:(NSError **)error;
+ (OnigRegexp*)compileIgnorecase:(NSString*)expression;
+ (OnigRegexp*)compileIgnorecase:(NSString*)expression error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended error:(NSError **)error;
+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)options;
+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)options error:(NSError **)error;

- (OnigResult*)search:(NSString*)target;
- (OnigResult*)search:(NSString*)target start:(int)start;
- (OnigResult*)search:(NSString*)target start:(int)start end:(int)end;
- (OnigResult*)search:(NSString*)target range:(NSRange)range;

- (OnigResult*)match:(NSString*)target;
- (OnigResult*)match:(NSString*)target start:(int)start;

- (NSString*)expression;

@end


@interface OnigResult : NSObject
{
    OnigRegexp* _expression;
    OnigRegion* _region;
    NSString* _target;
    NSMutableArray* _captureNames;
}

- (NSString*)target;

- (int)count;
- (NSString*)stringAt:(int)index;
- (NSArray*)strings;
- (NSRange)rangeAt:(int)index;
- (int)locationAt:(int)index;
- (int)lengthAt:(int)index;

- (NSString*)body;
- (NSRange)bodyRange;

- (NSString*)preMatch;
- (NSString*)postMatch;

// named capture support
- (NSArray*)captureNames;
- (int)indexForName:(NSString*)name;
- (NSIndexSet*)indexesForName:(NSString*)name;
- (NSString*)stringForName:(NSString*)name;
- (NSArray*)stringsForName:(NSString*)name;

@end
