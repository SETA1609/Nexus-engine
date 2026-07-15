#include <stdio.h>

int greetFromC() {

  printf("Hello world from C !! \n");
  // Flush so this line appears in the right order relative to Zig's
  // unbuffered writes. Without this, libc holds the buffer until exit.
  fflush(stdout);
  return 0;
}
