//
//  main.m
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

#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

#include <apr_general.h>
#include <apr_getopt.h>

#import "FileUtils.h"
#import "FailedDigest.h"
#import "haSHAr.h"

// command line options and values
#define CLI_LONG_OPTION_MODE                   "mode"
#define CLI_OPTION_CHAR_MODE                   'm'
#define CLI_LONG_OPTION_NUMFILE                "nfile"
#define CLI_OPTION_CHAR_NUMFILE                'n'
#define CLI_LONG_OPTION_DIRECTORY              "directory"
#define CLI_OPTION_CHAR_DIRECTORY              'd'
#define CLI_LONG_OPTION_EXTENSIONS             "extensions"
#define CLI_OPTION_CHAR_EXTENSIONS             'e'
#define CLI_LONG_OPTION_VERSION                "version"
#define CLI_OPTION_CHAR_VERSION                'v'
#define CLI_LONG_OPTION_HELP                   "help"
#define CLI_OPTION_CHAR_HELP                   'h'
#define CLI_MODE_VERIFY                        "v"
#define CLI_MODE_GENERATE                      "g"

#define DEFAULT_CONCURRENT_FILE_PROCESS        3

static const apr_getopt_option_t opt_option[] = {
    // long-option, short-option, has-arg flag, description
    { CLI_LONG_OPTION_MODE,       CLI_OPTION_CHAR_MODE,       TRUE,
      "mode [v]erify|[g]enereate" },
    // -m [v|g] or --mode [v|g]
    { CLI_LONG_OPTION_DIRECTORY,  CLI_OPTION_CHAR_DIRECTORY,  TRUE,
      "directory containing input files" },
    // -d name or --directory name
    { CLI_LONG_OPTION_EXTENSIONS, CLI_OPTION_CHAR_EXTENSIONS, TRUE,
      "comma-separated file extensions in format: txt,PDF,pdf,TXT,..." },
    // -n 3 [default] or --nfile 3 [default]
    { CLI_LONG_OPTION_NUMFILE,    CLI_OPTION_CHAR_NUMFILE,    TRUE,
      "number of files processed concurrently" },
    { CLI_LONG_OPTION_VERSION,    CLI_OPTION_CHAR_VERSION,    FALSE,
      "haSHAr version" },
    // -v or --version
    { CLI_LONG_OPTION_HELP,       CLI_OPTION_CHAR_HELP,       FALSE,
      "show help" },
    // -h or --help
    { NULL,                       0,                          0,
      NULL }
    // end (a.k.a. sentinel)
};

// function prototypes

void      printUsage(void);
void      printVersion(void);
void      showHelp(void);
int       verifyCliOptions(const char * mode, const char * directory);
NSArray * processFileExtensions(char * fileExtsString);
void      cleanup(void);

void printUsage()
{
    int i;

    int size = 5; // sizeof(&opt_option);

    printf("size: %d\n", size);

    printf("Usage: hashar ");
    for (i = 0; i < size; i++)
    {
        if (opt_option[i].name != NULL)
        {
            printf("-%c/--%s \"%s\" %s", opt_option[i].optch,
                opt_option[i].name, opt_option[i].description,
                // mode and directory are only required options
                (strcmp(opt_option[i].name, CLI_LONG_OPTION_MODE) == 0 ||
                 strcmp(opt_option[i].name, CLI_LONG_OPTION_DIRECTORY) == 0
                 ? "REQUIRED" : "optional"));
            printf("\n\t");
        }
    }
    printf("\n");
}

void printVersion()
{
    printf("haSHAr version: %s\n", HASHAR_VERSION_STR);

}

void showHelp()
{
    printf("Help: TODO\n");
}

int verifyCliOptions(const char * mode, const char * directory)
{
    int rc = 0;

    // check existence of mode and verify values
    if (mode == NULL || (strcmp(mode, CLI_MODE_GENERATE) != 0 &&
                         strcmp(mode, CLI_MODE_VERIFY) != 0))
    {
        if (mode == NULL)
        {
            printf("Mode not specified!\n");
        }
        else
        {
            printf("Invalid mode specified: '%s'\n", mode);
        }
        rc = 1;
    }

    if (!rc)
    {
        if (directory == NULL)
        {
            rc = 1;
        }
    }

    return rc;
}

NSArray * processFileExtensions(char * fileExtsString)
{
    NSMutableArray * fileExts = [NSMutableArray new];

    if (fileExtsString != NULL)
    {
        char * pChar;
        pChar = strtok(fileExtsString, ",");
        if (pChar != NULL)
        {
            [fileExts addObject:[NSString stringWithCString:pChar
                                                   encoding:
                                 NSASCIIStringEncoding]];
            while (pChar != NULL)
            {

                pChar = strtok(NULL, ",");
                if (pChar != NULL)
                {
                    [fileExts addObject:[NSString stringWithCString:pChar
                                                           encoding:
                                         NSASCIIStringEncoding]];
                }
            }
        }
    }

    return [fileExts autorelease];
}

// cleanup function called by atexit
void cleanup()
{
    apr_terminate();
}

