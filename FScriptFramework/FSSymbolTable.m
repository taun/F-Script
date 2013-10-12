/*   FSSymbolTable.m Copyright (c) 1998-2008 Philippe Mougin.  */
/*   This software is open source. See the license.  */  


#import "FSSymbolTable.h"
#import "Number_fscript.h"
#import "FSArray.h"
#import "FSBoolean.h"
#import "Space.h"
#import <Foundation/Foundation.h>
#import "FSUnarchiver.h"
#import "FSKeyedUnarchiver.h"
 
@implementation SymbolTableValueWrapper

+ (void)initialize 
{
  static BOOL tooLate = NO;
  if ( !tooLate )
  {
    [self setVersion:1];
    tooLate = YES; 
  }
}  

- (id)copy
{ return [self copyWithZone:NULL]; }
 
- (id)copyWithZone:(NSZone *)zone
{
  return [[SymbolTableValueWrapper allocWithZone:zone] initWrapperWithValue: self.value symbol: self.symbol status: self.status];
}                             

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeInteger: self.status forKey:@"status"];
  [coder encodeObject: self.value   forKey:@"value"];
  [coder encodeObject: self.symbol  forKey:@"symbol"];
}

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super init];

  if ([coder allowsKeyedCoding]) 
  {
    _status = [coder decodeIntegerForKey:@"status"];
    _value  = [coder decodeObjectForKey:@"value" ];
    _symbol = [coder decodeObjectForKey:@"symbol"];
  }
  else
  {
  	if ([coder versionForClassName:@"SymbolTableValueWrapper"] == 0)
    {
      [coder decodeIntegerForKey:@"type"];
	}  
    unsigned tmp;
    [coder decodeValueOfObjCType:@encode(typeof(tmp)) at:&tmp];
    _status = tmp;
    _value  = [coder decodeObject];
    _symbol = [coder decodeObject];
  }  
  return self;
}

- initWrapperWithValue:(id)theValue symbol:(NSString *)theSymbol
{
  return [self initWrapperWithValue:theValue symbol:theSymbol status:DEFINED];
}  

- initWrapperWithValue:(id)theValue symbol:(NSString *)theSymbol status:(enum FSContext_symbol_status)theStatus
{
  if ((self = [super init]))
  {
    _status = theStatus;
    _value = theValue;
    _symbol = theSymbol;
  }
  return self;
}

@end



/////////////////////////////////////////// FSSymbolTable ///////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

void __attribute__ ((constructor)) initializeForSymbolTabletoFSSymbolTableTransition(void)
{
  [NSUnarchiver decodeClassName:@"SymbolTable" asClassName:@"FSSymbolTable"];
  [NSKeyedUnarchiver setClass:[FSSymbolTable class] forClassName:@"SymbolTable"];
}

@interface FSSymbolTable ()
@property (nonatomic,strong) FSSymbolTable* parent;
@end

@implementation FSSymbolTable
  
+ (void)initialize 
{
  static BOOL tooLate = NO;
  if ( !tooLate )
  {
    [self setVersion:2];
    tooLate = YES; 
  }
}  
  
+ symbolTable
{
  return [[self alloc] init];
}

-(NSMutableArray*) locals {
  if (!_locals) {
    _locals = [NSMutableArray new];
  }
  return _locals;
}
  
//------------------- public methods ---------------

- (FSArray *)allDefinedSymbols
{
  FSArray *r = [FSArray arrayWithCapacity:30];
  for (NSUInteger i = 0; i < self.locals.count; i++)
  {
    if ([(SymbolTableValueWrapper*)(self.locals[i]) status] == DEFINED)
    {
      [r addObject:[NSMutableString stringWithString: [(SymbolTableValueWrapper*)(self.locals[i]) symbol]]];
    }
  }  
  return r;
}  

- (BOOL) containsSymbolAtFirstLevel:(NSString *)theKey 
// Does the receiver contains the symbol (without searching parents)
{
  for (NSUInteger i = 0; i < self.locals.count; i++)
  {
    if ([[(SymbolTableValueWrapper*)(self.locals[i]) symbol] isEqualToString:theKey]) return YES;
  } 
  return NO;  
} 

- (id)copy
{ return [self copyWithZone:NULL]; }

- (id)copyWithZone:(NSZone *)zone
{
  NSMutableArray* rLocals = [_locals mutableCopy];

  return [[FSSymbolTable allocWithZone:zone] initWithParent: self.parent tryToAttachWhenDecoding:tryToAttachWhenDecoding locals:rLocals];
}  

- (void) didSendDeallocToSymbolAtIndex:(struct FSContextIndex)index
{
  FSSymbolTable *s = self;
  for (NSUInteger i = 0; i < index.level && s; i++) s = s.parent;
  
  if (s)
  {
    [(SymbolTableValueWrapper*)(s.locals[index.index]) setValue: nil];
  }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeConditionalObject: self.parent forKey:@"parent"];
  [coder encodeObject:self.locals forKey:@"localsArray"];
  [coder encodeBool:tryToAttachWhenDecoding forKey:@"tryToAttachWhenDecoding"];
} 

