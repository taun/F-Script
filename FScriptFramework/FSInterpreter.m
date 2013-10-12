/* FSInterpreter.m Copyright (c) 1998-2009 Philippe Mougin.  */
/*   This software is open source. See the license.  */  

#import "build_config.h"

#import "FSInterpreter.h"
#import "FSInterpreterPrivate.h"
#import "FSExecutor.h"
#import "FSBooleanPrivate.h"
#import "FSVoidPrivate.h"
#import "FSArray.h"
#import "FSObjectBrowser.h"
#import "FSCompiler.h"

@interface FSInterpreter ()

@property (nonatomic,strong) FSExecutor* executor;

/*!
 Keep a strong reference to each brwoser window as they are opened.
 The browserWindow is removed and released when WindowWillClose: is called.
*/
@property (nonatomic,strong) NSMutableSet* browserWindows;

@end

@implementation FSInterpreter

+ (BOOL) validateSyntaxForIdentifier:(NSString *)identifier
{
   return [FSCompiler isValidIdentifier:identifier];
}

+ (void)initialize 
{
  static BOOL tooLate = NO;
  
  if (tooLate) return;
  tooLate = YES;
  
  // Dynamic class loading
  
  NSString *repositoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"FScriptRepositoryPath"];
  
  if (repositoryPath)
  {
    NSString *dirName = [repositoryPath stringByAppendingPathComponent:@"classes"]; 
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:dirName];
    NSString *pname; 

    while ((pname = [direnum nextObject])) 
    {
      if ([[pname pathExtension] isEqualToString:@"bundle"] || [[pname pathExtension] isEqualToString:@"framework"])
      {
        NSBundle *bundle = [NSBundle bundleWithPath:[dirName stringByAppendingPathComponent:pname]];
        [direnum skipDescendents]; // don't enumerate this directory
        [bundle principalClass];
      }
    }
  } 
}

+ (FSInterpreter *)newInterpreter
{
  return [[self alloc] init];
}

-(NSMutableSet*) browserWindows {
  if (_browserWindows == nil) {
    _browserWindows = [NSMutableSet new];
  }
  return _browserWindows;
}

- (FSObjectBrowserButtonCtxBlock *) objectBrowserButtonCtxBlockFromString:(NSString *)source // May raise
{
  return [FSObjectBrowserButtonCtxBlock blockWithSource:source parentSymbolTable:[self.executor symbolTable]]; // May raise
}

- (void)browse
{
  FSObjectBrowser *bb = [FSObjectBrowser objectBrowserWithRootObject:nil interpreter:self];
  [bb browseWorkspace];
  [bb setReleasedWhenClosed: NO];
  [bb makeKeyAndOrderFront:nil];
  [bb setDelegate: self];
  [self.browserWindows addObject: bb];
}

- (void)browse:(id)anObject
{
  FSObjectBrowser *bb = [FSObjectBrowser objectBrowserWithRootObject:anObject interpreter:self];
  [bb setReleasedWhenClosed: NO];
  [bb  makeKeyAndOrderFront:nil];
  [bb setDelegate: self];
  [self.browserWindows addObject: bb];
}

-(void)dealloc
{
  //NSLog(@"FSInterpreter dealloc");
  [_executor breakCycles];
  [_executor interpreterIsDeallocating];
  _executor = nil;
  
  [_browserWindows removeAllObjects];
  _browserWindows = nil;
}

- (NSArray *) identifiers
{
  return [self.executor allDefinedSymbols];
}

-(void)encodeWithCoder:(NSCoder *)coder
{
  if ([coder allowsKeyedCoding]) 
  {
    [coder encodeObject: self.executor forKey:@"executor"];
  }
  else
  {
    [coder encodeObject: self.executor];
  }  
}

-(FSInterpreterResult *)execute:(NSString *)command
{
  return [self.executor execute:command];
}

-(id)init
{
  if ((self = [super init]))
  {
    _executor = [[FSExecutor alloc] initWithInterpreter:self];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super init];
  if ([coder allowsKeyedCoding]) 
  {
    self.executor = [coder decodeObjectForKey:@"executor"];
  }
  else
  {
    self.executor = [coder decodeObject];
  }  
  return self;
}

- (void) installFlightTutorial
{
  [self.executor installFlightTutorial];
}

- (id)objectForIdentifier:(NSString *)identifier found:(BOOL *)found
{
  return [self.executor objectForSymbol:identifier found:found];
}

- (BOOL)setJournalName:(NSString *)filename
{
  return [self.executor setJournalName:filename];
}

-(void)setObject:(id)object forIdentifier:(NSString *)identifier
{
  [self.executor setObject:object forSymbol:identifier];
}

- (void)setShouldJournal:(BOOL)shouldJournal
{
  [self.executor setShouldJournal:shouldJournal];
}

- (BOOL)shouldJournal
{ return [self.executor shouldJournal]; }

#pragma mark - WindowDelegate protocol

-(void) windowWillClose:(NSNotification *)notification {
  NSWindow* theWindow = (NSWindow*)[notification object];
  if ([self.browserWindows containsObject: theWindow]) {
    [self.browserWindows removeObject: theWindow];
  }
}

@end
