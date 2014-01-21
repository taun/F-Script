//  FSObjectBrowserView.m Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSObjectBrowserView.h"
#import "FSObjectBrowserViewObjectInfo.h"
#import <objc/objc-class.h>
#import <objc/objc.h>
#import "FSCompiler.h"
#import "FSExecEngine.h"
#import "FSInterpreterPrivate.h"
#import "FSNSObject.h"
#import "FSArray.h"
#import "FSObjectBrowserCell.h"
#import "FSMiscTools.h" 
#import "BlockStackElem.h"
#import "BlockPrivate.h"
#import "BlockInspector.h"
#import "FSMiscTools.h"
#import "FSNewlyAllocatedObjectHolder.h"
#import "ArrayRepId.h"
#import "FSObjectBrowserArgumentPanel.h"
#import "FScriptTextView.h"
#import "FSGenericObjectInspector.h"
#import "FSSystem.h"
#import "FSObjectBrowserButtonCtxBlock.h"
#import "FSObjectBrowserToolbarButton.h"
#import "FSNSString.h"
#import "FSIdentifierFormatter.h"
#import "FSCollectionInspector.h"
#import "FSBoolean.h"
#import "FSNamedNumber.h"
#import "PointerPrivate.h"
#import "FSObjectBrowserMatrix.h"
#import "PointerPrivate.h"
#import "FSObjectBrowserNamedObjectWrapper.h"
#import "FSVoid.h"
#import "FSAssociation.h"
#import "FSObjectBrowserBottomBarTextDisplay.h"

#define ESCAPE '\033'

const int FSObjectBrowserBottomBarHeight = 22;

static Class NSManagedObjectClass;

/*
static int compareClassesForAlphabeticalOrder(id class1, id class2, void *context)
{
  NSString *class1String = printString(class1); 
  NSString *class2String = printString(class2); 
  
  if ([class1String hasPrefix:@"%"] && ![class2String hasPrefix:@"%"])
    return NSOrderedDescending;
  else if ([class2String hasPrefix:@"%"] && ![class1String hasPrefix:@"%"])
    return NSOrderedAscending;
  else
    return [class1String compare:class2String]; 
}
*/

static FSObjectBrowserCell *addRowToMatrix(NSMatrix *matrix)
{
  // Since we reuse cells when filtering (because we use renewRows:columns:), we must 
  // ensure that they are correctly set-up when reused. This is the job of this function.

  FSObjectBrowserCell *cell;
  
  // For an unknown reason, the following does not correctly maintain the selection:
  // ***********
  // int numberOfRows = [matrix numberOfRows];
  // [matrix renewRows:numberOfRows+1 columns:1];
  // cell = [matrix cellAtRow:numberOfRows column:0]; 
  // ***********
  // We do the folowing instead:
  // ***********
  [matrix addRow];
  cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0]; 
  // ***********

  [cell setLeaf:NO];
  [cell setEnabled:YES];
  [cell setObjectValue:nil]; 
  [cell setObjectBrowserCellType:FSOBUNKNOWN];
  [cell setClassLabel:nil];
  [cell setLabel:nil];
  [cell setRepresentedObject:nil];
  return cell;
}


NSInteger FSCompareClassNamesForAlphabeticalOrder(NSString *className1, NSString *className2, void *context)
{  
  if ([className1 hasPrefix:@"%"] && ![className2 hasPrefix:@"%"])
    return NSOrderedDescending;
  else if ([className2 hasPrefix:@"%"] && ![className1 hasPrefix:@"%"])
    return NSOrderedAscending;
  else
    return [className1 caseInsensitiveCompare:className2]; 
}


static NSInteger FSCompareMethodsNamesForAlphabeticalOrder(NSString *m1, NSString *m2, void *context)
{  
  if ([m1 hasPrefix:@"_"] && ![m2 hasPrefix:@"_"])
    return NSOrderedDescending;
  else if ([m2 hasPrefix:@"_"] && ![m1 hasPrefix:@"_"])
    return NSOrderedAscending;
  else
    return [m1 caseInsensitiveCompare:m2]; 
}

static NSString *printStringForObjectBrowser(id object)
{
  NSString *entityName;
  NSString *result  = nil;
  
  @try
  {
    if (NSManagedObjectClass && [object isKindOfClass:NSManagedObjectClass] && (entityName = [[object entity] name]) != nil)
    {
      result = [@"Managed object: " stringByAppendingString:entityName];
    }
  }
  @catch (id exception)
  {
    result = [NSString stringWithFormat:@"*** Non printable object. The following exception was raised when "
                                        @"trying to get a textual representation of the object: %@"
                                        ,FSErrorMessageFromException(exception)];                          
  }

  if (!result) 
  {
    result = printStringLimited(object, 1000);
    if ([result length] > 510)
      result = [[result substringWithRange:NSMakeRange(0,500)] stringByAppendingString:@" ..."];
  }
  
  return result;
}


static NSString *humanReadableFScriptTypeDescriptionFromEncodedObjCType(const char *ptr)
{
  while (*ptr == 'r' || *ptr == 'n' || *ptr == 'N' || *ptr == 'o' || *ptr == 'O' || *ptr == 'R' || *ptr == 'V')
    ptr++;

  if      (strcmp(ptr,@encode(id))                  == 0) return @"";
  else if (strcmp(ptr,@encode(char))                == 0) return @"";
  else if (strcmp(ptr,@encode(int))                 == 0) return @"int";
  else if (strcmp(ptr,@encode(short))               == 0) return @"short";
  else if (strcmp(ptr,@encode(long))                == 0) return @"long";
  else if (strcmp(ptr,@encode(long long))           == 0) return @"long long";
  else if (strcmp(ptr,@encode(unsigned char))       == 0) return @"unsigned char";
  else if (strcmp(ptr,@encode(unsigned short))      == 0) return @"unsigned short";
  else if (strcmp(ptr,@encode(unsigned int))        == 0) return @"unsigned int";
  else if (strcmp(ptr,@encode(unsigned long))       == 0) return @"unsigned long";
  else if (strcmp(ptr,@encode(unsigned long long))  == 0) return @"unsigned long long";
  else if (strcmp(ptr,@encode(float))               == 0) return @"float";
  else if (strcmp(ptr,@encode(double))              == 0) return @"double";
  else if (strcmp(ptr,@encode(char *))              == 0) return @"pointer";
  else if (strcmp(ptr,@encode(SEL))                 == 0) return @"SEL";
  else if (strcmp(ptr,@encode(Class))               == 0) return @"Class";
  else if (strcmp(ptr,@encode(NSRange))             == 0) return @"NSRange";
  else if (strcmp(ptr,@encode(NSPoint))             == 0) return @"NSPoint";
  else if (strcmp(ptr,@encode(NSSize))              == 0) return @"NSSize";
  else if (strcmp(ptr,@encode(NSRect))              == 0) return @"NSRect";
  else if (strcmp(ptr,@encode(CGPoint))             == 0) return @"CGPoint";
  else if (strcmp(ptr,@encode(CGSize))              == 0) return @"CGSize";
  else if (strcmp(ptr,@encode(CGRect))              == 0) return @"CGRect";
  else if (strcmp(ptr,@encode(CGAffineTransform))   == 0) return @"CGAffineTransform";
  else if (strcmp(ptr,@encode(_Bool))               == 0) return @"boolean";
  else if (*ptr == '{')
  {
    NSMutableString *structName = [NSMutableString string];
    ptr++;
    while (isalnum(*ptr) || *ptr == '_')
    {
      [structName appendString:[[NSString alloc] initWithBytes:ptr length:1 encoding:NSASCIIStringEncoding]];
      ptr++;
    }
    if (*ptr == '=' && ![structName isEqualToString:@""])
      return [@"struct " stringByAppendingString:structName];
    else 
      return @"";
  }
  else if (*ptr == '^')
  {
    NSString *pointed = humanReadableFScriptTypeDescriptionFromEncodedObjCType(++ptr);
    if ([pointed isEqualToString:@""])
      return @"pointer";
    else
      return [@"pointer to " stringByAppendingString:pointed];
  }
  else                                                    return @"";  
}

static NSString *FScriptObjectTemplateForEncodedObjCType(const char *ptr)
{
  while (*ptr == 'r' || *ptr == 'n' || *ptr == 'N' || *ptr == 'o' || *ptr == 'O' || *ptr == 'R' || *ptr == 'V')
    ptr++;

/*  if      (strcmp(ptr,@encode(id))                  == 0) return @"";
  else if (strcmp(ptr,@encode(char))                == 0) return @"";
  else if (strcmp(ptr,@encode(int))                 == 0) return @"";
  else if (strcmp(ptr,@encode(short))               == 0) return @"";
  else if (strcmp(ptr,@encode(long))                == 0) return @"";
  else if (strcmp(ptr,@encode(long long))           == 0) return @"";
  else if (strcmp(ptr,@encode(unsigned char))       == 0) return @"";
  else if (strcmp(ptr,@encode(unsigned short))      == 0) return @"";
  else if (strcmp(ptr,@encode(unsigned int))        == 0) return @"";
  else if (strcmp(ptr,@encode(unsigned long))       == 0) return @"";
  else if (strcmp(ptr,@encode(unsigned long long))  == 0) return @"";
  else if (strcmp(ptr,@encode(float))               == 0) return @"";
  else if (strcmp(ptr,@encode(double))              == 0) return @"";
  else if (strcmp(ptr,@encode(char *))              == 0) return @"";
#warning 64BIT: Inspect use of @encode
  else*/ if (strcmp(ptr,@encode(SEL))                 == 0) return @"#selector";
  //else if (strcmp(ptr,@encode(Class))               == 0) return @"";
  //else if (*ptr == '^')                                   return @"";
  else if (strcmp(ptr,@encode(NSRange))             == 0) return @"NSValue rangeWithLocation:0 length:0";
  else if (strcmp(ptr,@encode(NSPoint))             == 0) return @"0<>0";
  else if (strcmp(ptr,@encode(NSSize))              == 0) return @"NSValue sizeWithWidth:0 height:0";
  else if (strcmp(ptr,@encode(NSRect))              == 0) return @"0<>0 extent:0<>0";
  else if (strcmp(ptr,@encode(CGPoint))             == 0) return @"0<>0";
  else if (strcmp(ptr,@encode(CGSize))              == 0) return @"NSValue sizeWithWidth:0 height:0";
  else if (strcmp(ptr,@encode(CGRect))              == 0) return @"0<>0 extent:0<>0";
  //else if (strcmp(ptr,@encode(_Bool))               == 0) return @"";
  else                                                    return @"";  
}

static NSMutableArray *customButtons = nil; 

@interface FSObjectBrowserView()  // Methods declaration to let the compiler know

@property (nonatomic,strong) FSInterpreter* interpreter;
@property (nonatomic,strong) NSWindow*      tempInputWindow;

