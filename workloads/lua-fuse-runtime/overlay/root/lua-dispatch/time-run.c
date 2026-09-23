/* Untraced timing harness for the dispatch-fusion arms.
**
** The tacit encoder is not involved: this measures the runtime the arms are compared
** on, so nothing may perturb it. Spawn the command once, reap it, and report the core
** cycles and retired instructions that elapsed in between.
**
** The target is a single-hart MegaBoom v3, so rdcycle read in the parent counts every
** cycle the core spent between fork and reap -- the child's, plus the kernel time on
** its behalf -- which is exactly the quantity we want. Linux sets scounteren=0x7
** (arch/riscv/kernel/head.S), so CY/TM/IR are readable from U-mode.
**
** usage: time-run <tag> <rep> <command> [args...]
*/
#include <stdio.h>
#include <stdint.h>
#include <spawn.h>
#include <sys/wait.h>
#include <errno.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

static inline uint64_t rdcycle(void) {
  uint64_t x; __asm__ __volatile__("rdcycle %0" : "=r"(x)); return x;
}
static inline uint64_t rdinstret(void) {
  uint64_t x; __asm__ __volatile__("rdinstret %0" : "=r"(x)); return x;
}

int main(int argc, char **argv) {
  if (argc < 4) {
    fprintf(stderr, "usage: time-run <tag> <rep> <command> [args...]\n");
    return 2;
  }
  const char *tag = argv[1], *rep = argv[2];

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  uint64_t c0 = rdcycle(), i0 = rdinstret();

  pid_t pid;
  int spawn_rc = posix_spawnp(&pid, argv[3], NULL, NULL, &argv[3], environ);
  if (spawn_rc != 0) { errno = spawn_rc; perror("posix_spawnp"); return 1; }
  int status;
  if (waitpid(pid, &status, 0) < 0) { perror("waitpid"); return 1; }

  uint64_t i1 = rdinstret(), c1 = rdcycle();
  clock_gettime(CLOCK_MONOTONIC, &t1);

  double wall = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
  printf("RESULT arm=%s rep=%s cycles=%llu instret=%llu wall=%.3f status=%d\n",
         tag, rep, (unsigned long long)(c1 - c0), (unsigned long long)(i1 - i0),
         wall, WEXITSTATUS(status));
  fflush(stdout);
  return WEXITSTATUS(status);
}
