//  FSGenericObjectInspector.m Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSGenericObjectInspector.h"
#import "FSMiscTools.h"

static NSPoint topLeftPoint = {0,0}; // Used for cascading windows.

@implementation FSGenericObjectInspector

+(FSGenericObjectInspector *)newGenericObjectInspectorWithObject:(id)object
{
  return [[self alloc] initWithObject:object]; 
}
 
-(FSGenericObjectInspector *)initWithObject:(id)object 
{
  if ((self = [super init]))
  {
    inspectedObject = object;
    [NSBundle loadNibNamed:@"genObjInspector.nib" owner:self];
     // To balance the autorelease in windowWillClose:
    [self updateAction:nil];
    topLeftPoint = [window cascadeTopLeftFromPoint:topLeftPoint];
    [window makeKeyAndOrderFront:nil];
    return self;
  }
  return nil;
}


- (void)updateAction:(id)sender
{
  [window setTitle:[NSString stringWithFormat:@"Inspecting %@ at address %p",descriptionForFSMessage(inspectedObject), inspectedObject]];
  [printStringView setFont:[NSFont userFixedPitchFontOfSize:userFixedPitchFontSize()]];
  [printStringView setString:printString(inspectedObject)];
}

/////////////////// Window delegate callbacks

- (void)windowWillClose:(NSNotification *)aNotification
{
//  [self autorelease];
}


@end
