#include <dlfcn.h>
#include <notify.h>
#include <stdio.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>

static int tokenAction;
static int tokenExit;

@interface UFSDaemon : NSObject {
}

- (void)timerFireMethod:(NSTimer *)timer;
- (int)openAppWithIdentifier:(NSString *)identifier;
@end

@implementation UFSDaemon

- (void)timerFireMethod:(NSTimer *)timer {
	[timer invalidate];

	int status, check;
	static char first = 0;
	if (!first) {
		status = notify_register_check("com.uroboro.notification.exit", &tokenExit);
		if (status != NOTIFY_STATUS_OK) {
			fprintf(stderr, "registration failed (%u)\n", status);
			return;
		}

		status = notify_register_check("com.uroboro.notification.action", &tokenAction);
		if (status != NOTIFY_STATUS_OK) {
			fprintf(stderr, "registration failed (%u)\n", status);
			return;
		}

		first = 1;
	}

	status = notify_check(tokenExit, &check);
	if (status == NOTIFY_STATUS_OK && check != 0) {
		fprintf(stdout, "exit received (%u)\n", status);
		//don't start the timer so the process exits
		return;
	}

	status = notify_check(tokenAction, &check);
	if (status == NOTIFY_STATUS_OK && check != 0) {
		fprintf(stdout, "action received (%u)\n", status);
	}

	//start a timer so that the process does not exit.
	timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
		interval:5
		target:self
		selector:@selector(timerFireMethod:)
		userInfo:nil
		repeats:YES];

	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (int)openAppWithIdentifier:(NSString *)identifier {
	// the SpringboardServices.framework private framework can launch apps,
	// so we open it dynamically and find SBSLaunchApplicationWithIdentifier()
/*	void *sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
	int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
	int r = SBSLaunchApplicationWithIdentifier(identifier), false);
	dlclose(sbServices);
	return r;
*/
	return 0;
}

- (void)dealloc {
	notify_cancel(tokenAction);
	notify_cancel(tokenExit);
	[super dealloc];
}

@end

int main(int argc, char **argv, char **envp) {
	NSAutoreleasePool * pool = [NSAutoreleasePool new];

	//initialize our daemon
	UFSDaemon *daemon = [UFSDaemon new];

	//start a timer so that the process does not exit.
	NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
		interval:0.01
		target:daemon
		selector:@selector(timerFireMethod:)
		userInfo:nil
		repeats:NO];

	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	[runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
	[runLoop run];

	[daemon release];

	[pool release];
	return 0;
}
