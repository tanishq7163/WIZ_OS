export CFLAGS = -std=c99 -g
export ASMFLAGS = 
export LINKFLAGS = 
export LIBS = 
export CC = gcc
export CXX = g++
export LD = gcc
export ASM = nasm


export TARGET = i686-elf
export TARGET_CC = $(TARGET)-gcc
export TARGET_CXX = $(TARGET)-g++
export TARGET_LD = $(TARGET)-gcc
export TARGET_ASM = nasm

export TARGET_CFLAGS = -std=c99 -g -O2
export TARGET_LINKFLAGS =  
export TARGET_ASMFLAGS = 
export TARGET_LIBS = 

export SOURCE_DIR = $(abspath .)
export BUILD_DIR = $(abspath build)


BINUTILS_VERSION = 2.37
GCC_VERSION = 11.2.0

BINUTILS_URL = https://ftp.gnu.org/gnu/binutils/binutils-$(BINUTILS_VERSION).tar.xz
GCC_URL = https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.xz