- (void) fillMatrixForClassesBrowsing:(NSMatrix*)matrix;
- (void) fillMatrixForWorkspaceBrowsing:(NSMatrix*)matrix; 
// - (void) fillMatrix:(NSMatrix *)matrix withMethodsAndPropertiesForObject:(id)object;
- (void) fillMatrix:(NSMatrix *)matrix withMethodsForObject:(id)object;
//- (void) fillMatrix:(NSMatrix *)matrix withPropertiesForObject:(id)object;
- (void) filter;
- (void) inspectAction:(id)sender;
- (id)   selectedObject;
- (void) selectMethodNamed:(NSString *)methodName;
- (void) selfAction:(id)sender;
- (void) sendMessage:(SEL)selector withArguments:(FSArray *)arguments;
- (BOOL) sendMessageTo:(id)receiver selectorString:(NSString *)selectorStr arguments:(FSArray *)arguments putResultInMatrix:(NSMatrix *)matrix;
- (void) setFilterString:(NSString *)theFilterString;
- (void) setTitleOfLastColumn:(NSString *)title;
- (id)   validSelectedObject;

@end


@implementation FSObjectBrowserView

+ (NSArray *)customButtons 
{
  return customButtons;
}

+ (void) initialize 
{
  static BOOL tooLate = NO;
  if ( !tooLate ) 
  {  
    int i;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *registrationDict = [NSMutableDictionary dictionary];
        
    registrationDict[@"FScriptFontSize"] = @([[NSFont userFixedPitchFontOfSize:-1] pointSize]);
    [defaults registerDefaults:registrationDict];
        
    NSManagedObjectClass = NSClassFromString(@"NSManagedObject");
        
    customButtons = [[NSMutableArray alloc] initWithCapacity:10];
    
    for (i = 1; i < 11; i++)
    {
      FSObjectBrowserToolbarButton *button = [[FSObjectBrowserToolbarButton alloc] initWithFrame:NSMakeRect(0,0,80,20)];
      NSString *buttonName  = [defaults stringForKey:[NSString stringWithFormat:@"BigBrowserToolbarButtonCustom%dName",i]];
      NSData *blockData = [defaults objectForKey:[NSString stringWithFormat:@"BigBrowserToolbarButtonCustom%dBlock",i]];
      FSBlock *block = nil;
       
      if (blockData)
      { 
        @try
        {
          block = [NSKeyedUnarchiver unarchiveObjectWithData:blockData];
        }
        @catch (id exception)
        {
          NSLog(@"Problem while loading a block for an F-Script object browser custom button: %@", FSErrorMessageFromException(exception));
          block = nil; // We will fall back to the default block template
        }
      }
      
      if (!buttonName)  buttonName  = [NSString stringWithFormat:@"Custom%d", i];
      
      if (!block) 
      {
        NSString *blockSource;
        
        if (i == 1)
        {
          buttonName = @"Example1";
          blockSource = @"[:selectedObject|\n\n\"This block is an example illustrating the use of custom buttons in the object browser. This block prompts the user to save the selected object, and then returns a custom string.\"\n\nselectedObject save.\n'hello, I''m the result of the Example1 block !'\n]";
        }
        else if (i == 2)
        {
          buttonName = @"Example2";
          blockSource = @"#isEqual:";
        }
        else if (i == 3)
        {
          buttonName = @"Example3";
          blockSource = @"[\n\"This block is an example illustrating the use of custom buttons in the object browser. This block will simply open a standard about box.\"\n\nNSApplication sharedApplication orderFrontStandardAboutPanel:nil\n]";
        }
        else blockSource = @"[:selectedObject| selectedObject  \"Define your custom block here.\"]";
        
        block = [blockSource asBlock];
      }  
      
      [button setIdentifier:[NSString stringWithFormat:@"Custom%d", i]];
      [button setName:buttonName];
      [button setBlock:block];
      [button setAction:@selector(applyBlockAction:)];
      [customButtons addObject:button];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCustomButtonsSettings:) name:NSApplicationWillTerminateNotification object:nil];
  }
} 

+ (void)saveCustomButtonsSettings 
{
  int i;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  for (i = 0; i < 10; i++)
  { 
    [defaults setObject:[customButtons[i] name] forKey:[NSString stringWithFormat:@"BigBrowserToolbarButtonCustom%dName",i+1]]; 
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:[customButtons[i] block]] forKey:[NSString stringWithFormat:@"BigBrowserToolbarButtonCustom%dBlock",i+1]];
  } 
  [defaults synchronize];
}

+ (void)saveCustomButtonsSettings:(NSNotification *)aNotification
{
  [self saveCustomButtonsSettings];
}
 
- (void)addBindingForObject:(id)object withName:(NSString *)name toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{ 
  NSDictionary *infoForBinding = [object infoForBinding:name];
  if (infoForBinding)
  {
    NSString *objectBoundLabel     = @"Object bound";
    NSString *keyPathBoundLabel    = @"Key path bound";
    NSString *valueClassLabel      = @"Value class";
    NSString *valueLabel           = @"Value";
    NSString *optionsLabel         = @"Options";
    
    id objectBound         = infoForBinding[NSObservedObjectKey];
    NSString *keyPathBound = infoForBinding[NSObservedKeyPathKey];
    Class valueClass       = [object respondsToSelector:@selector(valueClassForBinding:)] ? [object valueClassForBinding:name] : nil;
    id value               = [objectBound valueForKeyPath:keyPathBound];  
    NSDictionary *options  = infoForBinding[NSOptionsKey];
  
    NSString *objectBoundString  = printString(objectBound);
    NSString *keyPathBoundString = keyPathBound;
    NSString *valueClassString   = printString(valueClass);
    NSString *valueString        = printString(value);
    NSString *optionsString      = printString(options);
        
    BOOL shouldDisplayBinding = [filterString isEqualToString:@""] 
                                || containsString(name              , filterString, NSCaseInsensitiveSearch)
                                || containsString(objectBoundLabel  , filterString, NSCaseInsensitiveSearch)
                                || containsString(objectBoundString , filterString, NSCaseInsensitiveSearch)                               
                                || containsString(keyPathBoundLabel , filterString, NSCaseInsensitiveSearch)
                                || containsString(keyPathBoundString, filterString, NSCaseInsensitiveSearch)
                                || containsString(valueLabel        , filterString, NSCaseInsensitiveSearch)
                                || containsString(valueString       , filterString, NSCaseInsensitiveSearch)
                                || (valueClass != nil && containsString(valueClassLabel   , filterString, NSCaseInsensitiveSearch))
                                || (valueClass != nil && containsString(valueClassString  , filterString, NSCaseInsensitiveSearch))
                                || containsString(optionsLabel      , filterString, NSCaseInsensitiveSearch)
                                || containsString(optionsString     , filterString, NSCaseInsensitiveSearch)
                                || (selectedClassLabel == classLabel && (   (selectedObject == objectBound  && selectedLabel == objectBoundLabel)
                                                                         || (selectedObject == keyPathBound && selectedLabel == keyPathBoundLabel)
                                                                         || (selectedObject == value        && selectedLabel == valueLabel)
                                                                         || (valueClass != nil && selectedObject == valueClass   && selectedLabel == valueClassLabel)
                                                                         || (selectedObject == options      && selectedLabel == optionsLabel)));

    if (shouldDisplayBinding)
    {
      [self addLabel:[NSString stringWithFormat:@"Binding: %@",name] toMatrix:matrix];         
      [self addObject:objectBound  withLabel:objectBoundLabel  toMatrix:matrix leaf:NO classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:1];
      [self addObject:keyPathBound withLabel:keyPathBoundLabel toMatrix:matrix leaf:NO classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:1];
      if (valueClass != nil) [self addObject:valueClass  withLabel:valueClassLabel toMatrix:matrix leaf:NO classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:1];
      [self addObject:value        withLabel:valueLabel toMatrix:matrix leaf:NO classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:1];
      [self addObject:options      withLabel:optionsLabel      toMatrix:matrix leaf:NO classLabel:classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:1];
      [self addBlankRowToMatrix:matrix];
    }
  }
} 
 
