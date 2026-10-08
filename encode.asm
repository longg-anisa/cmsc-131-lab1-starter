;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it writes nothing, so the
; twenty bytes driver.c saves are whatever the buffer held. Your job is to
; replace that with the construction described below.
;
; The contract, from driver.c:
;
;       unsigned char *hdr        [ebp+12]
;       struct ipv4_fields *in    [ebp+8]
;
; driver.c documents the struct layout:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; You write twenty bytes into hdr. Every multi-byte field goes out
; big-endian: the high byte first. The fragment offset's top five bits share
; byte 6 with the three flag bits. Its bottom eight bits are byte 7.
;
; The checksum is your job too. Bytes 10-11 must read as zero while the
; checksum is computed. Write them as zero, call ip_checksum over the
; finished header, and store its result into the field. The struct's
; checksum member is read on the decode path only. Don't copy it here.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        enter   0,0
        pusha

        ;
        ; TODO: build the header from the struct.
        ;
        ; This is the reverse of decode. Mask each field to its width,
        ; shift it up to where it lives, or the pieces of a shared byte
        ; together, then store the byte. The fields that do not straddle
        ; anything are one store each.
        ;
        ; The checksum comes last, after every other byte is written. Write
        ; bytes 10-11 as zero, call ip_checksum with the header and 20, and
        ; store its result (in ax) into the field big-endian. Computing it
        ; before the rest of the header is in place sums whatever garbage
        ; was in the buffer. ip_checksum preserves ebx, esi, edi, and ebp,
        ; so a pointer kept in one of those survives the call. eax, ecx, and
        ; edx do not.
        ;

        ; encoding header
        mov     esi, [ebp+8]            ; in, ipv4_fields
        mov     edi, [ebp+12]           ; hdr


        ; byte 0: version and ihl
        mov     eax, [esi+0]            ; get version
        shl     eax, 4                  ; shift version into upper 4 bits
        
        mov     ebx, [esi+4]            ; get ihl
        and     ebx, 0x0F               ; keep only lower 4 bits                   

        or      eax, ebx                ; combine version and ihl
        mov     [edi+0], al             ; store byte 0


        ; byte 1: dscp and ecn
        mov     eax, [esi+8]            ; get dscp
        shl     eax, 2                  ; shift dscp into upper 6 bits
        
        mov     ebx, [esi+12]           ; get ecn
        and     ebx, 0x03               ; keep only lower 2 bits                   

        or      eax, ebx                ; combine dscp and ecn
        mov     [edi+1], al             ; store byte 1


        ; bytes 2-3: total length, one 16-bits
        mov     eax, [esi+16]           ; get total length
        and     eax, 0xFF00             ; mask to get high byte
        
        mov     [edi+2], ah             ; store byte 2

        mov     ebx, [esi+16]           ; get total length again
        and     ebx, 0x00FF             ; mask to get lower byte                   

        mov     [edi+3], bl             ; store byte 3


        ; bytes 4-5: identification, one 16-bits
        mov     eax, [esi+20]           ; get identification
        and     eax, 0xFF00             ; mask to get high byte
        
        mov     [edi+4], ah             ; store byte 4

        mov     ebx, [esi+20]           ; get identification again
        and     ebx, 0x00FF             ; mask to get lower byte                   

        mov     [edi+5], bl             ; store byte 5


        ; byte 6-7: flags and fragment offset
        mov     eax, [esi+24]           ; get flags (3 bits)
        shl     eax, 13                 ; shift into upper 3 bits
        
        mov     ebx, [esi+28]           ; get fragment offset (13 bits)
        and     ebx, 0x1FFF             ; keep only 13 bits

        or      eax, ebx                ; combine flags and fragment
        
        and     eax, 0xFF00             ; mask to get high byte                   
        mov     [edi+6], ah             ; store byte 6

        and     ebx, 0x00FF             ; mask to get lower byte
        mov     [edi+7], bl             ; store byte 7


        ; byte 8: ttl
        mov     eax, [esi+32]           ; get ttl
        mov     [edi+8], al             ; store byte 8


        ; byte 9: protocol
        mov     eax, [esi+36]           ; get protocol
        mov     [edi+9], al             ; store byte 9 


        ; bytes 10-11: header checksum
        mov     word [edi+10], 0        ; checksum must be zero while calculating

        ; finished bytes 12-19 first before storing bytes 10-11

        ; bytes 12-15: source address
        mov     eax, [esi+44]           ; get first byte
        mov     [edi+12], al            ; store byte 12  

        mov     eax, [esi+45]           ; get second byte
        mov     [edi+13], al            ; store byte 13  

        mov     eax, [esi+46]           ; get third byte
        mov     [edi+14], al            ; store byte 14  

        mov     eax, [esi+47]           ; get fourth byte
        mov     [edi+15], al            ; store byte 15  


        ; bytes 16-19: destination address
        mov     eax, [esi+48]           ; get first byte
        mov     [edi+16], al            ; store byte 16  

        mov     eax, [esi+49]           ; get second byte
        mov     [edi+17], al            ; store byte 17  

        mov     eax, [esi+50]           ; get third byte
        mov     [edi+18], al            ; store byte 18  

        mov     eax, [esi+51]           ; get fourth byte
        mov     [edi+19], al            ; store byte 19


        push    20                      ; header length
        push    edi                     ; header address
        call    _ip_checksum            ; calculate checksum
        add     esp, 8                  ; remove arguments from stack

        mov     [edi+10], ah            ; store byte 10 (checksum high byte)
        mov     [edi+11], al            ; store byte 11 (checksum low byte)

        popa
        mov     eax, 0
        leave
        ret
