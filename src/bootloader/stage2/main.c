#include <stdint.h>
#include "stdio.h"
#include "x86.h"
#include "disk.h"
#include "fat.h"
#include "memdefs.h"
#include "memory.h"
#include "vbe.h"

uint8_t* kernelLoadBuffer = (uint8_t*)MEMORY_LOAD_KERNEL;
uint8_t* kernel = (uint8_t*)MEMORY_KERNEL_ADDR;

typedef void (*KernelStart) ();

#define COLOR(r,g,b) ((b) | (g << 8) | (r << 16))

void  puts_realmode(const char* str)
{
    while(*str){
        x86_realmode_putc(*str);
        str++;
    }
}

void __attribute__((cdecl)) start(uint16_t bootDrive)
{   
    clrscr();

    DISK disk;
    if(!DISK_Initialize(&disk, bootDrive))
    {
        printf("Disk init error\r\n");
        goto end;
    }

    if(!FAT_Initialize(&disk))
    {
        printf("FAT init error\r\n");
        goto end;
    }

    // Load Kernel
    FAT_File* fd = FAT_Open(&disk, "/kernel.bin");
    uint32_t read;
    uint8_t* kernelBuffer = kernel;
    while((read=FAT_Read(&disk, fd, MEMORY_KERNEL_SIZE, kernelLoadBuffer)))
    {
        memcpy(kernelBuffer,kernelLoadBuffer, read);
        kernelBuffer += read;
    }
    FAT_Close(fd);

    // Initialize Graphics

    // const int desiredWidth = 1024;
    // const int desiredHeight = 768;
    // const int desiredBpp = 32;
    // uint16_t pickedMode = 0xFFFF;
    // VbeInfoBlock* info = (VbeInfoBlock*)MEMORY_VESA_INFO;
    // VbeModeInfo* modeInfo = (VbeModeInfo*)MEMORY_MODE_INFO;
    // if (VBE_GetControllerInfo(info)) {

    //     uint16_t* mode = (uint16_t*)SEGOFF2LIN(info->VideoModePtr);
    //     for(int i = 0; mode[i]!=0xFFFF; i++){
    //         // printf("MODE[%d]: %x \n",i, mode[i]);
    //         if (!VBE_GetModeInfo(mode[i], modeInfo)) {
    //             printf("Can't get mode info %x :(\n", mode[i]);
    //             continue;
    //         }
    //         // printf("%d\n", modeInfo->attributes);
    //         bool hasFB = (modeInfo->attributes & 0x90) == 0x90;
    //         if (hasFB && modeInfo->width == desiredWidth && modeInfo->height == desiredHeight && modeInfo->bpp == desiredBpp) {
    //             pickedMode = mode[i];
    //             break;
    //         }
    //     }
// 
    //     if (pickedMode != 0xFFFF  && VBE_SetMode(pickedMode)) {
    //         uint32_t* fb = (uint32_t*)(modeInfo->framebuffer);
    //         int w = modeInfo->width;
    //         int h = modeInfo->height;
    //         for (int y = 0; y < h/2; y++){
    //             for (int x = 0; x < w; x++){
    //                 fb[y * modeInfo->pitch/4 + x ] = COLOR(x,y,x+y);
    //             }
    //         }
    //         // for (int y = h/2; y < h; y++){
    //         //     for (int x = 0; x < w; x++){
    //         //         fb[y * modeInfo->pitch/4 + x ] = COLOR(134,57,199);
    //         //     }
    //         // }
    //     }
    // }
    // else {
    //     printf("No VBE extensions :(\n");
    // }


    // execute kernel
    KernelStart kernelStart = (KernelStart)kernel;
    kernelStart();
    

    end:
        for(;;);
    
}