CC = riscv64-unknown-linux-gnu-gcc
CFLAGS := -O2 -static -DRISCV

time-run: time-run.c
	${CC} ${CFLAGS} -o time-run time-run.c

clean:
	rm -f time-run
