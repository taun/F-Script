/* ConstantsInitialisation.m Copyright (c) 1999-2009 Philippe Mougin.  */
/*   This software is open source. See the licence.  */  

#import "FSConstantsInitialization.h"
#import "FSInterpreter.h"
#import "FSGenericPointerPrivate.h"
#import <CoreAudio/AudioHardware.h>
#import <IOBluetooth/OBEX.h>

#import <Cocoa/Cocoa.h>

void FSConstantsInitialization(NSMutableDictionary *d)
{
  NSString *path;
  NSBundle *bundle = [NSBundle bundleForClass:[FSInterpreter class]];
  NSString *constantsDictionaryFileName = @"constantsDictionary";

  if ((path = [bundle pathForResource:constantsDictionaryFileName ofType:@""]))
  {
    [d addEntriesFromDictionary:[NSKeyedUnarchiver unarchiveObjectWithFile:path]]; 
  } 
 
  if (NSMultipleValuesMarker) d[@"NSMultipleValuesMarker"] = NSMultipleValuesMarker; 
  if (NSNoSelectionMarker)    d[@"NSNoSelectionMarker"] = NSNoSelectionMarker; 
  if (NSNotApplicableMarker)  d[@"NSNotApplicableMarker"] = NSNotApplicableMarker;
  
  if (NSErrorMergePolicy)                      d[@"NSErrorMergePolicy"] = NSErrorMergePolicy; 
  if (NSMergeByPropertyStoreTrumpMergePolicy)  d[@"NSMergeByPropertyStoreTrumpMergePolicy"] = NSMergeByPropertyStoreTrumpMergePolicy; 
  if (NSMergeByPropertyObjectTrumpMergePolicy) d[@"NSMergeByPropertyObjectTrumpMergePolicy"] = NSMergeByPropertyObjectTrumpMergePolicy; 
  if (NSOverwriteMergePolicy)                  d[@"NSOverwriteMergePolicy"] = NSOverwriteMergePolicy; 
  if (NSRollbackMergePolicy)                   d[@"NSRollbackMergePolicy"] = NSRollbackMergePolicy; 
 
  d[@"NSNotFound"] = @(NSNotFound);
  d[@"NSIntegerMax"] = @NSIntegerMax;
  d[@"NSIntegerMin"] = @NSIntegerMin;
  d[@"NSUIntegerMax"] = @NSUIntegerMax;
  d[@"NSUndefinedDateComponent"] = @(NSDateComponentUndefined);
  
#ifdef __LP64__
  // 64-bit code
  d[@"NSFontIdentityMatrix"] = [[[FSGenericPointer alloc] initWithCPointer:(CGFloat *)NSFontIdentityMatrix freeWhenDone:NO type:"d"] autorelease];
#else
  // 32-bit code
  [d setObject:[[[FSGenericPointer alloc] initWithCPointer:(CGFloat *)NSFontIdentityMatrix freeWhenDone:NO type:"f"] autorelease] forKey:@"NSFontIdentityMatrix"];
#endif

  d[@"kAudioAggregateDeviceIsPrivateKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioAggregateDeviceIsPrivateKey       freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioAggregateDeviceMasterSubDeviceKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioAggregateDeviceMasterSubDeviceKey freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioAggregateDeviceNameKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioAggregateDeviceNameKey            freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioAggregateDeviceSubDeviceListKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioAggregateDeviceSubDeviceListKey   freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioAggregateDeviceUIDKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioAggregateDeviceUIDKey             freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioHardwareRunLoopMode"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioHardwareRunLoopMode               freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceDriftCompensationKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceDriftCompensationKey     freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceExtraInputLatencyKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceExtraInputLatencyKey     freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceExtraOutputLatencyKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceExtraOutputLatencyKey    freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceInputChannelsKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceInputChannelsKey         freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceNameKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceNameKey                  freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceOutputChannelsKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceOutputChannelsKey        freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceUIDKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceUIDKey                   freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceDriftCompensationKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceDriftCompensationKey     freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceExtraInputLatencyKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceExtraInputLatencyKey     freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceExtraOutputLatencyKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceExtraOutputLatencyKey    freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceInputChannelsKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceInputChannelsKey         freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceNameKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceNameKey                  freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceOutputChannelsKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceOutputChannelsKey        freeWhenDone:NO type:"c"] autorelease];
  d[@"kAudioSubDeviceUIDKey"] = [[[FSGenericPointer alloc] initWithCPointer:kAudioSubDeviceUIDKey                   freeWhenDone:NO type:"c"] autorelease];

  d[@"kCharsetStringISO88591"] = [[[FSGenericPointer alloc] initWithCPointer:kCharsetStringISO88591         freeWhenDone:NO type:"c"] autorelease];
  d[@"kCharsetStringUTF8"] = [[[FSGenericPointer alloc] initWithCPointer:kCharsetStringUTF8             freeWhenDone:NO type:"c"] autorelease];
  d[@"kEncodingString8Bit"] = [[[FSGenericPointer alloc] initWithCPointer:kEncodingString8Bit            freeWhenDone:NO type:"c"] autorelease];
  d[@"kEncodingStringBase64"] = [[[FSGenericPointer alloc] initWithCPointer:kEncodingStringBase64          freeWhenDone:NO type:"c"] autorelease];
  d[@"kEncodingStringQuotedPrintable"] = [[[FSGenericPointer alloc] initWithCPointer:kEncodingStringQuotedPrintable freeWhenDone:NO type:"c"] autorelease];

  d[@"NSZeroPoint"] = [NSValue valueWithPoint:NSZeroPoint];
  d[@"NSZeroRect"] = [NSValue valueWithRect:NSZeroRect];
  d[@"NSZeroSize"] = [NSValue valueWithSize:NSZeroSize];

  // NSLog(@"constantsDictionary count = %lu", (unsigned long)[d count]);
}
