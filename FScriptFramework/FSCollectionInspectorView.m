/* FSCollectionInspectorView.m Copyright (c) 1998-2009 Philippe Mougin.  */
/*   This software is open source. See the license.  */  

#import "FSCollectionInspectorView.h"
#import "build_config.h"
#import "FSBlock.h" // value: 
#import "FSMiscTools.h"
#import "FSInterpreter.h"
#import <AppKit/AppKit.h>
#import "FSArray.h"
#import "FSNSArray.h" 
//#import "FSObjectFormatter.h"
#import "FSNumber.h"
#import "FSNSString.h"
#import "FSCollectionInspector.h"
#import "FSCellBlock.h"

// TODO: identifier change plan
/*
 TODO:
 Plan: Subclass NSTableColumn to include an FSBlock property and use initWithFSBlock
       Change FSBlock to include a string representation (asString) to use as column identifier.

 AND
  ** Subclass NSCell to store FSBlock then use custom cell for NSTableColumn header cell.
 
 
 
 */

static NSString *externalColumnIdentifier = @"externalColumnIdentifier";

// Moved to FSCellBlock class
//static NSString *headerCellStringForBlock(FSBlock *block)
//{
//  NSString *key = FS_Block_keyOfSetValueForKeyMessage(block);
//  if (key) return key;
//  else     return [[block printString] substringFromIndex:[[block printString] hasPrefix:@"#"] ? 1 : 0];  
//}

@interface FSCollectionInspectorView(FSCollectionInspectorViewPrivateInternal)  // Methods declaration to let the compiler know
- (void) filter;
- (NSArray *)selectedColumnObjects;
- (void)setFilteredSortedExternals:(NSArray *)newFilteredSortedExternals; 
- (void)setFilteredSortedModelArray:(NSArray *)newFilteredSortedModelArray; 
- (void)setFilterString:(NSString *)theFilterString;
- (void)setSortColumn:(NSTableColumn *)newColumn;
- (void)setSortedExternals:(NSArray *)newSortedExternals;
- (void)setSortedModelArray:(NSArray *)newSortedModelArray;
- (void)sortOnColumn:(NSTableColumn *)column;
- (void)sortOnColumn:(NSTableColumn *)column signalError:(BOOL)signalError;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
@end

@implementation FSCollectionInspectorView

+ (NSArray *)blocksForEntity:(NSEntityDescription *)entity interpreter:(FSInterpreter *)theInterpreter
{
  NSUInteger i, count;
  NSMutableArray *blocks = [NSMutableArray array];
  NSArray *propertyKeys  = [[[[entity attributesByName] allKeys] sortedArrayUsingSelector:@selector(compare:)] arrayByAddingObjectsFromArray:[[[entity relationshipsByName] allKeys] sortedArrayUsingSelector:@selector(compare:)]] ;    
  
  for (i = 0, count = [propertyKeys count]; i < count; i++)
  {
     NSMutableString *encodedPropertyKey = [[propertyKeys[i] mutableCopy] autorelease];
     [encodedPropertyKey replaceOccurrencesOfString:@"'" withString:@"''" options:0 range:NSMakeRange(0, [encodedPropertyKey length])];
     
     NSString *blockString = [NSString stringWithFormat:@"[:object| object valueForKey:'%@']", encodedPropertyKey];
     FSBlock *block = [[theInterpreter execute:blockString] result];
     [(NSMutableArray *)blocks addObject:block];
  }
  return blocks;
}