- (void)addDictionary:(NSDictionary *)d withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{
  if (d)
  {
    NSEnumerator *enumerator = [d keyEnumerator];
    id key,value;
    NSString *objectString;
    NSUInteger count = [d count];
    FSObjectBrowserCell *cell;
    
    if (count != 0) 
    {
      if ([self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch))
      {
        [self addLabel:label toMatrix:matrix];
        
        while ((key = [enumerator nextObject])) 
        {
          //[matrix addRow];
          //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
          cell =  addRowToMatrix(matrix); 
          
          value = d[key];
          [cell setRepresentedObject:[FSAssociation associationWithKey:key value:value]];      
          objectString = [NSString stringWithFormat:@"    %@ -> %@",printStringLimited(key,50),printStringLimited(value,1000)];
          if ([objectString length] > 510) 
            objectString = [[objectString substringWithRange:NSMakeRange(0,500)] stringByAppendingString:@" ..."];
          [cell setStringValue:objectString];
          [cell setObjectBrowserCellType:FSOBOBJECT];
          [cell setLabel:printString(key)];
          [cell setClassLabel:@""];
          if (value == selectedObject && [printString(key) isEqualToString:selectedLabel])
            [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
        }
      }  
      else
      {
        while ((key = [enumerator nextObject]) && !containsString(printString(key), filterString, NSCaseInsensitiveSearch) && !containsString(printString(d[key]), filterString, NSCaseInsensitiveSearch) && !(d[key] == selectedObject && [printString(key) isEqualToString:selectedLabel])); 

        if (key)
        {
          [self addLabel:label toMatrix:matrix];
          while (key) 
          {
            value = d[key];
            BOOL addingSelectedObject = (value == selectedObject && [printString(key) isEqualToString:selectedLabel]);
            if (containsString(printString(value), filterString, NSCaseInsensitiveSearch) || containsString(printString(key), filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
            {
              //[matrix addRow];
              //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
              cell =  addRowToMatrix(matrix);
              
              [cell setRepresentedObject:[FSAssociation associationWithKey:key value:value]];      
              objectString = [NSString stringWithFormat:@"    %@ -> %@",printStringLimited(key,50),printStringLimited(value,1000)];
              if ([objectString length] > 510) 
                objectString = [[objectString substringWithRange:NSMakeRange(0,500)] stringByAppendingString:@" ..."];
              [cell setStringValue:objectString];
              [cell setObjectBrowserCellType:FSOBOBJECT];
              [cell setLabel:printString(key)];
              [cell setClassLabel:@""];
              if (addingSelectedObject)
                [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
            }
            key = [enumerator nextObject];
          }
        }
      }
    }
  }
} 
 
- (void) applyBlockAction:(id)sender
{
  FSBlock *block = [sender block];

  @try
  {
    [block compilIfNeeded];
  }
  @catch (id exception)
  {
    NSRunAlertPanel(@"Syntax Error", FSErrorMessageFromException(exception), @"OK", nil, nil,nil);
    FSInspectBlocksInCallStackForException(exception);
    return;    
  }
  
  if ([block isCompact])
  {
    [self sendMessage:[block selector] withArguments:nil];
  }
  else
  { 
    FSObjectBrowserButtonCtxBlock *contextualizedBlock;
    SEL messageToArgumentSelector;
    
    contextualizedBlock = [self.interpreter objectBrowserButtonCtxBlockFromString:[block printString]];
    [contextualizedBlock setMaster:block];
    
    if ([contextualizedBlock argumentCount] == 0)
    {
      FSInterpreterResult *interpreterResult = [contextualizedBlock executeWithArguments:@[]];
      
      if (![interpreterResult isOK])
      {
        NSRunAlertPanel(@"Error", [interpreterResult errorMessage], @"OK", nil, nil,nil);
        [interpreterResult inspectBlocksInCallStack];
        return;
      }
    }  
    else if ((messageToArgumentSelector = [contextualizedBlock messageToArgumentSelector]) != (SEL)0 && messageToArgumentSelector != @selector(alloc) && messageToArgumentSelector != @selector(allocWithZone:))
    {
      NSString *methodName = [FSCompiler stringFromSelector:messageToArgumentSelector];
      id selectedObject;
      FSInterpreterResult *interpreterResult;

      if ((selectedObject = [self validSelectedObject]) == nil)
      {
        NSBeep();
        return;
      }
      
      [browser setDelegate:nil];
      [self selectMethodNamed:methodName];
      [browser setDelegate:self];
      
      interpreterResult = [contextualizedBlock executeWithArguments:@[selectedObject]];
    
      if ([interpreterResult isOK])
        [self fillMatrix:[browser matrixInColumn:[browser lastColumn]] withObject:[interpreterResult result]];
      else
      {
        NSRunAlertPanel(@"Error", [interpreterResult errorMessage], @"OK", nil, nil,nil);
        [interpreterResult inspectBlocksInCallStack];
        return;
      }
    }
    else 
      [self sendMessage:@selector(applyBlock:) withArguments:[FSArray arrayWithObject:contextualizedBlock]];
  } 
  [browser scrollColumnToVisible:[browser lastColumn]];
  [browser scrollColumnsLeftBy:1]; // Workaround for the call above to scrollColumnToVisible: not working as expected.
}

- (void)addBlankRowToMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  //[matrix addRow];
  //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
  cell =  addRowToMatrix(matrix);
  
  [cell setLeaf:YES];
  [cell setEnabled:NO];
}

- (void)addClassWithName:(NSString *)className toMatrix:(NSMatrix *)matrix label:(NSString *)label classLabel:(NSString *)classLabel indentationLevel:(NSUInteger)indentationLevel
{
  FSObjectBrowserCell *cell =  addRowToMatrix(matrix); 
  NSMutableString *cellString = [NSMutableString string];
  
  [cell setLabel:label];
  [cell setClassLabel:classLabel];
  
  for (NSUInteger i = 0; i < indentationLevel; i++) [cellString appendString:@"     "];
  
  [cellString appendString:className];
  [cell setStringValue:cellString];
  [cell setObjectBrowserCellType:FSOBCLASS];
}

// Not tested
/*
- (void)addClassWithName:(NSString *)className withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{ 
  BOOL hasEmptyFilterString = [filterString isEqualToString:@""];
  BOOL addingSelectedObject = (selectedObject != nil && [selectedObject class] == selectedObject && [NSStringFromClass(selectedObject) isEqualToString:className] && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]);

  if (hasEmptyFilterString || containsString(label, filterString, NSCaseInsensitiveSearch) || containsString(printString(object), filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
  { 
    [self addLabel:label toMatrix:matrix];
    [self addClassWithName:className toMatrix:matrix label:label classLabel:classLabel indentationLevel:1];
    if (addingSelectedObject)
      [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0]; 
  }  
}
*/

- (void)addClassesWithNames:(NSArray *)classNames withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{
  if (classNames)
  {
    NSUInteger i;
    NSUInteger count = [classNames count];
  
    if (count != 0) 
    {      
      if ([self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch))
      {
        [self addLabel:label toMatrix:matrix];
        for (i = 0; i < count; i++)
        { 
          NSString *className = classNames[i];
          [self addClassWithName:className toMatrix:matrix label:label classLabel:classLabel indentationLevel:1];

          if (selectedObject != nil && [selectedObject class] == selectedObject && [NSStringFromClass(selectedObject) isEqualToString:className] && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel])
            [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
        }
      }
      else
      {
        i = 0;
        while (i < count && !containsString(classNames[i], filterString, NSCaseInsensitiveSearch) && !(selectedObject != nil && [selectedObject class] == selectedObject && [NSStringFromClass(selectedObject) isEqualToString:classNames[i]] && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]))
          i++;
        if (i < count)
        {
          [self addLabel:label toMatrix:matrix];
          for (; i < count; i++)
          {
            BOOL addingSelectedObject = (selectedObject != nil && [selectedObject class] == selectedObject && [NSStringFromClass(selectedObject) isEqualToString:classNames[i]] && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]);
            if (containsString(classNames[i], filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
            {
              [self addClassWithName:classNames[i] toMatrix:matrix label:label classLabel:classLabel indentationLevel:1];
              if (addingSelectedObject)
                [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
            }
          }
        }
      }
    }
  }      
}

- (void)addClassLabel:(NSString *)label toMatrix:(NSMatrix *)matrix color:(NSColor *)color
{
  NSBrowserCell *cell;
  NSDictionary *txtDict = @{NSForegroundColorAttributeName: [NSColor whiteColor], NSBackgroundColorAttributeName: color};
  NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"   %@   ", label] attributes:txtDict];

  [self addBlankRowToMatrix:matrix];

  //[matrix addRow];
  //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
  cell =  addRowToMatrix(matrix); 
  
  [cell setLeaf:YES];
  [cell setEnabled:NO];
  [attrStr setAlignment:NSCenterTextAlignment range:NSMakeRange(0,[attrStr length])];
  [cell setAttributedStringValue:attrStr];
}

- (void)addClassLabel:(NSString *)label toMatrix:(NSMatrix *)matrix
{
  [self addClassLabel:label toMatrix:matrix color:[NSColor colorWithCalibratedRed:0.1 green:0.65 blue:0.12 alpha:1]];
}

- (void)addLabel:(NSString *)label toMatrix:(NSMatrix *)matrix indentationLevel:(NSUInteger)indentationLevel
{
  NSBrowserCell *cell;
  NSMutableString *cellString = [NSMutableString string];

  //[matrix addRow];
  //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
  cell =  addRowToMatrix(matrix); 
  
  [cell setLeaf:YES];
  [cell setEnabled:NO];
  for (NSUInteger i = 0; i < indentationLevel; i++) [cellString appendString:@"     "];
  [cellString appendString:label];
  [cell setStringValue:cellString];
}

- (void)addLabel:(NSString *)label toMatrix:(NSMatrix *)matrix
{
  [self addLabel:label toMatrix:matrix indentationLevel:0];
}

- (void)addLabelAlone:(NSString *)label toMatrix:(NSMatrix *)matrix
{
  if ( [self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch) )
  { 
    [self addLabel:label toMatrix:matrix];
  }  
}

- (void)addObject:(id)object toMatrix:(NSMatrix *)matrix label:(NSString *)label classLabel:(NSString *)classLabel indentationLevel:(NSUInteger)indentationLevel leaf:(BOOL)leaf 
{
  FSObjectBrowserCell *cell;
  NSString *objectString = printStringForObjectBrowser(object); 

  //[matrix addRow];
  //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
  cell =  addRowToMatrix(matrix); 
  
  if ([object isKindOfClass:[FSObjectBrowserNamedObjectWrapper class]]) [cell setRepresentedObject:[object object]];
  else                                                             [cell setRepresentedObject:object];
  
  [cell setLabel:label];
  [cell setClassLabel:classLabel];
  if (object == nil || leaf) 
  {  
    [cell setLeaf:YES];
  }
  
  NSMutableString *cellString = [NSMutableString string];
  for (NSUInteger i = 0; i < indentationLevel; i++) [cellString appendString:@"     "];
  [cellString appendString:objectString];

  if ([object isKindOfClass:[FSNewlyAllocatedObjectHolder class]])
  {
    NSColor *txtColor = [NSColor purpleColor];
    NSDictionary *txtDict = @{NSForegroundColorAttributeName: txtColor};
    NSAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:cellString attributes:txtDict];
    [cell setAttributedStringValue:attrStr];
  }
  else
  {
    [cell setStringValue:cellString];
  }
  [cell setObjectBrowserCellType:FSOBOBJECT];
}

- (void)addObject:(id)object toMatrix:(NSMatrix *)matrix label:(NSString *)label classLabel:(NSString *)classLabel indentationLevel:(NSUInteger)indentationLevel 
{
  [self addObject:object toMatrix:matrix label:label classLabel:classLabel indentationLevel:indentationLevel leaf:NO];
}

- (void)addObject:(id)object toMatrix:(NSMatrix *)matrix label:(NSString *)label classLabel:(NSString *)classLabel
{
  [self addObject:object toMatrix:matrix label:label classLabel:classLabel indentationLevel:1];
}

- (void)addObject:(id)object withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix leaf:(BOOL)leaf classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject indentationLevel:(NSUInteger)indentationLevel
{ 
  BOOL addingSelectedObject = (object == selectedObject && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]);

  // Note the use of printStringLimited below. We limit our matching test to the first 10000 elements for performance reasons.
  // if ([self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch) || containsString(printStringLimited(object, 10000), filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
  
  if ([self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch) || containsString(printString(object), filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
  { 
    [self addLabel:label toMatrix:matrix indentationLevel:indentationLevel];
    [self addObject:object toMatrix:matrix label:label classLabel:classLabel indentationLevel:indentationLevel+1 leaf:leaf];
    if (addingSelectedObject)
      [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0]; 
  }  
}

- (void)addObject:(id)object withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{
  [self addObject:object withLabel:label toMatrix:matrix leaf:NO classLabel:(NSString *)classLabel selectedClassLabel:selectedClassLabel selectedLabel:selectedLabel selectedObject:selectedObject indentationLevel:0];  
}

- (void)addObjects:(NSArray *)objects withLabel:(NSString *)label toMatrix:(NSMatrix *)matrix classLabel:(NSString *)classLabel selectedClassLabel:(NSString *)selectedClassLabel selectedLabel:(NSString *)selectedLabel selectedObject:(id)selectedObject
{
  if (objects)
  {
    NSUInteger i;
    NSUInteger count = [objects count];
  
    if (count != 0) 
    {      
      if ([self hasEmptyFilterString] || containsString(label, filterString, NSCaseInsensitiveSearch))
      {
        [self addLabel:label toMatrix:matrix];
        for (i = 0; i < count; i++)
        { 
          id object = objects[i];
          [self addObject:object toMatrix:matrix label:label classLabel:classLabel];
          if (object == selectedObject && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel])
            [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
        }
      }
      else
      {
        i = 0;
        while (i < count && !containsString(printString(objects[i]), filterString, NSCaseInsensitiveSearch) && !(objects[i] == selectedObject && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]))
          i++;
        if (i < count)
        {
          [self addLabel:label toMatrix:matrix];
          for (; i < count; i++)
          {
            BOOL addingSelectedObject = (objects[i] == selectedObject && [label isEqualToString:selectedLabel] && [classLabel isEqualToString:selectedClassLabel]);
            if (containsString(printString(objects[i]), filterString, NSCaseInsensitiveSearch) || addingSelectedObject)
            {
              [self addObject:objects[i] toMatrix:matrix label:label classLabel:classLabel];
              if (addingSelectedObject)
                [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
            }
          }
        }
      }
    }
  }      
}

- (void)addPropertyLabel:(NSString *)label toMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  NSDictionary *txtDict = @{NSForegroundColorAttributeName: [NSColor whiteColor], NSBackgroundColorAttributeName: [NSColor redColor]};
  NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"   %@   ", label] attributes:txtDict];

  [self addBlankRowToMatrix:matrix];
  //[matrix addRow];
  //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
  cell =  addRowToMatrix(matrix);

  [cell setLeaf:YES];
  [cell setEnabled:NO];
  [attrStr setAlignment:NSCenterTextAlignment range:NSMakeRange(0,[attrStr length])];
  [cell setAttributedStringValue:attrStr];
}