- (struct FSContextIndex) findOrInsertSymbol:(NSString*)theKey
// Find the symbol in the highest parent possible (or in self if we don't have a parent) or insert it 
{
  struct FSContextIndex r;
  NSUInteger i;
  
  for  (i = 0; i < self.locals.count; i++)
  {
    if ([[(SymbolTableValueWrapper*)(self.locals[i]) symbol] isEqualToString:theKey]) break;
  }  
  
  if (i == self.locals.count)
  {
    if (self.parent)
    {
      r = [self.parent findOrInsertSymbol:theKey];
      r.level++;
      return r;
    }
    else
    {
      return [self insertSymbol:theKey object:nil status:UNDEFINED];
    }  
  }    
  else
  {
    r.level = 0; r.index = i;
    return r;
  }    
}

- (id)initWithCoder:(NSCoder *)coder
{
  self = [super init];
  retainCount = 1;
  receiverRetained = YES;
  
  if ([coder allowsKeyedCoding]) 
  {
    self.parent = [coder decodeObjectForKey:@"parent"];
    NSArray* decodedArray = [coder decodeObjectForKey: @"localsArray"];
    if (decodedArray) self.locals = [decodedArray mutableCopy];
    
    tryToAttachWhenDecoding = [coder decodeBoolForKey:@"tryToAttachWhenDecoding"];
    if (tryToAttachWhenDecoding && !self.parent && [coder isKindOfClass:[FSKeyedUnarchiver class]])
      self.parent = [(FSKeyedUnarchiver *)coder loaderEnvironmentSymbolTable];
  }
  else
  {
    self.parent = [coder decodeObject];
    
    if ([coder versionForClassName:@"SymbolTable"] == 0)
    {
//      id *loc;
      unsigned int locCount;
      //NSLog(@"version == 0");
      [coder decodeValueOfObjCType: @encode(typeof(locCount)) at: &locCount];
//      loc = malloc(locCount*sizeof(id));
//      [coder decodeArrayOfObjCType: @encode(id) count:locCount at: loc];
//      free(loc);
    }
  
    if ([coder versionForClassName:@"SymbolTable"] <= 1)
    { 
      [coder decodeObject]; // Read the old "symbtable" NSDictionary
    }
    else
    {
      self.locals = [[coder decodeObject] mutableCopy];
    }
    [coder decodeValueOfObjCType:@encode(typeof(tryToAttachWhenDecoding)) at:&tryToAttachWhenDecoding];
    if (tryToAttachWhenDecoding && !self.parent && [coder isKindOfClass:[FSUnarchiver class]])
      self.parent = [(FSUnarchiver *)coder loaderEnvironmentSymbolTable];
  }  
  return self;
}

- (struct FSContextIndex)indexOfSymbol:(NSString*)theKey
{
  struct FSContextIndex r;
  NSUInteger i;
  
  for  (i = 0; i < self.locals.count; i++)
  {
    if ([[(SymbolTableValueWrapper*)(self.locals[i]) symbol] isEqualToString:theKey]) break;
  }  
      
  if (i == self.locals.count)
  {
    if (self.parent)
    {
      r = [self.parent indexOfSymbol:theKey];
      if (r.index != -1)
        r.level++;
      return r;
    }
    else
    {
      r.index = -1;
      r.level = 0; // In order to avoid a compiler warning "r.level is used uninitialized"
      return r;
    } 
  }    
  else
  {
    r.level = 0; r.index = i;
    return r;
  }    
}      

- init
{
  return [self initWithParent:nil];
}

- initWithParent:(FSSymbolTable *)theParent
{
  return [self initWithParent:theParent tryToAttachWhenDecoding:YES];
}

- initWithParent:(FSSymbolTable *)theParent tryToAttachWhenDecoding:(BOOL)shouldTry
{
  return [self initWithParent:theParent tryToAttachWhenDecoding:shouldTry locals:NULL];
} 

- initWithParent:(FSSymbolTable *)theParent tryToAttachWhenDecoding:(BOOL)shouldTry locals:(NSMutableArray *)theLocals
{
  if ((self = [super init]))
  {
    _parent = theParent;
    _locals = theLocals;
    tryToAttachWhenDecoding = shouldTry;
    receiverRetained = YES;
  }
  return self;
}

- (struct FSContextIndex)insertSymbol:(NSString*)symbol object:(id)object
{
  return [self insertSymbol:symbol object:object status:DEFINED];
}
                                   
                                   
-(struct FSContextIndex) insertSymbol:(NSString*)symbol object:(id)object status:(enum FSContext_symbol_status)status                                   
{
  struct FSContextIndex r;
  
  SymbolTableValueWrapper* newContext = [[SymbolTableValueWrapper alloc] init];
  newContext.status = status;
  newContext.value = object;
  newContext.symbol = symbol;
  
  [self.locals addObject: newContext];
  
  
  //[[NSNotificationCenter defaultCenter] postNotificationName:@"changed" object:self];   
  r.index = self.locals.count-1; r.level = 0;
  return r;
}      

