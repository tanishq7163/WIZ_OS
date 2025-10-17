#pragma once
#include <stdint.h>

typedef struct {

    // in the reverse order they are pushed
    uint32_t ds;
    uint32_t edi, esi, ebp, useless, ebx, edx, ecx, eax;
    uint32_t interrupt, error;
    uint32_t eip, cs, eflags, esp, ss;
} __attribute__((packed)) Registers;


typedef void (*ISRHandler)(Registers* regs);

void i686_ISR_Initialize();
void i686_ISR_RegisterHandler(int interrupt, ISRHandler handler);