- (IBAction)browseAction:(id)sender 
{
  [self.interpreter browse:[self selectedObject]];
}

- (void)browser:(NSBrowser *)sender createRowsForColumn:(NSInteger)column inMatrix:(NSMatrix *)matrix // We are our own delegate 
{
  [matrixes addObject:matrix];
  
  if (column == 0)
  { 
    switch (browsingMode)
    {
    case FSBrowsingWorkspace: [self fillMatrixForWorkspaceBrowsing:matrix];   break;
    case FSBrowsingClasses:   [self fillMatrixForClassesBrowsing:matrix];     break;
    case FSBrowsingObject:    [self fillMatrix:matrix withObject:rootObject]; break;
    case FSBrowsingNothing:   break;
    }     
  }
  else if ( [[browser selectedCell] objectBrowserCellType] == FSOBOBJECT || [[browser selectedCell] objectBrowserCellType] == FSOBCLASS)
  {
    [self fillMatrix:matrix withObject:[[browser selectedCell] representedObject]];
    // if ([browser selectedRowInColumn:[browser selectedColumn]] != 0 && (column != 1 || browsingMode == FSBrowsingObject)) [self performSelector:@selector(selfAction:) withObject:nil afterDelay:0]; 
  }
  /*else if ([[browser selectedCell] objectBrowserCellType] == PROPERTY)
  {
    id selectedObject = [self selectedObject];
    [self sendMessageTo:selectedObject selectorString:@"valueForKey:" arguments:[NSArray arrayWithObject:[[browser selectedCell] stringValue]] putResultInMatrix:matrix]; 
  }*/
  else 
  {     
    NSString    *selectedString     = [[browser selectedCell] stringValue];
    
    SEL          selector           = [FSCompiler selectorFromString:selectedString];
    NSArray     *selectorComponents = [NSStringFromSelector(selector) componentsSeparatedByString:@":"];
    NSInteger    nbarg              = [selectorComponents count]-1;
    id           selectedObject     = [self selectedObject];  
    FSMsgContext  *msgContext         = [[FSMsgContext alloc] init];
    NSInteger    unsupportedArgumentIndex;

    if ([selectedObject isKindOfClass:[FSNewlyAllocatedObjectHolder class]]) selectedObject = [selectedObject object];
    
    [msgContext prepareForMessageWithReceiver:selectedObject selector:[FSCompiler selectorFromString:selectedString]];
    unsupportedArgumentIndex = [msgContext unsuportedArgumentIndex];
    
    if (unsupportedArgumentIndex != -1)
    {
      NSString *errorString = [NSString stringWithFormat:@"Can't invoke method: the type expected for argument %ld is not supported by F-Script.", (long)unsupportedArgumentIndex+1];
      NSRunAlertPanel(@"Sorry", errorString, @"OK", nil, nil,nil);
      return;
    }
    else if ([msgContext unsuportedReturnType])
    {
      NSString *errorString = [NSString stringWithFormat:@"Can't invoke method: return type not supported by F-Script."];
      NSRunAlertPanel(@"Sorry", errorString, @"OK", nil, nil,nil);
      return;
    }  
    else if (nbarg == 0)
    {
      // NSBrowserCell *cell;
      [self sendMessageTo:selectedObject selectorString:selectedString arguments: [FSArray new] putResultInMatrix:matrix];
    
      /*if (cell = [matrix cellAtRow:0 column:0])
      {
        [self performSelector:@selector(setTitleOfLastColumn:) withObject:printString([[cell representedObject] classOrMetaclass]) afterDelay:0];
        // We do this because at the time tis method is called, the new column is not yet created.
        // Hence the need to delay the setTitle. 
      } */
    } 
    else
    {
      NSInteger i;
      NSInteger baseWidth  = 530;
      NSInteger baseHeight = nbarg*(userFixedPitchFontSize()+17)+75;
      NSButton *sendButton;
      NSButton *cancelButton;
      NSForm *f;
      NSWindow *argumentsWindow;
      NSMethodSignature *signature = [selectedObject methodSignatureForSelector:selector];
  
      argumentsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100,100,baseWidth,baseHeight) styleMask: NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
      [argumentsWindow setMinSize:NSMakeSize(240,baseHeight+22)];
      [argumentsWindow setMaxSize:NSMakeSize(1400,baseHeight+22)];
      [argumentsWindow setReleasedWhenClosed: NO];
      
      f = [[NSForm alloc] initWithFrame:NSMakeRect(20,60,baseWidth-40,baseHeight-80)];
      [f setAutoresizingMask:NSViewWidthSizable];
      [f setInterlineSpacing:8]; 
      [[argumentsWindow contentView] addSubview:f]; // The form must be the first subview 
                                                    // (this is used by method sendMessageAction:)
      [argumentsWindow setInitialFirstResponder:f];                                              
                                                          
      sendButton = [[NSButton alloc] initWithFrame:NSMakeRect(baseWidth/2,13,125,30)];
      [sendButton setBezelStyle:1];
      [sendButton setTitle:@"Send Message"];   
      [sendButton setAction:@selector(sendMessageAction:)];
      [sendButton setTarget:self];
      [sendButton setKeyEquivalent:@"\r"];
      [[argumentsWindow contentView] addSubview:sendButton];
      
      cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(baseWidth/2-95,13,95,30)];
      [cancelButton setBezelStyle:1];
      [cancelButton setTitle:@"Cancel"];   
      [cancelButton setAction:@selector(cancelArgumentsSheetAction:)];
      [cancelButton setTarget:self];
      [cancelButton setKeyEquivalent:@"\e"];
      [[argumentsWindow contentView] addSubview:cancelButton];
      
      if (nbarg == 1 && [selectorComponents[0] hasPrefix:@"operator_"]) 
      {
        const char *type = [signature getArgumentTypeAtIndex:2];
        NSString *typeDescription = humanReadableFScriptTypeDescriptionFromEncodedObjCType(type);
        NSString *template = FScriptObjectTemplateForEncodedObjCType(type);
        
        if ([typeDescription length] > 0) typeDescription = [[@"(" stringByAppendingString:typeDescription] stringByAppendingString:@")"];
          
        [f addEntry:[[selectedString stringByAppendingString:@" "] stringByAppendingString:typeDescription]];
        [[f cellAtIndex:0] setStringValue:template];
      }
      else 
        for (i = 0; i < nbarg; i++)
        {
          const char *type = [signature getArgumentTypeAtIndex:i+2];
          NSString *typeDescription = humanReadableFScriptTypeDescriptionFromEncodedObjCType(type);
          NSString *template = FScriptObjectTemplateForEncodedObjCType(type);
          
          if ([typeDescription length] > 0) typeDescription = [[@"(" stringByAppendingString:typeDescription] stringByAppendingString:@")"];
          
          [f addEntry:[[selectorComponents[i] stringByAppendingString:@":"] stringByAppendingString:typeDescription]];
          [[f cellAtIndex:i] setStringValue:template];
        }
        
      [f setTextFont:[NSFont userFixedPitchFontOfSize:userFixedPitchFontSize()]];
      [f setTitleFont:[NSFont systemFontOfSize:systemFontSize()]];

      [f setAutosizesCells:YES]; 
      [f setTarget:sendButton];
      [f setAction:@selector(performClick:)];
      [f selectTextAtIndex:0];
      self.tempInputWindow = argumentsWindow; // retain
      
      // 10.9 code
//      [self.window beginSheet: argumentsWindow completionHandler:^(NSModalResponse response) {
//        NSLog(@"Good bye sheet. Response %ld", (long)response);
//        if (response == NSModalResponseOK) {
//          // ok
//        } else {
//          // cancel
//          self.tempInputWindow = nil;
//          [[browser matrixInColumn:[browser lastColumn]-1] deselectAllCells];
//        }
//      }];
      [NSApp beginSheet: argumentsWindow modalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
//      [NSApp runModalForWindow: argumentsWindow];
    }
  }
  [browser tile]; 
}

- (void) browseNothing
{
  browsingMode = FSBrowsingNothing;
  rootObject = nil;
  [browser loadColumnZero];
}

- (void) browseWorkspace
{
  browsingMode = FSBrowsingWorkspace;
  rootObject = nil;
  [browser loadColumnZero];
}

- (void) cancelArgumentsSheetAction:(id)sender
{
  [NSApp endSheet:[sender window]];
  [[sender window] close];
  self.tempInputWindow = nil;
  [[browser matrixInColumn:[browser lastColumn]-1] deselectAllCells];
}

- (void) cancelNameSheetAction:(id)sender
{
  [NSApp endSheet:[sender window]];
  [[sender window] close];
  self.tempInputWindow = nil;
}

- (void) classesAction:(id)sender
{
  browsingMode = FSBrowsingClasses;
  rootObject = nil;
  [browser loadColumnZero];
}

- (void) doubleClickAction:(id)sender
{
  enum FSObjectBrowserCellType cellType = [[browser selectedCell] objectBrowserCellType];
  if (cellType == FSOBOBJECT || cellType == FSOBCLASS) [self inspectAction:sender];
}

