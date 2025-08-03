all: build

IMAGE = i8080_test

ifeq ($(OS),Windows_NT)
  EXE = .exe
  CC = cl /O2 -Fe$(IMAGE).exe
else
  RUN_PREFIX = ./
  #CC = cc -O3 -o $(IMAGE)
  CC = g++ -std=c++17 -O0 -g $(WITH_KVAZ) $(ROM) $(BENCHMARK) -o $(IMAGE) -Idisass
endif

FILES = \
  i8080.c \
  i8080_hal.c \
  i8080_test.c \
  memory.cpp \
  disass/Disasm.cpp

build:	$(FILES)
	$(CC) $(FILES)

#run:
#	$(RUN_PREFIX)$(IMAGE)$(EXE)

clean:
	-rm -f $(IMAGE)$(EXE)
