#include <iostream>

extern "C" void greetFromCpp() {
  // `std::flush` (or std::endl) forces this to appear in the right order
  // relative to Zig's unbuffered writes; without it libc++ holds the
  // buffer until exit and the line lands at the end of the program.
  std::cout << "Hello from Cpp!!!" << "\n" << std::flush;
}
