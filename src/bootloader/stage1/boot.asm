org 0x7C00
bits 16

%define ENDL 0x0D,0x0A

; 
; FAT12 header
; 
jmp short start
nop 

bdb_oem:					db 'MSWIN4.1' 	;8 bytes
bdb_bytes_per_sector: 		dw 512 			
bdb_sectors_per_cluster:	db 1
bdb_reserved_sector: 		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count: 		dw 0E0h
bdb_total_sectors: 			dw 2880
bdb_media_descriptor_type:	db 0F0h
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; extended Boot record

ebr_drive_number: 			db 0 	;0x00 for floppy, 0x80 for hdd useless
							db 0
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 34h,56h,78h
ebr_volume_label:			db 'WIZ OS     '
ebr_system_id: 				db 'FAT12   '

;
; Code Goes Here
;

start:
	mov ax,0
	mov ds,ax
	mov es,ax

	mov ss,ax
	mov sp,0x7C00

	; some bioses might start us at 07C0:0000 of 0000:7C00, make sure we are in the
	; expected location
	push es
	push word .after
	retf


.after:

	; read Something from floppy 
	; bios should set DL to drive number
	mov [ebr_drive_number],dl

	; show loading message
	mov si,msg_loading
	call puts

	; read drive parameters (sectors per track and head count)
	; instead of relying on data on formatted disk
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3F	;remove top 2 bits
	xor ch, ch
	mov [bdb_sectors_per_track], cx

	inc dh
	mov [bdb_heads], dh		;head count

	;read FAT root directory
	mov ax, [bdb_sectors_per_fat] 	;compute lba of root directory = reserved + fat * sectors_per_fat
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx
	add ax, [bdb_reserved_sector]
	push ax

	; compute size of root directory = (32 * number of entries)/ bytes_per_sector
	mov ax, [bdb_dir_entries_count]
	shl ax, 5
	xor dx,dx
	div word [bdb_bytes_per_sector]

	test dx, dx
	jz .rootDirAfter
	inc ax 				; div remainder != 0, add 1
						; this means we have a sector only partially filled with entries

.rootDirAfter:
	mov cl,al
	pop ax
	mov dl, [ebr_drive_number]
	mov bx, buffer
	call disk_read

	xor bx,bx
	mov di,buffer

.searchKernel:
	mov si, file_stage2_bin
	mov cx, 11
	push di
	repe cmpsb
	pop di
	je .foundKernel

	add di,32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .searchKernel

	jmp kernelNotFound


.foundKernel:
	mov si, kernel_found
	call puts

	mov ax, [di+26]
	mov [stage2_cluster],ax

	mov ax,[bdb_reserved_sector]
	mov bx,buffer
	mov cl,[bdb_sectors_per_fat]
	mov dl,[ebr_drive_number]
	call disk_read

	mov bx, stage2_load_segment
	mov es, bx
	mov bx, stage2_load_offset

.loadKernelLoop:
	mov ax,[stage2_cluster]
	add ax,31
	mov cl,1
	mov dl,[ebr_drive_number]
	call disk_read

	add bx,[bdb_bytes_per_sector]

	mov ax, [stage2_cluster]
	mov cx,3
	mul cx
	mov cx,2
	div cx

	mov si,buffer
	add si,ax
	mov ax,[ds:si]

	or dx,dx
	jz .even 

.odd:
	shr ax,4
	jmp .nextClusterAfter

.even:
	and ax, 0x0FFF

.nextClusterAfter:
	cmp ax, 0x0FF8
	jae .readFinish

	mov [stage2_cluster],ax
	jmp .loadKernelLoop

.readFinish:
	; jump to our kernel
	mov dl,[ebr_drive_number]			; boot device in dl
	mov ax, stage2_load_segment			; set segment registers
	mov ds,ax
	mov es,ax
	jmp stage2_load_segment:stage2_load_offset
	
	jmp wait_key_and_reboot				; should never happen

	cli
	hlt

floppy_error:
	mov si,msg_floppy_error
	call puts
	jmp wait_key_and_reboot

kernelNotFound:
	mov si, msg_stage2_not_found
	call puts	
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah,0
	int 16h			; wait for keypress
	jmp 0FFFFh:0 	;jmp to beginning of BIOS and should reboot

.halt:
	cli				; disable interrupts, this way cpu doesnt get out of halt state
	hlt

;
; Prints a string to a screen
;
puts:
	push si
	push ax
	push bx

.loop:
	lodsb
	or al,al
	jz .done

	mov ah,0x0E
	mov bh,0
	int 0x10

	jmp .loop

.done:
	pop bx
	pop ax
	pop si
	ret

;
; Disk Routines
;
lba_to_chs:
	push ax
	push dx

	xor dx,dx
	div word [bdb_sectors_per_track]

	inc dx
	mov cx, dx

	xor dx,dx
	div word [bdb_heads]

	mov dh,dl
	mov ch,al
	shl ah,6
	or cl,ah

	pop ax
	mov dl,al
	pop ax
	ret

;
; Read Sector from Disk
;

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3

.retry:
	pusha
	stc
	int 13h
	jnc .done_read

	popa
	call disk_reset

	dec di
	test di,di
	jnz .retry

.fail:
	jmp floppy_error

.done_read:
	popa
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

disk_reset:
	pusha
	mov ah,0
	stc
	int 13h
	jc floppy_error
	popa
	ret



kernel_found: 				db 'Found S',ENDL,0
msg_floppy_error: 			db 'Floppy Error',ENDL,0
msg_loading: 				db 'Loading..',ENDL,0
msg_stage2_not_found: 		db 'STAGE2 NOT FOUND',ENDL,0
file_stage2_bin: 			db 'STAGE2  BIN'
stage2_cluster:			 	dw 0

stage2_load_segment 	equ 0x0
stage2_load_offset 		equ 0x500

times 510-($-$$) db 0
dw 0AA55h
buffer: