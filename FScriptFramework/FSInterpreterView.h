/* FSInterpreterView.h Copyright (c) 1998-2009 Philippe Mougin.  */
/*   This software is open source. See the license.  */  

#import <AppKit/AppKit.h>

@class FSInterpreter;

@interface FSInterpreterView : NSView

@property (nonatomic,strong) FSInterpreter* interpreter;

- (CGFloat)fontSize;
- (void)notifyUser:(NSString *)message;
- (void)putCommand:(NSString *)command;
- (void)setFontSize:(CGFloat)theSize;

@end
