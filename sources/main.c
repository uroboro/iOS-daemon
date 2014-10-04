#include <stdio.h> // for: NULL, stderr, stdout, fprintf(), fscanf(), fopen(), fclose()
#include <string.h> // for: strlen()
#include <unistd.h> // for: read(), write(), STDOUT_FILENO, select(), FD_ZERO, FD_SET, FD_ISSET
#include <sys/types.h> // for: uint32_t

#include <dlfcn.h> // for: RTLD_LAZY, dlopen(), dlsym(), dlclose()

#include <notify.h> // for: NOTIFY_REUSE, NOTIFY_STATUS_OK, notify_post(), notify_register_file_descriptor(), notify_cancel()

#include <CoreFoundation/CFString.h>
#include "GSEvent.h" // for: GSEventRecord, GSCurrentEventTimestamp(), GSSendSystemEvent()

typedef struct notificationPair {
	char *name;
	int token;
} notificationPair;

// file read when attempting to open an app. Might look into using sockets to send the string instead
static const char *notiFile = "/User/app2open.txt";

int launchApp(const char *cIdentifier);
void sendHomeButtonEvent(void);
void sendSleepButtonEvent(void);

// saves identifier on a local static variable
char *readIdentifierFromFile(const char *path);

// this function is specific to the purposes of this project, not intended for reusability
uint32_t registerNotification(const char *notification, int *fd, int *token);

int main(int argc, char **argv) {
//for (int i=0;i<argc;i++){printf("%s ",argv[i]);}printf("\n");
	if (argc > 1) {
		uint32_t r = notify_post(argv[1]);
		fprintf(stdout, "%sposted.\n", (r)?"not ":"");
		return 0;
	}

	notificationPair n_pair[] = {
		{"com.uroboro.notify.quit1", 0}, // quitting notification
		{"com.uroboro.notify.open1", 0}, // opening notification
		{"com.uroboro.notify.home1", 0}, // home button notification
		{"com.uroboro.notify.sleep1", 0} // sleep button notification
	};

	int fd;
	for (int i = 0; i < sizeof(n_pair)/sizeof(notificationPair); i++) {
		if (registerNotification(n_pair[i].name, &fd, &n_pair[i].token) != NOTIFY_STATUS_OK) {
			return 1;
		}
	}
	
	fd_set readfds;
	FD_ZERO(&readfds);
	FD_SET(fd, &readfds);

	char shouldContinue = 1;
	while (shouldContinue) {
		int status = select(fd + 1, &readfds, NULL, NULL, NULL);
		if (status <= 0 || !FD_ISSET(fd, &readfds)) {
			continue;
		}

		int t;
		status = read(fd, &t, sizeof(int));
		if (status < 0) {
			break;
		}
		t = ntohl(t); // notify_register_file_descriptor docs: "The value is sent in network byte order."

		// value in file descriptor matches token for quit notification
		if (t == n_pair[0].token) {
			shouldContinue = 0;
		}

		// value in file descriptor matches token for quit notification
		if (t == n_pair[1].token) {
			char *identifier = readIdentifierFromFile(notiFile);

			int p = (identifier)?launchApp(identifier):0;
			p ^= p; //hide unused warning
		}

		// value in file descriptor matches token for home button notification
		if (t == n_pair[2].token) {
			sendHomeButtonEvent();
		}

		// value in file descriptor matches token for sleep button notification
		if (t == n_pair[3].token) {
			sendSleepButtonEvent();
		}
	}

	// cancel
	for (int i = 0; i < sizeof(n_pair)/sizeof(notificationPair); i++) {
		notify_cancel(n_pair[i].token);
	}
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
	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventMenuButtonUp;
	GSSendSystemEvent(&record);
}

void sendSleepButtonEvent(void) {
	struct GSEventRecord record;
	memset(&record, 0, sizeof(record));
	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventLockButtonDown;
	GSSendSystemEvent(&record);
	record.timestamp = GSCurrentEventTimestamp();
	record.type = kGSEventLockButtonUp;
	GSSendSystemEvent(&record);
}

char *readIdentifierFromFile(const char *path) {
	static char identifier[1<<8];
	FILE *fp = fopen(path, "r");
	if (!fp) {
		return NULL;
	}
	int s = fscanf(fp, "%s\n", identifier);
	fclose(fp);
	return (s == -1)? NULL:identifier;
}

uint32_t registerNotification(const char *notification, int *fd, int *token) {
	static char once = 0;
	uint32_t status = notify_register_file_descriptor(notification, fd, once?NOTIFY_REUSE:0, token);
	if (status != NOTIFY_STATUS_OK) {
		fprintf(stderr, "registration failed (%u)\n", status);
	} else {
		fprintf(stdout, "registered %s with token %d\n", notification, *token);
	}
	once = 1;
	return status;
}
