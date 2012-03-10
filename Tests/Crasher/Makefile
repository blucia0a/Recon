CFLAGS=
LDFLAGS=-lpthread

all:
	$(CC) -c $(CFLAGS) -O1 -g -o Crasher.o ./Crasher.c
	$(CC) $(LDFLAGS) -g -o Crasher ./Crasher.o
clean:
	-rm *.o
	-rm Crasher
