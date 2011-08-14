//
//  haSHAr.m
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

#import "haSHAr.h"
#import "FileUtils.h"
#import "FailedDigest.h"
#import "AsyncFileIoHasher.h"

#import "DDFileLogger.h"
#import "DDTTYLogger.h"

#import "DDLog.h"

#include <CommonCrypto/CommonDigest.h>

// Set logger level
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation haSHAr

@synthesize delegate;
@synthesize printToStdout;

- (id) init
{
    self = [super init];
    if (self)
    {
        // Initialization code here.

        // Logger init
        self->fileLogger = [[DDFileLogger alloc] init];
        self->fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        self->fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        
        [DDLog addLogger:fileLogger];
//        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        
        ioQueue = [[NSOperationQueue alloc] init];
        [ioQueue setName:@"IOQueue"];

        computeQueue = [[NSOperationQueue alloc] init];
        [computeQueue setName:@"ComputeQueue"];

        printQueue = [[NSOperationQueue alloc] init];
        [printQueue setName:@"PrintQueue"];
        [printQueue setMaxConcurrentOperationCount:1]; // limit width
    }
    return self;
}

- (void) dealloc
{
    if (filesSem)
    {
        dispatch_release(filesSem);
    }

    [printQueue dealloc];
    [computeQueue dealloc];
    [ioQueue dealloc];

    [super dealloc];
}

// based on progress meter suggestion by "fvu" of stackoverflow.com
// http://stackoverflow.com/questions/1637587/c-libcurl-console-progress-bar
inline static void do_progress_bar(double totalFileCnt, double curFileCnt)
{
    // how wide you want the progress meter to be
    int totaldotz = 40;
    double fractiondownloaded = curFileCnt / totalFileCnt;
    // part of the progressmeter that's already "full"
    int dotz = round(fractiondownloaded * totaldotz);

    // create the "meter"
    int ii = 0;

    printf("%3.0f%% (%3.0f/%3.0f) [", fractiondownloaded * 100, curFileCnt,
        totalFileCnt);
    // part that's full already
    for (; ii < dotz; ii++)
    {
        printf("=");
    }
    // remaining part (spaces)
    for (; ii < totaldotz; ii++)
    {
        printf(" ");
    }

    if (curFileCnt == totalFileCnt)
    {
        // last ... ensure we move to the next line
        printf("]\n");
    }
    else
    {
        // and back to line begin - do not forget the fflush to avoid output
        // buffering problems!
        printf("]\r");
    }
    fflush(stdout);
}

inline static FailedDigest * handleFailedDigest(NSURL * fileURL,
    NSData *                                            fileDataHash,
    NSData *                                            sideCarHash)
{
    FailedDigest * failedDigest = [[FailedDigest alloc] init];

    failedDigest.fileURL = fileURL;
    failedDigest.currentHash = fileDataHash;
    failedDigest.previousHash = sideCarHash;

    return [failedDigest autorelease];
}

static void performDigestVerification(NSURL * fileURL, NSData * fileDataHash,
    NSData * sideCarHash, NSMutableArray * failedDigests)
{
    if (fileDataHash != nil && sideCarHash != nil)
    {
        NSUInteger fileDataHashLen;
        NSUInteger sideCarHashLen;

        fileDataHashLen = [fileDataHash length];
        sideCarHashLen = [sideCarHash length];

        // Failure conditions:
        //    a. The message digest is NULL
        //    b. The message digest length is 0
        //    c. The message digest length > EVP_MAX_MD_SIZE
        if (fileDataHashLen <= CC_SHA1_DIGEST_LENGTH &&
            sideCarHashLen <= CC_SHA1_DIGEST_LENGTH)
        {

            if (![fileDataHash isEqualToData:sideCarHash])
            {

#ifdef DEBUGPRINT
                printf("Digests are NOT EQUAL for %s\n",
                       [[fileURL path] UTF8String]);
#endif
                FailedDigest * failedDigest =
                    handleFailedDigest(fileURL, fileDataHash, sideCarHash);
                [failedDigests addObject:failedDigest];

            }
    #ifdef DEBUGPRINT
            else
            {

                printf("Digests are equal for %s\n",
                       [[fileURL path] UTF8String]);
            }
    #endif

        }
#ifdef DEBUGPRINT
        else
        {
            NSLog(@"Invalid hashes to compare!");
        }
#endif
    }
    else if (fileDataHash != nil && sideCarHash == nil)
    {
        DDLogCWarn(@"File %@ does not have a side car hash\n", fileURL);
    }
}

- (NSArray *) verifyMessageDigests:(NSArray *)URLs numfiles:(unsigned int)
   numfiles
{
    DDLogInfo(@"");
    // how many files being processed concurrently
    filesSem = dispatch_semaphore_create(numfiles);

    [ioQueue setMaxConcurrentOperationCount:numfiles]; // limit width

    NSMutableArray * failedDigests = [[NSMutableArray alloc] init];
    NSUInteger totalFileCnt = [URLs count];
    __block int curFileCnt = 0;

    for (NSURL * URL in URLs)
    {
        // set by computeOperation
        __block NSData * messageDigest = nil;
        // set by readDigestSidecarFileOperation
        __block NSData * digestFromSideCarFile = nil;

        // Create operations to do the work for this URL

        NSBlockOperation * readAndComputeOperation =
            [NSBlockOperation blockOperationWithBlock:^{

                 AsyncFileIoHasher * hashar = [AsyncFileIoHasher new];

                 // file will be processed asyncronously, but we block
                 // until hash has been computed!
                 [hashar process:URL];

                 messageDigest = [[hashar messageDigest] retain];

                 [hashar release];

                 // increment semaphore to continue processing
                 dispatch_semaphore_signal (filesSem);
             }];

        NSBlockOperation * readDigestSideCarFileOperation =
            [NSBlockOperation blockOperationWithBlock:^{
                 digestFromSideCarFile =
                     [[FileUtils readMessageDigestFromURL:URL] retain];
             }];

        NSBlockOperation * computeOperation =
            [NSBlockOperation blockOperationWithBlock:^{
                 performDigestVerification (URL, messageDigest,
                                            digestFromSideCarFile,
                                            failedDigests);

                 [messageDigest release];
                 [digestFromSideCarFile release];
             }];

        NSBlockOperation * printOperation =
            [NSBlockOperation blockOperationWithBlock:^{
                if (printToStdout)
                {
                    do_progress_bar (totalFileCnt, ++curFileCnt);
                }
                
                // notify the delegate the file has been processed
                if ([self->delegate respondsToSelector:@selector(processedFile:)])
                {
                    [self->delegate processedFile:URL];
                }
#ifdef DEBUGPRINT                
                else
                {
                    // DEBUG only
                    printf("Delegate does not respond to selector:  delegate is nil: %d\n", delegate == nil);
                }
#endif                
             }];

//        [printOperation setQueuePriority:NSOperationQueuePriorityHigh];

        // Set up dependencies between operations

        [readDigestSideCarFileOperation addDependency:readAndComputeOperation];
        [computeOperation addDependency:readAndComputeOperation];
        [computeOperation addDependency:readDigestSideCarFileOperation];
        [printOperation addDependency:computeOperation];

        // Add operations to appropriate queues

        [ioQueue addOperation:readAndComputeOperation];
        [computeQueue addOperation:computeOperation];
        [ioQueue addOperation:readDigestSideCarFileOperation];
        [printQueue addOperation:printOperation];
    }

    [printQueue waitUntilAllOperationsAreFinished];

    return [failedDigests autorelease];
}

- (void) generateMessageDigests:(NSArray *)URLs numfiles:(unsigned int)numfiles
{
    // how many files being processed concurrently
    filesSem = dispatch_semaphore_create(numfiles);

    [ioQueue setMaxConcurrentOperationCount:numfiles]; // limit width

    NSUInteger totalFileCnt = [URLs count];
    __block int curFileCnt = 0;

    for (NSURL * URL in URLs)
    {
        // check if we're cancelled
        if (isCancelled)
        {
            return;
        }

        if (!dispatch_semaphore_wait(filesSem, DISPATCH_TIME_FOREVER))
        {
            // check

            // set by computeOperation
            __block NSData * messageDigest = nil;

            // Create operations to do the work for this URL

            NSBlockOperation * readAndComputeOperation =
                [NSBlockOperation blockOperationWithBlock:^{
                    
                     AsyncFileIoHasher * hashar = [AsyncFileIoHasher new];
                    
                     // file will be processed asyncronously, but we block
                     // until hash has been computed!
                     [hashar process:URL];

                     messageDigest = [[hashar messageDigest] retain];

                     [hashar release];

                     // increment semaphore to continue processing
                     dispatch_semaphore_signal (filesSem);
                 }];

            NSBlockOperation * writeOperation =
                [NSBlockOperation blockOperationWithBlock:^{
                     [FileUtils writeMessageDigestRelativeToURL:messageDigest
                                                        fileURL:URL];
                     [messageDigest release]; // created in computeOperation
                 }];

            // assume write operation has highest priority
            [writeOperation setQueuePriority:NSOperationQueuePriorityHigh];

            NSBlockOperation * printOperation =
                [NSBlockOperation blockOperationWithBlock:^{
                    if (printToStdout)
                    {
                        do_progress_bar (totalFileCnt, ++curFileCnt);
                    }
                    
                    // notify the delegate the file has been processed
                    if ([self->delegate respondsToSelector:@selector(processedFile:)])
                    {
                        [self->delegate processedFile:URL];
                    }
#ifdef DEBUGPRINT                
                    else
                    {
                        // DEBUG only
                        printf("Delegate does not respond to selector:  delegate is nil: %d\n", delegate == nil);
                    }
#endif            
                 }];

            // Set up dependencies between operations

            [writeOperation addDependency:readAndComputeOperation];
            [printOperation addDependency:writeOperation];

            // Add operations to appropriate queues

            [computeQueue addOperation:readAndComputeOperation];
            [ioQueue addOperation:writeOperation];
            [printQueue addOperation:printOperation];

        }
    }

    [printQueue waitUntilAllOperationsAreFinished];
}

// TODO provide max wait as param to cancel method
-(void)cancel
{
    static int waitSecs = 1;
    int maxWaitIntervals = 5;
    
    isCancelled = TRUE;
    
    // cancel the operations in queues
    [ioQueue cancelAllOperations];
    [computeQueue cancelAllOperations];
    [printQueue cancelAllOperations];
    
    // ensure all queues are empty
    NSArray * queues = [NSArray arrayWithObjects:ioQueue, computeQueue,
                        printQueue, nil];
    
    while (maxWaitIntervals > 0)
    {
        int queuesWithOps = 0;
        for (NSOperationQueue * queue in queues)
        {
            if ([queue operationCount] > 0)
            {
                queuesWithOps++;
            }
        }
        
        if (queuesWithOps > 0)
        {
            // debug
            printf("%d queues have remaininng operations\n", queuesWithOps);
            
            sleep(waitSecs);
            maxWaitIntervals--;
        }
        else
        {
            break;
        }
    }
}

@end
