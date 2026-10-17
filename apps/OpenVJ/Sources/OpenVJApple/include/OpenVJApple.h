#pragma once

#include <stddef.h>

/// Creates a wgpu instance and Metal-layer surface. Outputs are owned by the caller.
void openvj_apple_create_surface(void *metal_layer, void **out_instance, void **out_surface);
