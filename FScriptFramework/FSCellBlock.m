//
//  FSCellBlock.m
//  FScript
//
//  Created by Taun Chapman on 07/24/13.
//
//

#import "FSCellBlock.h"
#import "FSBlock.h"

static NSString *headerCellStringForBlock(FSBlock *block)
{
  NSString *key = FS_Block_keyOfSetValueForKeyMessage(block);
  if (key) return key;
  else     return [[block printString] substringFromIndex:[[block printString] hasPrefix:@"#"] ? 1 : 0];
}


@implementation FSCellBlock

+(FSCellBlock*) newCellBlockWithFSBlock:(id)fsBlock {
  return [[FSCellBlock alloc] initWithFSBlock: fsBlock];
}

-(id)init {
  self = [super init];
  
  return self;
}

-(id)initImageCell:(NSImage *)image {
  self = [super initImageCell:image];
  
  return self;
}

-(id)initTextCell:(NSString *)aString {
  self = [super initTextCell:aString];
  
  return self;
}

-(id)initWithFSBlock:(id)fsBlock {
  self = [super initTextCell: headerCellStringForBlock(fsBlock)];
  if (self) {
    [self setFsBlock: fsBlock];
  }
  
  return self;
}
@end
