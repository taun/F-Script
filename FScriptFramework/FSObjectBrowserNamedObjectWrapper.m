//  FSObjectBrowserNamedObjectWrapper.m Copyright (c) 2005-2009 Philippe Mougin.
//  This software is open source. See the license.

#import "FSObjectBrowserNamedObjectWrapper.h"

@implementation FSObjectBrowserNamedObjectWrapper

+ (id)namedObjectWrapperWithObject:(id)theObject name:(NSString *)theName
{
  return [[self alloc] initWithObject:theObject name:theName];
}

- (id)initWithObject:(id)theObject name:(NSString *)theName
{
  if ((self = [super init]))
  {
    _object = theObject;
    _name = theName;
    return self;
  }
  return nil;
}

- (id)object { return _object; }

- (NSString *)description
{
  return _name;
}

@end
