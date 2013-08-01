//
//  FSCellBlock.h
//  FScript
//
//  Created by Taun Chapman on 07/24/13.
//
//

#import <Cocoa/Cocoa.h>

@class FSBlock;


@interface FSCellBlock : NSCell

@property (strong,readwrite) FSBlock*   fsBlock;


+(FSCellBlock*) newCellBlockWithFSBlock: (FSBlock*) fsBlock;

-(id)initWithFSBlock: (FSBlock*) fsBlock;


@end
