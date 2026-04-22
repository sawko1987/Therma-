#include "my_application.h"

#include <cstdlib>

int main(int argc, char** argv) {
  // Force Mesa llvmpipe on older Linux GPUs that can't initialize Flutter's
  // desktop renderer reliably with hardware OpenGL.
  setenv("LIBGL_ALWAYS_SOFTWARE", "1", 0);
  setenv("MESA_LOADER_DRIVER_OVERRIDE", "llvmpipe", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