- (BOOL) isEmpty  { return (self.locals.count == 0);}

- objectForIndex:(struct FSContextIndex)index isDefined:(BOOL *)isDefined
{
  FSSymbolTable *s = self;
  
  for (NSUInteger i = 0; i < index.level && s; i++) s = s.parent;
  
  if (s)
  {
    if ([(SymbolTableValueWrapper*)(self.locals[index.index]) status] == DEFINED)
    {
      *isDefined = YES;
      return [(SymbolTableValueWrapper*)(self.locals[index.index]) value];
    }
  }
  *isDefined = NO;
  return nil;
}

- (id)objectForSymbol:(NSString *)symbol found:(BOOL *)found // foud may be passed as NULL
{
  struct FSContextIndex ind = [self indexOfSymbol:symbol];
  
  if (ind.index == -1) 
  {
    if (found) *found = NO; 
    return nil;
  }
  else
  {
    BOOL isDefined;
    id r = [self objectForIndex:ind isDefined:&isDefined];
    if (isDefined)
    {
      if (found) *found = YES;
      return r;
    }
    else 
    {
      if (found) *found = NO;
      return nil;
    } 
  } 
}


- (void) removeAllObjects
{
  [self.locals removeAllObjects];
}

-(void)setObject:(id)object forSymbol:(NSString *)symbol
{
  struct FSContextIndex ind = [self indexOfSymbol:symbol];

  if (ind.index == -1) [self insertSymbol:symbol object:object];
  else                 [self setObject:object forIndex:ind];
}


- (void)setToNilSymbolsFrom:(NSUInteger)ind
{
  for (SymbolTableValueWrapper* context in self.locals) {
    context.status = DEFINED;
    context.value = nil;
  }
}


- setObject:(id)object forIndex:(struct FSContextIndex)index
{
  NSInteger i; 
  FSSymbolTable *s = self;

  for (i = 0; i < index.level && s; i++) s = s.parent;
  
  if (s)
  {    
    if (index.index != 0 || s->receiverRetained) 
    {
      // We are assigning to a regular variable (i.e., not to a "self" pointing to a non-retained receiver).
      // Therefore, we release the old value, as usual. 
      
      [(SymbolTableValueWrapper*)(self.locals[index.index]) setValue: nil];
    }
    else     
    {
      // We are assigning to a "self" pointing to a non-retained receiver (we know that because a symbol table with receiverRetained == NO
      // is a symbol table used for method execution, and the index for "self" in such tables is always 0). 
      // Therefore, we don't release the old value (i.e., the non-retained receiver).
      // The new value for "self" has been retained in (1). We note that in the receiverRetained ivar.

      s->receiverRetained = YES;
    }
    [(SymbolTableValueWrapper*)(self.locals[index.index]) setValue: object];
    [(SymbolTableValueWrapper*)(self.locals[index.index]) setStatus: DEFINED];
    return self;
  }  
  else return nil;
}

- (NSString *) symbolForIndex:(struct FSContextIndex)index
{
  FSSymbolTable *s = self;
  
  for (NSUInteger i = 0; i < index.level && s; i++) s = s.parent;
  
  if (s) return [(SymbolTableValueWrapper*)(self.locals[index.index]) symbol];
  else   return nil;
}


-(void) undefineSymbolAtIndex:(struct FSContextIndex)index
{
  FSSymbolTable *s = self;
  for (NSUInteger i = 0; i < index.level && s; i++) s = s.parent;

  if (s)
  {
    SymbolTableValueWrapper* context = self.locals[index.index];
    context.status = UNDEFINED;
    context.value = nil;
  }
}

- (void) willSendReleaseToSymbolAtIndex:(struct FSContextIndex)index
{
  FSSymbolTable *s = self;
  for (NSUInteger i = 0; i < index.level && s; i++) s = s.parent;
  
  if (s && index.index == 0 && !s->receiverRetained)
  {
    // We are informed that a release message is going to be sent to a "self" pointing to a non-retained receiver (we know that because a symbol table 
    // with receiverRetained == NO is a symbol table used for method execution, and the index for "self" in such tables is always 0).
    // Such receivers are non retained because they might be uninitialized objects (if we are executing an init... method defined in F-Script).
    // However, to follow the F-Script language semantics, if they are actualy not unitialized they must act as if they where retained. 
    // The release message might lead to a premature dealloction, and consequently break correct semantic. We retain this receiver in
    // order to avoid such premature deallocation. Note that we can safely retain it because the fact it is going to receive a release
    // message means that it is not actually an uninitialized object (unless there is programming error in the F-Script user code of course).
    s->receiverRetained = YES; 
  }
}
                                                                                
@end

