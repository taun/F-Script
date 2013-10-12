//  FSGenericObjectInspector.h Copyright (c) 2001-2009 Philippe Mougin.
//  This software is open source. See the license.

#import <AppKit/AppKit.h>

@interface FSGenericObjectInspector : NSObject
{
  id inspectedObject;
  IBOutlet NSWindow   *window;
  IBOutlet NSTextView *printStringView;  
}

+ (FSGenericObjectInspector *)newGenericObjectInspectorWithObject:(id)object;
- (FSGenericObjectInspector *)initWithObject:(id)object;
- (void)updateAction:(id)sender;

- (void)windowWillClose:(NSNotification *)aNotification;

@end
