#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>

#include <dlfcn.h>

#include <notify.h>

#import <CoreFoundation/CoreFoundation.h>
//#import <GraphicsServices/GraphicsServices.h>
#import "GSEvent.h"

static const char *ufsQuit = "com.uroboro.notify.quit";
static const char *ufsOpen = "com.uroboro.notify.open";
static const char *ufsHome = "com.uroboro.notify.home";
static const char *ufsSleep = "com.uroboro.notify.sleep";

static const char *notiFile = "/User/app2open.txt";

int launchApp(const char *cIdentifier);
void sendHomeButtonEvent(void);
void sendSleepButtonEvent(void);

char *readIdentifierFromFile(const char *path);

int registerNotification(const char *notification, int *nf, int *token);

int main(int argc, char **argv) {
//for (int i=0;i<argc;i++){printf("%s ",argv[i]);}printf("\n");
	if (argc > 1) {
		uint32_t r = notify_post(argv[1]);
		fprintf(stdout, "%sposted\n", (r)?"not ":"");
		return 0;
	}

	int nf = 0, t = 0, status = 0, qtoken = 0, otoken = 0, htoken = 0, stoken = 0;
	fd_set readfds;

	//register for quitting notification
	if (registerNotification(ufsQuit, &nf, &qtoken) != NOTIFY_STATUS_OK) {
		return 1;
	}
	//register for opening notification
	if (registerNotification(ufsOpen, &nf, &qtoken) != NOTIFY_STATUS_OK) {
		return 1;
	}
	//register for home button notification
	if (registerNotification(ufsHome, &nf, &qtoken) != NOTIFY_STATUS_OK) {
		return 1;
	}
	//register for sleep button notification
	if (registerNotification(ufsSleep, &nf, &qtoken) != NOTIFY_STATUS_OK) {
		return 1;
	}

//	printf("fd is %d\n", nf);
	FD_ZERO(&readfds);
	FD_SET(nf, &readfds);

	char shouldContinue = 1;
	while (shouldContinue) {
		status = select(nf+1, &readfds, NULL, NULL, NULL);
		if (status <= 0) continue;
		if (!FD_ISSET(nf, &readfds)) continue;
		status = read(nf, &t, sizeof(int));
		if (status < 0) {
			perror("read");
			break;
		}

		//notify_register_file_descriptor uses big endian to write to files, so this flips the token to little endian
		t = (((t >> 24) & 0xff) <<  0) +
			(((t >> 16) & 0xff) <<  8) +
			(((t >>  8) & 0xff) << 16) +
			(((t >>  0) & 0xff) << 24);

		char *s;
		int size, wsize;
//		size = asprintf(&s, "read %d;\t", t);
//		wsize = write(STDOUT_FILENO, s, size);

		if (t == qtoken) {
			shouldContinue = 0;
		}

		if (t == otoken) {
//			size = asprintf(&s, "open\n", t);
//			wsize = write(STDOUT_FILENO, s, size);
			char *identifier = readIdentifierFromFile(notiFile);
			size = asprintf(&s, "read %s\n", identifier);
			wsize = write(STDOUT_FILENO, s, size);
			free(s);
			int p = (identifier)?launchApp(identifier):0;
			if (p) {
				size = asprintf(&s, "launched %s\n", identifier);
				wsize = write(STDOUT_FILENO, s, size);
				free(s);
			}
			free(identifier);
		}

		if (t == htoken) {
//			size = asprintf(&s, "home\n", t);
//			wsize = write(STDOUT_FILENO, s, size);
//			free(s);
			sendHomeButtonEvent();
		}

		if (t == stoken) {
//			size = asprintf(&s, "sleep\n", t);
//			wsize = write(STDOUT_FILENO, s, size);
//			free(s);
			sendSleepButtonEvent();
		}
	}

	printf("shutting down\n");
	notify_cancel(qtoken);
	notify_cancel(otoken);
	notify_cancel(htoken);
	notify_cancel(stoken);
	return 0;
}

int launchApp(const char *cIdentifier) {
	void *sbServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
	int (*SBSLaunchApplicationWithIdentifier)(CFStringRef identifier, Boolean suspended) = dlsym(sbServices, "SBSLaunchApplicationWithIdentifier");
	CFStringRef identifier = CFStringCreateWithCString(kCFAllocatorDefault, cIdentifier, CFStringGetSystemEncoding());
	int r = SBSLaunchApplicationWithIdentifier(identifier, false);
	CFRelease(identifier);
	dlclose(sbServices);
	return r;
}

void sendHomeButtonEvent(void) {
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventMenuButtonDown;
	GSSendSystemEvent(&record);
//	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventMenuButtonUp;
	GSSendSystemEvent(&record);
}

void sendSleepButtonEvent(void) {
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventLockButtonDown;
	GSSendSystemEvent(&record);
//	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventLockButtonUp;
	GSSendSystemEvent(&record);
}

char *readIdentifierFromFile(const char *path) {
	static char identifier[1<<8];
	FILE *fp = fopen(path, "r");
	if (fp == NULL) {
		return NULL;
	}
	int s = fscanf(fp, "%s\n", identifier);
	fclose(fp);
	return (s == -1)? NULL:identifier;
}

int registerNotification(const char *notification, int *nf, int *token) {
	uint32_t status = notify_register_file_descriptor(notification, nf, NOTIFY_REUSE, token);
	if (status != NOTIFY_STATUS_OK) {
		fprintf(stderr, "registration failed (%u)\n", status);
	} else {
		fprintf(stdout, "registered %s with %d token\n", notification, *token);
	}
	return status;
}