- (id)initWithFrame:(NSRect)frame 
{
  self = [super initWithFrame:frame];
  if (self) 
  {
    CGFloat dataFontSize = userFixedPitchFontSize();
    filterString = @"";
    [NSBundle loadNibNamed:@"FSCollectionInspectorView.nib" owner:self];
    [self addSubview:contentView];
    [contentView release]; // contentView is a top level object in the nib file and thus comes with a reference count of 1 that needs to be released.
    [contentView setFrame:[self bounds]];

    /////////////////////////////////// NSSearchField menu setup
    NSMenu *cellMenu = [[[NSMenu alloc] initWithTitle:@"Search Menu"] autorelease];
    NSMenuItem *item1, *item2, *item3, *item4;

    item1 = [[[NSMenuItem alloc] initWithTitle:@"Recent Searches" action: @selector(limitOne:) keyEquivalent:@""] autorelease];
    [item1 setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [cellMenu insertItem:item1 atIndex:0];

    item2 = [[[NSMenuItem alloc] initWithTitle:@"Recents" action:@selector(limitTwo:) keyEquivalent:@""]  autorelease];
    [item2 setTag:NSSearchFieldRecentsMenuItemTag];
    [cellMenu insertItem:item2 atIndex:1];
 
    item3 = [[[NSMenuItem alloc] initWithTitle:@"Clear" action:@selector(limitThree:) keyEquivalent:@""]  autorelease];
    [item3 setTag:NSSearchFieldClearRecentsMenuItemTag];
    [cellMenu insertItem:item3 atIndex:2];

    item4 = [[[NSMenuItem alloc] initWithTitle:@"No Recent Searches" action:@selector(limitFour:) keyEquivalent:@""]  autorelease];
    [item4 setTag:NSSearchFieldNoRecentsMenuItemTag];
    [cellMenu insertItem:item4 atIndex:3];
        
    [searchField setSearchMenuTemplate:cellMenu]; 
    ////////////////////////////////////////////////////////////////
  
    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(inspect:)];

    [tableView setRowHeight:dataFontSize + 4];
    if ([tableView respondsToSelector:@selector(setGridStyleMask:)]) [tableView setGridStyleMask:NSTableViewSolidVerticalGridLineMask];

    [self setCollection:@[] interpreter:[FSInterpreter newInterpreter] blocks:@[] showExternals:YES];   
  }
  return self;
}

- (IBAction)add:(id)sender 
{
  FSBlock *defaultBlock = [[interpreter execute:@"#self"] result];
  FSCellBlock* headerCell = [FSCellBlock newCellBlockWithFSBlock: defaultBlock];
  // TODO: as of 10.7 the signature of NSTableColumn initWithIdentifier: has changed to
  // - (id)initWithIdentifier:(NSString *)identifier;
  NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier: [headerCell stringValue]] autorelease];
  
  NSInteger newColumnIndex = [tableView numberOfColumns] > 0 && [[tableView tableColumns][0] identifier] == externalColumnIdentifier ? 1 : 0;
  
  [column setHeaderCell: headerCell];
  [column setEditable:NO];
  [[column dataCell] setFont:[NSFont userFixedPitchFontOfSize:userFixedPitchFontSize()]];
  [[column dataCell] setDrawsBackground:NO];  
  [column setMinWidth:50];
  //[[column dataCell] setFormatter:[[[FSObjectFormatter alloc] init] autorelease]];
  [tableView addTableColumn:column];
  
  // Display trick (getting an acceptable layout is not that easy!) 
  [tableView moveColumn:[tableView numberOfColumns]-1 toColumn:newColumnIndex];
  [tableView sizeLastColumnToFit];
  //[tableView moveColumn:newColumnIndex toColumn:[tableView numberOfColumns]-1];
  
  [tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:newColumnIndex] byExtendingSelection:NO];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(blockDidChange:) name:@"BlockDidChangeNotification" object:defaultBlock];
  
  [self filter];
  [tableView reloadData];
  
  [defaultBlock inspect];
}

- (IBAction)browse:(id)sender 
{
  NSInteger row = [tableView selectedRow];
  NSArray *objects;

  if (row != -1) [interpreter browse:filteredSortedModelArray[row]];
  else if ((objects = [self selectedColumnObjects])) [interpreter browse:objects];  
}

- (void)blockDidChange:(NSNotification *)notification 
{
  id notificationObject = [notification object];
  
  NSTableColumn *column = [tableView tableColumnWithIdentifier: notificationObject];
  
  NSAssert2([notificationObject isKindOfClass: [FSBlock class]], @"Notification object should be of class FSBlock instead %@ is class %@", notificationObject, NSStringFromClass([notificationObject class]));
  
  FSCellBlock* headerCell = [FSCellBlock newCellBlockWithFSBlock: notificationObject];
  
  [column setHeaderCell: headerCell];

  if (sortColumn == column) [self setSortColumn:nil];
  [self filter];
  [tableView reloadData];
}

