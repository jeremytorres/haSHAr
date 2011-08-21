//
//  haSHArAppDelegate.h
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
#import "haSHAr.h"

#define GENERATE_BUTTON_TAG_VAL 1
#define VERIFY_BUTTON_TAG_VAL   0

@interface haSHArAppDelegate : NSObject <NSApplicationDelegate,
                                         NSOpenSavePanelDelegate,
                                         haSHArDelegate>
{
@private
    NSWindow *window;
    NSMatrix *modeRadioButton;
    NSProgressIndicator *progressInd;
    NSButton *cancelButton;
    NSPathControl *pathControl;
    NSButton *selectDirectoryButton;
    NSButton *startButton;
    haSHAr *hashar;
    NSURL *directoryToProcess;
    NSArray *fileURLs;
    NSArray *fileExts;
    NSUInteger totalFilesToProcess;
    NSUInteger processedFileCnt;
    NSOperationQueue * processQueue;
    NSBox *outputBox;
    NSTextFieldCell *fileProcessedLabel;
    NSTableView *failedDigestsTableView;
}

@property (assign) IBOutlet NSTableView *failedDigestsTableView;
@property (assign) IBOutlet NSTextFieldCell *fileProcessedLabel;
@property (assign) IBOutlet NSBox *outputBox;
@property (assign) IBOutlet NSButton *selectDirectoryButton;
@property (assign) IBOutlet NSButton *startButton;
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSMatrix *modeRadioButton;
@property (assign) IBOutlet NSProgressIndicator *progressInd;
@property (assign) IBOutlet NSButton *cancelButton;
@property (assign) IBOutlet NSPathControl *pathControl;

- (IBAction)selectDirectory:(id)sender;
- (IBAction)findSelectedButton:(id)sender;
- (IBAction)startProcessing:(id)sender;
- (IBAction)cancelProcessing:(id)sender;

// NSOpenSavePanelDelegate
- (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url;
- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError;

// haSHAr delegte
-(void)processedFile:(NSURL *)url;

-(void)fileProcessingComplete;


@end
