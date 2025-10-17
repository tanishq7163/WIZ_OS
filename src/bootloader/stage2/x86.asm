extern LoadGDT

%macro x86_EnterRealMode 0
    [bits 32]
    jmp word 18h:.pmode16

.pmode16:
    [bits 16]

    ; 2 - disable protected mode bit in cr0
    mov eax, cr0
    and al, ~1
    mov cr0, eax

    ; 3 - jump to real mode
    jmp word 00h:.rmode

.rmode:
    ; 4- setup segments
    mov ax, 0
    mov ds, ax
    mov ss, ax

    ; 5 - enable interrupts
    sti

%endmacro 

%macro x86_EnterProtectedMode 0
    cli 
    call LoadGDT

    ; 4 - set protection enable flag in CR0
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; 5 - far jump into protected mode
    jmp dword 08h:.pmode

.pmode:
    ; we are now in protected mode!
    [bits 32]
    
    ; 6 - setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

%endmacro

;
; Convert linear address to segment:offset address
;Args:
;   1 - linear address
;   2 - (out) target segment (e.g. es)
;   3 - target 32bit register to use (e.g. eax)
;   4 - target lower 16 bit half of #3 (e.g. ax)

%macro LineartoSegOffset 4 

    mov %3, %1
    shr %3, 4
    mov %2, %4
    mov %3, %1
    and %3, 0xf

%endmacro


global x86_outb
x86_outb:
    [bits 32]
    mov dx, [esp+4]
    mov al, [esp+8]
    out dx, al
    ret

global x86_inb
x86_inb:
    [bits 32]
    mov dx, [esp+4]
    xor eax, eax
    in al, dx 
    ret

global x86_realmode_putc
x86_realmode_putc:
    [bits 32]
    push ebp
    mov ebp, esp
    x86_EnterRealMode

    mov al, [bp +8]
    mov ah, 0xE
    int 10h


    x86_EnterProtectedMode 
    mov esp, ebp
    pop ebp
    ret



;
; void __cdecl x86_Disk_GetDriveParams(uint8_t drive,
;                                     uint8_t* driveTypeOut,
;                                     uint16_t* cylindersOut,
;                                     uint16_t* sectorsOut,
;                                     uint16_t* headsOut);
;
;
global x86_Disk_GetDriveParams
x86_Disk_GetDriveParams:
    [bits 32]

    ; new call frame
    push ebp
    mov ebp,esp

    x86_EnterRealMode

    [bits 16]

    ; save regs
    push es
    push bx
    push esi
    push di


    mov dl, [bp+8]
    mov ah, 08h
    mov di, 0
    mov es, di
    stc
    int 13h

    ; out params
    mov eax, 1
    sbb eax, 0

    ; here [bp+6] points to driveTypeOut and keeping its location insid si register
    LineartoSegOffset [bp + 12], es, esi, si 
    mov [es:si], bl    ; now we move  bl which contains the driveType after interrupt into the driveTypeOut location -> si

    ; cylinders
    mov bl, ch
    mov bh, cl
    shr bh, 6
    inc bx

    LineartoSegOffset [bp + 16], es, esi, si 
    mov [es:si], bx

    ;sectors
    xor ch, ch
    and cl,3Fh

    LineartoSegOffset [bp + 20], es, esi, si 
    mov [es:si],cx

    ;heads
    mov cl, dh
    inc cx
    LineartoSegOffset [bp + 24], es, esi, si 
    mov [es:si], cx


    ; restore regs 
    pop di
    pop esi
    pop bx
    pop es

    ;return 
    push eax

    x86_EnterProtectedMode

    [bits 32]
    pop eax

    ; restore call frame
    mov esp,ebp
    pop ebp
    ret


;
; void __cdecl x86_Disk_Reset(uint8_t drive);
;
global x86_Disk_Reset
x86_Disk_Reset:
    [bits 32]
    ; make new call frame and store previous one
    push ebp
    mov ebp, esp

    x86_EnterRealMode
    [bits 16]
    
    mov ah,0
    mov dl,[bp+8]
    stc 
    int 13h
    
    mov eax,1
    sbb eax,0    ; 1 on success 0 on fail

    push eax

    x86_EnterProtectedMode
    [bits 32]

    pop eax
    ; restore old call frame
    mov esp,ebp
    pop ebp
    ret



; void __cdecl x86_Disk_Read(uint8_t drive,
;                             uint16_t cylinder,
;                             uint16_t head,
;                             uint16_t sector,
;                             uint8_t count,
;                             uint8_t __far* dataOut);

global x86_Disk_Read
x86_Disk_Read:
    [bits 32]
    push ebp
    mov ebp, esp

    x86_EnterRealMode
    [bits 16]
    push ebx
    push es

    mov dl,[bp+8]
    mov ch, [bp+12]
    mov cl, [bp+13]
    shl cl,6

    mov al, [bp+16]
    and al, 3Fh
    or cl,al

    mov dh, [bp+20]
    mov al, [bp+24]

    LineartoSegOffset [bp + 28],  es, ebx, bx
    
    mov ah,02h
    stc 
    int 13h

    ; set return value
    mov eax,1
    sbb eax,0    ; 1 on success 0 on fail
    ; restore regs
    pop es
    pop ebx

    push eax

    x86_EnterProtectedMode
    [bits 32]

    pop eax

    ; restore old call frame
    mov esp,ebp
    pop ebp
    ret


global x86_Video_GetVbeInfo
x86_Video_GetVbeInfo:

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp          ; initialize new call frame

    x86_EnterRealMode

    ; save modified regs
    push edi
    push es
    push ebp                ; bochs vbe changes ebp

    ; call interrupt
    mov ax, 0x4f00
    LineartoSegOffset [bp + 8], es, edi, di
    int 10h

    ; check return
    cmp al, 4fh
    jne .error
    
    ; put status in eax
    mov al, ah
    and eax, 0xFF
    jmp .cont

.error:
    mov eax, -1

.cont:
    ; restore regs
    pop ebp                ; bochs vbe changes ebp
    pop es
    pop edi

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret


global x86_Video_GetModeInfo
x86_Video_GetModeInfo:

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp          ; initialize new call frame

    x86_EnterRealMode

    ; save modified regs
    push edi
    push es
    push ebp                ; bochs vbe changes ebp
    push ecx

    ; call interrupt
    mov ax, 0x4f01
    mov cx, [bp + 8]
    LineartoSegOffset [bp + 12], es, edi, di
    int 10h

    ; check return
    cmp al, 4fh
    jne .error
    
    ; put status in eax
    mov al, ah
    and eax, 0xFF
    jmp .cont

.error:
    mov eax, -1

.cont:
    ; restore regs
    pop ecx
    pop ebp                ; bochs vbe changes ebp
    pop es
    pop edi

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret


global x86_Video_SetMode
x86_Video_SetMode:

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp          ; initialize new call frame

    x86_EnterRealMode

    ; save modified regs
    push edi
    push es
    push ebp                ; bochs vbe changes ebp
    push ebx

    ; call interrupt
    mov ax, 0
    mov es, ax
    mov edi, 0
    mov ax, 0x4f02
    mov bx, [bp + 8]

    int 10h

    ; check return
    cmp al, 4fh
    jne .error
    
    ; put status in eax
    mov al, ah
    and eax, 0xFF
    jmp .cont

.error:
    mov eax, -1

.cont:
    ; restore regs
    pop ebx
    pop ebp                ; bochs vbe changes ebp
    pop es
    pop edi

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret
