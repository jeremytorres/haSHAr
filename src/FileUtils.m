//
//  FileUtils.m
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

#import "FileUtils.h"
#import "DDLog.h"

#define DIGEST_EXTENSION_BASE_STRING        "sha1"
#define DIGEST_EXTENSION_STRING             ".sha1"

// Set logger level
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation FileUtils

+ (NSArray *) retrieveFilesForDirectory:(NSString *)directory
                         fileExtensions:(NSArray *)fileExtensions
{
    NSMutableArray * files;
    NSString * regularExpressionString;
    NSPredicate * regExPredicate;
    NSFileManager * fileManager;

    BOOL checkFileExt = fileExtensions == nil ? NO : YES;

    NSURL * directoryURL = [NSURL fileURLWithPath:directory];

    NSArray * keys = [NSArray arrayWithObjects:
                      NSURLIsDirectoryKey, NSURLIsRegularFileKey,
                      NSURLLocalizedNameKey, nil];

    fileManager = [NSFileManager new];
    
    NSDirectoryEnumerator * enumerator =
        [fileManager enumeratorAtURL:directoryURL
          includingPropertiesForKeys:keys
                             options:(
             NSDirectoryEnumerationSkipsPackageDescendants |
             NSDirectoryEnumerationSkipsHiddenFiles)
                        errorHandler:^(NSURL * url, NSError * error) {
             // Return YES if the enumeration should continue after the error.
             NSLog (@"Error reading directory at %@\n%@", directoryURL,
                    [error localizedFailureReason]);
             // return NO so enumeration does not continue
             return NO;
         }];

    if (checkFileExt)
    {
        regularExpressionString = @"^.+\\.(";

        // add initial regex
        int cnt = 0;
        for (NSString * fileExtension in fileExtensions)
        {
            if (cnt > 0)
            {
                regularExpressionString =
                    [regularExpressionString stringByAppendingString:@"|"];
            }

            // append the or
            regularExpressionString =
                [regularExpressionString stringByAppendingString:@"("];
            regularExpressionString =
                [regularExpressionString stringByAppendingString:fileExtension];
            regularExpressionString =
                [regularExpressionString stringByAppendingString:@")"];

            cnt++;
        }

        regularExpressionString =
            [regularExpressionString stringByAppendingString:@")$"];

#ifdef DEBUGPRINT
        NSLog (@"Regular expression string: %@", regularExpressionString);
#endif

        regExPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
                                      regularExpressionString];
    }

    files = [NSMutableArray new];

    for (NSURL * url in enumerator)
    {
        NSNumber * isFile = nil;
        [url getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:NULL];

        // only process files (less .sha1 digest files), ignoring directory
        // names
        if ([isFile boolValue] &&
            ![[[[url relativePath] pathExtension] lowercaseString]
              isEqualToString:@DIGEST_EXTENSION_BASE_STRING])
        {

            NSString * localizedName = nil;
            [url getResourceValue:&localizedName
                           forKey:NSURLLocalizedNameKey
                            error:NULL];

            if (checkFileExt)
            {
                BOOL isMatch =
                    [regExPredicate evaluateWithObject:localizedName];

                if (isMatch)
                {
                    [files addObject:url];
                }
            }
            else
            {
                [files addObject:url];
            }
        }
    }

    [fileManager release];

    return [files autorelease];
}

+ (NSData *) readMessageDigestFromURL:(NSURL *)targetFileURL
{
    NSMutableData * digestBytes;
    NSError * error;

    // sidecar file assumed to have .sha1 ext

    NSURL * parentDir = [targetFileURL URLByDeletingLastPathComponent];

    NSString * sideCarFileName = [[targetFileURL lastPathComponent]
                                  stringByAddingPercentEscapesUsingEncoding:(
                                      NSUTF8StringEncoding)];

    NSString * sideCarFileNameWithExt =
        [NSString stringWithFormat:@"%@.%@", sideCarFileName,
         @DIGEST_EXTENSION_BASE_STRING];

    NSURL * sideCarFileURL =
        [NSURL URLWithString:sideCarFileNameWithExt relativeToURL:parentDir];

    NSString * fileDigestHexStr =
        [NSString stringWithContentsOfURL:sideCarFileURL
                                 encoding:NSUTF8StringEncoding
                                    error:&error];
    
    if (fileDigestHexStr != nil)
    {
#ifdef DEBUGPRINT
        NSLog(@"Hex String from file: %@", fileDigestHexStr);
#endif

        NSUInteger fileDigestLen = [fileDigestHexStr length];
        digestBytes = [NSMutableData new];
        unsigned char wholeByte;
        char byteChars[3] = { '\0', '\0', '\0' };
        int i;
#ifdef DEBUGPRINT
        printf("Digest from file: [ ");
#endif
        for (i = 0; i < fileDigestLen / 2; i++)
        {
            // TODO perform error check on i*2 and i*2+1
            byteChars[0] = [fileDigestHexStr characterAtIndex:i * 2];
            byteChars[1] = [fileDigestHexStr characterAtIndex:i * 2 + 1];
            wholeByte = strtoul(byteChars, NULL, 16);
            [digestBytes appendBytes:&wholeByte length:1];
#ifdef DEBUGPRINT
            printf("%02X", wholeByte);
#endif
        }
#ifdef DEBUGPRINT
        printf(" ]\n");
#endif

    }
//#ifdef DEBUGPRINT
    else
    {
        // an error occurred.  File most likely does not exist
        DDLogError(@"Error reading digest file at: %@ reason: %@\n",
            targetFileURL, [error localizedFailureReason]);
    }
//#endif

    return [digestBytes autorelease];
}

+ (int) writeMessageDigestRelativeToURL:(NSData *)digest 
                                fileURL:(NSURL *)fileURL
{
    int returnCode = 0;
    NSURL * newFileWithExtension;
    NSError * writeError;

    NSString * origFileNameWithExtension = [fileURL lastPathComponent];

    if ( ![[[origFileNameWithExtension pathExtension] lowercaseString]
           isEqualToString:@DIGEST_EXTENSION_BASE_STRING])
    {
        newFileWithExtension =
            [fileURL URLByAppendingPathExtension:@DIGEST_EXTENSION_BASE_STRING];
    }

    // convert digest to hex for writing to file
    NSMutableString * hex = [NSMutableString string];

    const unsigned char * rawDigest = (const unsigned char *)[digest bytes];
    
    NSUInteger rawDigestLen = [digest length];
    
    for (int i = 0; i < rawDigestLen; i++)
    {
        [hex appendFormat:@"%02X", rawDigest[i]];   // & 0x00FF];
    }
    
    BOOL success = [hex writeToURL:newFileWithExtension 
                        atomically:NO
                          encoding:NSUTF8StringEncoding
                             error:&writeError];
    if (!success)
    {
        // an error occurred
        NSLog(@"Error writing digestfile at %@.  Failure Reason: %@",
            newFileWithExtension, [writeError localizedFailureReason]);

        returnCode = 1;
    }
#ifdef DEBUGPRINT
    else
    {
        printf("Created MessageDigest file: %s\n",
            [[newFileURL relativeString] UTF8String]);
    }
#endif

    return returnCode;

}

@end