- (void)computeSortedModelArrayAndSortedExternals
{
  if ([model isKindOfClass:[NSArray class]])
  {
    [self setSortedExternals:[@([(NSArray *)model count]) iota]];
    [self setSortedModelArray:model];
  }
  else if ([model isKindOfClass:[NSDictionary class]])
  {
    NSUInteger i, count;
    NSMutableArray *newSortedModelArray = [NSMutableArray arrayWithCapacity:[model count]];
    [self setSortedExternals:[model allKeys]];
    for (i = 0, count = [sortedExternals count]; i < count; i++)
      [newSortedModelArray addObject:model[sortedExternals[i]]];
    
    [self setSortedModelArray:newSortedModelArray];    
  }
  else if ([model isKindOfClass:[NSCountedSet class]])
  {
    NSUInteger i, count;
    NSMutableArray *newSortedExternals = [NSMutableArray arrayWithCapacity:[model count]];
    [self setSortedModelArray:[model allObjects]];
    for (i = 0, count = [sortedModelArray count]; i < count; i++)
      [newSortedExternals addObject:[FSNumber numberWithDouble:[model countForObject:sortedModelArray[i]]]];
    
    [self setSortedExternals:newSortedExternals];
  }
  else if ([model isKindOfClass:[NSSet class]])
  {
    [self setSortedExternals:[model allObjects]]; // Will not be displayed or used in any meaningful ways. Just here because we need something here in order to avoid adding tests elsewhere in the code.
    [self setSortedModelArray:[model allObjects]];
  }
} 

- (void)dealloc 
{
  //NSLog(@"FSCollectionInspector dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [model release];
  [sortedExternals release];
  [sortColumn release];
  [sortedModelArray release];
  [filteredSortedModelArray release];
  [filteredSortedExternals release];

  [filterString release];
  [super dealloc];
}

- (void) filter
{
  [self setFilteredSortedExternals:sortedExternals];
  [self setFilteredSortedModelArray:sortedModelArray];
  
  if ([filterString length] != 0)
  {
    NSMutableArray *newFilteredSortedExternals  = [NSMutableArray array];
    NSMutableArray *newFilteredSortedModelArray = [NSMutableArray array];
    NSArray *columns = [tableView tableColumns];
    NSUInteger numberOfColumns = [columns count];
    NSUInteger numberOfRows = [model count];
    NSUInteger rowIndex, columnIndex;
    Class NSAttributedStringClass = [NSAttributedString class];
    
    for (rowIndex = 0; rowIndex < numberOfRows; rowIndex++)
    {
      for (columnIndex = 0; columnIndex < numberOfColumns; columnIndex++)
      {
        id currentString = [self tableView:tableView objectValueForTableColumn:columns[columnIndex] row:rowIndex];
        if ([currentString isKindOfClass:NSAttributedStringClass]) currentString = [currentString string];
        if (containsString(currentString, filterString, NSCaseInsensitiveSearch))
          break;
      }
      if (columnIndex < numberOfColumns)
      {
        [newFilteredSortedExternals  addObject:sortedExternals[rowIndex]];
        [newFilteredSortedModelArray addObject:sortedModelArray[rowIndex]];
      } 
    }
    [self setFilteredSortedExternals:newFilteredSortedExternals];
    [self setFilteredSortedModelArray:newFilteredSortedModelArray];
  }
  [tableView reloadData];
}

- (IBAction)filter:(id)sender
{  
  [self setFilterString:[sender stringValue]];
  [self filter];
  [tableView deselectAll:self];
  if ([filterString isEqualToString:@""] || [tableView numberOfRows] == 0) [narrowButton setEnabled:NO];      
  else [narrowButton setEnabled:YES];
}

