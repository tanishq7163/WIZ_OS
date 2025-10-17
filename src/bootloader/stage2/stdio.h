#pragma once
#include <stdint.h>
#include <stdbool.h>

void clrscr();
void putc(char c);
void puts(const char* str);
void printf(const char* fmt,...);
void print_buffer(const char* msg, const void* buffer, uint32_t count);

#define PRINTF_STATE_NORMAL         0
#define PRINTF_STATE_LENGTH         1
#define PRINTF_STATE_SHORT          2
#define PRINTF_STATE_LONG           3
#define PRINTF_STATE_SPEC           4

#define PRINTF_LENGTH_DEFAULT       0
#define PRINTF_LENGTH_SHORT_SHORT   1
#define PRINTF_LENGTH_SHORT         2
#define PRINTF_LENGTH_LONG          3
#define PRINTF_LENGTH_LONG_LONG     4
