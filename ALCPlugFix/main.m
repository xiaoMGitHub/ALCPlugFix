//
//  main.m
//  ALCPlugFix
//
//  Created by Oleksandr Stoyevskyy on 11/3/16.
//  Copyright © 2016 Oleksandr Stoyevskyy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AppKit/AppKit.h>


void fixAudio();
NSString *binPrefix;

@protocol DaemonProtocol
- (void)performWork;
@end

@interface NSString (ShellExecution)
- (NSString*)runAsCommand;
@end

@implementation NSString (ShellExecution)

- (NSString*)runAsCommand {
    NSPipe* pipe = [NSPipe pipe];

    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@", self]]];
    [task setStandardOutput:pipe];

    NSFileHandle* file = [pipe fileHandleForReading];
    [task launch];

    return [[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];
}

@end

# pragma mark ALCPlugFix Object Conforms to Protocol

@interface ALCPlugFix : NSObject <DaemonProtocol>
@end;
@implementation ALCPlugFix
- (id)init
{
    self = [super init];
    if (self) {
        // Do here what you needs to be done to start things
        
        // sleep wake
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                               selector: @selector(receiveWakeNote:)
                                                                   name: NSWorkspaceDidWakeNotification object: NULL];
        // screen unlock
        [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                               selector: @selector(receiveWakeNote:)
                                                                   name: @"com.apple.screenIsUnlocked" object: NULL];

    }
    return self;
}


- (void)dealloc
{
    // Do here what needs to be done to shut things down
    //[super dealloc];
}

- (void)performWork
{
    // This method is called periodically to perform some routine work
    NSLog(@"Performing periodical work");
    fixAudio();

}
- (void) receiveWakeNote: (NSNotification*) note
{
    NSLog(@"receiveSleepNote: %@", [note name]);
    NSLog(@"Wake detected");
    fixAudio();
}


@end

# pragma mark Setup the daemon

// Seconds runloop runs before performing work in second.
#define kRunLoopWaitTime 0.0

BOOL keepRunning = TRUE;

void sigHandler(int signo)
{
    NSLog(@"sigHandler: Received signal %d", signo);

    switch (signo) {
        case SIGTERM: keepRunning = FALSE; break; // SIGTERM means we must quit
        default: break;
    }
}

void fixAudio(){
    NSLog(@"Fixing...");
    NSString *output1 = [[binPrefix stringByAppendingString:@"hda-verb 0x18 SET_PIN_WIDGET_CONTROL 0x22"] runAsCommand];
    NSString *output2 = [[binPrefix stringByAppendingString:@"hda-verb 0x21 SET_UNSOLICITED_ENABLE 0x83"] runAsCommand];
}





int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Headphones daemon running!");
        binPrefix = @"";

        signal(SIGHUP, sigHandler);
        signal(SIGTERM, sigHandler);

        ALCPlugFix *task = [[ALCPlugFix alloc] init];

        // Check hda-verb location
        NSFileManager *filemgr;
        filemgr = [[NSFileManager alloc] init];

        if ([filemgr fileExistsAtPath:@"./hda-verb"]){
            // hda-verb at work dir
            NSLog(@"Found had-verb in work dir");
            binPrefix = [filemgr.currentDirectoryPath stringByAppendingString:@"/"];
        }else
            NSLog(@"Current Directory %@", filemgr.currentDirectoryPath);

        fixAudio();

        // Audio Listener setup
        AudioDeviceID defaultDevice = 0;
        UInt32 defaultSize = sizeof(AudioDeviceID);

        const AudioObjectPropertyAddress defaultAddr = {
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMaster
        };


        AudioObjectPropertyAddress sourceAddr;
        sourceAddr.mSelector = kAudioDevicePropertyDataSource;
        sourceAddr.mScope = kAudioDevicePropertyScopeOutput;
        sourceAddr.mElement = kAudioObjectPropertyElementMaster;

        OSStatus osStatus;

        do {
            AudioObjectGetPropertyData(kAudioObjectSystemObject, &defaultAddr, 0, NULL, &defaultSize, &defaultDevice);

            osStatus = AudioObjectAddPropertyListenerBlock(defaultDevice, &sourceAddr, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
                // Audio device have changed
                NSLog(@"Audio device changed!");
                fixAudio();
            });


            if (osStatus != 0){
                NSLog(@"ERROR: Something went wrong! Failed to add Audio Listener!");
                NSLog(@"OS Status: %d",osStatus);
                NSLog(@"Waiting 15 second...");
                sleep(15);
            } else
                NSLog(@"Correctly added Audio Listener!");

        }while(osStatus!=0);

//        while (keepRunning) {
//            [task performWork];
//            CFRunLoopRunInMode(kCFRunLoopDefaultMode, kRunLoopWaitTime, false);
//        }
//        [task release];


        NSLog(@"Daemon exiting");
    }
    return 0;
}