- (IBAction)inspect:(id)sender 
{
  if ([tableView numberOfSelectedRows] == 1)
  {
    inspect(filteredSortedModelArray[[tableView selectedRow]], interpreter, nil);
  }
  else if ([tableView numberOfSelectedColumns] == 1)
  {  
    inspect([self selectedColumnObjects], interpreter, nil);
  }    
}

- (IBAction)modify:(id)sender 
{
  NSInteger i = [tableView selectedColumn]; 
  
  if (i != -1 && [[tableView tableColumns][i] identifier] != externalColumnIdentifier)
  {
    [(id)[[tableView tableColumns][i] identifier] inspect];
  }
}

- (IBAction)narrow:(id)sender
{
  NSArray *blocks = [[@"[:tableColumns| tableColumns identifier at:(tableColumns identifier @isKindOfClass:FSBlock)]" asBlock] value:[tableView tableColumns]];
  NSArray *objects;
  if ([tableView numberOfSelectedRows] == 0) objects = filteredSortedModelArray;
  else objects = [[@"[:array :index| array at:index]" asBlock] value:filteredSortedModelArray value:[tableView selectedRowIndexes]];
  
  if ([model isKindOfClass:[NSDictionary class]])
  {
    NSArray *keys;
    if ([tableView numberOfSelectedRows] == 0) keys = filteredSortedExternals;
    else keys = [[@"[:array :index| array at:index]" asBlock] value:filteredSortedExternals value:[tableView selectedRowIndexes]];
       
    [FSCollectionInspector collectionInspectorWithCollection:[NSDictionary dictionaryWithObjects:objects forKeys:keys] interpreter:interpreter blocks:blocks];
  }
  else if ([model isKindOfClass:[NSCountedSet class]])
  {
    NSCountedSet *narrowCountedSet = [[@"[:objects :model| narrowCountedSet := NSCountedSet set. [:object| 1 to:(model countForObject:object) do:[narrowCountedSet addObject:object]] value:@ objects. narrowCountedSet]" asBlock] value:objects value:model];
    [FSCollectionInspector collectionInspectorWithCollection:narrowCountedSet interpreter:interpreter blocks:blocks];  
  }
  else if ([model isKindOfClass:[NSSet class]])
  {
    [FSCollectionInspector collectionInspectorWithCollection:[NSSet setWithArray:objects] interpreter:interpreter blocks:blocks];
  }
  else if ([model isKindOfClass:[NSArray class]])
  {
    [FSCollectionInspector collectionInspectorWithCollection:objects interpreter:interpreter blocks:blocks showExternals:NO]; 
  }
}

- (IBAction)refresh:(id)sender 
{
  [self computeSortedModelArrayAndSortedExternals];
  if (sortColumn)
  {
    NSTableColumn *sortCol = sortColumn;
    [self setSortColumn:nil];
    [self sortOnColumn:sortCol signalError:NO];
  }
  [self filter];
  [tableView reloadData];
} 

- (IBAction)remove:(id)sender  
{
  NSInteger i = [tableView selectedColumn];
  
  if (i != -1 && [tableView numberOfColumns] > 1)
  {
    NSTableColumn *column = [tableView tableColumns][i];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"BlockDidChangeNotification" object:[column identifier]];
    [tableView removeTableColumn:column];
    [tableView sizeLastColumnToFit];
    [self setSortColumn:nil];
    [self filter];
    [tableView reloadData];
  }
  else NSBeep();
} 

/*- (void)resetSortParameters
{
  [self setSortColumn:nil];
  [self setSortedExternals:[[(NSArray *)model size] iota]];
  [self setSortedModelArray:model];
}*/