- (void)fillMatrixForClassesBrowsing:(NSMatrix*)matrix
{
  FSArray *classNames = allClassNames();
  NSUInteger count = [classNames count];
  FSObjectBrowserCell *cell;
  FSObjectBrowserCell *selectedCell = [matrix selectedCell]; // retain and autorelease in order to avoid premature deallocation as a side effect of the removing of rows
  NSString *selectedObjectName  = [selectedCell  objectBrowserCellType] == FSOBCLASS ? [selectedCell stringValue] : nil ;
  
  [classNames sortUsingFunction:FSCompareClassNamesForAlphabeticalOrder context:NULL];
  
  // for (int i = [matrix numberOfRows]-1; i >= 0; i--) [matrix removeRow:i]; // Remove all rows. As a side effect, this will supress the selection.
  [matrix renewRows:0 columns:1]; 
  
  for (NSInteger i = 0; i < count; i++)
  {
    NSString *className = classNames[i];
    if ([self hasEmptyFilterString] || containsString(className, filterString, NSCaseInsensitiveSearch) || (selectedObjectName != nil && [className isEqualToString:selectedObjectName]))
    {
      cell =  addRowToMatrix(matrix); 
      
      [cell setStringValue:className];
      [cell setObjectBrowserCellType:FSOBCLASS];
      if (selectedObjectName != nil && [className isEqualToString:selectedObjectName])
        [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
    }  
  }
  [matrix sizeToCells];     // The NSMatrix doc advise to do that after calling addRow
  [matrix scrollCellToVisibleAtRow:[matrix selectedRow] column:0];
  [matrix setNeedsDisplay]; // The NSMatrix doc advise to do that after calling addRow
} 

- (void)fillMatrixForWorkspaceBrowsing:(NSMatrix*)matrix 
{
  NSArray *identifiers = [self.interpreter identifiers];
  NSUInteger count = [identifiers count];
  FSObjectBrowserCell *cell;
  NSString *cellString; 
  id object;
  FSObjectBrowserCell *selectedCell = [matrix selectedCell]; // retain and autorelease in order to avoid premature deallocation as a side effect of the removing of rows
  NSString *selectedLabel      = [[selectedCell label] copy];    // copy and autorelease in order to avoid prmature invalidation as a side effect of the removing of rows
  id selectedObject            = [selectedCell representedObject];

  //for (int i = [matrix numberOfRows]-1; i >= 0; i--) [matrix removeRow:i]; // Remove all rows. As a side effect, this will supress the selection.
  [matrix renewRows:0 columns:1]; 

  for (NSInteger i = 0; i < count; i++)
  {
    NSString *identifier = identifiers[i];
    object = [self.interpreter objectForIdentifier:identifier found:NULL];
    NSString *objectPrintString = printStringForObjectBrowser(object);
    if ([self hasEmptyFilterString] || containsString(identifier, filterString, NSCaseInsensitiveSearch) || containsString(objectPrintString, filterString, NSCaseInsensitiveSearch) || (object == selectedObject && [identifier isEqualToString:selectedLabel]))
    {
      //[matrix addRow];
      //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];  
      cell =  addRowToMatrix(matrix); 
      
      [cell setRepresentedObject:object];
      if (object == nil) [cell setLeaf:YES];
      cellString = [NSString stringWithFormat:@"%@ = %@",identifier,objectPrintString];
      [cell setStringValue:cellString];
      [cell setObjectBrowserCellType:FSOBOBJECT];
      [cell setLabel:identifier];
      if (object == selectedObject && [identifier isEqualToString:selectedLabel])
        [matrix selectCellAtRow:[matrix numberOfRows]-1 column:0];
    }    
  }
  
  [matrix sizeToCells];     // The NSMatrix doc advise to do that after calling addRow
  [matrix scrollCellToVisibleAtRow:[matrix selectedRow] column:0];
  [matrix setNeedsDisplay]; // The NSMatrix doc advise to do that after calling addRow
}

- (void)fillMatrix:(NSMatrix *)matrix withMethod:(NSString *)method
{
  //[matrix addRow];
  //FSObjectBrowserCell *cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
  FSObjectBrowserCell *cell = addRowToMatrix(matrix); 
  
  [cell setStringValue:method];
  [cell setObjectBrowserCellType:FSOBMETHOD];
}

/*- (void) fillMatrix:(NSMatrix *)matrix withMethodsAndPropertiesForObject:(id)object
{
  BOOL isHolder = NO;

  @try
  {
    if ([object isKindOfClass:[NewlyAllocatedObjectHolder class]]) isHolder = YES; 
  }
  @catch (id exception)
  {  
    // An exception may happend if the object is invalid (i.e. an invalid proxy)
    NSBeep();
    return;
  }
  
  if (isHolder) 
  {
    object = [object object];
    [self fillMatrix:matrix withMethodsForObject:object];
  }
  else
  {
    [self fillMatrix:matrix withPropertiesForObject:object];
    [self fillMatrix:matrix withMethodsForObject:object];
  }  
} */

- (void)fillMatrix:(NSMatrix *)matrix withMethodsForObject:(id)object
{
  id cls;
  BOOL doNotShowSelectorsStartingWithUnderscore    = [[NSUserDefaults standardUserDefaults] boolForKey:@"FScriptDoNotShowSelectorsStartingWithUnderscore"];
  BOOL doNotShowSelectorsStartingWithAccessibility = [[NSUserDefaults standardUserDefaults] boolForKey:@"FScriptDoNotShowSelectorsStartingWithAccessibility"];
  BOOL isHolder = NO;

  @try
  {
    if ([object isKindOfClass:[FSNewlyAllocatedObjectHolder class]]) isHolder = YES; 
  }
  @catch (id exception)
  { 
    // An exception may happend if the object is invalid (i.e. an invalid proxy)
    NSBeep();
    return; 
  }
  
  if (isHolder) object = [object object];
          
  if (isKindOfClassNSProxy(object) && object != [object class]) // the second condition is used because NSProxy is instance of itself and thus the isKindOfClassNSProxy() function returns YES even for the classes in the NSProxy hierarchy
  {
    // We try to get the class of the real object
    NSString *realObjectClassName = nil;
    
    @try
    {
      realObjectClassName = [object className]; 
      // HACK: className is a method implemented by NSObject, but not by NSProxy.
      // Thus, this method should be forwarded to the real object. 
      // We do this inside an exception handler because the call to className may raise 
      // (for instance, if the real object is not in the NSObject hierarchy and does not responds to className,
      // or if there is a communication problem during the distributed object call)
      
      cls = NSClassFromString(realObjectClassName);
    }
    @catch (id exception)
    { 
      cls = nil;
    }    
    
    if (cls == nil)
	{ 
      if (realObjectClassName) NSBeginInformationalAlertSheet(@"Method list not available", @"OK", nil, nil, [self window], nil, NULL, NULL, NULL, @"Sorry, the method list for this object is not available. The class of the object (i.e. %@) is not loaded in the current application.", realObjectClassName);
      else                     NSBeginInformationalAlertSheet(@"Method list not available", @"OK", nil, nil, [self window], nil, NULL, NULL, NULL, @"Sorry, the method list for this object is not available.");
    }
  }
  else cls = [object classOrMetaclass];
  
  while (cls)
  {      
    NSInteger i,nb;
    FSObjectBrowserCell *cell;
    NSMutableArray *selectorStrings = [NSMutableArray arrayWithCapacity:400];
    NSDictionary *txtDict = @{NSForegroundColorAttributeName: [NSColor whiteColor], NSBackgroundColorAttributeName: [NSColor blueColor]};
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"   %@ Methods  ", [cls printString]] attributes:txtDict];
    [attrStr setAlignment:NSCenterTextAlignment range:NSMakeRange(0,[attrStr length])];

    //[matrix addRow];
    //cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
    cell =  addRowToMatrix(matrix); 
    
    [cell setLeaf:YES];
    [cell setEnabled:NO];
    [cell setAttributedStringValue:attrStr];
    //[matrix setToolTip:[cls printString] forCell:cell];
                 
    /*if ([filterString isEqualToString:@""])
      while ( mlist = class_nextMethodList( cls, &iterator ) )
      {
        for (i = 0; i < mlist->method_count; i++) 
        {
          [selectorStrings addObject:[FSCompiler stringFromSelector:mlist->method_list[i].method_name]];
        }
      }
    else*/  
	
#if OBJC_API_VERSION == 2
    unsigned methodCount; 
    Method *methods = class_copyMethodList(cls, &methodCount);
	
    for (i = 0; i < methodCount; i++)
    {
      NSString *methodName = [FSCompiler stringFromSelector:method_getName(methods[i])];
      if (   ([self hasEmptyFilterString] || containsString(methodName, filterString, NSCaseInsensitiveSearch)) 
             && (!doNotShowSelectorsStartingWithUnderscore    || ![methodName hasPrefix:@"_"])
             && (!doNotShowSelectorsStartingWithAccessibility || ![methodName hasPrefix:@"accessibility"])
             && (![methodName isEqualToString:@"<ignored selector>"])
             && (![methodName hasPrefix:@"__F-ScriptGeneratedStub"])
         )             
        [selectorStrings addObject:methodName];
    }
	free(methods);
#else
    struct objc_method_list *mlist;
    void *iterator = 0;

    while ( (mlist = class_nextMethodList( cls, &iterator )) )  
    {
      for (i = 0; i < mlist->method_count; i++)
      {
        NSString *methodName = [FSCompiler stringFromSelector:mlist->method_list[i].method_name];
        if (   ([self hasEmptyFilterString] || containsString(methodName, filterString, NSCaseInsensitiveSearch)) 
               && (!doNotShowSelectorsStartingWithUnderscore    || ![methodName hasPrefix:@"_"])
               && (!doNotShowSelectorsStartingWithAccessibility || ![methodName hasPrefix:@"accessibility"])
               && (![methodName isEqualToString:@"<ignored selector>"])
               && (![methodName hasPrefix:@"__F-ScriptGeneratedStub"])
           )             
          [selectorStrings addObject:methodName];
      }
    }
#endif	
    
    [selectorStrings sortUsingFunction:FSCompareMethodsNamesForAlphabeticalOrder context:NULL];
    
    for (i = 0, nb = [selectorStrings count]; i < nb; i++) [self fillMatrix:matrix withMethod:selectorStrings[i]];
    
    if (cls == [cls superclass])  // The NSProxy class return itself when asked for its superclass.
                                  // This would result in an infinite loop. This test work around this.
      cls = nil;   
    else 
      cls = [cls superclass]; // TODO : test if it works ok now (see comment below)
      // cls = ((struct {struct objc_class *isa; struct objc_class *super_class;}*)cls)->super_class;
      // This direct access technique is used instead of the -superclass method because this method is broken in the NSProxy hierarchy (does not return the "real" superclass) (Mac OS X 10.1.2).
    
    if (cls) [self addBlankRowToMatrix:matrix];
  }    
}

