//
//  AsyncFileIo.m
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

#import "AsyncFileIoHasher.h"

@implementation AsyncFileIoHasher

@synthesize messageDigest;
@synthesize bytesRead;

- (id) init
{
    self = [super init];
    if (self)
    {
        // Initialization code here.
        self->messageDigest = [[NSMutableData data] retain];
        self->bytesRead = 0;
        self->sem = dispatch_semaphore_create(0);
    }

    return self;
}

- (void) dealloc
{
    if (messageDigest)
    {
        [messageDigest release];
    }
    if (sem)
    {
        dispatch_release(sem);
    }
    [super dealloc];
}

- (void) process:(NSURL *)url
{
    dispatch_queue_t queue = dispatch_get_global_queue(
                                                       DISPATCH_QUEUE_PRIORITY_HIGH,
                                                       0);
    
    fileReaderChannel =
    dispatch_io_create_with_path(DISPATCH_IO_STREAM,
                                 [[url path] UTF8String],
                                 O_RDONLY,
                                 0,
                                 queue,
                                 ^(int error) {
                                     if (error)
                                     {
                                         printf ("Error occured in FileReader Dispatch IO: %d\n",
                                                 error);
                                     }
                                     
                                     // Cleanup code for normal channel operation.
                                     // Assumes that dispatch_io_close was called elsewhere.
                                     if (error == 0)
                                     {
                                         dispatch_release (self->fileReaderChannel);
                                         self->fileReaderChannel = NULL;
                                     }
                                 });
    
    if (fileReaderChannel != NULL)
    {
        
        dispatch_io_read(fileReaderChannel, 0, SIZE_MAX, queue,
                         ^(bool done, dispatch_data_t data, int error) {
                             
                             if (data)
                             {
                                 // handle data received async
                                 dispatch_data_apply(data,
                                                     (dispatch_data_applier_t)
                                                     ^(dispatch_data_t region,
                                                       size_t offset,
                                                       const void * buffer,
                                                       size_t size) {
                                                         CC_SHA1_Update(&ctx,
                                                                        buffer,
                                                                        (CC_LONG)size);
                                                         
                                                         bytesRead += size;
                                                         
                                                         return true;
                                                     });

                             if (done)
                             {
                                 CC_SHA1_Final(md, &ctx);
                                 
                                 [self->messageDigest appendBytes:(const void
                                                                   *)md
                                                           length:sizeof (md)
                                  / sizeof (uint8_t)];
                                 
                                 dispatch_io_close (fileReaderChannel, 0);
                                 
                                 dispatch_semaphore_signal (sem);
                             }
                             
                             if (error)
                             {
                                 printf (
                                         "Error occured in dispatch IO Read: %d\n",
                                         error);
                                 
                                 dispatch_io_close (fileReaderChannel,
                                                    DISPATCH_IO_STOP);
                                 
                                 dispatch_semaphore_signal (sem);
                                 
                             }
                             }
                         });
        
        dispatch_semaphore_wait (sem, DISPATCH_TIME_FOREVER);
    }

}

@end
