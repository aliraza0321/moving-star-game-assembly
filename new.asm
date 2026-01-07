 [org 0x0100]
jmp start

player_row:    db 24     ;default position of player
player_col:    db 40
player_dir:    db 3    ;have four directions 0 1 2 3
tick_count:    db 0    ;tick_count for movement of player 
old_isr:       dd 0
msg_lost:      db 'Game Lost $'
msg_win:       db 'Game Win! $'


clrscr:
    push es
    push ax
    push cx
    push di
    mov ax,0xb800
    mov es,ax
    xor di,di
    mov ax,0x0720     ;07 for white color and 20 for space char
    mov cx,2000
    rep stosw
    pop di
    pop cx
    pop ax
    pop es
    ret


place_obstacles:
    push ax
    push cx
    push di
    push es

    mov ax,0xb800
    mov es,ax

    ; right boundary
    mov cx,25
    xor di,di

lastColumns:
    mov word [es:di+158],0x2220      ;green color with green background and 20 for space green space as char
    add di,160                       ;move next row last column
    loop  lastColumns

    ; horizontal wall
    mov cx,21                 ;for 21 characters as space with green color
    mov di,(5*80+10)*2 
firstwall:
    mov ax,0x2220
    stosw
    loop firstwall

    ; vertical wall
    mov cx,6                   ;for 6 times loop run 
    mov di,(10*80+20)*2      ;10th row and 20th column this obstacles will start
secondwall:
    mov ax,0x2220
    mov word [es:di],ax
    add di,160      ;add 160 move to next row 
    loop secondwall

    pop es
    pop di
    pop cx
    pop ax
    ret

place_goal:
    push ax
    push es
    mov ax,0xb800
    mov es,ax
    xor di,di
    mov ax,0x4420   ;place red on red space at 0th position
    stosw
    pop es
    pop ax
    ret

place_player:
    push ax
    push es
    mov ax,0xb800
    mov es,ax

    mov al,[player_row]    
    xor ah,ah
    mov bl,80
    mul bl
    mov dl,[player_col]
    xor dh,dh
    add ax,dx
    shl ax,1
    mov di,ax

    mov ax,0x0F2A   ;place place with blue background and red steric
    stosw

    pop es
    pop ax
    ret

check_keyboard:
    mov ah,1  ;wait any key
    int 16h
    jz done   ;if not any key pressed zero flag is zero 

    mov ah,0    
    int 16h
    mov al,ah    ;scan code in ah so mov it in al

    cmp al,0x48  
    je up
    cmp al,0x50
    je down
    cmp al,0x4B
    je left
    cmp al,0x4D
    je right
    jmp done

up:    
        mov byte [player_dir],0  ; up
        jmp done
down: 
        mov byte [player_dir],1  ; down
        jmp done
left: 
         mov byte [player_dir],2  ; left
         jmp done
right:
          mov byte [player_dir],3  ; right
done:
    ret


timer_handler:
    pusha
    push ds
    push es

    inc byte [tick_count]
    cmp byte [tick_count],2
    jl skip
    mov byte [tick_count],0
    call move_player
skip:

    mov al,20h
    out 20h,al

    pop es
    pop ds
    popa
    jmp far [cs:old_isr]    ;chanining


move_player:
    pusha
    push es

    mov al,[player_dir]
    mov bl,[player_row]
    mov bh,[player_col]

    cmp al,0
    je upward
    cmp al,1
    je downward
    cmp al,2
    je leftward
    cmp al,3
    je rightward
    jmp check

upward:
    dec bl
    jmp check
downward: 
    inc bl
    jmp check
leftward:
     dec bh
    jmp check
rightward:
     inc bh

check:                     ;if player at boundary then no need no move just stop 
    cmp bl,0     
    jl nomove
    cmp bl,24
    jg nomove
    cmp bh,0
    jl nomove
    cmp bh,79
    jg nomove
                        ;other wise move 
    mov ax,0xb800
    mov es,ax

    mov al,bl
    xor ah,ah
    mov cl,80
    mul cl
    mov dl,bh
    xor dh,dh
    add ax,dx
    shl ax,1
    mov di,ax

    mov ax,[es:di]
    mov cl,ah

    cmp cl,0x22     ;if cl is green space means obstacles
    je lost
    cmp cl,0x44    ;if cl is red 
    je win

    ; if not win or lose then just move forward and remove from previous place
    mov al,[player_row]
    xor ah,ah
    mov cl,80
    mul cl
    mov dl,[player_col]
    xor dh,dh
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0720     ;place space previous positon of player
    stosw

    ; place player at new position
    mov al,bl
    xor ah,ah
    mov cl,80
    mul cl
    mov dl,bh
    xor dh,dh
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0F2A     ;place player at new position
    stosw

    mov [player_row],bl     ;update player position row wise
    mov [player_col],bh     ;update player position column wise

nomove:
    pop es
    popa
    ret

lost:
    mov dx,msg_lost
    call print_string
    call exit

win:
    mov dx,msg_win
    call print_string
    call exit

print_string:
    mov ah,9    ;for print_string
    int 21h
    ret


exit:
    cli
    xor ax,ax
    mov es,ax
    mov ax,[old_isr]    ;unhooking interrupt
    mov word [es:8*4],ax 
    mov ax,[old_isr+2]
    mov word [es:8*4+2],ax
    sti
    mov ax,0x4c00
    int 21h

start:
    call clrscr
    call place_obstacles
    call place_goal
    call place_player

    ; save old vector
    xor ax,ax
    mov es,ax
    mov ax,[es:8*4]
    mov [old_isr],ax
    mov ax,[es:8*4+2]
    mov [old_isr+2],ax

    ; set new handler
    cli
    mov ax,timer_handler
    mov dx,cs
    mov [es:8*4],ax
    mov [es:8*4+2],dx
    sti

main:
    call check_keyboard
    jmp main     ;infinite loop 