/*- (void)fillMatrix:(NSMatrix *)matrix withProperty:(NSString *)property
{
  //[matrix addRow];
  //FSObjectBrowserCell *cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
  FSObjectBrowserCell *cell = addRowToMatrix(matrix); 

  [cell setObjectBrowserCellType:BBOBJECT];
  [cell setStringValue:property];
}*/

/*- (void)fillMatrix:(NSMatrix *)matrix withProperties:(NSArray *)properties label:(NSString *)label
{
  if ([properties count] == 0) return;
  
  NSUInteger        propertiesCount     = [properties count];
  NSMutableArray *filteredProperties  = [NSMutableArray arrayWithCapacity:propertiesCount];
  BOOL            hasEmptyFilterString = [filterString isEqualToString:@""];
    
  for (NSUInteger i = 0; i < propertiesCount; i++)
  {
    NSString *property = [properties objectAtIndex:i];
    if (hasEmptyFilterString || containsString(property, filterString, NSCaseInsensitiveSearch))             
      [filteredProperties addObject:property];
  }
    
  [filteredProperties sortUsingSelector:@selector(compare:)];
    
  NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, [NSColor redColor], NSBackgroundColorAttributeName, nil];
  NSMutableAttributedString *attrStr = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"   %@   ", label] attributes:txtDict] autorelease];
  [attrStr setAlignment:NSCenterTextAlignment range:NSMakeRange(0,[attrStr length])];
  //[matrix addRow];
  //FSObjectBrowserCell *cell = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
  FSObjectBrowserCell *cell =  addRowToMatrix(matrix);

  [cell setLeaf:YES];
  [cell setEnabled:NO];
  [cell setAttributedStringValue:attrStr];
  
  for (NSUInteger i = 0, count = [filteredProperties count]; i < count; i++) 
    [self fillMatrix:matrix withProperty:[filteredProperties objectAtIndex:i]];
  
  [self addBlankRowToMatrix:matrix];
} */

/*- (void)fillMatrix:(NSMatrix *)matrix withPropertiesForObject:(id)object
{
  //NSArray        *attributeKeys         = [object attributeKeys];
  
  if (!NSManagedObjectClass || ![object isKindOfClass:NSManagedObjectClass]) return;
  
  NSArray        *attributeKeys         = [[[object entity] attributesByName] allKeys];  
  [self fillMatrix:(NSMatrix *)matrix withProperties:attributeKeys label:@"Attributes"];
  
  NSArray        *relationshipKeys         = [[[object entity] relationshipsByName] allKeys];
  [self fillMatrix:(NSMatrix *)matrix withProperties:relationshipKeys label:@"Relationships"];
} */

- (void)filter
{
  NSInteger i,j,columnCount,rowCount;
  Class NSAttributedStringClass = [NSAttributedString class];
  
  if      (browsingMode == FSBrowsingWorkspace) [self fillMatrixForWorkspaceBrowsing:[browser matrixInColumn:0]];
  else if (browsingMode == FSBrowsingClasses)   [self fillMatrixForClassesBrowsing:[browser matrixInColumn:0]];
  
  i = 0; // In order to avoid a warning "may be used unintialized"
  switch (browsingMode)
  {
    case FSBrowsingWorkspace: 
    case FSBrowsingClasses:   i = 1; break;
    case FSBrowsingNothing:
    case FSBrowsingObject:    i = 0; break;
  }
 
  for (columnCount = [browser lastColumn]+1; i < columnCount; i++)
  {
    NSMatrix *matrix = [browser matrixInColumn:i];
    NSInteger selectedRow = [matrix selectedRow];
    enum FSObjectBrowserCellType cellType = FSOBMETHOD; // init in order to avoid a compiler warning "may be used uninitialized"
    NSString *classLabelForSelectedRow = nil;         // init to nil to avoid a compiler warning
    NSString *selectedMethod = nil;                   // init to nil to avoid a compiler warning
    
    if (selectedRow != -1 && (cellType = [[matrix cellAtRow:selectedRow column:0] objectBrowserCellType]) == FSOBMETHOD)
    {
      selectedMethod = [[matrix cellAtRow:selectedRow column:0] stringValue];
      for (j = selectedRow-1; ![[[matrix cellAtRow:j column:0] objectValue] isKindOfClass:NSAttributedStringClass] ; j--);
      classLabelForSelectedRow = [[matrix cellAtRow:j column:0] stringValue];
    } 
            
    if ([matrix numberOfRows] > 0) [self fillMatrix:matrix withObject:[[matrix cellAtRow:0 column:0] representedObject]];
    
    if (selectedRow != -1 && cellType == FSOBMETHOD)
    {
      for (j = 0, rowCount = [matrix numberOfRows]; j < rowCount; j++)
      {
        NSCell *cell = [matrix cellAtRow:j column:0];
        if ([[cell objectValue] isKindOfClass:NSAttributedStringClass] &&  [[cell stringValue] isEqualToString:classLabelForSelectedRow])
        { 
          j++;
          break;
        }  
      }
      while (1)
      { 
        if (j == rowCount)
        { 
          //[matrix addRow];
          //[[matrix cellAtRow:j column:0] setStringValue:selectedMethod];
          //[[matrix cellAtRow:j column:0] setObjectBrowserCellType:cellType];
          //[matrix selectCellAtRow:j column:0];
          FSObjectBrowserCell *cell =  addRowToMatrix(matrix); 
          [cell setStringValue:selectedMethod]; 
          [cell setObjectBrowserCellType:cellType];
          
          [matrix selectCellAtRow:j column:0];          
          //[matrix scrollCellToVisibleAtRow:j column:0];
          break;
        }
        else
        {
          FSObjectBrowserCell     *cell        = [matrix cellAtRow:j column:0];
          NSString           *stringValue = [cell stringValue];
          id                 objectValue  = [cell objectValue];
          NSComparisonResult order        = FSCompareMethodsNamesForAlphabeticalOrder(stringValue, selectedMethod, nil);
          
          if (order == NSOrderedSame && ![objectValue isKindOfClass:NSAttributedStringClass])
          {
            [matrix selectCellAtRow:j column:0];
            //[matrix scrollCellToVisibleAtRow:j column:0];
            break;
          }
          else if (order == NSOrderedDescending) 
          {
            [matrix insertRow:j];
            [[matrix cellAtRow:j column:0] setStringValue:selectedMethod];
            [[matrix cellAtRow:j column:0] setObjectBrowserCellType:cellType];
            [matrix selectCellAtRow:j column:0];
            //[matrix scrollCellToVisibleAtRow:j column:0];
            break;
          }
          else if ([objectValue isKindOfClass:NSAttributedStringClass])
          {
            // Insert at j-1 to preserve the empty line before the line with the class name.
            [matrix insertRow:j-1];
            [[matrix cellAtRow:j-1 column:0] setStringValue:selectedMethod];
            [[matrix cellAtRow:j-1 column:0] setObjectBrowserCellType:cellType];          
            [matrix selectCellAtRow:j-1 column:0];
            //[matrix scrollCellToVisibleAtRow:j-1 column:0];
            break;
          }
        }  
        j++;
      }
    }     
  } 
  [browser tile];
}  

- (void)filterAction:(id)sender
{  
  [self setFilterString:[sender stringValue]];
  [self filter];
}

- (BOOL) hasEmptyFilterString
{
  return [filterString isEqualToString:@""];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if (self)
  { 
    CGFloat baseWidth  = NSWidth([self bounds]);
    CGFloat baseHeight = NSHeight([self bounds]);
    CGFloat fontSize;
  
    fontSize = systemFontSize();
  
    browser = [[NSBrowser alloc] initWithFrame:NSMakeRect(0, FSObjectBrowserBottomBarHeight, baseWidth, baseHeight-FSObjectBrowserBottomBarHeight)];
    //[browser setMatrixClass:[FSObjectBrowserMatrix class]];
    [browser setCellClass:[FSObjectBrowserCell class]];
    [browser setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];  
    [browser setHasHorizontalScroller:YES];
    [browser setMinColumnWidth:145+(fontSize*6)];
    [browser setTakesTitleFromPreviousColumn:NO];
    [browser setTitled:NO];
    [browser setTarget:self];
    [browser setDoubleAction:@selector(doubleClickAction:)];
    [[browser cellPrototype] setFont:[NSFont systemFontOfSize:fontSize]];
    [browser setDelegate:self];
    [browser setFocusRingType:NSFocusRingTypeNone];
    [browser setAutohidesScroller:YES];
    //[browser setAcceptsArrowKeys:NO];
    
    if ([browser respondsToSelector:@selector(setColumnResizingType:)]) [browser setColumnResizingType:2];
    
    if ([browser respondsToSelector:@selector(setColumnsAutosaveName:)]) [browser setColumnsAutosaveName:@"Object browser columns autosave configuration"];
        
    bottomBarTextDisplay = [[FSObjectBrowserBottomBarTextDisplay alloc] initWithFrame:NSMakeRect(0, 0, baseWidth, FSObjectBrowserBottomBarHeight)];

    [self addSubview:browser];  
    [self addSubview:bottomBarTextDisplay];

    browsingMode = FSBrowsingWorkspace;
    
    filterString = @"";
    
    matrixes = [[NSMutableSet alloc] init];
  }
  return self;
} 

- (void) inspectAction:(id)sender
{
  inspect([self selectedObject], self.interpreter, nil);
}

- (void)menuWillSendAction:(NSNotification *)notification;
{
  NSMenuItem *item = [notification userInfo][@"MenuItem"];
  selectedView = item;
}

@class FSObjectBrowser;

- (void)mouseMoved:(NSEvent *)theEvent
{
  NSInteger row, column;
  NSPoint baseMouseLocation = [[self window]  convertScreenToBase:[NSEvent mouseLocation]];
  NSView *view = [self hitTest:[[self superview] convertPoint:baseMouseLocation fromView:nil]];

  if ([view isKindOfClass:[NSMatrix class]] && [(NSMatrix *)view getRow:&row column:&column forPoint:[view convertPoint:baseMouseLocation fromView:nil]])
  {    
    [bottomBarTextDisplay setString:[[(NSMatrix *)view cellAtRow:row column:column] stringValue]];
  }
  else [bottomBarTextDisplay setTitle:@""];
    
  [super mouseMoved:theEvent];
}