-(NSArray *) selectedColumnObjects  
{
  NSArray* resultArray = nil;
  FSBlock* block = nil;
  
  if ([tableView selectedColumn] != -1)  {
    NSUInteger i;
    const NSUInteger count = [filteredSortedModelArray count];
    NSTableColumn *column = [tableView tableColumns][[tableView selectedColumn]];
    
    NSCell* headerCell = [column headerCell];
    
    
    if ([headerCell isKindOfClass: [FSCellBlock class]]) {
      block = [(FSCellBlock*)headerCell fsBlock];
    }

    FSArray *objects = [FSArray arrayWithCapacity:count];

    if ([column identifier] == externalColumnIdentifier){
      resultArray = [[filteredSortedExternals copy] autorelease];
    } else {
      for (i = 0; i < count; i++)
      {
        FSInterpreterResult *interpreterResult = [block executeWithArguments:[FSArray arrayWithObject:filteredSortedModelArray[i]]]; // We use an FSArray instead of NSArray because the argumement might be nil
        if (![interpreterResult isOK])
        {
          [interpreterResult inspectBlocksInCallStack];
          NSBeginInformationalAlertSheet(@"An error occurred while computing the column's values", @"OK", nil, nil, [tableView window], nil, NULL, NULL, NULL, @"%@", [interpreterResult errorMessage]);
          return nil;
        }
        [objects addObject:[interpreterResult result]];
      }
      resultArray = objects;
    }
    
  }
  return resultArray;
}    

- (void) setCollection:(id)theCollection interpreter:(FSInterpreter *)theInterpreter blocks:(NSArray *)blocks showExternals:(BOOL)showExternals
// You can pass nil for blocks. In this case the view will use a default block set. 
{
  NSTableColumn *column;
  CGFloat dataFontSize = userFixedPitchFontSize();

  [theCollection  retain]; [model       release]; model       = theCollection;
  [theInterpreter retain]; [interpreter release]; interpreter = theInterpreter;
  
  while ([[tableView tableColumns] count] > 0)
    [tableView removeTableColumn:[tableView tableColumns][0]];
 
  if (blocks == nil)
  {
    Class NSManagedObjectClass = NSClassFromString(@"NSManagedObject");
    if (NSManagedObjectClass)
    {
      NSArray *objects;
      id element;
      NSString *entityName = nil;
      NSUInteger i, count;
      
      if ([theCollection isKindOfClass:[NSSet class]]) objects = [theCollection allObjects];
      else if ([theCollection isKindOfClass:[NSDictionary class]]) objects = [theCollection allValues];
      else /* collection is an NSArray */ objects = theCollection; 
      
      count = [objects count];
      i = 0;
      
      if (count > 0 && [objects[0] isKindOfClass:NSManagedObjectClass]) 
      {
        entityName = [[objects[0] entity] name];

        // We don't use an NSEnumerator because our collection may be an FSArray containing nil.
        for (i = 1; i  < count; i++)
        {
          element  = objects[i];
          if (![element isKindOfClass:NSManagedObjectClass] || ![[[element entity] name] isEqualToString:entityName]) 
            break;
        }
      }  
      
      if (count > 0 && i == count) blocks = [[self class] blocksForEntity:[objects[0] entity] interpreter:interpreter];
    }
    if (blocks == nil) blocks = @[[[interpreter execute:@"#self"] result]];
  }
  
  if (showExternals && ([model isKindOfClass:[NSArray class]] || [model isKindOfClass:[NSDictionary class]] || [model isKindOfClass:[NSCountedSet class]]))
  {
    column = [[[NSTableColumn alloc] initWithIdentifier:externalColumnIdentifier] autorelease];
    
    if ([model isKindOfClass:[NSArray class]])
    {
      [[column headerCell] setStringValue:@" index "];
    }
    else if ([model isKindOfClass:[NSDictionary class]])
    {
      [[column headerCell] setStringValue:@"                          key                          "];
    }
    else if ([model isKindOfClass:[NSCountedSet class]])
    {
      [[column headerCell] setStringValue:@" count "];
    }

    [column setEditable:NO];
    [[column dataCell] setFont:[NSFont systemFontOfSize:dataFontSize]];
    [[column dataCell] setDrawsBackground:NO];
    [column setMinWidth:50];
    [tableView addTableColumn:column];
    [column sizeToFit];
  }
  
  for (NSUInteger i = 0, count = [blocks count]; i < count; i++) {
    FSBlock* headerBlock = blocks[i];
    FSCellBlock* headerCell = [FSCellBlock newCellBlockWithFSBlock: headerBlock];
    // Check for class == FSCellBlock?
    column = [[[NSTableColumn alloc] initWithIdentifier:[headerCell stringValue]] autorelease];
    [column setHeaderCell: headerCell];
    [column setEditable:NO];
    [[column dataCell] setFont:[NSFont userFixedPitchFontOfSize:dataFontSize]];
    [[column dataCell] setDrawsBackground:NO];
    [column setMinWidth:50];
    //[[column dataCell] setFormatter:formatter];
    [tableView addTableColumn:column];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(blockDidChange:) name:@"BlockDidChangeNotification" object:blocks[i]];
  }
  //[tableView sizeToFit];
  //[tableView setNeedsDisplay:YES];
  [tableView sizeLastColumnToFit];

  [self computeSortedModelArrayAndSortedExternals];
  [self filter];
}