int main(int argc, const char * argv[])
{

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    apr_status_t rv;
    apr_pool_t * mp;
    apr_getopt_t * opt;
    int optch;
    const char * optarg;

    // ensure cleanup function is invoked upon program exit
    atexit(&cleanup);

    apr_initialize();
    apr_pool_create(&mp, NULL);

    /* initialize apr_getopt_t */
    apr_getopt_init(&opt, mp, argc, argv);

    const char * mode = NULL;
    const char * directory = NULL;
    const char * extensions = NULL;
    const char * numfiles = NULL;
    int rc;

    /* parse the all options based on opt_option[] */
    while ((rv =
                apr_getopt_long(opt, opt_option, &optch,
                    &optarg)) == APR_SUCCESS)
    {
        switch (optch)
        {
            case 'm':
#ifdef DEBUGPRINT
                printf("opt=m, %s\n", optarg);
#endif
                mode = optarg;
                break;
            case 'd':
#ifdef DEBUGPRINT
                printf("opt=d, %s\n", optarg);
#endif
                directory = optarg;
                break;
            case 'e':
#ifdef DEBUGPRINT
                printf("opt=e, %s\n", optarg);
#endif
                extensions = optarg;
                break;
            case 'v':
#ifdef DEBUGPRINT
                printf("show version\n"); /* no arg*/
#endif
                printVersion();
                break;
            case 'h':
#ifdef DEBUGPRINT
                printf("show help\n");  /* no arg */
#endif
                showHelp();
                break;
            case 'n':
#ifdef DEBUGPRINT
                printf("opt=n, %s\n", optarg);
#endif
                numfiles = optarg;
                break;
            default:
                printf("Invalid argument: %c\n", optch);
                printUsage();
        }
    }
    if (rv != APR_EOF)
    {
        printf("Invalid options\n");
        printUsage();
        return 1;
    }

    // ensure all required options are present and valid
    rc = verifyCliOptions(mode, directory);

    if (rc)
    {
        // failure...invalid mode and/or directory
        printUsage();
        return 1;
    }

    // determine number of concurrent files to process
    int nf = DEFAULT_CONCURRENT_FILE_PROCESS;
    if (numfiles != NULL)
    {
        nf = atoi(numfiles);
        if (nf <= 0 || nf == INT_MAX )
        {
            printf("Error: %d is invalid number.  Defaulting to %d\n", nf,
                DEFAULT_CONCURRENT_FILE_PROCESS);
            nf = DEFAULT_CONCURRENT_FILE_PROCESS;
        }
        else
        {
            printf("Will process %d file(s) concurrently\n", nf);
        }
    }

    // process file extensions

    NSArray * fileExtsArray = processFileExtensions((char *)extensions);

    NSArray * filesInDir =
        [FileUtils retrieveFilesForDirectory:[NSString stringWithCString:
                                              directory
                                                                encoding:
                                              NSASCIIStringEncoding]
                              fileExtensions:fileExtsArray];

    if (filesInDir == nil)
    {
        printf("Error: no files in directory %s.  Aborting."
            "  Using file extension filter=%s",
            directory,
            extensions == NULL ? "" : extensions);
        if (fileExtsArray != nil)
        {

            int cnt = 1;
            for (NSString * fileExt in fileExtsArray)
            {
                printf("%s",
                    [fileExt cStringUsingEncoding:NSASCIIStringEncoding]);
                if (cnt++ < [fileExtsArray count])
                {
                    printf(",");
                }
            }
            printf("\n");
            return 1;
        }

    }

    // invoke the hashar API

    haSHAr * hashar = [haSHAr new];
    [hashar setPrintToStdout:TRUE];

    uint64_t start;
    uint64_t end;
    uint64_t elapsed;
    Nanoseconds elapsedNano;

    // Start the clock
    start = mach_absolute_time();

    if (strcmp(mode, CLI_MODE_GENERATE) == 0)
    {
        printf("*** %s version %s ***\nExecuting digest generation on %lu "
            "file(s) in directory %s\n",
            HASHAR_PROGRAM_NAME_STR,
            HASHAR_VERSION_STR,
            [filesInDir count],
            directory);

        // generate message digests for files in directory
        [hashar generateMessageDigests:filesInDir numfiles:nf];
    }
    else
    {
        printf("*** %s version %s ***\nExecuting digest verification on %lu "
            "file(s) of directory %s\n",
            HASHAR_PROGRAM_NAME_STR,
            HASHAR_VERSION_STR,
            [filesInDir count],
            directory);

        NSArray * failedDigests =
            [[hashar verifyMessageDigests:filesInDir numfiles:nf] retain];

        if (failedDigests != nil && [failedDigests count] > 0)
        {
            printf("\nThe following files FAILED digest verification:\n");
            for (FailedDigest * failedDigest in failedDigests)
            {
                printf("--> %s <--\n",
                    [[failedDigest.fileURL relativePath] cStringUsingEncoding:
                     NSASCIIStringEncoding]);

                [failedDigest release];
            }
            printf("\n");
        }
        else
        {
            printf("Success.  All file(s) with existing message digest have "
                "been verified.\n");
        }

        [failedDigests release];
    }

    [hashar release];

    // Stop the clock
    end = mach_absolute_time();

    // Calculate the duration.
    elapsed = end - start;

    // Convert to nanoseconds.

    // AbsoluteToNanoseconds is a struct of hi/lo UInt32.  Convert
    // elapsed time (64-bit) into this struct.
    UnsignedWide tmp;
    tmp.hi = (UInt32)(elapsed >> 32);
    tmp.lo = (UInt32)(elapsed & 0xFFFFFFFF);

    elapsedNano = AbsoluteToNanoseconds(tmp);

    // print out stats
    uint64_t elapsedNanos = *(uint64_t *)&elapsedNano;

    Float64 seconds = elapsedNanos / 1000000000.0;
    Float64 minutes =  seconds / 60.0;
    Float64 hours = minutes / 60.0;

    printf("\nElapased Time: Hours: %3.2F Minutes: %3.2F Seconds: %3.2F\n",
        (hours < 1.0 ? 0.0 : hours), (minutes < 1.0 ? 0.0 : minutes),
        seconds);
    fflush(stdout);

    [pool drain];

    return 0;
}