- (void) nameObjectAction:(id)sender
{
  CGFloat fontSize = systemFontSize(); 
  CGFloat baseWidth  = 230;
  CGFloat baseHeight = 15+fontSize+9+60;
  NSWindow *nameSheet;
  NSTextField *field;
  NSButton *nameButton;
  NSButton *cancelButton;

  if ([self selectedObject] == nil) 
  {
    NSBeep();
    return;
  }
  
  nameSheet = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,baseWidth,baseHeight) styleMask: NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
  [nameSheet setReleasedWhenClosed: NO];
  [nameSheet setMinSize:NSMakeSize(130,80)];
   
  field = [[NSTextField alloc] initWithFrame:NSMakeRect(20,baseHeight-(15+fontSize+9),baseWidth-40,fontSize+10)];
  [field setFont:[NSFont systemFontOfSize:fontSize]];
  [field setTarget:self];
  [field setAction:@selector(okNameSheetAction:)];
  [field setFormatter:[[FSIdentifierFormatter alloc] init]];
  
  [[nameSheet contentView] addSubview:field];

  nameButton = [[NSButton alloc] initWithFrame:NSMakeRect(baseWidth/2,13,95,30)];
  [nameButton setBezelStyle:1];
  [nameButton setTitle:@"Name"];   
  [nameButton setAction:@selector(performClick:)]; // Will make field to send its action message
  [nameButton setTarget:field];
  [nameButton setKeyEquivalent:@"\r"];
  [[nameSheet contentView] addSubview:nameButton];
      
  cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(baseWidth/2-95,13,95,30)];
  [cancelButton setBezelStyle:1];
  [cancelButton setTitle:@"Cancel"];   
  [cancelButton setAction:@selector(cancelNameSheetAction:)];
  [cancelButton setTarget:self];
  [cancelButton setKeyEquivalent:@"\e"];
  [[nameSheet contentView] addSubview:cancelButton];
  
  self.tempInputWindow = nameSheet;
  [NSApp beginSheet: nameSheet modalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
  [field selectText:nil];
}

-(void)okNameSheetAction:(id)sender
{
  if ([[sender stringValue] length] == 0)
  {
    [NSApp endSheet:[sender window]];
    [[sender window] close];
    self.tempInputWindow = nil;
  }
  else if ([[sender stringValue] isEqualToString:@"sys"])
  {
    // don't close the sheet
    NSRunAlertPanel(@"Invalid name", @"Sorry, the name \"sys\" is reserved. Please, choose an other name.", @"OK", nil, nil,nil);
    [[sender window] makeFirstResponder:sender];
  }
  else if ([FSCompiler isValidIdentifier:[sender stringValue]])
  {
    [self.interpreter setObject:[self selectedObject] forIdentifier:[sender stringValue]];
    [NSApp endSheet:[sender window]];
    [[sender window] close];
    self.tempInputWindow = nil;
  }
  else
  {
    // don't close the sheet
    NSRunAlertPanel(@"Malformed Name", @"Sorry, an F-Script identifier must start with an alphabetic, non-accentuated, character or with an underscore (i.e. \"_\") and must only contains non-accentuated alphanumeric characters and underscores. Please, enter a well-formed name.", @"OK", nil, nil,nil);
    [[sender window] makeFirstResponder:sender];
  }  
}

-(id) selectedObject 
{ 
  FSObjectBrowserCell *selectedCell = [browser selectedCell];
  enum FSObjectBrowserCellType selectedCellType = [selectedCell objectBrowserCellType];
  
  if (selectedCellType == FSOBOBJECT || selectedCellType == FSOBCLASS)
    return [selectedCell representedObject];
  else  
  {
    if ([browser lastColumn] == 0) 
    { 
      switch (browsingMode)
      {
      case FSBrowsingWorkspace: return nil;
      case FSBrowsingClasses:   return nil;
      case FSBrowsingNothing:   return nil;
      case FSBrowsingObject:    break;
      }
    }       
    return [[browser loadedCellAtRow:0 column:[browser lastColumn]] representedObject];  
  }  
}

- (void) selectMethodNamed:(NSString *)methodName
{
  NSInteger      methodColumn = [browser lastColumn];
  NSInteger      i            = 0;
  NSArray *methodCells  = [[browser matrixInColumn:methodColumn] cells];
  NSInteger      count        = [methodCells count];
    
  if (count == 0 && [methodName isEqualToString:@"applyBlock:"]) // may happend if the selected object is a proxy to an object in an app not linked against the F-Script framework.
  {
    NSMatrix *matrix = [browser matrixInColumn:methodColumn];
    
    //[matrix addRow];
    //[[matrix cellAtRow:0 column:0] setStringValue:@"applyBlock:"];
    //[[matrix cellAtRow:0 column:0] setEnabled:NO];
    FSObjectBrowserCell *cell =  addRowToMatrix(matrix); 
    [cell setStringValue:@"applyBlock:"]; 
    [cell setEnabled:NO];
    
    count = 1;
    methodCells  = [[browser matrixInColumn:methodColumn] cells];
  }
  
  while (i < count && !([[methodCells[i] stringValue] isEqualToString:methodName] && [methodCells[i] objectBrowserCellType] == FSOBMETHOD)) i++;
  
  if (i < count) 
    [browser selectRow:i inColumn:methodColumn];
  else
  {
    NSString *oldFilterString = filterString;
    BOOL oldDoNotShowSelectorsStartingWithUnderscore    = [[NSUserDefaults standardUserDefaults] boolForKey:@"FScriptDoNotShowSelectorsStartingWithUnderscore"];
    BOOL oldDoNotShowSelectorsStartingWithAccessibility = [[NSUserDefaults standardUserDefaults] boolForKey:@"FScriptDoNotShowSelectorsStartingWithAccessibility"];
    
    if (![oldFilterString isEqualToString:@""] || oldDoNotShowSelectorsStartingWithUnderscore == YES || oldDoNotShowSelectorsStartingWithAccessibility == YES) // Note that the method we are looking for might not exist. In this case, this test is important in order to avoid a infinite recursion.
    {
      filterString = @"";
      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"FScriptDoNotShowSelectorsStartingWithUnderscore"];
      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"FScriptDoNotShowSelectorsStartingWithAccessibility"];

      [self filter];
      [self selectMethodNamed:methodName];
      
      filterString = oldFilterString;
      [[NSUserDefaults standardUserDefaults] setBool:oldDoNotShowSelectorsStartingWithUnderscore    forKey:@"FScriptDoNotShowSelectorsStartingWithUnderscore"];
      [[NSUserDefaults standardUserDefaults] setBool:oldDoNotShowSelectorsStartingWithAccessibility forKey:@"FScriptDoNotShowSelectorsStartingWithAccessibility"];
      
      [self filter];
    }  
  }
}


/*
- (void)mouseMoved:(NSEvent *)theEvent
{
  NSInteger row, column;
  NSPoint baseMouseLocation = [[self window]  convertScreenToBase:[NSEvent mouseLocation]];
  NSView *view = [self hitTest:[[self superview] convertPoint:baseMouseLocation fromView:nil]];

  if ([view isKindOfClass:[NSMatrix class]] && [(NSMatrix *)view getRow:&row column:&column forPoint:[view convertPoint:baseMouseLocation fromView:nil]])
  {
    [statusBar setStringValue:[[(NSMatrix *)view cellAtRow:row column:column] stringValue]];
  }
  else [statusBar setStringValue:@""];
    
  [super mouseMoved:theEvent];
}
*/

- (void) selectView:(id)dummy
{ 
  NSEvent  *event;
  id        view;
  NSCursor *cursor = [NSCursor crosshairCursor];  
  NSDate   *distantFuture = [NSDate distantFuture];
  
  NSRect infoRect = NSMakeRect(0, 0, 290, 100);
  NSTextView *infoView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [infoView setEditable:NO];
  [infoView setSelectable:NO];
  [infoView setDrawsBackground:NO];
  [infoView setTextColor:[NSColor whiteColor]];
  [infoView setFont:[NSFont controlContentFontOfSize:10]];
  [infoView setTextContainerInset:NSMakeSize(4, 4)];
  //[infoView setAutoresizingMask:NSViewHeightSizable|NSViewMinYMargin];
  [infoView setVerticallyResizable:NO];
  
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
  [infoView setDefaultParagraphStyle:paragraphStyle];
          
  NSPanel *infoWindow = [[NSPanel alloc] initWithContentRect:infoRect styleMask:NSHUDWindowMask /*| NSTitledWindowMask*/ | NSUtilityWindowMask backing:NSBackingStoreBuffered defer:NO];
  [infoWindow setLevel:NSFloatingWindowLevel];
  [infoWindow setContentView:infoView];
  [infoWindow setReleasedWhenClosed: NO]; // the default for NSPanel
  
 // NSWindow *focusWindow = [[[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
  
  NSWindow *focusWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] ;

  [focusWindow setBackgroundColor:[NSColor selectedTextBackgroundColor]];
  [focusWindow setAlphaValue:0.7];
  [focusWindow setIgnoresMouseEvents:YES];
  [focusWindow setReleasedWhenClosed: NO]; // ARC will handle the release

  [cursor push];
  
  selectedView = nil;
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillSendAction:) name:NSMenuWillSendActionNotification object:nil];
  
  do
  { 
    [cursor push]; 
    event = [NSApp nextEventMatchingMask:~0 untilDate:distantFuture inMode:NSEventTrackingRunLoopMode dequeue:YES];
    [cursor pop];
    if ([event type] == NSMouseMoved)
    {      
      NSInteger  windowCount; 
      NSInteger *windows;
      
      view = nil;
      
      NSCountWindows(&windowCount);
      windows = malloc(windowCount*sizeof(NSInteger));
      NSWindowList(windowCount, windows);
      
      for (unsigned i = 0; i < windowCount; i++)
      {
        NSWindow *window = [NSApp windowWithWindowNumber:windows[i]];
        if (window && window != focusWindow && window != infoWindow) 
        {
          view = [[[window contentView] superview] hitTest:[window convertScreenToBase:[NSEvent mouseLocation]]];
          if (view) break;
        }
      }
      
      free(windows);
      
      if (view) 
      {
        NSRect rectInWindowCoordinates = [view convertRect:[view visibleRect] toView:nil];;
        NSRect rectInScreenCoordinates;
        NSSize size = NSMakeSize(220,21);
        rectInScreenCoordinates.size = rectInWindowCoordinates.size;
        rectInScreenCoordinates.origin = [[view window] convertBaseToScreen:rectInWindowCoordinates.origin];       
        
        if ([focusWindow parentWindow] != [view window])
        {
          [[focusWindow parentWindow] removeChildWindow:focusWindow];
          [[view window] addChildWindow:focusWindow ordered:NSWindowAbove];
        }
        [focusWindow setFrame:rectInScreenCoordinates display:YES];
        
        /* NSMutableString *infoString = [NSMutableString string];
        
        [infoString appendFormat:@"Bounds:\t%@\n", printString([NSValue valueWithRect:[view bounds]])];
        [infoString appendFormat:@"Frame:\t%@\n", printString([NSValue valueWithRect:[view frame]])];
        [infoString appendFormat:@"Superview:\t%@\n", [[view superview] class]];
        [infoString appendString:@"Subviews:\n"];
        for (NSView *subview in [view subviews]) [infoString appendFormat:@"\t\t%@\n", [subview class]];
        
        [infoView setString:infoString];
        
        size = [[infoView textStorage] size];
        size.width  += 15;
        size.height += 10;
        */
         
        NSPoint origin = NSMakePoint([NSEvent mouseLocation].x+12, [NSEvent mouseLocation].y-size.height-9);
        [infoWindow setFrame:NSMakeRect(origin.x, origin.y, size.width, size.height) display:YES animate:NO];
        //[infoWindow setTitle:[NSString stringWithFormat:@"%@: %p", [view class], view]];
        [infoView setString:[NSString stringWithFormat:@"%@: %p", [view class], view]];
        
        [infoWindow orderFront:nil];
      }
      else
      {
        [[focusWindow parentWindow] removeChildWindow:focusWindow];
        [focusWindow orderOut:nil];
        [infoWindow orderOut:nil];
        //[self browseNothing];
      }
    }  

  }
  while ( [event type] != NSLeftMouseDown && selectedView == nil && !([event type] == NSKeyDown && [[event characters] characterAtIndex:0] == ESCAPE) );
   
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMenuWillSendActionNotification object:nil];
  [cursor pop];
  [[focusWindow parentWindow] removeChildWindow:focusWindow];
  [focusWindow close];
  focusWindow = nil; // force release
  
  [infoWindow close];
  infoWindow = nil;
  
  if ( !([event type] == NSKeyDown && [[event characters] characterAtIndex:0] == ESCAPE) )
  {
    if (selectedView == nil)
      view = [[[[event window] contentView] superview] hitTest:[event locationInWindow]];
    else
      view = selectedView;
    
    [self setRootObject:view];
    [[self window] performSelector:@selector(makeKeyAndOrderFront:) withObject:nil afterDelay:0];
    [NSApp activateIgnoringOtherApps:YES];    
  }
} 

