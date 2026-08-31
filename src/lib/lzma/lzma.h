#pragma once

#include <stddef.h>
#include <stdint.h>

size_t lzma_inflate(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size);
