//
//  haSHAr.h
//  https://github.com/jtphotog/haSHAr
//  Licensed under the terms of the MIT License, as specified below.
//

/*
 Copyright (c) 2011 Jeremy Torres, https://github.com/jtphotog/haSHAr
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
 */

#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#define HASHAR_PROGRAM_NAME_STR        "haSHAr"
#define HASHAR_VERSION_STR             "1.0"

@class DDFileLogger;

@interface haSHAr : NSObject {
@private
    dispatch_semaphore_t filesSem;
    NSOperationQueue * ioQueue;
    NSOperationQueue * computeQueue;
    NSOperationQueue * printQueue;
    DDFileLogger * fileLogger;
    id delegate;
    bool isCancelled;
    bool printToStdout;
}

@property bool printToStdout;

@property (retain) id delegate;

- (void) generateMessageDigests:(NSArray *)URLs numfiles:(unsigned int)numfiles;
- (NSArray *) verifyMessageDigests:(NSArray *)URLs numfiles:(unsigned int)
   numfiles;
- (void) cancel;

@end

@protocol haSHArDelegate <NSObject>
@optional
-(void)processingFile:(NSURL *)url;
@optional
-(void)processedFile:(NSURL *)url;
@end
