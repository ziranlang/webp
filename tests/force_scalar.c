/* Test host only: select unchanged libwebp's portable C reference kernels. */
extern int (*VP8GetCPUInfo)(int);
__attribute__((constructor)) static void force_scalar(void) { VP8GetCPUInfo = 0; }
