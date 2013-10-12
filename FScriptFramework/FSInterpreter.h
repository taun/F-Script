/* FSInterpreter.h Copyright (c) 1998-2009 Philippe Mougin.  */
/*   This software is open source. See the license.  */  

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "FSInterpreterResult.h"

@class FSExecutor;
@class FSObjectBrowser;


@interface FSInterpreter : NSObject <NSCoding, NSWindowDelegate>
{
  FSExecutor *_executor;
}

+ (FSInterpreter *)newInterpreter;
+ (BOOL) validateSyntaxForIdentifier:(NSString *)identifier;

- (void) browse;
- (void) browse:(id)anObject;
- (NSArray *) identifiers;
- (FSInterpreterResult *) execute:(NSString *)command;
- (void) installFlightTutorial;
- (id)   objectForIdentifier:(NSString *)identifier found:(BOOL *)found; // found may be passed as NULL
- (void) setObject:(id)object forIdentifier:(NSString *)identifier;
- (BOOL) setJournalName:(NSString *)filename;
- (void) setShouldJournal:(BOOL)shouldJournal;
- (BOOL) shouldJournal;

@end