- (void)setFilteredSortedExternals:(NSArray *)newFilteredSortedExternals 
{
  [newFilteredSortedExternals retain];
  [filteredSortedExternals release];
  filteredSortedExternals = newFilteredSortedExternals;
}

- (void)setFilteredSortedModelArray:(NSArray *)newFilteredSortedModelArray 
{
  [newFilteredSortedModelArray retain];
  [filteredSortedModelArray release];
  filteredSortedModelArray = newFilteredSortedModelArray;
}

-(void)setFilterString:(NSString *)theFilterString
{
  [theFilterString retain];
  [filterString release];
  filterString = theFilterString;
}

- (void)setSortColumn:(NSTableColumn *)newColumn 
{
  if (sortColumn) [tableView setIndicatorImage:nil inTableColumn:sortColumn];
  if (newColumn)  [tableView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:newColumn];
  [newColumn retain];
  [sortColumn release];
  sortColumn = newColumn;
} 

- (void)setSortedExternals:(NSArray *)newSortedExternals 
{
  [newSortedExternals retain];
  [sortedExternals release];
  sortedExternals = newSortedExternals;
}

- (void)setSortedModelArray:(NSArray *)newSortedModelArray 
{
  [newSortedModelArray retain];
  [sortedModelArray release];
  sortedModelArray = newSortedModelArray;
}

- (void)sortOnColumn:(NSTableColumn *)column 
{
  [self sortOnColumn:column signalError:YES];
}

- (void)sortOnColumn:(NSTableColumn *)column signalError:(BOOL)signalError 
{
  if ([column identifier] == externalColumnIdentifier)
  {
    @try
    {
      NSArray *sortedIndices = [sortedExternals sort];
      [self setSortedExternals:[sortedExternals at:sortedIndices]];
      [self setSortedModelArray:[sortedModelArray at:sortedIndices]];
      [self setSortColumn:column];
    }
    @catch (id exception) 
    {
      if (signalError) NSBeginInformationalAlertSheet(@"An error occurred while sorting", @"OK", nil, nil, [tableView window], nil, NULL, NULL, NULL, @"%@", FSErrorMessageFromException(exception));
    }
  }
  else
  {
    NSUInteger i;
    const NSUInteger count = [sortedModelArray count];
    FSBlock *block = nil;
    
    NSCell* headerCell = [column headerCell];
    if ([headerCell isKindOfClass:[FSCellBlock class]]) {
      block = [(FSCellBlock*)headerCell fsBlock];
    }

    FSArray *objects = [FSArray arrayWithCapacity:count];
    
    for (i = 0; i < count; i++)
    {
      FSInterpreterResult *interpreterResult = [block executeWithArguments:[FSArray arrayWithObject:sortedModelArray[i]]]; // We use an FSArray instead of NSArray because the argumement might be nil

      if ([interpreterResult isOK]) [objects addObject:[interpreterResult result]];
      else
      { 
        if (signalError)
        {
          [interpreterResult inspectBlocksInCallStack];
          NSBeginInformationalAlertSheet(@"An error occurred while sorting", @"OK", nil, nil, [tableView window], nil, NULL, NULL, NULL, @"%@", [interpreterResult errorMessage]);
        }
        break;
      }
    }
    
    if (i == count)
    {
      @try
      {
        NSArray *sortedIndices = [objects sort]; // may throw      
        [self setSortedExternals:[sortedExternals at:sortedIndices]];
        [self setSortedModelArray:[sortedModelArray at:sortedIndices]];
        [self setSortColumn:column];
      }
      @catch (id exception)
      {
        if (signalError) NSBeginInformationalAlertSheet(@"An error occurred while sorting", @"OK", nil, nil, [tableView window], nil, NULL, NULL, NULL, @"%@", FSErrorMessageFromException(exception));
      }
    }
  } 
  [self filter]; 
  [tableView reloadData];
}

