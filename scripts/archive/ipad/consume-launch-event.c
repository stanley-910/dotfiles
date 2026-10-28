// Shim for launchd agents triggered by LaunchEvents (com.apple.iokit.matching).
//
// launchd requires the launched process to consume the triggering XPC event
// via xpc_set_event_stream_handler. A plain script never does, so launchd
// treats the event as still pending and relaunches the job every
// ThrottleInterval for as long as the device is attached (observed: an
// infinite 30s reconnect loop). This shim consumes the event, then execs the
// real handler.
//
// Build (binary is gitignored, rebuild on a fresh machine):
//   clang -O2 -o ~/dotfiles/scripts/bin/consume-launch-event \
//     ~/dotfiles/scripts/src/consume-launch-event.c
//
// Usage in a plist: ProgramArguments = [consume-launch-event, <program>, ...]
#include <xpc/xpc.h>
#include <dispatch/dispatch.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <program> [args...]\n", argv[0]);
        return 2;
    }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    xpc_set_event_stream_handler("com.apple.iokit.matching", NULL,
                                 ^(xpc_object_t event) {
        (void)event;
        dispatch_semaphore_signal(sem);
    });
    // The pending event is delivered almost immediately; the timeout only
    // covers the manual-run case where no event exists to consume.
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW,
                                               10 * NSEC_PER_SEC));
    // A single device attach can emit several matching events (USB
    // re-enumeration). Linger briefly so the handler consumes them all —
    // otherwise launchd relaunches the job once per leftover event, one
    // ThrottleInterval apart.
    while (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW,
                                                      2 * NSEC_PER_SEC)) == 0)
        ;
    execvp(argv[1], &argv[1]);
    perror("execvp");
    return 1;
}
