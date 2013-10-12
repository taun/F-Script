/*   FSObjectBrowserButtonCtxBlock.m Copyright (c) 2002-2009 Philippe Mougin.  */
/*   This software is open source. See the license.                  */ 

#import "FSObjectBrowserButtonCtxBlock.h"


@implementation FSObjectBrowserButtonCtxBlock


- (BlockInspector *)inspector { return [master inspector]; } 

- (void) setMaster:(FSBlock *)theMaster
{
  master = theMaster;
}

@end
