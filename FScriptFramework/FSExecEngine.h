
/*   FSExecEngine.h Copyright (c) 1998-2009 Philippe Mougin.  */
/*   This software is open source. See the license.     */   

#import "FSSymbolTable.h"
#import "FSMsgContext.h"

@class NSException;
@class FSCNBase;
@class FSPattern;
@class FSBlock;
@class FSObjectPointer;

@interface ExecException : NSObject

    @property(nonatomic,assign) NSInteger errorFirstCharIndex;
    @property(nonatomic,assign) NSInteger errorLastCharIndex;
    @property(nonatomic,copy) NSString *errorStr;
    @property(nonatomic,strong) id exception;
    @property(nonatomic,strong) id result;

@end

#pragma message "need to investigate life of object referenced in ObjCValue union."
union ObjCValue
{
  id   __unsafe_unretained     idValue;
  Class              ClassValue;
  SEL                SELValue;
  _Bool              _BoolValue;
  char               charValue;
  unsigned char      unsignedCharValue;
  short              shortValue;
  unsigned short     unsignedShortValue;
  int                intValue;
  unsigned int       unsignedIntValue;
  long               longValue;
  unsigned long      unsignedLongValue;
  long long          longLongValue;
  unsigned long long unsignedLongLongValue;
  float              floatValue;
  double             doubleValue;
  NSRange            NSRangeValue;
  NSSize             NSSizeValue;
  CGSize             CGSizeValue;
  NSPoint            NSPointValue;
  CGPoint            CGPointValue;
  NSRect             NSRectValue;
  CGRect             CGRectValue;
  CGAffineTransform  CGAffineTransformValue;
  void *             voidPtrValue;  
};


enum FSMapType {FSMapArgument, FSMapReturnValue, FSMapDereferencedPointer, FSMapIVar};

void FSMapFromObject(void *valuePtr, NSUInteger index, char fsEncodedType, id object, enum FSMapType mapType, NSUInteger argumentNumber, SEL selector, NSString *ivarName, FSObjectPointer **mappedFSObjectPointerPtr);

id FSMapToObject(void *valuePtr, NSUInteger index, char fsEncodedType, const char *foundationStyleEncodedType, NSString *unsuportedTypeErrorMessage, NSString *ivarName);

ExecException* execute(FSCNBase *codeNode, FSSymbolTable *symbolTable); // may raise

ExecException* executeForBlock(FSCNBase *codeNode, FSSymbolTable *symbolTable, FSBlock* executedBlock); // may raise

id execute_rec(FSCNBase *codeNode, FSSymbolTable *localSymbolTable, NSInteger *errorFirstCharIndexPtr, NSInteger *errorLastCharIndexPtr);  

id sendMsg(id receiver, SEL selector, NSUInteger argumentCount, id args,FSPattern* pattern,FSMsgContext *msgContext, Class ancestorToStartWith);

id sendMsgNoPattern(id receiver, SEL selector, NSUInteger argumentCount, id args,FSMsgContext *msgContext, Class ancestorToStartWith);

id sendMsgPattern(id receiver, SEL selector, NSUInteger argumentCount, id args,FSPattern* pattern,FSMsgContext *msgContext, Class ancestorToStartWith);
