//
//  AsyncFileIo.h
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

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>

@interface AsyncFileIoHasher : NSObject
{
    NSMutableData * messageDigest;
    NSUInteger bytesRead;
    CC_SHA1_CTX ctx;
    uint8_t md[CC_SHA1_DIGEST_LENGTH];
    dispatch_io_t fileReaderChannel;
    dispatch_semaphore_t sem;
}

@property (readonly, assign) NSMutableData * messageDigest;
@property (readonly, assign) NSUInteger bytesRead;

- (void) process:(NSURL *)url;

@end