- (IBAction)sort:(id)sender 
{
  NSInteger i = [tableView selectedColumn];
  if (i != -1) [self sortOnColumn:[tableView tableColumns][i]];
} 

//////////////////// NSTableView callbacks (NSTableDataSource informal protocol)

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex 
{
  // Note: We do not return the result of the block evaluation, but its printString (or, in case of error, an NSAttributedString).
  // There are two reasons, somewhat related, for that: 
  // 
  // 1) NSTableViews apply their own formatting to objects like NSString, NSArray etc. Since we want the F-Script 
  // formatting style, not the NSTableView one, we have to return a formated string.  
  // 
  // 2) This method is not only called by the tableview, but also by the "filter" method (defined in this class). The later, 
  // in order to work accurately, needs to get the string that will be displayed by the tableview to the user. 

  id result, object;

  
  @try
  {
  
    if ([aTableColumn identifier] == externalColumnIdentifier) 
      object = filteredSortedExternals[rowIndex];
    else {
      NSCell* headerCell = [aTableColumn headerCell];
      if ([headerCell isKindOfClass:[FSCellBlock class]] && [(FSCellBlock*)headerCell fsBlock]) {
        object = [[(FSCellBlock*)headerCell fsBlock] value:filteredSortedModelArray[rowIndex]];
      }
    }

    if ([object isKindOfClass:[NSString class]]) result = object; // Because we don't want the quotes to appear.
    else result = printStringLimited(object, 500);
  }
  @catch (NSException *exception)
  {
    result = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"***%@", [exception reason]] attributes:@{NSForegroundColorAttributeName: [NSColor redColor]}];
  }
  @catch (id exception)
  {
    result = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"***%@", FSErrorMessageFromException(exception)] attributes:@{NSForegroundColorAttributeName: [NSColor redColor]}];
  }  
  return result;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView 
{
  return [filteredSortedModelArray count];
}

//////////////////// NSTableView callbacks (delegate)

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification 
{
  if ([tableView selectedColumn] == -1)
  { 
    [modifyButton setEnabled:NO];
    [removeButton setEnabled:NO];
    [sortButton setEnabled:NO];

    if ([tableView selectedRow] == -1) 
    {
      if ([filterString isEqualToString:@""] || [tableView numberOfRows] == 0) [narrowButton setEnabled:NO];      
      else [narrowButton setEnabled:YES];
      [inspectButton setEnabled:NO];
      [browseButton setEnabled:NO];
    }
    else                               
    {
      if ([tableView numberOfSelectedRows] == 1) 
      {
        [inspectButton setEnabled:YES];
        [browseButton setEnabled:YES];
      }
      else 
      {
        [inspectButton setEnabled:NO];
        [browseButton setEnabled:NO];
      }
      [narrowButton setEnabled:YES];
    }
  }
  else
  {
    if ([[tableView tableColumns][[tableView selectedColumn]] identifier] == externalColumnIdentifier)
    {
      [modifyButton  setEnabled:NO];
    }
    else
    {
      [modifyButton  setEnabled:YES];
    }
    
    if ([tableView numberOfColumns] == 1)
      [removeButton setEnabled:NO];
    else
      [removeButton setEnabled:YES];
    
    [sortButton setEnabled:YES];
    [inspectButton setEnabled:YES];
    [browseButton setEnabled:YES];

  }
}

@end
