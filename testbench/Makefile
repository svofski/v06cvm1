all: build

IMAGE = i8080_test

ifeq ($(OS),Windows_NT)
  EXE = .exe
  CC = cl /O2 -Fe$(IMAGE).exe
else
  RUN_PREFIX = ./
  #CC = cc -O3 -o $(IMAGE)
  CC = gcc -O0 -g -o $(IMAGE)
endif

FILES = \
  i8080.c \
  i8080_hal.c \
  i8080_test.c

build:	$(FILES)
	$(CC) $(FILES)

#run:
#	$(RUN_PREFIX)$(IMAGE)$(EXE)

clean:
	-rm -f $(IMAGE)$(EXE)