- (void) selectViewAction:(id)sender 
{
  [self performSelector:@selector(selectView:) withObject:nil afterDelay:0]; 
}

- (void) selfAction:(id)sender
{
  [self sendMessage:@selector(self) withArguments:nil];
}

- (void) sendMessage:(SEL)selector withArguments:(FSArray *)arguments // You can pass nil for "arguments"
{
  // Simulate the user invoking a method on the selected object through the browser.
  
  NSString *methodName = [FSCompiler stringFromSelector:selector];
  id selectedObject;

  if ((selectedObject = [self validSelectedObject]) == nil)
  {
    NSBeep();
    return;
  }
  
  if (![selectedObject respondsToSelector:selector] && selector != @selector(applyBlock:)/* Account for a proxy to an object in an app not linked against the F-Script framework */)
  {
    NSBeginInformationalAlertSheet(@"Inavlid message", @"OK", nil, nil, [self window], nil, NULL, NULL, NULL, @"The selected object doesn't responds to \"%@\".", methodName);
    return;
  }
  
  if (arguments && [arguments count] > 0) [browser setDelegate:nil];
  
  [self selectMethodNamed:methodName];
  
  if (arguments && [arguments count] > 0)
  {
    [browser setDelegate:self];
    [self sendMessageTo:selectedObject selectorString:methodName arguments:arguments putResultInMatrix:[browser matrixInColumn:[browser lastColumn]]];
  }

  [browser scrollColumnToVisible:[browser lastColumn]];
  [browser scrollColumnsLeftBy:1]; // Workaround for the call above to scrollColumnToVisible: not working as expected.
  //[browser tile];
}

- (void)sendMessageAction:(id)sender
{
  NSString *selectedString = [[browser selectedCell] stringValue];
  id selectedObject = [[browser loadedCellAtRow:0 column:[browser selectedColumn]] representedObject];
  NSForm *f = [[[sender window] contentView] subviews][0];
  NSInteger nbarg = [f numberOfRows];
  FSArray *arguments = [FSArray arrayWithCapacity:nbarg]; // FSArray instead of NSMutableArray in order to support nil
  NSInteger i;

  for (i = 0; i < nbarg; i++)
  {
    NSFormCell *cell = [f cellAtIndex:i];
    NSString *argumentString = [cell stringValue];
    FSInterpreterResult *result = [self.interpreter execute:argumentString];

    if ([result isOK])
      [arguments addObject:[result result]];
    else
    {
      NSString *errorArgumentString = [NSString stringWithFormat:@"Argument %ld %@", (long)(i+1), [result errorMessage]];

      [result inspectBlocksInCallStack];
      [f selectTextAtIndex:i];
      NSRunAlertPanel(@"ERROR", errorArgumentString, @"OK", nil, nil,nil);

      // An alternative for displaying the error message in a more Smalltalk-like way. Not yet functionnal.
      /*
        NSMutableString *errorArgumentString = [NSMutableString stringWithString:argumentString];
       NSBeep();
       [errorArgumentString insertString:[result errorMessage] atIndex:[result errorRange].location];
       [cell setStringValue:errorArgumentString];
       [cell selectWithFrame:NSMakeRect(0,0,[cell cellSize].width,[cell cellSize].height) inView:[cell controlView] editor:[f currentEditor] delegate:self start:[result errorRange].location length:[result errorRange].length]; */

      break;
    }
  }

  if (i == nbarg) // There were no error evaluating the arguments
  {
    BOOL success; 
    NSMatrix *matrix = [browser matrixInColumn:[browser lastColumn]];
    //NSBrowserCell *cell;

    //[[sender window] orderOut:nil];
    //[NSApp endSheet:[sender window]];
    //[[sender window] close];
    
    success = [self sendMessageTo:selectedObject selectorString:selectedString arguments:arguments putResultInMatrix:matrix];
    /*if (cell = [matrix cellAtRow:0 column:0])
    {
      [browser setTitle:printString([[cell representedObject] classOrMetaclass]) ofColumn:[browser lastColumn]];
    }*/

    //[[sender window] orderOut:nil];
    if (success)
    {
      [NSApp endSheet:[sender window]];
      [[sender window] close];
      self.tempInputWindow = nil;
      [browser tile];
    }  
  }
}

- (BOOL) sendMessageTo:(id)receiver selectorString:(NSString *)selectorStr arguments:(FSArray *)arguments putResultInMatrix:(NSMatrix *)matrix
{ 
  SEL selector = [FSCompiler selectorFromString:selectorStr];
  NSInteger i;
  id result = nil; // To avoid a warning "might be used uninitialized"
   
  if ([receiver isKindOfClass:[FSNewlyAllocatedObjectHolder class]]) receiver = [receiver object];
  
  NSMutableArray* args = [[NSMutableArray alloc] initWithObjects: receiver, selectorStr, nil];
  
  for (i = 0; i < arguments.count; i++) [args addObject: arguments[i]];
    
  @try
  {
    result = sendMsgNoPattern(receiver, selector, args.count, args, [FSMsgContext msgContext], nil);
  }
  @catch (id exception)
  {
    FSInspectBlocksInCallStackForException(exception);
    NSRunAlertPanel(@"Error", FSErrorMessageFromException(exception), @"OK", nil, nil,nil);
    return NO;
  }
  
  if (selector == @selector(alloc) || selector == @selector(allocWithZone:))
    result = [FSNewlyAllocatedObjectHolder newlyAllocatedObjectHolderWithObject:result];

  if (FSEncode([[receiver methodSignatureForSelector:selector] methodReturnType]) != 'v')
    [self fillMatrix:matrix withObject:result];

  return YES;
}

-(void)setFilterString:(NSString *)theFilterString
{
  filterString = theFilterString;
}

-(void)setRootObject:(id)theRootObject 
{
  rootObject = theRootObject;
  browsingMode = FSBrowsingObject;
  [browser loadColumnZero];
  //[browser displayColumn:0]; // may be unnecessary
} 
  
- (void)setTitleOfLastColumn:(NSString *)title
{
  [browser setTitle:title ofColumn:[browser lastColumn]];
}

- (void)updateAction:(id)sender
{
 [self filter];
 /* int i, nb;
    
  for (i = 0, nb = [browser lastColumn]+1; i < nb; i +=2)
  {
    NSMatrix *matrix = [browser matrixInColumn:i];
    int selectedRow = [matrix selectedRow];
    id object = [[matrix cellAtRow:0 column:0] representedObject];
    
    if ((i == 0 && (browsingMode == FSBrowsingWorkspace || browsingMode == FSBrowsingClasses)) || (selectedRow != 0 && ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSSet class]])) )
    {
      int j = 0;
      int numberOfRows;
      id selectedElement = [[matrix cellAtRow:selectedRow column:0] representedObject];
        
      [selectedElement retain]; // (1) To ensure selectedElement will not be deallocated as a side effect of the following fillMatrix:withObject: message  

      if (browsingMode == FSBrowsingWorkspace && i == 0)
        [self fillMatrixForWorkspaceBrowsing:matrix]; // As a side effect, this will supress the selection
      else if (browsingMode == FSBrowsingClasses && i == 0)
        [self fillMatrixForClassesBrowsing:matrix];   // As a side effect, this will supress the selection
      else
        [self fillMatrix:matrix withObject:object];   // As a side effect, this will supress the selection

      //if (i == nb-2) [browser setLastColumn:i];
      
      // Since the collection may have been modified, we search for  
      // the element of the collection that was selected (if still in the collection)
      // in order to re-install the selection
      numberOfRows = [matrix numberOfRows];
      while (1) 
      {
        if (selectedRow+j >= numberOfRows && selectedRow-j < 0) break;
        else if (selectedRow+j < numberOfRows && [[matrix cellAtRow:selectedRow+j column:0] representedObject] == selectedElement)
        {
          [matrix selectCellAtRow:selectedRow+j column:0];
          break;
        }
        else if (selectedRow-j >= 0 && [[matrix cellAtRow:selectedRow-j column:0] representedObject] == selectedElement)
        {
          [matrix selectCellAtRow:selectedRow-j column:0];
          break;
        }
        else
          j++;
      }
      [selectedElement release]; // We can now match the retain in (1)
      
      // If no object is selected in the current matrix, then we "disable" the next matrix 
      // (which contains a method list), because we won't be able call a method from this matrix.
      if ([matrix selectedRow] == -1 && i+1 <= [browser lastColumn])
        [[browser matrixInColumn:i+1] setEnabled:NO];
    }
    else 
    {
      [self fillMatrix:matrix withObject:object];    // As a side effect, this will supress the selection
      if (selectedRow == 0)
        [matrix selectCellAtRow:selectedRow column:0]; // I reinstall the selection
      else 
        if (i+1 <= [browser lastColumn])
          [[browser matrixInColumn:i+1] setEnabled:NO];
    }
  }
  [[self window] display]; // To display the changes. Is there an other way ? */
}

- (id) validSelectedObject
{
  id selectedObject = [self selectedObject];

  // We test wether the selectedObject object is valid (an invalid proxy will raise when sent -respondsToSelector:)
  @try
  {
    [selectedObject respondsToSelector:@selector(class)];
  }
  @catch (id exception)
  {
    return nil;
  }
  
  return selectedObject;
}

- (void) workspaceAction:(id)sender
{
  [self browseWorkspace]; 
}

//- (BOOL) isOpaque{return YES;}
@end
