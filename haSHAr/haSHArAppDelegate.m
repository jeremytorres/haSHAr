//
//  haSHArAppDelegate.m
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

#import "haSHArAppDelegate.h"
#import "FileUtils.h"

@implementation haSHArAppDelegate

@synthesize modeRadioButton;
@synthesize progressInd;
@synthesize cancelButton;
@synthesize pathControl;
@synthesize fileProcessedLabel;
@synthesize outputBox;
@synthesize selectDirectoryButton;
@synthesize startButton;
@synthesize window;

-(void)initHashar
{
    hashar = [haSHAr new];
    [hashar setDelegate:self];
    [hashar setPrintToStdout:FALSE];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    processedFileCnt = 0;
    
    // setup queues
    processQueue = [NSOperationQueue new];
    [processQueue setName:@"ProcessQueue"];
    
    // instantiate haSHAr API
    [self initHashar];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // cleanup
    
    [directoryToProcess release];
    [hashar release];
    [processQueue release];
    
    NSLog(@"Application quitting");
}

- (IBAction)selectDirectory:(id)sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    
    [panel setDelegate:self];
    
    // allow only directories to be chosen
    [panel setCanChooseFiles:FALSE];
    [panel setCanChooseDirectories:TRUE];
    
    // set panel to open to user's home dir
    [panel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    
    [panel beginSheetModalForWindow:window
                  completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            // selection is made
            [panel setDelegate:nil];
            NSLog(@"Selection is made");
        }
        else if (result == NSFileHandlingPanelCancelButton)
        {
            NSLog(@"Cancelled directory selection");
        }
    }];
}

-(void)fileProcessingComplete
{
    [fileURLs release];
    fileURLs = nil;
    
    [fileExts release];
    fileExts = nil;
    
    [outputBox setHidden:TRUE];
    [startButton setEnabled:TRUE];
    [cancelButton setEnabled:FALSE];
    [selectDirectoryButton setEnabled:TRUE];
    [modeRadioButton setEnabled:TRUE];
    processedFileCnt = 0;
}

- (IBAction)startProcessing:(id)sender
{
    // disable start button
    [startButton setEnabled:FALSE];
    
    // disable radio buttons
    [modeRadioButton setEnabled:FALSE];
    
    // disable select directory button
    [selectDirectoryButton setEnabled:FALSE];
    
    // get selected mode
    NSButtonCell * selCell = [modeRadioButton selectedCell];

    NSUInteger mode = [selCell tag];
    
    // disable directory chooser
    [selectDirectoryButton setEnabled:FALSE];
    
    // show and enable cancel button
    [cancelButton setHidden:FALSE];
    [cancelButton setEnabled:TRUE];
    
    [outputBox setHidden:FALSE];
    
    // set progress indicator to nondeterministic until we have all file URLs
    [progressInd setIndeterminate:TRUE];
    [progressInd displayIfNeeded];
    
    // TODO get file extensions from UI
    fileExts = [[NSArray arrayWithObjects:@"NEF", nil] retain];
    
    // get files from chosen directory
    fileURLs = [[FileUtils retrieveFilesForDirectory:[directoryToProcess path]
                                      fileExtensions:fileExts] retain];
    
    if (fileURLs != nil)
    {
        // set progress indicator to deterministic and max value
        [progressInd setIndeterminate:FALSE];
        [progressInd setMaxValue:[fileURLs count]];
        [progressInd displayIfNeeded];
        
        // create block operation to be placed on queue
        NSBlockOperation * processFilesOperation =
        [NSBlockOperation blockOperationWithBlock:^{
            // start processing files
            switch (mode)
            {
                case GENERATE_BUTTON_TAG_VAL:
                    // TODO get num of files to process from app preferences
                    [hashar generateMessageDigests:fileURLs numfiles:1];
                    break;
                case VERIFY_BUTTON_TAG_VAL:
                    // TODO get num of files to process from app preference
                    [hashar verifyMessageDigests:fileURLs numfiles:1];
                    break;
                default:
                    NSLog(@"Error: invalid mode %lu\n", mode);
            }
            
            // set file processing complete
            [self fileProcessingComplete];
        }];
        
        [processQueue addOperation:processFilesOperation];
    }
    else
    {
        // TODO show error sheet
    }
}

- (IBAction)cancelProcessing:(id)sender
{
    [fileProcessedLabel setStringValue:@"Cancelling..."];
    
    [processQueue cancelAllOperations];
    
    [hashar cancel];
    
    [hashar release];
    
    [self initHashar];
    
    [fileProcessedLabel setStringValue:@"Cancelled"];
    
    [self fileProcessingComplete];
    
}

- (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url
{
    NSLog(@"Changed to URL %@?", url);
    
}
- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
    NSLog(@"Validate URL %@", url);
    
    // assuming file is directory, per NSPanel config, but check for nil
    if (url != nil)
    {
        // release previous directory
        if (directoryToProcess != nil)
        {
            [directoryToProcess release];
            directoryToProcess = nil;
        }
        
        directoryToProcess = [url retain];
        
        // set path control

        [pathControl setURL:directoryToProcess];
        [pathControl setEnabled:TRUE];
        [pathControl setHidden:FALSE];
        [pathControl displayIfNeeded];
        
        // enable start button
        [startButton setHidden:FALSE];
        [startButton setEnabled:TRUE];
        
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

// haSHAr delegate
-(void)processedFile:(NSURL *)url
{
    [fileProcessedLabel setStringValue:[url lastPathComponent]];
    [progressInd setDoubleValue:(double)++processedFileCnt];
    [progressInd displayIfNeeded];
}

@end
