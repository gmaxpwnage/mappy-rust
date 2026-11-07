; ============================================================================
; Mappy (Japan) (En) - NROM (mapper 0), 16 KiB PRG, 8 KiB CHR, vertical mirroring
;
; Annotated disassembly produced by `recompiler` from the iNES image.
; The code is executed from the $C000-$FFFF mirror; all addresses below are
; CPU addresses in that window. `phys` offsets are shown in the header table.
;
; Vectors:  NMI $C2EF   RESET $C031   IRQ/BRK $C304
; ============================================================================

        .byte $43,$4F,$50,$59,$52,$49,$47,$48  ; COPYRIGH
        .byte $54,$20,$31,$39,$38,$33,$20,$31  ; T 1983 1
        .byte $39,$38,$34,$20,$4E,$41,$4D,$43  ; 984 NAMC
        .byte $4F,$20,$4C,$54                  ; O LT
C01C  44 2E     NOP $2E                      
C01E  41 4C     EOR ($4C,X)                  
C020  4C 20 52  JMP L5220                    
        .byte $49,$47,$48,$54,$53,$20,$52,$45  ; IGHTS RE
        .byte $53,$45,$52,$56,$45,$44          ; SERVED

; RESET entry
reset:
C031  78        SEI                          
C032  D8        CLD                          
C033  A2 5F     LDX #$5F                     
C035  9A        TXS                          
C036  A9 00     LDA #$00                     
C038  8D 00 20  STA $2000                    PPU: control
C03B  8D 01 20  STA $2001                    PPU: mask

; branch target entry
LC03E:
C03E  AD 02 20  LDA $2002                    PPU: status
C041  10 FB     BPL LC03E                    
C043  A9 07     LDA #$07                     
C045  85 01     STA $01                      
C047  A9 00     LDA #$00                     
C049  85 00     STA $00                      
C04B  A8        TAY                          

; branch target entry
LC04C:
C04C  91 00     STA ($00),Y                  
C04E  C8        INY                          
C04F  D0 FB     BNE LC04C                    
C051  C6 01     DEC $01                      
C053  D0 F7     BNE LC04C                    
C055  20 5C C2  JSR cold_boot_check          
C058  A9 5A     LDA #$5A                     
C05A  85 3E     STA $3E                      
C05C  A9 A5     LDA #$A5                     
C05E  85 3F     STA $3F                      
C060  A0 00     LDY #$00                     
C062  20 28 C1  JSR state_dispatch           
C065  20 B5 F4  JSR LF4B5                    
C068  A9 88     LDA #$88                     
C06A  8D 00 20  STA $2000                    PPU: control

; branch target entry
LC06D:
C06D  A5 20     LDA $20                      
C06F  F0 FC     BEQ LC06D                    
C071  A9 07     LDA #$07                     
C073  8D 14 40  STA $4014                    OAM DMA
C076  20 50 C1  JSR vram_update_flush        
C079  20 C9 C1  JSR read_controllers         
C07C  20 D0 C0  JSR pause_sprites            
C07F  A2 14     LDX #$14                     
C081  86 2C     STX $2C                      
C083  A5 28     LDA $28                      
C085  85 10     STA $10                      
C087  A5 29     LDA $29                      
C089  06 10     ASL $10                      
C08B  2A        ROL A                        
C08C  06 10     ASL $10                      
C08E  2A        ROL A                        
C08F  06 10     ASL $10                      
C091  2A        ROL A                        
C092  8D 05 20  STA $2005                    PPU: scroll
C095  A9 00     LDA #$00                     
C097  8D 05 20  STA $2005                    PPU: scroll
C09A  A9 88     LDA #$88                     
C09C  69 00     ADC #$00                     
C09E  8D 00 20  STA $2000                    PPU: control
C0A1  20 F1 F4  JSR apu_engine               
C0A4  A5 23     LDA $23                      
C0A6  F0 0D     BEQ LC0B5                    
C0A8  20 35 D7  JSR LD735                    
C0AB  A5 24     LDA $24                      
C0AD  29 03     AND #$03                     
C0AF  C9 01     CMP #$01                     
C0B1  D0 14     BNE LC0C7                    
C0B3  F0 12     BEQ LC0C7                    

; branch target entry
LC0B5:
C0B5  A5 24     LDA $24                      
C0B7  29 03     AND #$03                     
C0B9  C9 01     CMP #$01                     
C0BB  D0 02     BNE LC0BF                    
C0BD  EA        NOP                          
C0BE  EA        NOP                          

; branch target entry
LC0BF:
C0BF  20 C9 C7  JSR write_attribute_table    
C0C2  A0 00     LDY #$00                     
C0C4  20 46 C1  JSR stack_frame_swap_y       

; branch target entry
LC0C7:
C0C7  E6 21     INC $21                      
C0C9  A9 00     LDA #$00                     
C0CB  85 20     STA $20                      
C0CD  4C 6D C0  JMP LC06D                    

; subroutine entry
pause_sprites:
C0D0  A2 00     LDX #$00                     
C0D2  A5 23     LDA $23                      
C0D4  F0 41     BEQ LC117                    
C0D6  A5 24     LDA $24                      
C0D8  29 03     AND #$03                     
C0DA  C9 01     CMP #$01                     
C0DC  EA        NOP                          
C0DD  EA        NOP                          
C0DE  A9 68     LDA #$68                     
C0E0  85 10     STA $10                      
C0E2  A0 67     LDY #$67                     
C0E4  A5 21     LDA $21                      
C0E6  29 10     AND #$10                     
C0E8  D0 02     BNE LC0EC                    
C0EA  A0 F7     LDY #$F7                     

; branch target entry
LC0EC:
C0EC  84 11     STY $11                      
C0EE  A0 00     LDY #$00                     

; branch target entry
LC0F0:
C0F0  A5 11     LDA $11                      
C0F2  9D 00 07  STA $0700,X                  
C0F5  E8        INX                          
C0F6  B9 23 C1  LDA $C123,Y                  
C0F9  C8        INY                          
C0FA  9D 00 07  STA $0700,X                  
C0FD  E8        INX                          
C0FE  A9 02     LDA #$02                     
C100  9D 00 07  STA $0700,X                  
C103  E8        INX                          
C104  A5 10     LDA $10                      
C106  9D 00 07  STA $0700,X                  
C109  18        CLC                          
C10A  69 08     ADC #$08                     
C10C  85 10     STA $10                      
C10E  E8        INX                          
C10F  E0 14     CPX #$14                     
C111  D0 DD     BNE LC0F0                    

; branch target entry
LC113:
C113  E8        INX                          
C114  10 FD     BPL LC113                    
C116  60        RTS                          

; branch target entry
LC117:
C117  A9 F7     LDA #$F7                     

; branch target entry
LC119:
C119  9D 00 07  STA $0700,X                  
C11C  E8        INX                          
C11D  E8        INX                          
C11E  E8        INX                          
C11F  E8        INX                          
C120  D0 F7     BNE LC119                    
C122  60        RTS                          
        .byte $D0,$D2,$DC,$CF,$D4              ; .....

; subroutine entry
state_dispatch:
C128  B9 3E C1  LDA $C13E,Y                  
C12B  85 1E     STA $1E                      
C12D  B9 3F C1  LDA $C13F,Y                  
C130  85 1F     STA $1F                      
C132  BA        TSX                          
C133  8A        TXA                          
C134  BE 40 C1  LDX $C140,Y                  
C137  9D C1 00  STA $00C1,X                  
C13A  9A        TXS                          
C13B  6C 1E 00  JMP ($001E)                  
        .byte $4F,$C8,$3F                      ; O.?

; reachable via computed jump entry
stack_frame_swap:
C141  BA        TSX                          
C142  8A        TXA                          
C143  29 C0     AND #$C0                     
C145  A8        TAY                          

; subroutine entry
stack_frame_swap_y:
C146  BA        TSX                          
C147  8A        TXA                          
C148  BE 00 01  LDX $0100,Y                  
C14B  99 00 01  STA $0100,Y                  
C14E  9A        TXS                          
C14F  60        RTS                          

; subroutine entry
vram_update_flush:
C150  20 41 C2  JSR ppu_rendering_off        

; branch target entry
LC153:
C153  E4 2A     CPX $2A                      
C155  F0 1E     BEQ LC175                    
C157  BC 00 05  LDY $0500,X                  
C15A  E8        INX                          
C15B  BD 00 05  LDA $0500,X                  
C15E  E8        INX                          
C15F  8D 06 20  STA $2006                    PPU: VRAM address
C162  8C 06 20  STY $2006                    PPU: VRAM address
C165  BC 00 05  LDY $0500,X                  
C168  E8        INX                          

; branch target entry
LC169:
C169  BD 00 05  LDA $0500,X                  
C16C  E8        INX                          
C16D  8D 07 20  STA $2007                    PPU: VRAM data
C170  88        DEY                          
C171  D0 F6     BNE LC169                    
C173  F0 DE     BEQ LC153                    

; branch target entry
LC175:
C175  A2 00     LDX #$00                     

; jump target entry
jmp_C177:
C177  E4 2B     CPX $2B                      
C179  F0 27     BEQ LC1A2                    
C17B  BC C0 04  LDY $04C0,X                  
C17E  E8        INX                          
C17F  BD C0 04  LDA $04C0,X                  
C182  E8        INX                          
C183  8D 06 20  STA $2006                    PPU: VRAM address
C186  8C 06 20  STY $2006                    PPU: VRAM address
C189  BD C0 04  LDA $04C0,X                  
C18C  E8        INX                          
C18D  85 1E     STA $1E                      
C18F  BD C0 04  LDA $04C0,X                  
C192  E8        INX                          
C193  85 1F     STA $1F                      
C195  AD 07 20  LDA $2007                    PPU: VRAM data
C198  AD 07 20  LDA $2007                    PPU: VRAM data
C19B  A0 08     LDY #$08                     
C19D  91 1E     STA ($1E),Y                  
C19F  4C 77 C1  JMP LC177                    

; branch target entry
LC1A2:
C1A2  20 39 C2  JSR clear_update_queue       
C1A5  A9 00     LDA #$00                     
C1A7  8D 05 20  STA $2005                    PPU: scroll
C1AA  8D 05 20  STA $2005                    PPU: scroll
C1AD  A9 88     LDA #$88                     
C1AF  8D 00 20  STA $2000                    PPU: control
C1B2  A6 2B     LDX $2B                      

; branch target entry
LC1B4:
C1B4  EA        NOP                          
C1B5  EA        NOP                          
C1B6  E8        INX                          
C1B7  E0 40     CPX #$40                     
C1B9  D0 F9     BNE LC1B4                    
C1BB  A6 2A     LDX $2A                      

; branch target entry
LC1BD:
C1BD  EA        NOP                          
C1BE  EA        NOP                          
C1BF  EA        NOP                          
C1C0  EA        NOP                          
C1C1  E8        INX                          
C1C2  D0 F9     BNE LC1BD                    
C1C4  86 2A     STX $2A                      
C1C6  86 2B     STX $2B                      
C1C8  60        RTS                          

; subroutine entry
read_controllers:
C1C9  A2 01     LDX #$01                     
C1CB  8E 16 40  STX $4016                    APU/joy1 port
C1CE  CA        DEX                          
C1CF  8E 16 40  STX $4016                    APU/joy1 port
C1D2  20 49 C2  JSR joypad_shift_bits        
C1D5  E8        INX                          
C1D6  20 49 C2  JSR joypad_shift_bits        
C1D9  A5 41     LDA $41                      
C1DB  49 01     EOR #$01                     
C1DD  AA        TAX                          
C1DE  76 10     ROR $10,X                    
C1E0  76 10     ROR $10,X                    
C1E2  A6 41     LDX $41                      
C1E4  76 10     ROR $10,X                    
C1E6  2A        ROL A                        
C1E7  76 10     ROR $10,X                    
C1E9  2A        ROL A                        
C1EA  29 03     AND #$03                     
C1EC  C9 01     CMP #$01                     
C1EE  26 22     ROL $22                      
C1F0  66 11     ROR $11                      
C1F2  66 10     ROR $10                      
C1F4  26 24     ROL $24                      
C1F6  66 11     ROR $11                      
C1F8  66 10     ROR $10                      
C1FA  26 25     ROL $25                      
C1FC  B5 10     LDA $10,X                    
C1FE  29 0F     AND #$0F                     
C200  4A        LSR A                        
C201  4A        LSR A                        
C202  AA        TAX                          
C203  BD 58 C2  LDA $C258,X                  
C206  A2 00     LDX #$00                     
C208  C5 26     CMP $26                      
C20A  F0 01     BEQ LC20D                    
C20C  E8        INX                          

; branch target entry
LC20D:
C20D  85 26     STA $26                      
C20F  86 27     STX $27                      
C211  A5 42     LDA $42                      
C213  F0 1F     BEQ LC234                    
C215  A5 4F     LDA $4F                      
C217  05 4B     ORA $4B                      
C219  D0 19     BNE LC234                    
C21B  AD 0F 04  LDA $040F                    
C21E  F0 14     BEQ LC234                    
C220  A5 25     LDA $25                      
C222  29 03     AND #$03                     
C224  C9 01     CMP #$01                     
C226  D0 0B     BNE LC233                    
C228  45 23     EOR $23                      
C22A  85 23     STA $23                      
C22C  F0 05     BEQ LC233                    
C22E  A9 01     LDA #$01                     
C230  8D 00 06  STA $0600                    

; branch target entry
LC233:
C233  60        RTS                          

; branch target entry
LC234:
C234  A9 00     LDA #$00                     
C236  85 23     STA $23                      
C238  60        RTS                          

; subroutine entry
clear_update_queue:
C239  A2 1E     LDX #$1E                     
C23B  8E 01 20  STX $2001                    PPU: mask
C23E  86 2D     STX $2D                      
C240  60        RTS                          

; subroutine entry
ppu_rendering_off:
C241  A2 00     LDX #$00                     
C243  8E 01 20  STX $2001                    PPU: mask
C246  86 2D     STX $2D                      
C248  60        RTS                          

; subroutine entry
joypad_shift_bits:
C249  A0 08     LDY #$08                     

; branch target entry
LC24B:
C24B  BD 16 40  LDA $4016,X                  APU/joy1 port
C24E  29 03     AND #$03                     
C250  C9 01     CMP #$01                     
C252  76 10     ROR $10,X                    
C254  88        DEY                          
C255  D0 F4     BNE LC24B                    
C257  60        RTS                          
        .byte $00,$FF,$01,$00                  ; ....

; subroutine entry
cold_boot_check:
C25C  A5 3E     LDA $3E                      
C25E  C9 5A     CMP #$5A                     
C260  D0 45     BNE LC2A7                    
C262  A5 3F     LDA $3F                      
C264  C9 A5     CMP #$A5                     
C266  D0 3F     BNE LC2A7                    
C268  A5 41     LDA $41                      
C26A  F0 03     BEQ LC26F                    
C26C  20 81 CA  JSR LCA81                    

; branch target entry
LC26F:
C26F  20 B3 C2  JSR LC2B3                    
C272  20 E5 C2  JSR clear_ram_0020           
C275  A2 01     LDX #$01                     
C277  B5 00     LDA $00,X                    
C279  E8        INX                          
C27A  85 40     STA $40                      
C27C  B5 00     LDA $00,X                    
C27E  E8        INX                          
C27F  85 41     STA $41                      
C281  B5 00     LDA $00,X                    
C283  E8        INX                          
C284  85 4A     STA $4A                      
C286  B5 00     LDA $00,X                    
C288  E8        INX                          
C289  85 77     STA $77                      
C28B  A0 71     LDY #$71                     
C28D  20 97 C2  JSR LC297                    
C290  A0 B1     LDY #$B1                     
C292  20 97 C2  JSR LC297                    
C295  A0 44     LDY #$44                     

; subroutine entry
sub_C297:
C297  A9 04     LDA #$04                     
C299  85 00     STA $00                      

; branch target entry
LC29B:
C29B  B5 00     LDA $00,X                    
C29D  E8        INX                          
C29E  99 00 00  STA $0000,Y                  
C2A1  C8        INY                          
C2A2  C6 00     DEC $00                      
C2A4  D0 F5     BNE LC29B                    
C2A6  60        RTS                          

; branch target entry
LC2A7:
C2A7  20 E5 C2  JSR clear_ram_0020           
C2AA  A9 02     LDA #$02                     
C2AC  85 45     STA $45                      
C2AE  A9 01     LDA #$01                     
C2B0  85 77     STA $77                      
C2B2  60        RTS                          

; subroutine entry
sub_C2B3:
C2B3  A2 01     LDX #$01                     
C2B5  A5 40     LDA $40                      
C2B7  95 00     STA $00,X                    
C2B9  E8        INX                          
C2BA  A5 41     LDA $41                      
C2BC  95 00     STA $00,X                    
C2BE  E8        INX                          
C2BF  A5 4A     LDA $4A                      
C2C1  95 00     STA $00,X                    
C2C3  E8        INX                          
C2C4  A5 77     LDA $77                      
C2C6  95 00     STA $00,X                    
C2C8  E8        INX                          
C2C9  A0 71     LDY #$71                     
C2CB  20 D5 C2  JSR LC2D5                    
C2CE  A0 B1     LDY #$B1                     
C2D0  20 D5 C2  JSR LC2D5                    
C2D3  A0 44     LDY #$44                     

; subroutine entry
sub_C2D5:
C2D5  A9 04     LDA #$04                     
C2D7  85 00     STA $00                      

; branch target entry
LC2D9:
C2D9  B9 00 00  LDA $0000,Y                  
C2DC  C8        INY                          
C2DD  95 00     STA $00,X                    
C2DF  E8        INX                          
C2E0  C6 00     DEC $00                      
C2E2  D0 F5     BNE LC2D9                    
C2E4  60        RTS                          

; subroutine entry
clear_ram_0020:
C2E5  A2 20     LDX #$20                     
C2E7  A9 00     LDA #$00                     

; branch target entry
LC2E9:
C2E9  95 00     STA $00,X                    
C2EB  E8        INX                          
C2EC  D0 FB     BNE LC2E9                    
C2EE  60        RTS                          

; NMI entry
nmi_handler:
C2EF  08        PHP                          
C2F0  48        PHA                          
C2F1  8A        TXA                          
C2F2  48        PHA                          
C2F3  98        TYA                          
C2F4  48        PHA                          
C2F5  A5 20     LDA $20                      
C2F7  F0 03     BEQ LC2FC                    
C2F9  20 F1 F4  JSR apu_engine               

; branch target entry
LC2FC:
C2FC  E6 20     INC $20                      
C2FE  68        PLA                          
C2FF  A8        TAY                          
C300  68        PLA                          
C301  AA        TAX                          
C302  68        PLA                          
C303  28        PLP                          

; IRQ/BRK entry
irq_handler:
C304  40        RTI                          
C305  A5 2C     LDA $2C                      
C307  48        PHA                          
C308  A0 00     LDY #$00                     
C30A  84 11     STY $11                      
C30C  B1 1E     LDA ($1E),Y                  
C30E  C8        INY                          
C30F  38        SEC                          
C310  E5 28     SBC $28                      
C312  85 10     STA $10                      
C314  B1 1E     LDA ($1E),Y                  
C316  C8        INY                          
C317  E5 29     SBC $29                      
C319  06 10     ASL $10                      
C31B  2A        ROL A                        
C31C  06 10     ASL $10                      
C31E  2A        ROL A                        
C31F  06 10     ASL $10                      
C321  2A        ROL A                        
C322  90 02     BCC LC326                    
C324  C6 11     DEC $11                      
C326  85 10     STA $10                      
C328  B1 1E     LDA ($1E),Y                  
C32A  C8        INY                          
C32B  85 16     STA $16                      
C32D  B1 1E     LDA ($1E),Y                  
C32F  C8        INY                          
C330  06 16     ASL $16                      
C332  2A        ROL A                        
C333  06 16     ASL $16                      
C335  2A        ROL A                        
C336  06 16     ASL $16                      
C338  2A        ROL A                        
C339  85 16     STA $16                      
C33B  20 42 C3  JSR LC342                    
C33E  68        PLA                          
C33F  C5 2C     CMP $2C                      
C341  60        RTS                          
C342  B1 1E     LDA ($1E),Y                  
C344  85 15     STA $15                      
C346  29 FE     AND #$FE                     
C348  AA        TAX                          
C349  BD 56 C3  LDA $C356,X                  
C34C  85 1C     STA $1C                      
C34E  BD 57 C3  LDA $C357,X                  
C351  85 1D     STA $1D                      
C353  6C 1C 00  JMP ($001C)                  
        .byte $4F,$C1,$C0,$C3,$A8,$C4,$B0,$C4  ; O.......
        .byte $C6,$C4,$F5,$C4,$18,$C5,$10,$C5  ; ........
        .byte $21,$C5,$A3,$C5,$B2,$C5,$F6,$C5  ; !.......
        .byte $1E,$C6,$4F,$C1,$87,$C6,$AC,$C6  ; ..O.....
        .byte $C1,$C6,$7C,$C3,$A7,$C3,$A9,$AE  ; ..|.....
        .byte $85,$12,$A9,$00,$85,$14,$A9,$03  ; ........
        .byte $85,$13,$A5,$1E,$C9,$20,$D0,$04  ; ..... ..
        .byte $A9,$66,$85,$12,$20,$15,$C4,$A9  ; .f.. ...
        .byte $67,$85,$12,$A5,$10,$18,$69,$08  ; g.....i.
        .byte $85,$10,$90,$02,$E6,$11,$4C,$15  ; ......L.
        .byte $C4,$A0,$07,$B1,$1E,$29,$08,$F0  ; .....)..
        .byte $10,$A9,$06,$4C,$44,$C3          ; ...LD.

; reachable via computed jump entry
dyn_C3B4:
C3B4  A0 05     LDY #$05                     
C3B6  B1 1E     LDA ($1E),Y                  
C3B8  AA        TAX                          
C3B9  BD 7C C4  LDA $C47C,X                  
C3BC  85 13     STA $13                      
C3BE  8A        TXA                          
C3BF  60        RTS                          
C3C0  20 B4 C3  JSR LC3B4                    
C3C3  0A        ASL A                        
C3C4  0A        ASL A                        
C3C5  85 12     STA $12                      
C3C7  A0 07     LDY #$07                     
C3C9  B1 1E     LDA ($1E),Y                  
C3CB  4A        LSR A                        
C3CC  4A        LSR A                        
C3CD  29 03     AND #$03                     
C3CF  05 12     ORA $12                      
C3D1  AA        TAX                          
C3D2  BD 80 C4  LDA $C480,X                  
C3D5  85 12     STA $12                      
C3D7  A0 06     LDY #$06                     
C3D9  B1 1E     LDA ($1E),Y                  
C3DB  30 06     BMI LC3E3                    
C3DD  A5 13     LDA $13                      
C3DF  49 40     EOR #$40                     
C3E1  85 13     STA $13                      
C3E3  A5 13     LDA $13                      
C3E5  2A        ROL A                        
C3E6  2A        ROL A                        
C3E7  2A        ROL A                        
C3E8  29 03     AND #$03                     
C3EA  85 14     STA $14                      
C3EC  20 01 C4  JSR LC401                    
C3EF  A5 10     LDA $10                      
C3F1  38        SEC                          
C3F2  E9 08     SBC #$08                     
C3F4  85 10     STA $10                      
C3F6  B0 02     BCS LC3FA                    
C3F8  C6 11     DEC $11                      
C3FA  A5 16     LDA $16                      
C3FC  18        CLC                          
C3FD  69 08     ADC #$08                     
C3FF  85 16     STA $16                      
C401  20 0F C4  JSR LC40F                    
C404  A5 10     LDA $10                      
C406  18        CLC                          
C407  69 08     ADC #$08                     
C409  85 10     STA $10                      
C40B  90 02     BCC LC40F                    
C40D  E6 11     INC $11                      
C40F  20 15 C4  JSR LC415                    
C412  E6 12     INC $12                      
C414  60        RTS                          
C415  A5 11     LDA $11                      
C417  D0 3B     BNE LC454                    
C419  A5 10     LDA $10                      
C41B  C9 F9     CMP #$F9                     
C41D  B0 35     BCS LC454                    
C41F  A6 2C     LDX $2C                      
C421  E0 34     CPX #$34                     
C423  90 0E     BCC LC433                    
C425  A5 21     LDA $21                      
C427  29 0F     AND #$0F                     
C429  A8        TAY                          
C42A  8A        TXA                          
C42B  59 55 C4  EOR $C455,Y                  
C42E  C9 34     CMP #$34                     
C430  90 01     BCC LC433                    
C432  AA        TAX                          
C433  A5 16     LDA $16                      
C435  38        SEC                          
C436  E9 01     SBC #$01                     
C438  9D 00 07  STA $0700,X                  
C43B  A5 12     LDA $12                      
C43D  45 14     EOR $14                      
C43F  9D 01 07  STA $0701,X                  
C442  20 65 C4  JSR LC465                    
C445  9D 02 07  STA $0702,X                  
C448  A5 10     LDA $10                      
C44A  9D 03 07  STA $0703,X                  
C44D  A5 2C     LDA $2C                      
C44F  18        CLC                          
C450  69 04     ADC #$04                     
C452  85 2C     STA $2C                      
C454  60        RTS                          
        .byte $00,$F0,$20,$D0,$40,$B0,$60,$90  ; .. .@.`.
        .byte $80,$70,$A0,$50,$C0,$30,$E0,$10  ; .p.P.0..

; reachable via computed jump entry
dyn_C465:
C465  A5 7C     LDA $7C                      
C467  D0 10     BNE LC479                    
C469  A5 15     LDA $15                      
C46B  4A        LSR A                        
C46C  B0 06     BCS LC474                    
C46E  A5 16     LDA $16                      
C470  C9 40     CMP #$40                     
C472  B0 05     BCS LC479                    
C474  A5 13     LDA $13                      
C476  09 20     ORA #$20                     
C478  60        RTS                          
C479  A5 13     LDA $13                      
C47B  60        RTS                          
        .byte $00,$02,$02,$01,$04,$00,$04,$00  ; ........
        .byte $74,$78,$7C,$A4,$34,$38,$34,$30  ; tx|.4840
        .byte $1C,$18,$1C,$18,$10,$74,$48,$28  ; .....tH(
        .byte $08,$0C,$08,$0C,$74,$78,$7C,$A4  ; ....tx|.
        .byte $40,$44,$40,$44,$20,$24,$20,$24  ; @D@D $ $
        .byte $14,$A8,$4C,$2C                  ; ..L,

; reachable via computed jump entry
dyn_C4A8:
C4A8  20 B4 C3  JSR LC3B4                    
C4AB  09 10     ORA #$10                     
C4AD  4C D1 C3  JMP LC3D1                    
C4B0  20 B4 C3  JSR LC3B4                    
C4B3  0A        ASL A                        
C4B4  0A        ASL A                        
C4B5  69 14     ADC #$14                     
C4B7  85 12     STA $12                      
C4B9  A0 07     LDY #$07                     
C4BB  B1 1E     LDA ($1E),Y                  
C4BD  29 0C     AND #$0C                     
C4BF  4A        LSR A                        
C4C0  4A        LSR A                        
C4C1  05 12     ORA $12                      
C4C3  4C D1 C3  JMP LC3D1                    
C4C6  A5 21     LDA $21                      
C4C8  4A        LSR A                        
C4C9  29 03     AND #$03                     
C4CB  85 13     STA $13                      
C4CD  A9 50     LDA #$50                     
C4CF  85 12     STA $12                      
C4D1  A0 06     LDY #$06                     
C4D3  B1 1E     LDA ($1E),Y                  
C4D5  30 06     BMI LC4DD                    
C4D7  A5 13     LDA $13                      
C4D9  09 40     ORA #$40                     
C4DB  85 13     STA $13                      
C4DD  20 E3 C3  JSR LC3E3                    
C4E0  A5 10     LDA $10                      
C4E2  38        SEC                          
C4E3  E9 08     SBC #$08                     
C4E5  85 10     STA $10                      
C4E7  B0 02     BCS LC4EB                    
C4E9  C6 11     DEC $11                      
C4EB  A5 16     LDA $16                      
C4ED  18        CLC                          
C4EE  69 08     ADC #$08                     
C4F0  85 16     STA $16                      
C4F2  4C E3 C3  JMP LC3E3                    
        .byte $A9,$3C,$85,$12,$A0,$05,$B1,$1E  ; .<......
        .byte $C9,$01,$D0,$08,$A0,$41,$A5,$21  ; .....A.!
        .byte $29,$10,$D0,$02,$A0,$01,$84,$13  ; ).......
        .byte $4C,$E3,$C3                      ; L..

; reachable via computed jump entry
dyn_C510:
C510  A0 07     LDY #$07                     
C512  B1 1E     LDA ($1E),Y                  
C514  29 08     AND #$08                     
C516  D0 08     BNE LC520                    
C518  20 B4 C3  JSR LC3B4                    
C51B  09 24     ORA #$24                     
C51D  4C D1 C3  JMP LC3D1                    
C520  60        RTS                          
C521  A5 21     LDA $21                      
C523  4A        LSR A                        
C524  29 03     AND #$03                     
C526  85 13     STA $13                      
C528  A9 00     LDA #$00                     
C52A  85 14     STA $14                      
C52C  A0 07     LDY #$07                     
C52E  B1 1E     LDA ($1E),Y                  
C530  08        PHP                          
C531  0A        ASL A                        
C532  AA        TAX                          
C533  20 40 C5  JSR LC540                    
C536  A2 28     LDX #$28                     
C538  20 40 C5  JSR LC540                    
C53B  28        PLP                          
C53C  10 24     BPL LC562                    
C53E  A2 2C     LDX #$2C                     
C540  20 43 C5  JSR LC543                    
C543  20 63 C5  JSR LC563                    
C546  A5 16     LDA $16                      
C548  18        CLC                          
C549  69 08     ADC #$08                     
C54B  85 16     STA $16                      
C54D  20 63 C5  JSR LC563                    
C550  A5 16     LDA $16                      
C552  38        SEC                          
C553  E9 08     SBC #$08                     
C555  85 16     STA $16                      
C557  A5 10     LDA $10                      
C559  18        CLC                          
C55A  69 08     ADC #$08                     
C55C  85 10     STA $10                      
C55E  90 02     BCC LC562                    
C560  E6 11     INC $11                      
C562  60        RTS                          
C563  BD 73 C5  LDA $C573,X                  
C566  F0 09     BEQ LC571                    
C568  85 12     STA $12                      
C56A  86 17     STX $17                      
C56C  20 15 C4  JSR LC415                    
C56F  A6 17     LDX $17                      
C571  E8        INX                          
C572  60        RTS                          
        .byte $00,$00,$58,$5C,$00,$00,$5E,$5F  ; ..X\..^_
        .byte $00,$00,$58,$64,$5A,$5B,$58,$5C  ; ..XdZ[X\
        .byte $5A,$5B,$62,$63,$58,$5C,$58,$59  ; Z[bcX\XY
        .byte $58,$5D,$58,$59,$5E,$5F,$58,$59  ; X]XY^_XY
        .byte $60,$61,$58,$59,$62,$63,$58,$59  ; `aXYbcXY
        .byte $58,$59,$58,$59,$00,$65,$58,$5C  ; XYXY.eX\

; reachable via computed jump entry
dyn_C5A3:
C5A3  A9 02     LDA #$02                     
C5A5  85 13     STA $13                      
C5A7  A9 70     LDA #$70                     
C5A9  85 12     STA $12                      
C5AB  A9 00     LDA #$00                     
C5AD  85 14     STA $14                      
C5AF  4C EC C3  JMP LC3EC                    
C5B2  A9 02     LDA #$02                     
C5B4  85 13     STA $13                      
C5B6  A9 00     LDA #$00                     
C5B8  85 14     STA $14                      
C5BA  A9 69     LDA #$69                     
C5BC  85 12     STA $12                      
C5BE  A5 10     LDA $10                      
C5C0  38        SEC                          
C5C1  E9 08     SBC #$08                     
C5C3  85 10     STA $10                      
C5C5  B0 02     BCS LC5C9                    
C5C7  C6 11     DEC $11                      
C5C9  A5 16     LDA $16                      
C5CB  38        SEC                          
C5CC  E9 08     SBC #$08                     
C5CE  85 16     STA $16                      
C5D0  20 01 C4  JSR LC401                    
C5D3  A5 10     LDA $10                      
C5D5  38        SEC                          
C5D6  E9 08     SBC #$08                     
C5D8  85 10     STA $10                      
C5DA  B0 02     BCS LC5DE                    
C5DC  C6 11     DEC $11                      
C5DE  A5 16     LDA $16                      
C5E0  18        CLC                          
C5E1  69 08     ADC #$08                     
C5E3  85 16     STA $16                      
C5E5  20 0F C4  JSR LC40F                    
C5E8  A5 10     LDA $10                      
C5EA  18        CLC                          
C5EB  69 08     ADC #$08                     
C5ED  85 10     STA $10                      
C5EF  90 02     BCC LC5F3                    
C5F1  E6 11     INC $11                      
C5F3  4C EC C3  JMP LC3EC                    
C5F6  A9 00     LDA #$00                     
C5F8  85 13     STA $13                      
C5FA  A0 07     LDY #$07                     
C5FC  B1 1E     LDA ($1E),Y                  
C5FE  0A        ASL A                        
C5FF  30 13     BMI LC614                    
C601  29 0C     AND #$0C                     
C603  09 80     ORA #$80                     
C605  85 12     STA $12                      
C607  B1 1E     LDA ($1E),Y                  
C609  29 08     AND #$08                     
C60B  F0 04     BEQ LC611                    
C60D  A9 C0     LDA #$C0                     
C60F  85 13     STA $13                      
C611  4C D7 C3  JMP LC3D7                    
C614  4A        LSR A                        
C615  29 04     AND #$04                     
C617  09 90     ORA #$90                     
C619  85 12     STA $12                      
C61B  4C D7 C3  JMP LC3D7                    
        .byte $A9,$02,$85,$13,$A9,$00,$85,$14  ; ........
        .byte $A5,$21,$29,$20,$F0,$11,$A9,$E8  ; .!) ....
        .byte $85,$12,$20,$4C,$C6,$A5,$16,$38  ; .. L...8
        .byte $E9,$08,$85,$16,$4C,$15,$C4      ; ....L..

; subroutine entry
sub_C63D:
C63D  A9 DD     LDA #$DD                     
C63F  85 12     STA $12                      
C641  A5 10     LDA $10                      
C643  38        SEC                          
C644  E9 06     SBC #$06                     
C646  85 10     STA $10                      
C648  B0 02     BCS LC64C                    
C64A  C6 11     DEC $11                      

; branch target entry
LC64C:
C64C  A9 03     LDA #$03                     
C64E  85 18     STA $18                      

; branch target entry
LC650:
C650  20 5C C6  JSR LC65C                    
C653  C6 18     DEC $18                      
C655  D0 F9     BNE LC650                    
C657  A9 02     LDA #$02                     
C659  4C 5E C6  JMP LC65E                    

; subroutine entry
sub_C65C:
C65C  A9 03     LDA #$03                     

; jump target entry
jmp_C65E:
C65E  85 17     STA $17                      

; branch target entry
LC660:
C660  20 15 C4  JSR LC415                    
C663  A5 10     LDA $10                      
C665  18        CLC                          
C666  69 08     ADC #$08                     
C668  85 10     STA $10                      
C66A  90 02     BCC LC66E                    
C66C  E6 11     INC $11                      

; branch target entry
LC66E:
C66E  E6 12     INC $12                      
C670  C6 17     DEC $17                      
C672  D0 EC     BNE LC660                    
C674  A5 10     LDA $10                      
C676  38        SEC                          
C677  E9 18     SBC #$18                     
C679  85 10     STA $10                      
C67B  B0 02     BCS LC67F                    
C67D  C6 11     DEC $11                      

; branch target entry
LC67F:
C67F  A5 16     LDA $16                      
C681  18        CLC                          
C682  69 08     ADC #$08                     
C684  85 16     STA $16                      
C686  60        RTS                          
C687  A9 02     LDA #$02                     
C689  85 13     STA $13                      
C68B  A9 00     LDA #$00                     
C68D  85 14     STA $14                      
C68F  A9 F4     LDA #$F4                     
C691  85 12     STA $12                      
C693  A9 08     LDA #$08                     
C695  85 17     STA $17                      
C697  20 15 C4  JSR LC415                    
C69A  A5 10     LDA $10                      
C69C  18        CLC                          
C69D  69 08     ADC #$08                     
C69F  85 10     STA $10                      
C6A1  90 02     BCC LC6A5                    
C6A3  E6 11     INC $11                      
C6A5  E6 12     INC $12                      
C6A7  C6 17     DEC $17                      
C6A9  D0 EC     BNE LC697                    
C6AB  60        RTS                          
C6AC  A0 07     LDY #$07                     
C6AE  B1 1E     LDA ($1E),Y                  
C6B0  C9 08     CMP #$08                     
C6B2  A9 98     LDA #$98                     
C6B4  90 02     BCC LC6B8                    
C6B6  A9 9C     LDA #$9C                     
C6B8  85 12     STA $12                      
C6BA  A9 00     LDA #$00                     
C6BC  85 13     STA $13                      
C6BE  4C D7 C3  JMP LC3D7                    
        .byte $A5,$1E,$C9,$20,$90,$05,$D0,$0E  ; ... ....
        .byte $4C,$B2,$C5,$A9,$A8,$85,$12,$A9  ; L.......
        .byte $02,$85,$13,$4C,$D7,$C3,$A9,$2C  ; ...L...,
        .byte $85,$12,$A9,$01,$85,$13,$20,$D7  ; ...... .
        .byte $C3,$A5,$16,$38,$E9,$10,$85,$16  ; ...8....
        .byte $A9,$AE,$85,$12,$A9,$03,$85,$13  ; ........
        .byte $20,$4D,$E8,$A9,$67,$85,$12,$4C  ;  M..g..L
        .byte $4D,$E8                          ; M.

; reachable via computed jump entry
dyn_C6FB:
C6FB  A0 00     LDY #$00                     
C6FD  B1 12     LDA ($12),Y                  
C6FF  D0 16     BNE LC717                    
C701  C8        INY                          
C702  B1 12     LDA ($12),Y                  
C704  F0 10     BEQ LC716                    
C706  10 02     BPL LC70A                    
C708  C6 11     DEC $11                      
C70A  C8        INY                          
C70B  18        CLC                          
C70C  65 10     ADC $10                      
C70E  85 10     STA $10                      
C710  90 EB     BCC LC6FD                    
C712  E6 11     INC $11                      
C714  B0 E7     BCS LC6FD                    
C716  60        RTS                          
C717  C8        INY                          
C718  85 15     STA $15                      
C71A  85 16     STA $16                      
C71C  20 8E C7  JSR LC78E                    
C71F  A5 14     LDA $14                      
C721  30 5E     BMI LC781                    
C723  A5 10     LDA $10                      
C725  85 17     STA $17                      
C727  A5 11     LDA $11                      
C729  85 18     STA $18                      
C72B  06 17     ASL $17                      
C72D  26 18     ROL $18                      
C72F  06 17     ASL $17                      
C731  2A        ROL A                        
C732  06 17     ASL $17                      
C734  06 17     ASL $17                      
C736  26 18     ROL $18                      
C738  06 17     ASL $17                      
C73A  26 18     ROL $18                      
C73C  06 17     ASL $17                      
C73E  26 18     ROL $18                      
C740  06 17     ASL $17                      
C742  2A        ROL A                        
C743  29 03     AND #$03                     
C745  AA        TAX                          
C746  A5 14     LDA $14                      
C748  85 17     STA $17                      
C74A  A9 03     LDA #$03                     
C74C  E8        INX                          
C74D  CA        DEX                          
C74E  F0 09     BEQ LC759                    
C750  0A        ASL A                        
C751  0A        ASL A                        
C752  06 17     ASL $17                      
C754  06 17     ASL $17                      
C756  CA        DEX                          
C757  D0 F7     BNE LC750                    
C759  A6 18     LDX $18                      
C75B  49 FF     EOR #$FF                     
C75D  3D 80 01  AND $0180,X                  
C760  05 17     ORA $17                      
C762  9D 80 01  STA $0180,X                  
C765  46 18     LSR $18                      
C767  46 18     LSR $18                      
C769  46 18     LSR $18                      
C76B  8A        TXA                          
C76C  29 07     AND #$07                     
C76E  AA        TAX                          
C76F  A9 01     LDA #$01                     
C771  E8        INX                          
C772  CA        DEX                          
C773  F0 04     BEQ LC779                    
C775  0A        ASL A                        
C776  CA        DEX                          
C777  D0 FC     BNE LC775                    
C779  A6 18     LDX $18                      
C77B  1D 70 01  ORA $0170,X                  
C77E  9D 70 01  STA $0170,X                  
C781  E6 10     INC $10                      
C783  D0 02     BNE LC787                    
C785  E6 11     INC $11                      
C787  C6 16     DEC $16                      
C789  D0 94     BNE LC71F                    
C78B  4C 02 C7  JMP LC702                    
C78E  A5 2D     LDA $2D                      
C790  F0 22     BEQ LC7B4                    
C792  A6 2A     LDX $2A                      
C794  A5 10     LDA $10                      
C796  9D 00 05  STA $0500,X                  
C799  E8        INX                          
C79A  A5 11     LDA $11                      
C79C  9D 00 05  STA $0500,X                  
C79F  E8        INX                          
C7A0  A5 15     LDA $15                      
C7A2  9D 00 05  STA $0500,X                  
C7A5  E8        INX                          
C7A6  B1 12     LDA ($12),Y                  
C7A8  C8        INY                          
C7A9  9D 00 05  STA $0500,X                  
C7AC  E8        INX                          
C7AD  C6 15     DEC $15                      
C7AF  D0 F5     BNE LC7A6                    
C7B1  86 2A     STX $2A                      
C7B3  60        RTS                          
C7B4  A5 11     LDA $11                      
C7B6  8D 06 20  STA $2006                    PPU: VRAM address
C7B9  A5 10     LDA $10                      
C7BB  8D 06 20  STA $2006                    PPU: VRAM address
C7BE  B1 12     LDA ($12),Y                  
C7C0  C8        INY                          
C7C1  8D 07 20  STA $2007                    PPU: VRAM data
C7C4  C6 15     DEC $15                      
C7C6  D0 F6     BNE LC7BE                    
C7C8  60        RTS                          

; subroutine entry
write_attribute_table:
C7C9  A9 00     LDA #$00                     
C7CB  85 12     STA $12                      
C7CD  85 13     STA $13                      
C7CF  A9 C0     LDA #$C0                     
C7D1  85 10     STA $10                      
C7D3  A9 23     LDA #$23                     
C7D5  85 11     STA $11                      
C7D7  20 E2 C7  JSR write_attribute_page     
C7DA  A9 C0     LDA #$C0                     
C7DC  85 10     STA $10                      
C7DE  A9 27     LDA #$27                     
C7E0  85 11     STA $11                      

; subroutine entry
write_attribute_page:
C7E2  A9 08     LDA #$08                     
C7E4  85 14     STA $14                      

; branch target entry
LC7E6:
C7E6  A9 08     LDA #$08                     
C7E8  85 15     STA $15                      

; jump target entry
jmp_C7EA:
C7EA  A4 12     LDY $12                      
C7EC  B9 70 01  LDA $0170,Y                  
C7EF  F0 12     BEQ LC803                    
C7F1  4A        LSR A                        
C7F2  99 70 01  STA $0170,Y                  
C7F5  90 03     BCC LC7FA                    
C7F7  20 18 C8  JSR LC818                    

; branch target entry
LC7FA:
C7FA  E6 10     INC $10                      
C7FC  E6 13     INC $13                      
C7FE  C6 15     DEC $15                      
C800  4C EA C7  JMP LC7EA                    

; branch target entry
LC803:
C803  A5 10     LDA $10                      
C805  18        CLC                          
C806  65 15     ADC $15                      
C808  85 10     STA $10                      
C80A  A5 13     LDA $13                      
C80C  18        CLC                          
C80D  65 15     ADC $15                      
C80F  85 13     STA $13                      
C811  E6 12     INC $12                      
C813  C6 14     DEC $14                      
C815  D0 CF     BNE LC7E6                    
C817  60        RTS                          

; subroutine entry
sub_C818:
C818  A5 2D     LDA $2D                      
C81A  F0 20     BEQ LC83C                    
C81C  A6 2A     LDX $2A                      
C81E  A5 10     LDA $10                      
C820  9D 00 05  STA $0500,X                  
C823  E8        INX                          
C824  A5 11     LDA $11                      
C826  9D 00 05  STA $0500,X                  
C829  E8        INX                          
C82A  A9 01     LDA #$01                     
C82C  9D 00 05  STA $0500,X                  
C82F  E8        INX                          
C830  A4 13     LDY $13                      
C832  B9 80 01  LDA $0180,Y                  
C835  9D 00 05  STA $0500,X                  
C838  E8        INX                          
C839  86 2A     STX $2A                      
C83B  60        RTS                          

; branch target entry
LC83C:
C83C  A5 11     LDA $11                      
C83E  8D 06 20  STA $2006                    PPU: VRAM address
C841  A5 10     LDA $10                      
C843  8D 06 20  STA $2006                    PPU: VRAM address
C846  A4 13     LDY $13                      
C848  B9 80 01  LDA $0180,Y                  
C84B  8D 07 20  STA $2007                    PPU: VRAM data
C84E  60        RTS                          
C84F  A9 00     LDA #$00                     
C851  85 42     STA $42                      
C853  20 BF F4  JSR LF4BF                    
C856  A5 41     LDA $41                      
C858  F0 03     BEQ LC85D                    
C85A  20 81 CA  JSR LCA81                    
C85D  85 75     STA $75                      
C85F  A9 02     LDA #$02                     
C861  85 76     STA $76                      
C863  A9 FF     LDA #$FF                     
C865  85 48     STA $48                      
C867  A9 07     LDA #$07                     
C869  85 49     STA $49                      
C86B  A9 03     LDA #$03                     
C86D  85 70     STA $70                      
C86F  A2 20     LDX #$20                     
C871  A9 00     LDA #$00                     
C873  95 70     STA $70,X                    
C875  E8        INX                          
C876  E0 40     CPX #$40                     
C878  D0 F9     BNE LC873                    
C87A  20 41 C2  JSR ppu_rendering_off        
C87D  20 B1 CB  JSR LCBB1                    
C880  20 39 C2  JSR clear_update_queue       
C883  A9 00     LDA #$00                     
C885  85 28     STA $28                      
C887  85 29     STA $29                      
C889  20 2B CD  JSR LCD2B                    
C88C  A9 F0     LDA #$F0                     
C88E  85 0F     STA $0F                      
C890  20 41 C1  JSR stack_frame_swap         
C893  20 3E CD  JSR LCD3E                    
C896  EA        NOP                          
C897  EA        NOP                          
C898  EA        NOP                          
C899  20 3E D7  JSR LD73E                    
C89C  A5 25     LDA $25                      
C89E  29 03     AND #$03                     
C8A0  C9 01     CMP #$01                     
C8A2  F0 07     BEQ start_game_setup         
C8A4  C6 0F     DEC $0F                      
C8A6  D0 E8     BNE LC890                    
C8A8  4C 65 FF  JMP LFF65                    
C8AB  A9 01     LDA #$01                     
C8AD  85 42     STA $42                      
C8AF  A5 4A     LDA $4A                      
C8B1  85 40     STA $40                      
C8B3  A9 00     LDA #$00                     
C8B5  85 41     STA $41                      
C8B7  85 71     STA $71                      
C8B9  85 72     STA $72                      
C8BB  85 73     STA $73                      
C8BD  85 74     STA $74                      
C8BF  85 7A     STA $7A                      
C8C1  85 7D     STA $7D                      
C8C3  A9 01     LDA #$01                     
C8C5  85 77     STA $77                      
C8C7  A2 00     LDX #$00                     
C8C9  B5 70     LDA $70,X                    
C8CB  95 B0     STA $B0,X                    
C8CD  E8        INX                          
C8CE  E0 20     CPX #$20                     
C8D0  D0 F7     BNE LC8C9                    
C8D2  C6 70     DEC $70                      
C8D4  20 A7 CA  JSR LCAA7                    
C8D7  20 41 C2  JSR ppu_rendering_off        
C8DA  20 49 CD  JSR LCD49                    
C8DD  20 5B E3  JSR LE35B                    
C8E0  20 C5 E5  JSR LE5C5                    
C8E3  20 62 E8  JSR LE862                    
C8E6  20 01 F0  JSR LF001                    
C8E9  20 39 C2  JSR clear_update_queue       
C8EC  A2 00     LDX #$00                     
C8EE  BD 00 02  LDA $0200,X                  
C8F1  9D 00 03  STA $0300,X                  
C8F4  E8        INX                          
C8F5  D0 F7     BNE LC8EE                    
C8F7  A2 01     LDX #$01                     
C8F9  B5 70     LDA $70,X                    
C8FB  95 B0     STA $B0,X                    
C8FD  E8        INX                          
C8FE  E0 40     CPX #$40                     
C900  D0 F7     BNE LC8F9                    
C902  20 C1 F3  JSR LF3C1                    
C905  20 F1 D7  JSR LD7F1                    
C908  20 46 D8  JSR LD846                    
C90B  A9 00     LDA #$00                     
C90D  85 4B     STA $4B                      
C90F  85 4F     STA $4F                      
C911  85 31     STA $31                      
C913  A9 3C     LDA #$3C                     
C915  85 0F     STA $0F                      
C917  20 41 C1  JSR stack_frame_swap         
C91A  20 60 CB  JSR LCB60                    
C91D  20 02 CB  JSR LCB02                    
C920  AD A6 CB  LDA $CBA6                    
C923  85 1E     STA $1E                      
C925  AD A7 CB  LDA $CBA7                    
C928  85 1F     STA $1F                      
C92A  20 3B CB  JSR LCB3B                    
C92D  C6 0F     DEC $0F                      
C92F  D0 E6     BNE LC917                    
C931  A9 02     LDA #$02                     
C933  8D 0F 04  STA $040F                    
C936  A2 20     LDX #$20                     
C938  A9 02     LDA #$02                     
C93A  9D 0F 04  STA $040F,X                  
C93D  8A        TXA                          
C93E  18        CLC                          
C93F  69 10     ADC #$10                     
C941  AA        TAX                          
C942  E4 68     CPX $68                      
C944  D0 F2     BNE LC938                    
C946  20 41 C1  JSR stack_frame_swap         
C949  A5 60     LDA $60                      
C94B  C9 01     CMP #$01                     
C94D  F0 12     BEQ LC961                    
C94F  C9 03     CMP #$03                     
C951  D0 06     BNE LC959                    
C953  A5 61     LDA $61                      
C955  C9 3C     CMP #$3C                     
C957  D0 08     BNE LC961                    
C959  A9 01     LDA #$01                     
C95B  8D 13 06  STA $0613                    
C95E  8D 14 06  STA $0614                    
C961  20 60 CB  JSR LCB60                    
C964  20 E6 F2  JSR LF2E6                    
C967  A5 4F     LDA $4F                      
C969  D0 07     BNE LC972                    
C96B  A5 4B     LDA $4B                      
C96D  F0 D7     BEQ LC946                    
C96F  4C 28 CA  JMP LCA28                    

; branch target entry
LC972:
C972  20 41 C1  JSR stack_frame_swap         
C975  20 60 CB  JSR LCB60                    
C978  AD A5 04  LDA $04A5                    
C97B  0D AD 04  ORA $04AD                    
C97E  D0 F2     BNE LC972                    
C980  A9 B4     LDA #$B4                     
C982  85 0F     STA $0F                      

; branch target entry
LC984:
C984  20 41 C1  JSR stack_frame_swap         
C987  A5 0F     LDA $0F                      
C989  C9 78     CMP #$78                     
C98B  D0 08     BNE LC995                    
C98D  A9 01     LDA #$01                     
C98F  8D 11 06  STA $0611                    
C992  8D 12 06  STA $0612                    

; branch target entry
LC995:
C995  20 60 CB  JSR LCB60                    
C998  C6 0F     DEC $0F                      
C99A  D0 E8     BNE LC984                    
C99C  20 BF F4  JSR LF4BF                    

; jump target entry
jmp_C99F:
C99F  20 E8 D6  JSR LD6E8                    
C9A2  20 A7 CA  JSR LCAA7                    
C9A5  A2 20     LDX #$20                     
C9A7  A9 00     LDA #$00                     

; branch target entry
LC9A9:
C9A9  95 70     STA $70,X                    
C9AB  E8        INX                          
C9AC  E0 40     CPX #$40                     
C9AE  D0 F9     BNE LC9A9                    
C9B0  20 41 C2  JSR ppu_rendering_off        
C9B3  20 49 CD  JSR LCD49                    
C9B6  20 5B E3  JSR LE35B                    
C9B9  A5 7C     LDA $7C                      
C9BB  D0 12     BNE LC9CF                    
C9BD  20 C5 E5  JSR LE5C5                    
C9C0  20 62 E8  JSR LE862                    
C9C3  20 01 F0  JSR LF001                    
C9C6  20 17 EF  JSR LEF17                    
C9C9  20 39 C2  JSR clear_update_queue       
C9CC  4C 02 C9  JMP LC902                    

; branch target entry
LC9CF:
C9CF  20 C1 F3  JSR LF3C1                    
C9D2  20 3A F1  JSR LF13A                    
C9D5  20 39 C2  JSR clear_update_queue       
C9D8  20 0B D8  JSR LD80B                    
C9DB  20 C0 D8  JSR LD8C0                    
C9DE  A9 00     LDA #$00                     
C9E0  85 4B     STA $4B                      
C9E2  85 4F     STA $4F                      
C9E4  A9 AC     LDA #$AC                     
C9E6  85 0F     STA $0F                      
C9E8  A9 08     LDA #$08                     
C9EA  85 0E     STA $0E                      

; branch target entry
LC9EC:
C9EC  20 41 C1  JSR stack_frame_swap         
C9EF  20 7B CB  JSR LCB7B                    
C9F2  A5 4B     LDA $4B                      
C9F4  F0 08     BEQ LC9FE                    
C9F6  AD 2F 04  LDA $042F                    
C9F9  0D 3F 04  ORA $043F                    
C9FC  F0 13     BEQ LCA11                    

; branch target entry
LC9FE:
C9FE  A5 4F     LDA $4F                      
CA00  D0 0F     BNE LCA11                    
CA02  A5 0F     LDA $0F                      
CA04  38        SEC                          
CA05  E9 01     SBC #$01                     
CA07  85 0F     STA $0F                      
CA09  B0 02     BCS LCA0D                    
CA0B  C6 0E     DEC $0E                      

; branch target entry
LCA0D:
CA0D  05 0E     ORA $0E                      
CA0F  D0 DB     BNE LC9EC                    

; branch target entry
LCA11:
CA11  A9 1E     LDA #$1E                     
CA13  85 0F     STA $0F                      

; branch target entry
LCA15:
CA15  20 41 C1  JSR stack_frame_swap         
CA18  20 1C D7  JSR LD71C                    
CA1B  C6 0F     DEC $0F                      
CA1D  D0 F6     BNE LCA15                    
CA1F  20 BF F4  JSR LF4BF                    
CA22  20 1A CE  JSR LCE1A                    
CA25  4C 9F C9  JMP LC99F                    
CA28  20 41 C1  JSR stack_frame_swap         
CA2B  20 60 CB  JSR LCB60                    
CA2E  AD 0F 04  LDA $040F                    
CA31  D0 F5     BNE LCA28                    
CA33  A5 40     LDA $40                      
CA35  D0 0A     BNE LCA41                    
CA37  A5 70     LDA $70                      
CA39  D0 2C     BNE LCA67                    
CA3B  20 C3 CA  JSR LCAC3                    
CA3E  4C 4F C8  JMP title_screen_loop        

; branch target entry
LCA41:
CA41  A5 70     LDA $70                      
CA43  D0 1B     BNE LCA60                    
CA45  20 B4 CA  JSR LCAB4                    
CA48  A5 B0     LDA $B0                      
CA4A  D0 18     BNE LCA64                    
CA4C  A9 3C     LDA #$3C                     
CA4E  85 0F     STA $0F                      

; branch target entry
LCA50:
CA50  20 41 C1  JSR stack_frame_swap         
CA53  20 31 CB  JSR LCB31                    
CA56  20 1C D7  JSR LD71C                    
CA59  C6 0F     DEC $0F                      
CA5B  D0 F3     BNE LCA50                    
CA5D  4C 4F C8  JMP title_screen_loop        

; branch target entry
LCA60:
CA60  A5 B0     LDA $B0                      
CA62  F0 03     BEQ LCA67                    

; branch target entry
LCA64:
CA64  20 81 CA  JSR LCA81                    
CA67  C6 70     DEC $70                      
CA69  20 A7 CA  JSR LCAA7                    
CA6C  20 41 C2  JSR ppu_rendering_off        
CA6F  20 49 CD  JSR LCD49                    
CA72  20 5B E3  JSR LE35B                    
CA75  20 14 E6  JSR LE614                    
CA78  20 B2 E8  JSR LE8B2                    
CA7B  20 39 C2  JSR clear_update_queue       
CA7E  4C 02 C9  JMP LC902                    

; subroutine entry
sub_CA81:
CA81  A5 41     LDA $41                      
CA83  49 01     EOR #$01                     
CA85  85 41     STA $41                      
CA87  A2 00     LDX #$00                     

; branch target entry
LCA89:
CA89  BD 00 02  LDA $0200,X                  
CA8C  BC 00 03  LDY $0300,X                  
CA8F  9D 00 03  STA $0300,X                  
CA92  98        TYA                          
CA93  9D 00 02  STA $0200,X                  
CA96  E8        INX                          
CA97  D0 F0     BNE LCA89                    

; branch target entry
LCA99:
CA99  B5 70     LDA $70,X                    
CA9B  B4 B0     LDY $B0,X                    
CA9D  95 B0     STA $B0,X                    
CA9F  94 70     STY $70,X                    
CAA1  E8        INX                          
CAA2  E0 40     CPX #$40                     
CAA4  D0 F3     BNE LCA99                    
CAA6  60        RTS                          
CAA7  A9 00     LDA #$00                     
CAA9  A2 00     LDX #$00                     
CAAB  9D 00 04  STA $0400,X                  
CAAE  E8        INX                          
CAAF  E0 C0     CPX #$C0                     
CAB1  D0 F8     BNE LCAAB                    
CAB3  60        RTS                          

; subroutine entry
sub_CAB4:
CAB4  A5 B0     LDA $B0                      
CAB6  F0 0B     BEQ LCAC3                    
CAB8  A9 78     LDA #$78                     
CABA  85 0F     STA $0F                      
CABC  A9 00     LDA #$00                     
CABE  85 0E     STA $0E                      
CAC0  4C DA CA  JMP LCADA                    
CAC3  A9 01     LDA #$01                     
CAC5  8D 15 06  STA $0615                    
CAC8  8D 16 06  STA $0616                    
CACB  8D 17 06  STA $0617                    
CACE  A9 00     LDA #$00                     
CAD0  85 42     STA $42                      
CAD2  A9 A4     LDA #$A4                     
CAD4  85 0F     STA $0F                      
CAD6  A9 01     LDA #$01                     
CAD8  85 0E     STA $0E                      
CADA  20 41 C1  JSR stack_frame_swap         
CADD  A5 40     LDA $40                      
CADF  F0 03     BEQ LCAE4                    
CAE1  20 02 CB  JSR LCB02                    
CAE4  20 31 CB  JSR LCB31                    
CAE7  20 1C D7  JSR LD71C                    
CAEA  A5 25     LDA $25                      
CAEC  29 03     AND #$03                     
CAEE  C9 01     CMP #$01                     
CAF0  F0 0F     BEQ LCB01                    
CAF2  A5 0F     LDA $0F                      
CAF4  38        SEC                          
CAF5  E9 01     SBC #$01                     
CAF7  85 0F     STA $0F                      
CAF9  B0 02     BCS LCAFD                    
CAFB  C6 0E     DEC $0E                      
CAFD  05 0E     ORA $0E                      
CAFF  D0 D9     BNE LCADA                    
CB01  60        RTS                          
CB02  AD 8A CB  LDA $CB8A                    
CB05  85 1E     STA $1E                      
CB07  AD 8B CB  LDA $CB8B                    
CB0A  85 1F     STA $1F                      
CB0C  20 3B CB  JSR LCB3B                    
CB0F  A5 41     LDA $41                      
CB11  18        CLC                          
CB12  69 D6     ADC #$D6                     
CB14  F0 0F     BEQ LCB25                    
CB16  85 12     STA $12                      
CB18  A9 02     LDA #$02                     
CB1A  85 13     STA $13                      
CB1C  A9 00     LDA #$00                     
CB1E  85 14     STA $14                      
CB20  85 15     STA $15                      
CB22  20 15 C4  JSR LC415                    
CB25  A5 10     LDA $10                      
CB27  18        CLC                          
CB28  69 08     ADC #$08                     
CB2A  85 10     STA $10                      
CB2C  D0 02     BNE LCB30                    
CB2E  E6 11     INC $11                      
CB30  60        RTS                          
CB31  AD 97 CB  LDA $CB97                    
CB34  85 1E     STA $1E                      
CB36  AD 98 CB  LDA $CB98                    
CB39  85 1F     STA $1F                      
CB3B  A0 00     LDY #$00                     
CB3D  B1 1E     LDA ($1E),Y                  
CB3F  C8        INY                          
CB40  85 10     STA $10                      
CB42  B1 1E     LDA ($1E),Y                  
CB44  C8        INY                          
CB45  85 11     STA $11                      
CB47  B1 1E     LDA ($1E),Y                  
CB49  C8        INY                          
CB4A  85 16     STA $16                      
CB4C  B1 1E     LDA ($1E),Y                  
CB4E  C8        INY                          
CB4F  85 18     STA $18                      
CB51  B1 1E     LDA ($1E),Y                  
CB53  84 17     STY $17                      
CB55  20 14 CB  JSR LCB14                    
CB58  A4 17     LDY $17                      
CB5A  C8        INY                          
CB5B  C6 18     DEC $18                      
CB5D  D0 F2     BNE LCB51                    
CB5F  60        RTS                          
CB60  20 FE E3  JSR LE3FE                    
CB63  20 D8 D8  JSR LD8D8                    
CB66  20 4E ED  JSR LED4E                    
CB69  20 3F EF  JSR LEF3F                    
CB6C  20 34 E6  JSR LE634                    
CB6F  20 CC E8  JSR LE8CC                    
CB72  20 4D F0  JSR LF04D                    
CB75  20 1C D7  JSR LD71C                    
CB78  4C AB D5  JMP LD5AB                    

; subroutine entry
sub_CB7B:
CB7B  20 FE E3  JSR LE3FE                    
CB7E  20 D8 D8  JSR LD8D8                    
CB81  20 8F F1  JSR LF18F                    
CB84  20 1C D7  JSR LD71C                    
CB87  4C AB D5  JMP LD5AB                    
        .byte $8C,$CB,$58,$00,$78,$07,$D0,$D1  ; ..X.x...
        .byte $D2,$D3,$D4,$D5,$00,$99,$CB,$58  ; .......X
        .byte $00,$88,$09,$D8,$D2,$D9,$D4,$00  ; ........
        .byte $DA,$DB,$D4,$D5,$A8,$CB,$60,$00  ; ......`.
        .byte $88,$05,$D5,$D4,$D2,$CA,$D3      ; .......

; reachable via computed jump entry
dyn_CBB1:
CBB1  20 F5 CB  JSR LCBF5                    
CBB4  A0 02     LDY #$02                     
CBB6  20 15 CC  JSR LCC15                    
CBB9  A0 00     LDY #$00                     
CBBB  20 D9 D5  JSR LD5D9                    
CBBE  A0 04     LDY #$04                     
CBC0  20 D9 D5  JSR LD5D9                    
CBC3  A0 08     LDY #$08                     
CBC5  20 D9 D5  JSR LD5D9                    
CBC8  A9 B0     LDA #$B0                     
CBCA  85 10     STA $10                      
CBCC  A0 00     LDY #$00                     
CBCE  A2 14     LDX #$14                     
CBD0  B9 EE CB  LDA $CBEE,Y                  
CBD3  8D 06 20  STA $2006                    PPU: VRAM address
CBD6  B9 ED CB  LDA $CBED,Y                  
CBD9  8D 06 20  STA $2006                    PPU: VRAM address
CBDC  A5 10     LDA $10                      
CBDE  8D 07 20  STA $2007                    PPU: VRAM data
CBE1  E6 10     INC $10                      
CBE3  CA        DEX                          
CBE4  D0 F6     BNE LCBDC                    
CBE6  C8        INY                          
CBE7  C8        INY                          
CBE8  C0 08     CPY #$08                     
CBEA  D0 E2     BNE LCBCE                    
CBEC  60        RTS                          
        .byte $07,$21,$27,$21,$47,$21,$67,$21  ; .!'!G!g!

; reachable via computed jump entry
dyn_CBF5:
CBF5  A9 00     LDA #$00                     
CBF7  85 2A     STA $2A                      
CBF9  85 2B     STA $2B                      
CBFB  A9 20     LDA #$20                     
CBFD  8D 06 20  STA $2006                    PPU: VRAM address
CC00  A9 00     LDA #$00                     
CC02  8D 06 20  STA $2006                    PPU: VRAM address
CC05  A9 00     LDA #$00                     
CC07  A0 08     LDY #$08                     
CC09  A2 00     LDX #$00                     
CC0B  8D 07 20  STA $2007                    PPU: VRAM data
CC0E  CA        DEX                          
CC0F  D0 FA     BNE LCC0B                    
CC11  88        DEY                          
CC12  D0 F7     BNE LCC0B                    
CC14  60        RTS                          
CC15  B9 41 CC  LDA $CC41,Y                  
CC18  85 10     STA $10                      
CC1A  B9 42 CC  LDA $CC42,Y                  
CC1D  85 11     STA $11                      
CC1F  A0 00     LDY #$00                     
CC21  B1 10     LDA ($10),Y                  
CC23  F0 EF     BEQ LCC14                    
CC25  C8        INY                          
CC26  85 12     STA $12                      
CC28  B1 10     LDA ($10),Y                  
CC2A  C8        INY                          
CC2B  AA        TAX                          
CC2C  B1 10     LDA ($10),Y                  
CC2E  C8        INY                          
CC2F  8D 06 20  STA $2006                    PPU: VRAM address
CC32  8E 06 20  STX $2006                    PPU: VRAM address
CC35  B1 10     LDA ($10),Y                  
CC37  C8        INY                          
CC38  8D 07 20  STA $2007                    PPU: VRAM data
CC3B  C6 12     DEC $12                      
CC3D  D0 F6     BNE LCC35                    
CC3F  F0 E0     BEQ LCC21                    
CC41  4B CC     ALR #$CC                     
CC43  60        RTS                          
        .byte $CC,$EF,$CC,$03,$CD,$17,$CD,$11  ; ........
        .byte $4B,$20,$A0,$A1,$A2,$A3,$A4,$A5  ; K ......
        .byte $A6,$A7,$00,$00,$00,$AC,$AD,$00  ; ........
        .byte $00,$00,$AE,$00,$20,$00,$3F,$0F  ; .... .?.
        .byte $30,$16,$21,$0F,$16,$17,$13,$0F  ; 0.!.....
        .byte $27,$29,$13,$0F,$29,$21,$13,$0F  ; ')..)!..
        .byte $10,$11,$36,$0F,$25,$11,$27,$0F  ; ..6.%.'.
        .byte $16,$11,$36,$0F,$30,$30,$30,$06  ; ..6.000.
        .byte $D1,$23,$55,$55,$55,$AA,$FF,$FF  ; .#UUU...
        .byte $15,$45,$20,$A8,$AA,$AB,$00,$00  ; .E .....
        .byte $00,$A0,$A1,$A2,$A3,$A4,$A5,$A6  ; ........
        .byte $A7,$00,$00,$00,$00,$A9,$AA,$AB  ; ........
        .byte $08,$EB,$21,$02,$00,$1A,$16,$0B  ; ..!.....
        .byte $23,$0F,$1C,$09,$2B,$22,$03,$00  ; #...+"..
        .byte $1A,$16,$0B,$23,$0F,$1C,$1D,$01  ; ...#....
        .byte $8B,$22,$27,$16,$E5,$22,$26,$00  ; ."'.."&.
        .byte $02,$0A,$09,$04,$00,$02,$0A,$09  ; ........
        .byte $05,$00,$18,$0B,$17,$0D,$19,$00  ; ........
        .byte $16,$1E,$0E,$25,$13,$27,$23,$0B  ; ...%.'#.
        .byte $16,$16,$00,$1C,$13,$11,$12,$1E  ; ........
        .byte $1D,$00,$1C,$0F,$1D,$0F,$1C,$20  ; ....... 
        .byte $0F,$0E,$00,$10,$00,$3F,$0F,$30  ; .....?.0
        .byte $16,$21,$0F,$16,$36,$17,$0F,$19  ; .!..6...
        .byte $11,$36,$0F,$29,$19,$13,$00,$10  ; .6.)....
        .byte $00,$3F,$0F,$30,$16,$21,$0F,$11  ; .?.0.!..
        .byte $36,$17,$0F,$19,$11,$36,$0F,$29  ; 6....6.)
        .byte $19,$13,$00,$10,$00,$3F,$0F,$30  ; .....?.0
        .byte $16,$21,$0F,$19,$36,$17,$0F,$19  ; .!..6...
        .byte $11,$36,$0F,$29,$19,$13,$00      ; .6.)...

; reachable via computed jump entry
dyn_CD2B:
CD2B  A2 00     LDX #$00                     
CD2D  BD 39 CD  LDA $CD39,X                  
CD30  9D 90 04  STA $0490,X                  
CD33  E8        INX                          
CD34  E0 05     CPX #$05                     
CD36  D0 F5     BNE LCD2D                    
CD38  60        RTS                          
        .byte $00,$0C,$00,$14,$1C              ; .....

; reachable via computed jump entry
dyn_CD3E:
CD3E  A9 90     LDA #$90                     
CD40  85 1E     STA $1E                      
CD42  A9 04     LDA #$04                     
CD44  85 1F     STA $1F                      
CD46  4C 05 C3  JMP LC305                    
CD49  20 F5 CB  JSR LCBF5                    
CD4C  20 03 D7  JSR LD703                    
CD4F  A5 7A     LDA $7A                      
CD51  0A        ASL A                        
CD52  0A        ASL A                        
CD53  85 1F     STA $1F                      
CD55  AA        TAX                          
CD56  BD BF CD  LDA $CDBF,X                  
CD59  85 7C     STA $7C                      
CD5B  F0 30     BEQ LCD8D                    
CD5D  A9 00     LDA #$00                     
CD5F  85 28     STA $28                      
CD61  85 29     STA $29                      
CD63  A0 0C     LDY #$0C                     
CD65  20 26 D1  JSR LD126                    
CD68  20 39 C2  JSR clear_update_queue       
CD6B  A9 01     LDA #$01                     
CD6D  8D 0E 06  STA $060E                    
CD70  8D 0F 06  STA $060F                    
CD73  8D 10 06  STA $0610                    
CD76  A9 D2     LDA #$D2                     
CD78  85 0F     STA $0F                      

; branch target entry
LCD7A:
CD7A  20 41 C1  JSR stack_frame_swap         
CD7D  20 FF CD  JSR LCDFF                    
CD80  C6 0F     DEC $0F                      
CD82  D0 F6     BNE LCD7A                    
CD84  20 41 C2  JSR ppu_rendering_off        
CD87  20 F5 CB  JSR LCBF5                    
CD8A  20 03 D7  JSR LD703                    
CD8D  A0 08     LDY #$08                     
CD8F  20 69 CF  JSR LCF69                    
CD92  A6 1F     LDX $1F                      
CD94  BC C0 CD  LDY $CDC0,X                  
CD97  20 15 CC  JSR LCC15                    
CD9A  A6 1F     LDX $1F                      
CD9C  BC C1 CD  LDY $CDC1,X                  
CD9F  20 69 CF  JSR LCF69                    
CDA2  A6 1F     LDX $1F                      
CDA4  BC C2 CD  LDY $CDC2,X                  
CDA7  20 26 D1  JSR LD126                    
CDAA  A2 00     LDX #$00                     
CDAC  A0 18     LDY #$18                     
CDAE  A9 00     LDA #$00                     
CDB0  20 B7 CD  JSR LCDB7                    
CDB3  A0 78     LDY #$78                     
CDB5  A9 55     LDA #$55                     
CDB7  9D 70 01  STA $0170,X                  
CDBA  E8        INX                          
CDBB  88        DEY                          
CDBC  D0 F9     BNE LCDB7                    
CDBE  60        RTS                          
        .byte $00,$04,$00,$00,$00,$08,$00,$00  ; ........
        .byte $02,$04,$0A,$0A,$00,$06,$02,$02  ; ........
        .byte $00,$04,$02,$02,$00,$08,$02,$02  ; ........
        .byte $04,$04,$0A,$0A,$00,$06,$04,$04  ; ........
        .byte $00,$04,$04,$04,$00,$08,$04,$04  ; ........
        .byte $06,$04,$0A,$0A,$00,$06,$06,$06  ; ........
        .byte $00,$04,$06,$06,$00,$08,$06,$06  ; ........
        .byte $08,$04,$0A,$0A,$00,$06,$00,$00  ; ........

; subroutine entry
sub_CDFF:
CDFF  A9 7C     LDA #$7C                     
CE01  85 10     STA $10                      
CE03  A9 00     LDA #$00                     
CE05  85 11     STA $11                      
CE07  85 14     STA $14                      
CE09  85 15     STA $15                      
CE0B  A9 AA     LDA #$AA                     
CE0D  85 16     STA $16                      
CE0F  A9 CB     LDA #$CB                     
CE11  85 12     STA $12                      
CE13  A9 02     LDA #$02                     
CE15  85 13     STA $13                      
CE17  4C EC C3  JMP LC3EC                    

; subroutine entry
sub_CE1A:
CE1A  A9 00     LDA #$00                     
CE1C  85 28     STA $28                      
CE1E  85 29     STA $29                      
CE20  20 41 C2  JSR ppu_rendering_off        
CE23  20 F5 CB  JSR LCBF5                    
CE26  20 03 D7  JSR LD703                    
CE29  20 39 C2  JSR clear_update_queue       
CE2C  A0 00     LDY #$00                     
CE2E  20 CD CE  JSR LCECD                    
CE31  A9 01     LDA #$01                     
CE33  8D 01 06  STA $0601                    
CE36  8D 18 06  STA $0618                    
CE39  20 BB CE  JSR LCEBB                    
CE3C  A0 04     LDY #$04                     
CE3E  20 CD CE  JSR LCECD                    
CE41  A0 0E     LDY #$0E                     
CE43  20 D9 D5  JSR LD5D9                    
CE46  A0 12     LDY #$12                     
CE48  20 D9 D5  JSR LD5D9                    
CE4B  20 BB CE  JSR LCEBB                    
CE4E  A0 08     LDY #$08                     
CE50  20 CD CE  JSR LCECD                    
CE53  A0 10     LDY #$10                     
CE55  20 D9 D5  JSR LD5D9                    
CE58  A0 14     LDY #$14                     
CE5A  20 D9 D5  JSR LD5D9                    
CE5D  20 94 CE  JSR LCE94                    
CE60  A5 5A     LDA $5A                      
CE62  85 5E     STA $5E                      
CE64  F0 10     BEQ LCE76                    
CE66  A5 52     LDA $52                      
CE68  D0 0C     BNE LCE76                    
CE6A  A0 0C     LDY #$0C                     
CE6C  20 CD CE  JSR LCECD                    
CE6F  A5 5E     LDA $5E                      
CE71  18        CLC                          
CE72  69 50     ADC #$50                     
CE74  85 5E     STA $5E                      

; branch target entry
LCE76:
CE76  20 94 CE  JSR LCE94                    
CE79  A0 10     LDY #$10                     
CE7B  20 CD CE  JSR LCECD                    
CE7E  A0 0A     LDY #$0A                     
CE80  20 E5 D4  JSR LD4E5                    
CE83  A0 16     LDY #$16                     
CE85  20 D9 D5  JSR LD5D9                    
CE88  20 94 CE  JSR LCE94                    
CE8B  A9 01     LDA #$01                     
CE8D  85 43     STA $43                      
CE8F  A0 0C     LDY #$0C                     
CE91  4C E5 D4  JMP LD4E5                    

; subroutine entry
sub_CE94:
CE94  A9 78     LDA #$78                     
CE96  85 0F     STA $0F                      

; branch target entry
LCE98:
CE98  20 41 C1  JSR stack_frame_swap         
CE9B  A9 38     LDA #$38                     
CE9D  85 10     STA $10                      
CE9F  A9 70     LDA #$70                     
CEA1  85 16     STA $16                      
CEA3  A9 00     LDA #$00                     
CEA5  85 11     STA $11                      
CEA7  85 14     STA $14                      
CEA9  A9 02     LDA #$02                     
CEAB  85 13     STA $13                      
CEAD  20 3D C6  JSR LC63D                    
CEB0  20 1C D7  JSR LD71C                    
CEB3  20 AB D5  JSR LD5AB                    
CEB6  C6 0F     DEC $0F                      
CEB8  D0 DE     BNE LCE98                    
CEBA  60        RTS                          

; subroutine entry
sub_CEBB:
CEBB  A9 78     LDA #$78                     
CEBD  85 0F     STA $0F                      

; branch target entry
LCEBF:
CEBF  20 41 C1  JSR stack_frame_swap         
CEC2  20 1C D7  JSR LD71C                    
CEC5  20 AB D5  JSR LD5AB                    
CEC8  C6 0F     DEC $0F                      
CECA  D0 F3     BNE LCEBF                    
CECC  60        RTS                          

; subroutine entry
sub_CECD:
CECD  B9 08 CF  LDA $CF08,Y                  
CED0  85 10     STA $10                      
CED2  B9 09 CF  LDA $CF09,Y                  
CED5  85 11     STA $11                      
CED7  B9 0A CF  LDA $CF0A,Y                  
CEDA  85 12     STA $12                      
CEDC  B9 0B CF  LDA $CF0B,Y                  
CEDF  85 13     STA $13                      
CEE1  A9 80     LDA #$80                     
CEE3  85 14     STA $14                      
CEE5  4C FB C6  JMP LC6FB                    
        .byte $A2,$00,$A9,$00,$95,$04,$E8,$E0  ; ........
        .byte $04,$D0,$F9,$A5,$51,$F0,$04,$A9  ; ....Q...
        .byte $50,$85,$06,$60,$A2,$00,$A9,$00  ; P..`....
        .byte $95,$00,$E8,$E0,$04,$D0,$F9,$60  ; .......`
        .byte $0C,$21,$1C,$CF,$67,$21,$26,$CF  ; .!..g!&.
        .byte $09,$22,$3A,$CF,$86,$22,$48,$CF  ; .":.."H.
        .byte $0D,$23,$5F,$CF,$08,$0F,$0B,$1C  ; .#_.....
        .byte $18,$13,$18,$11,$1D,$00,$02,$28  ; .......(
        .byte $29,$1E,$0E,$2A,$2B,$00,$03,$01  ; )..*+...
        .byte $01,$00,$8B,$00,$00,$00,$00,$00  ; ........
        .byte $8A,$00,$0C,$03,$01,$01,$01,$00  ; ........
        .byte $8B,$00,$00,$00,$00,$00,$8A,$00  ; ........
        .byte $15,$1A,$0F,$1C,$10,$0F,$0D,$1E  ; ........
        .byte $00,$11,$0B,$17,$0F,$00,$00,$8A  ; ........
        .byte $00,$00,$06,$01,$01,$01,$00,$08  ; ........
        .byte $1E,$19,$1E,$0B,$16,$00,$00,$8A  ; ........
        .byte $00                              ; .

; reachable via computed jump entry
dyn_CF69:
CF69  B9 A6 CF  LDA $CFA6,Y                  
CF6C  85 10     STA $10                      
CF6E  B9 A7 CF  LDA $CFA7,Y                  
CF71  85 11     STA $11                      
CF73  A0 00     LDY #$00                     
CF75  B1 10     LDA ($10),Y                  
CF77  F0 2C     BEQ LCFA5                    
CF79  C8        INY                          
CF7A  85 17     STA $17                      
CF7C  B1 10     LDA ($10),Y                  
CF7E  C8        INY                          
CF7F  AA        TAX                          
CF80  B1 10     LDA ($10),Y                  
CF82  C8        INY                          
CF83  8D 06 20  STA $2006                    PPU: VRAM address
CF86  8E 06 20  STX $2006                    PPU: VRAM address
CF89  84 16     STY $16                      
CF8B  B1 10     LDA ($10),Y                  
CF8D  F0 0D     BEQ LCF9C                    
CF8F  C8        INY                          
CF90  AA        TAX                          
CF91  B1 10     LDA ($10),Y                  
CF93  C8        INY                          
CF94  8D 07 20  STA $2007                    PPU: VRAM data
CF97  CA        DEX                          
CF98  D0 FA     BNE LCF94                    
CF9A  F0 EF     BEQ LCF8B                    
CF9C  C8        INY                          
CF9D  C6 17     DEC $17                      
CF9F  F0 D4     BEQ LCF75                    
CFA1  A4 16     LDY $16                      
CFA3  D0 E6     BNE LCF8B                    
CFA5  60        RTS                          
        .byte $B2,$CF,$DB,$CF,$0E,$D0,$47,$D0  ; ......G.
        .byte $7A,$D0,$C5,$D0,$01,$A3,$20,$01  ; z..... .
        .byte $5A,$1C,$84,$02,$00,$01,$5A,$1D  ; Z.....Z.
        .byte $84,$01,$00,$01,$5A,$1E,$84,$00  ; ....Z...
        .byte $01,$A0,$24,$18,$84,$01,$5B,$07  ; ..$...[.
        .byte $00,$19,$84,$01,$5B,$06,$00,$1A  ; ....[...
        .byte $84,$01,$5B,$00,$00,$01,$93,$20  ; ..[.... 
        .byte $01,$74,$0C,$75,$01,$00,$01,$7B  ; .t.u...{
        .byte $1E,$84,$01,$00,$01,$77,$1E,$84  ; .....w..
        .byte $01,$7B,$1F,$84,$00,$01,$80,$24  ; .{.....$
        .byte $08,$75,$01,$76,$17,$00,$1A,$84  ; .u.v....
        .byte $01,$7E,$05,$00,$1A,$84,$01,$7A  ; .~.....z
        .byte $05,$00,$1B,$84,$01,$7E,$00,$00  ; .....~..
        .byte $01,$91,$20,$01,$74,$0E,$75,$10  ; .. .t.u.
        .byte $00,$01,$7B,$0F,$84,$10,$00,$01  ; ..{.....
        .byte $77,$0F,$84,$08,$00,$07,$81,$01  ; w.......
        .byte $7B,$10,$84,$00,$01,$80,$24,$0A  ; {.....$.
        .byte $75,$01,$76,$15,$00,$0B,$84,$01  ; u.v.....
        .byte $7E,$14,$00,$0B,$84,$01,$7A,$14  ; ~.....z.
        .byte $00,$0C,$84,$01,$7E,$07,$81,$00  ; ....~...
        .byte $00,$01,$82,$20,$01,$74,$1D,$75  ; ... .t.u
        .byte $01,$00,$01,$7B,$1E,$84,$01,$00  ; ...{....
        .byte $01,$77,$1E,$84,$01,$7B,$1F,$84  ; .w...{..
        .byte $00,$01,$80,$24,$19,$75,$01,$76  ; ...$.u.v
        .byte $06,$00,$1A,$84,$01,$7E,$05,$00  ; .....~..
        .byte $1A,$84,$01,$7A,$05,$00,$1B,$84  ; ...z....
        .byte $01,$7E,$00,$00,$05,$01,$21,$01  ; .~....!.
        .byte $4C,$1E,$4A,$01,$00,$01,$4C,$1F  ; L.J...L.
        .byte $00,$01,$4C,$1F,$00,$01,$4C,$1F  ; ..L...L.
        .byte $00,$00,$05,$00,$25,$1A,$4A,$01  ; ....%.J.
        .byte $4D,$1F,$00,$01,$4D,$1F,$00,$01  ; M...M...
        .byte $4D,$1F,$00,$01,$4D,$05,$00,$00  ; M...M...
        .byte $20,$80,$23,$01,$4E,$01,$4F,$00  ;  .#.N.O.
        .byte $20,$80,$27,$01,$4E,$01,$4F,$00  ;  .'.N.O.
        .byte $01,$C0,$23,$08,$00,$38,$55,$00  ; ..#..8U.
        .byte $01,$C0,$27,$40,$55,$00,$00,$05  ; ..'@U...
        .byte $A2,$20,$01,$82,$01,$83,$04,$4A  ; . .....J
        .byte $00,$16,$C2,$20,$01,$4C,$01,$4D  ; ... .L.M
        .byte $04,$00,$01,$4C,$01,$4D,$04,$00  ; ...L.M..
        .byte $01,$4C,$01,$4D,$04,$00,$01,$4C  ; .L.M...L
        .byte $01,$4D,$04,$00,$01,$4C,$01,$4D  ; .M...L.M
        .byte $06,$00,$00,$04,$A0,$24,$01,$82  ; .....$..
        .byte $01,$83,$04,$4A,$00,$01,$B8,$24  ; ...J...$
        .byte $01,$82,$01,$83,$00,$16,$C0,$24  ; .......$
        .byte $01,$4C,$01,$4D,$04,$00,$01,$4C  ; .L.M...L
        .byte $01,$4D,$04,$00,$01,$4C,$01,$4D  ; .M...L.M
        .byte $04,$00,$01,$4C,$01,$4D,$04,$00  ; ...L.M..
        .byte $01,$4C,$01,$4D,$06,$00,$00,$00  ; .L.M....

; reachable via computed jump entry
dyn_D126:
D126  B9 85 D1  LDA $D185,Y                  
D129  85 10     STA $10                      
D12B  B9 86 D1  LDA $D186,Y                  
D12E  85 11     STA $11                      
D130  A0 00     LDY #$00                     
D132  B1 10     LDA ($10),Y                  
D134  F0 4E     BEQ LD184                    
D136  C8        INY                          
D137  85 17     STA $17                      
D139  B1 10     LDA ($10),Y                  
D13B  C8        INY                          
D13C  85 12     STA $12                      
D13E  B1 10     LDA ($10),Y                  
D140  C8        INY                          
D141  85 13     STA $13                      
D143  B1 10     LDA ($10),Y                  
D145  C8        INY                          
D146  85 14     STA $14                      
D148  B1 10     LDA ($10),Y                  
D14A  C8        INY                          
D14B  85 15     STA $15                      
D14D  84 16     STY $16                      
D14F  A0 00     LDY #$00                     
D151  A5 15     LDA $15                      
D153  8D 06 20  STA $2006                    PPU: VRAM address
D156  A5 14     LDA $14                      
D158  8D 06 20  STA $2006                    PPU: VRAM address
D15B  B1 12     LDA ($12),Y                  
D15D  C8        INY                          
D15E  AA        TAX                          
D15F  B1 12     LDA ($12),Y                  
D161  C8        INY                          
D162  8D 07 20  STA $2007                    PPU: VRAM data
D165  CA        DEX                          
D166  D0 F7     BNE LD15F                    
D168  B1 12     LDA ($12),Y                  
D16A  F0 10     BEQ LD17C                    
D16C  10 02     BPL LD170                    
D16E  C6 15     DEC $15                      
D170  C8        INY                          
D171  18        CLC                          
D172  65 14     ADC $14                      
D174  85 14     STA $14                      
D176  90 D9     BCC LD151                    
D178  E6 15     INC $15                      
D17A  B0 D5     BCS LD151                    
D17C  A4 16     LDY $16                      
D17E  C6 17     DEC $17                      
D180  D0 C1     BNE LD143                    
D182  F0 AE     BEQ LD132                    
D184  60        RTS                          
        .byte $93,$D1,$F5,$D1,$62,$D2,$D9,$D2  ; ....b...
        .byte $50,$D3,$1C,$D4,$83,$D4,$04,$51  ; P......Q
        .byte $D3,$A8,$20,$B2,$20,$A8,$24,$B2  ; .. . .$.
        .byte $24,$03,$6B,$D3,$8D,$20,$9D,$20  ; $.k.. . 
        .byte $8D,$24,$01,$B3,$D3,$06,$21,$04  ; .$....!.
        .byte $D1,$D3,$86,$21,$06,$22,$86,$22  ; ...!."."
        .byte $06,$23,$01,$C2,$D3,$00,$25,$04  ; .#....%.
        .byte $C5,$D3,$85,$25,$05,$26,$85,$26  ; ...%.&.&
        .byte $05,$27,$15,$10,$D4,$82,$21,$02  ; .'....!.
        .byte $22,$82,$22,$02,$23,$A2,$23,$92  ; ".".#.#.
        .byte $21,$12,$22,$92,$22,$12,$23,$B2  ; !.".".#.
        .byte $23,$1C,$21,$86,$25,$06,$26,$86  ; #.!.%.&.
        .byte $26,$06,$27,$A6,$27,$96,$25,$16  ; &.'.'.%.
        .byte $26,$96,$26,$16,$27,$B6,$27,$00  ; &.&.'.'.
        .byte $08,$5D,$D3,$C3,$20,$C7,$20,$CB  ; .].. . .
        .byte $20,$CF,$20,$CB,$24,$CF,$24,$D3  ;  . .$.$.
        .byte $24,$D7,$24,$04,$51,$D3,$B5,$20  ; $.$.Q.. 
        .byte $B8,$20,$A2,$24,$A5,$24,$01,$6F  ; . .$.$.o
        .byte $D3,$BC,$20,$02,$B3,$D3,$06,$21  ; .. ....!
        .byte $06,$23,$03                      ; .#.
D220  E0 D3     CPX #$D3                     
D222  86 21     STX $21                      
D224  06 22     ASL $22                      
D226  86 22     STX $22                      
D228  02        KIL                          
        .byte $C2,$D3,$00,$25,$00,$27,$03,$EF  ; ...%.'..
        .byte $D3,$80,$25,$00,$26,$80,$26,$13  ; ..%.&.&.
        .byte $10,$D4,$02,$21,$82,$21,$02,$22  ; ...!.!."
        .byte $82,$22,$02,$23,$A2,$23,$10,$22  ; .".#.#."
        .byte $1C,$21,$9C,$21,$9C,$22,$1C,$23  ; .!.!.".#
        .byte $BC,$23,$08,$26,$16,$25,$96,$25  ; .#.&.%.%
        .byte $16,$26,$96,$26,$16,$27,$B6,$27  ; .&.&.'.'
        .byte $00,$02,$81,$D3,$82,$20,$96,$24  ; ..... .$
        .byte $03,$51,$D3,$B2,$20,$BD,$20,$A8  ; .Q.. . .
        .byte $24,$04,$5D,$D3,$B6,$20,$B9,$20  ; $.].. . 
        .byte $A1,$24,$A4,$24,$03,$B3,$D3,$06  ; .$.$....
        .byte $21,$86,$21,$86,$22,$01,$FE,$D3  ; !.!."...
        .byte $06,$22,$01,$D1,$D3,$06,$23,$04  ; ."....#.
        .byte $C2,$D3,$00,$25,$80,$25,$00,$26  ; ...%.%.&
        .byte $80,$26,$01,$C5,$D3,$05,$27,$01  ; .&....'.
        .byte $16,$D4,$1C,$21,$18,$10,$D4,$02  ; ...!....
        .byte $21,$82,$21,$02,$22,$82,$22,$02  ; !.!.".".
        .byte $23,$A2,$23,$12,$21,$92,$21,$12  ; #.#.!.!.
        .byte $22,$92,$22,$12,$23,$B2,$23,$06  ; ".".#.#.
        .byte $25,$86,$25,$06,$26,$86,$26,$06  ; %.%.&.&.
        .byte $27,$A6,$27,$16,$25,$96,$25,$16  ; '.'.%.%.
        .byte $26,$96,$26,$16,$27,$B6,$27,$00  ; &.&.'.'.
        .byte $08,$51,$D3,$A3,$20,$A9,$20,$AF  ; .Q.. . .
        .byte $20,$B5,$20,$A5,$24,$AB,$24,$B1  ;  . .$.$.
        .byte $24,$B7,$24,$08,$5D,$D3,$A6,$20  ; $.$.].. 
        .byte $AC,$20,$B2,$20,$B8,$20,$A2,$24  ; . . . .$
        .byte $A8,$24,$AE,$24,$B4,$24,$01,$A1  ; .$.$.$..
        .byte $D3,$BC,$20,$04,$65,$D3,$88,$20  ; .. .e.. 
        .byte $94,$20,$84,$24,$90,$24,$05,$C2  ; . .$.$..
        .byte $D3,$06,$21,$86,$21,$06,$22,$86  ; ..!.!.".
        .byte $22,$06,$23,$05,$B3,$D3,$00,$25  ; ".#....%
        .byte $80,$25,$00,$26,$80,$26,$00,$27  ; .%.&.&.'
        .byte $12,$10,$D4,$02,$21,$82,$21,$02  ; ....!.!.
        .byte $23,$A2,$23,$0C,$22,$8C,$22,$9C  ; #.#.".".
        .byte $21,$1C,$22,$9C,$22,$1C,$23,$BC  ; !.".".#.
        .byte $23,$1C,$21,$0C,$26,$8C,$26,$16  ; #.!.&.&.
        .byte $25,$96,$25,$16,$27,$B6,$27,$00  ; %.%.'.'.
        .byte $02,$5C,$5D,$20,$02,$5E,$5F,$20  ; .\] .^_ 
        .byte $02,$60,$60,$00,$02,$71,$72,$20  ; .``..qr 
        .byte $02,$73,$73,$00,$04,$76,$00,$00  ; .ss..v..
        .byte $74,$00,$02,$61,$62,$1F,$04,$63  ; t..ab..c
        .byte $64,$65,$66,$20,$04,$67,$68,$69  ; def .ghi
        .byte $6A,$20,$04,$67,$6B,$6C,$6A,$00  ; j .gklj.
        .byte $04,$74,$75,$75,$76,$1F,$06,$7B  ; .tuuv..{
        .byte $84,$78,$79,$84,$7E,$20,$06,$77  ; .xy.~ .w
        .byte $84,$7C,$7D,$84,$7A,$1F,$08,$7B  ; .|}.z..{
        .byte $84,$84,$6B,$6C,$84,$84,$7E,$00  ; ..kl..~.
        .byte $04,$78,$7F,$80,$79,$20,$04,$7C  ; .x..y .|
        .byte $00,$00,$7D,$20,$04,$6B,$00,$00  ; ..} .k..
        .byte $6C,$00,$01,$4B,$06,$01,$4B,$05  ; l..K..K.
        .byte $01,$4B,$05,$01,$4B,$05,$01,$4B  ; .K..K..K
        .byte $00,$01,$4B,$05,$01,$4B,$05,$01  ; ..K..K..
        .byte $4B,$05,$01,$4B,$06,$01,$4B,$00  ; K..K..K.
        .byte $01,$4B,$06,$01,$4B,$05,$01,$4B  ; .K..K..K
        .byte $05,$01,$4B,$07,$01,$4B,$00,$01  ; ..K..K..
        .byte $4B,$05,$01,$4B,$04,$01,$4B,$05  ; K..K..K.
        .byte $01,$4B,$07,$01,$4B,$00,$01,$4B  ; .K..K..K
        .byte $07,$01,$4B,$05,$01,$4B,$04,$01  ; ..K..K..
        .byte $4B,$05,$01,$4B,$00,$01,$4B,$06  ; K..K..K.
        .byte $01,$4B,$05,$01,$4B,$05,$01,$4B  ; .K..K..K
        .byte $03,$01,$4B,$02,$01,$4B,$00,$04  ; ..K..K..
        .byte $00,$00,$00,$00,$00,$04,$49,$49  ; ......II
        .byte $49,$49,$00,$05,$67,$D4,$E8,$20  ; II..g.. 
        .byte $EE,$22,$E0,$26,$66,$25,$F2,$24  ; .".&f%.$
        .byte $06,$5B,$D4,$68,$22,$14,$21,$1A  ; .[.h".!.
        .byte $22,$00,$25,$EC,$25,$72,$26,$04  ; ".%.%r&.
        .byte $7B,$D4,$02,$22,$8E,$22,$80,$26  ; {..".".&
        .byte $12,$26,$0A,$10,$D4,$84,$23,$A4  ; .&....#.
        .byte $23,$AA,$23,$B0,$23,$B6,$23,$BC  ; #.#.#.#.
        .byte $23,$A2,$27,$A8,$27,$AE,$27,$B4  ; #.'.'.'.
        .byte $27,$00,$02,$00,$00,$20,$02,$00  ; '.... ..
        .byte $00,$20,$02,$00,$00,$20,$02,$00  ; . ... ..
        .byte $00,$20,$02,$00,$00,$20,$02,$00  ; . ... ..
        .byte $00,$20,$02,$00,$00,$20,$02,$00  ; . ... ..
        .byte $00,$00,$02,$82,$83,$06,$02,$82  ; ........
        .byte $83,$00,$01,$93,$D4,$6A,$21,$01  ; .....j!.
        .byte $A0,$D4,$51,$22,$01,$AF,$D4,$C9  ; ..Q"....
        .byte $22,$00,$0B,$0C,$19,$18,$1F,$1D  ; ".......
        .byte $00,$1C,$19,$1F,$18,$0E,$00,$02  ; ........
        .byte $28,$29,$1A,$09,$1D,$1E,$13,$18  ; ()......
        .byte $11,$00,$2A,$2B,$1D,$00,$0D,$0C  ; ..*+....
        .byte $0F,$10,$19,$1C,$0F,$00,$00,$00  ; ........
        .byte $0F,$18,$0E,$1D,$00              ; .....

; reachable via computed jump entry
dyn_D4BE:
D4BE  85 19     STA $19                      
D4C0  A4 19     LDY $19                      
D4C2  20 CA D4  JSR LD4CA                    
D4C5  C6 18     DEC $18                      
D4C7  D0 F7     BNE LD4C0                    
D4C9  60        RTS                          
D4CA  A5 42     LDA $42                      
D4CC  F0 FB     BEQ LD4C9                    
D4CE  85 43     STA $43                      
D4D0  98        TYA                          
D4D1  18        CLC                          
D4D2  6D 61 D5  ADC $D561                    
D4D5  85 12     STA $12                      
D4D7  AD 62 D5  LDA $D562                    
D4DA  69 00     ADC #$00                     
D4DC  85 13     STA $13                      
D4DE  A2 74     LDX #$74                     
D4E0  A0 03     LDY #$03                     
D4E2  4C 02 D5  JMP LD502                    

; subroutine entry
sub_D4E5:
D4E5  B9 36 D5  LDA $D536,Y                  
D4E8  85 10     STA $10                      
D4EA  B9 37 D5  LDA $D537,Y                  
D4ED  85 11     STA $11                      
D4EF  A0 00     LDY #$00                     
D4F1  B1 10     LDA ($10),Y                  
D4F3  C8        INY                          
D4F4  AA        TAX                          
D4F5  B1 10     LDA ($10),Y                  
D4F7  C8        INY                          
D4F8  85 12     STA $12                      
D4FA  B1 10     LDA ($10),Y                  
D4FC  C8        INY                          
D4FD  85 13     STA $13                      
D4FF  B1 10     LDA ($10),Y                  
D501  A8        TAY                          
D502  18        CLC                          
D503  B1 12     LDA ($12),Y                  
D505  29 0F     AND #$0F                     
D507  85 14     STA $14                      
D509  B1 12     LDA ($12),Y                  
D50B  29 F0     AND #$F0                     
D50D  85 15     STA $15                      
D50F  B5 00     LDA $00,X                    
D511  29 0F     AND #$0F                     
D513  65 14     ADC $14                      
D515  C9 0A     CMP #$0A                     
D517  90 02     BCC LD51B                    
D519  69 05     ADC #$05                     
D51B  85 14     STA $14                      
D51D  18        CLC                          
D51E  B5 00     LDA $00,X                    
D520  29 F0     AND #$F0                     
D522  65 14     ADC $14                      
D524  65 15     ADC $15                      
D526  B0 04     BCS LD52C                    
D528  C9 A0     CMP #$A0                     
D52A  90 03     BCC LD52F                    

; branch target entry
LD52C:
D52C  69 5F     ADC #$5F                     
D52E  38        SEC                          
D52F  95 00     STA $00,X                    
D531  CA        DEX                          
D532  88        DEY                          
D533  10 CE     BPL LD503                    
D535  60        RTS                          
        .byte $44,$D5,$48,$D5,$4C,$D5,$50,$D5  ; D.H.L.P.
        .byte $54,$D5,$58,$D5,$5C,$D5,$76,$49  ; T.X.\.vI
        .byte $00,$00,$70,$60,$D5,$00,$77,$60  ; ..p`..w`
        .byte $D5,$00,$50,$60,$D5,$00,$57,$67  ; ..P`..Wg
        .byte $D5,$03,$5F,$54,$00,$03,$74,$5C  ; .._T..t\
        .byte $00,$03,$01,$63,$D5,$00,$00,$01  ; ...c....
        .byte $00,$00,$00,$02,$00,$00,$00,$03  ; ........
        .byte $00,$00,$00,$04,$00,$00,$00,$05  ; ........
        .byte $00,$00,$00,$02,$00,$00,$00,$04  ; ........
        .byte $00,$00,$00,$08,$00,$00,$00,$12  ; ........
        .byte $00,$00,$00,$16,$00,$00,$00,$20  ; ....... 
        .byte $00,$00,$00,$30,$00,$00,$00,$40  ; ...0...@
        .byte $00,$00,$00,$50,$00,$00,$00,$60  ; ...P...`
        .byte $00,$00,$00,$00,$10,$00,$00,$00  ; ........
        .byte $50,$00,$00,$10,$00              ; P....

; reachable via computed jump entry
dyn_D5AB:
D5AB  A5 30     LDA $30                      
D5AD  F0 0F     BEQ LD5BE                    
D5AF  85 18     STA $18                      
D5B1  A9 40     LDA #$40                     
D5B3  20 BE D4  JSR LD4BE                    
D5B6  A9 00     LDA #$00                     
D5B8  85 30     STA $30                      
D5BA  A9 01     LDA #$01                     
D5BC  85 43     STA $43                      
D5BE  A5 43     LDA $43                      
D5C0  F0 66     BEQ LD628                    
D5C2  C9 01     CMP #$01                     
D5C4  F0 0F     BEQ LD5D5                    
D5C6  A9 00     LDA #$00                     
D5C8  85 43     STA $43                      
D5CA  20 94 D6  JSR LD694                    
D5CD  20 AA D6  JSR LD6AA                    
D5D0  A0 08     LDY #$08                     
D5D2  4C D9 D5  JMP LD5D9                    
D5D5  E6 43     INC $43                      
D5D7  A0 00     LDY #$00                     
D5D9  B9 40 D6  LDA $D640,Y                  
D5DC  85 10     STA $10                      
D5DE  B9 41 D6  LDA $D641,Y                  
D5E1  85 11     STA $11                      
D5E3  A0 00     LDY #$00                     
D5E5  B1 10     LDA ($10),Y                  
D5E7  C8        INY                          
D5E8  85 12     STA $12                      
D5EA  B1 10     LDA ($10),Y                  
D5EC  C8        INY                          
D5ED  85 13     STA $13                      
D5EF  B1 10     LDA ($10),Y                  
D5F1  C8        INY                          
D5F2  AA        TAX                          
D5F3  B1 10     LDA ($10),Y                  
D5F5  C8        INY                          
D5F6  85 14     STA $14                      
D5F8  B1 10     LDA ($10),Y                  
D5FA  85 15     STA $15                      
D5FC  A4 2A     LDY $2A                      
D5FE  A5 12     LDA $12                      
D600  99 00 05  STA $0500,Y                  
D603  C8        INY                          
D604  A5 13     LDA $13                      
D606  99 00 05  STA $0500,Y                  
D609  C8        INY                          
D60A  A5 14     LDA $14                      
D60C  0A        ASL A                        
D60D  99 00 05  STA $0500,Y                  
D610  C8        INY                          
D611  B5 00     LDA $00,X                    
D613  4A        LSR A                        
D614  4A        LSR A                        
D615  4A        LSR A                        
D616  4A        LSR A                        
D617  20 29 D6  JSR LD629                    
D61A  B5 00     LDA $00,X                    
D61C  E8        INX                          
D61D  29 0F     AND #$0F                     
D61F  20 29 D6  JSR LD629                    
D622  C6 14     DEC $14                      
D624  D0 EB     BNE LD611                    
D626  84 2A     STY $2A                      
D628  60        RTS                          
D629  D0 09     BNE LD634                    
D62B  C6 15     DEC $15                      
D62D  30 05     BMI LD634                    
D62F  99 00 05  STA $0500,Y                  
D632  C8        INY                          
D633  60        RTS                          
D634  18        CLC                          
D635  69 01     ADC #$01                     
D637  99 00 05  STA $0500,Y                  
D63A  C8        INY                          
D63B  A9 00     LDA #$00                     
D63D  85 15     STA $15                      
D63F  60        RTS                          
        .byte $58,$D6,$5D,$D6,$67,$D6,$62,$D6  ; X.].g.b.
        .byte $6C,$D6,$71,$D6,$76,$D6,$7B,$D6  ; l.q.v.{.
        .byte $80,$D6,$85,$D6,$8A,$D6,$8F,$D6  ; ........
        .byte $62,$20,$71,$04,$06,$74,$20,$71  ; b q..t q
        .byte $04,$06,$62,$20,$B1,$04,$06,$74  ; ..b ...t
        .byte $20,$B1,$04,$06,$6B,$20,$44,$04  ;  ...k D.
        .byte $06,$76,$20,$70,$01,$01,$7A,$20  ; .v p..z 
        .byte $77,$01,$01,$90,$21,$50,$01,$01  ; w...!P..
        .byte $10,$22,$51,$01,$01,$97,$21,$56  ; ."Q...!V
        .byte $02,$02,$17,$22,$5A,$02,$02,$15  ; ..."Z...
        .byte $23,$5D,$03,$04                  ; #]..

; reachable via computed jump entry
dyn_D694:
D694  A2 03     LDX #$03                     
D696  38        SEC                          
D697  B5 44     LDA $44,X                    
D699  F5 71     SBC $71,X                    
D69B  CA        DEX                          
D69C  10 F9     BPL LD697                    
D69E  B0 09     BCS LD6A9                    
D6A0  A2 03     LDX #$03                     

; branch target entry
LD6A2:
D6A2  B5 71     LDA $71,X                    
D6A4  95 44     STA $44,X                    
D6A6  CA        DEX                          
D6A7  10 F9     BPL LD6A2                    
D6A9  60        RTS                          
D6AA  A5 75     LDA $75                      
D6AC  C5 48     CMP $48                      
D6AE  F0 F9     BEQ LD6A9                    
D6B0  A5 72     LDA $72                      
D6B2  C5 76     CMP $76                      
D6B4  90 F3     BCC LD6A9                    
D6B6  A5 75     LDA $75                      
D6B8  D0 02     BNE LD6BC                    
D6BA  85 76     STA $76                      

; branch target entry
LD6BC:
D6BC  E6 75     INC $75                      
D6BE  D0 02     BNE LD6C2                    
D6C0  C6 75     DEC $75                      

; branch target entry
LD6C2:
D6C2  A0 00     LDY #$00                     
D6C4  20 E5 D4  JSR LD4E5                    
D6C7  90 04     BCC LD6CD                    
D6C9  A5 48     LDA $48                      
D6CB  85 75     STA $75                      

; branch target entry
LD6CD:
D6CD  A9 01     LDA #$01                     
D6CF  8D 02 06  STA $0602                    
D6D2  8D 03 06  STA $0603                    
D6D5  8D 04 06  STA $0604                    
D6D8  A0 02     LDY #$02                     
D6DA  20 E5 D4  JSR LD4E5                    
D6DD  90 04     BCC LD6E3                    
D6DF  A9 99     LDA #$99                     
D6E1  85 70     STA $70                      

; branch target entry
LD6E3:
D6E3  A0 0A     LDY #$0A                     
D6E5  4C D9 D5  JMP LD5D9                    

; subroutine entry
sub_D6E8:
D6E8  A0 04     LDY #$04                     
D6EA  20 E5 D4  JSR LD4E5                    
D6ED  E6 7A     INC $7A                      
D6EF  A5 7A     LDA $7A                      
D6F1  29 0F     AND #$0F                     
D6F3  85 7A     STA $7A                      
D6F5  A5 7D     LDA $7D                      
D6F7  18        CLC                          
D6F8  69 01     ADC #$01                     
D6FA  C9 20     CMP #$20                     
D6FC  90 02     BCC LD700                    
D6FE  A9 1C     LDA #$1C                     

; branch target entry
LD700:
D700  85 7D     STA $7D                      
D702  60        RTS                          
D703  A0 00     LDY #$00                     
D705  20 15 CC  JSR LCC15                    
D708  A0 08     LDY #$08                     
D70A  20 D9 D5  JSR LD5D9                    
D70D  A0 0A     LDY #$0A                     
D70F  20 D9 D5  JSR LD5D9                    
D712  A0 0C     LDY #$0C                     
D714  20 D9 D5  JSR LD5D9                    
D717  A0 00     LDY #$00                     
D719  4C D9 D5  JMP LD5D9                    
D71C  A5 42     LDA $42                      
D71E  F0 15     BEQ LD735                    
D720  A5 21     LDA $21                      
D722  29 0F     AND #$0F                     
D724  D0 0E     BNE LD734                    
D726  A5 21     LDA $21                      
D728  4A        LSR A                        
D729  4A        LSR A                        
D72A  4A        LSR A                        
D72B  29 02     AND #$02                     
D72D  05 41     ORA $41                      
D72F  0A        ASL A                        
D730  A8        TAY                          
D731  4C 7A D7  JMP LD77A                    
D734  60        RTS                          

; subroutine entry
sub_D735:
D735  A9 02     LDA #$02                     
D737  05 41     ORA $41                      
D739  0A        ASL A                        
D73A  A8        TAY                          
D73B  4C 7A D7  JMP LD77A                    
D73E  A5 24     LDA $24                      
D740  29 03     AND #$03                     
D742  C9 01     CMP #$01                     
D744  D0 0A     BNE LD750                    
D746  A9 F0     LDA #$F0                     
D748  85 0F     STA $0F                      
D74A  A5 4A     LDA $4A                      
D74C  49 01     EOR #$01                     
D74E  85 4A     STA $4A                      
D750  A5 4A     LDA $4A                      
D752  0A        ASL A                        
D753  69 08     ADC #$08                     
D755  48        PHA                          
D756  A8        TAY                          
D757  20 7A D7  JSR LD77A                    
D75A  68        PLA                          
D75B  18        CLC                          
D75C  69 04     ADC #$04                     
D75E  A8        TAY                          
D75F  4C 7A D7  JMP LD77A                    
        .byte $A5,$22,$29,$03,$C9,$01,$D0,$0A  ; .").....
        .byte $A9,$F0,$85,$0F,$A5,$2E,$49,$01  ; ......I.
        .byte $85,$2E,$A5,$2E,$0A,$69,$10,$A8  ; .....i..

; jump target entry
jmp_D77A:
D77A  B9 AD D7  LDA $D7AD,Y                  
D77D  85 10     STA $10                      
D77F  B9 AE D7  LDA $D7AE,Y                  
D782  85 11     STA $11                      
D784  A0 00     LDY #$00                     
D786  A6 2A     LDX $2A                      
D788  B1 10     LDA ($10),Y                  
D78A  C8        INY                          
D78B  9D 00 05  STA $0500,X                  
D78E  E8        INX                          
D78F  B1 10     LDA ($10),Y                  
D791  C8        INY                          
D792  9D 00 05  STA $0500,X                  
D795  E8        INX                          
D796  B1 10     LDA ($10),Y                  
D798  C8        INY                          
D799  9D 00 05  STA $0500,X                  
D79C  85 12     STA $12                      
D79E  E8        INX                          

; branch target entry
LD79F:
D79F  B1 10     LDA ($10),Y                  
D7A1  C8        INY                          
D7A2  9D 00 05  STA $0500,X                  
D7A5  E8        INX                          
D7A6  C6 12     DEC $12                      
D7A8  D0 F5     BNE LD79F                    
D7AA  86 2A     STX $2A                      
D7AC  60        RTS                          
        .byte $C1,$D7,$C7,$D7,$CD,$D7,$D3,$D7  ; ........
        .byte $D9,$D7,$E1,$D7,$DD,$D7,$E5,$D7  ; ........
        .byte $E9,$D7,$ED,$D7,$45,$20,$03,$00  ; ....E ..
        .byte $00,$00,$45,$20,$03,$00,$00,$00  ; ..E ....
        .byte $45,$20,$03,$A8,$AA,$AB,$45,$20  ; E ....E 
        .byte $03,$A9,$AA,$AB,$E9,$21,$01,$AF  ; .....!..
        .byte $29,$22,$01,$00,$E9,$21,$01,$00  ; )"...!..
        .byte $29,$22,$01,$AF,$AC,$21,$01,$00  ; )"...!..
        .byte $AC,$21,$01,$18                  ; .!..

; reachable via computed jump entry
dyn_D7F1:
D7F1  20 25 D8  JSR LD825                    
D7F4  B9 38 D8  LDA $D838,Y                  
D7F7  91 1E     STA ($1E),Y                  
D7F9  C8        INY                          
D7FA  C0 07     CPY #$07                     
D7FC  D0 F6     BNE LD7F4                    
D7FE  A9 4B     LDA #$4B                     
D800  A0 08     LDY #$08                     
D802  91 1E     STA ($1E),Y                  
D804  A9 00     LDA #$00                     
D806  A0 0F     LDY #$0F                     
D808  91 1E     STA ($1E),Y                  
D80A  60        RTS                          

; subroutine entry
sub_D80B:
D80B  20 25 D8  JSR LD825                    

; branch target entry
LD80E:
D80E  B9 3F D8  LDA $D83F,Y                  
D811  91 1E     STA ($1E),Y                  
D813  C8        INY                          
D814  C0 07     CPY #$07                     
D816  D0 F6     BNE LD80E                    
D818  A9 00     LDA #$00                     
D81A  A0 08     LDY #$08                     
D81C  91 1E     STA ($1E),Y                  
D81E  A9 02     LDA #$02                     
D820  A0 0F     LDY #$0F                     
D822  91 1E     STA ($1E),Y                  
D824  60        RTS                          
D825  A9 00     LDA #$00                     
D827  85 28     STA $28                      
D829  A9 1C     LDA #$1C                     
D82B  85 29     STA $29                      
D82D  A9 00     LDA #$00                     
D82F  85 1E     STA $1E                      
D831  A9 04     LDA #$04                     
D833  85 1F     STA $1F                      
D835  A0 00     LDY #$00                     
D837  60        RTS                          
        .byte $00,$34,$00,$1A,$02,$00,$FF,$00  ; .4......
        .byte $35,$00,$0A,$06,$00,$FF          ; 5.....

; reachable via computed jump entry
dyn_D846:
D846  A9 30     LDA #$30                     
D848  85 4C     STA $4C                      
D84A  A9 00     LDA #$00                     
D84C  85 4D     STA $4D                      
D84E  A9 10     LDA #$10                     
D850  85 4E     STA $4E                      
D852  A9 30     LDA #$30                     
D854  85 1E     STA $1E                      
D856  A9 04     LDA #$04                     
D858  85 1F     STA $1F                      
D85A  A2 00     LDX #$00                     
D85C  A9 03     LDA #$03                     
D85E  20 94 D8  JSR LD894                    
D861  A9 01     LDA #$01                     
D863  A0 06     LDY #$06                     
D865  91 1E     STA ($1E),Y                  
D867  8A        TXA                          
D868  18        CLC                          
D869  69 08     ADC #$08                     
D86B  AA        TAX                          
D86C  A5 1E     LDA $1E                      
D86E  18        CLC                          
D86F  69 10     ADC #$10                     
D871  85 1E     STA $1E                      
D873  C5 68     CMP $68                      
D875  D0 E5     BNE LD85C                    
D877  A9 00     LDA #$00                     
D879  85 35     STA $35                      
D87B  A9 09     LDA #$09                     
D87D  85 36     STA $36                      
D87F  A9 04     LDA #$04                     
D881  85 37     STA $37                      
D883  A9 20     LDA #$20                     
D885  85 1E     STA $1E                      
D887  A9 04     LDA #$04                     
D889  85 1F     STA $1F                      
D88B  A9 FF     LDA #$FF                     
D88D  8D 26 04  STA $0426                    
D890  A2 00     LDX #$00                     
D892  A9 02     LDA #$02                     
D894  A0 05     LDY #$05                     
D896  91 1E     STA ($1E),Y                  
D898  8A        TXA                          
D899  0A        ASL A                        
D89A  0A        ASL A                        
D89B  69 20     ADC #$20                     
D89D  A0 00     LDY #$00                     
D89F  91 1E     STA ($1E),Y                  
D8A1  C8        INY                          
D8A2  BD 64 02  LDA $0264,X                  
D8A5  91 1E     STA ($1E),Y                  
D8A7  BD 65 02  LDA $0265,X                  
D8AA  A0 03     LDY #$03                     
D8AC  91 1E     STA ($1E),Y                  
D8AE  C8        INY                          
D8AF  A9 02     LDA #$02                     
D8B1  91 1E     STA ($1E),Y                  
D8B3  A9 00     LDA #$00                     
D8B5  A0 0F     LDY #$0F                     
D8B7  91 1E     STA ($1E),Y                  
D8B9  A9 4B     LDA #$4B                     
D8BB  A0 08     LDY #$08                     
D8BD  91 1E     STA ($1E),Y                  
D8BF  60        RTS                          

; subroutine entry
sub_D8C0:
D8C0  A2 00     LDX #$00                     

; branch target entry
LD8C2:
D8C2  BD D3 D8  LDA $D8D3,X                  
D8C5  9D 10 04  STA $0410,X                  
D8C8  E8        INX                          
D8C9  E0 05     CPX #$05                     
D8CB  D0 F5     BNE LD8C2                    
D8CD  A9 0E     LDA #$0E                     
D8CF  8D 1F 04  STA $041F                    
D8D2  60        RTS                          
        .byte $00,$05,$00,$18,$18              ; .....

; reachable via computed jump entry
dyn_D8D8:
D8D8  A9 00     LDA #$00                     
D8DA  85 1E     STA $1E                      
D8DC  A9 04     LDA #$04                     
D8DE  85 1F     STA $1F                      
D8E0  20 39 D9  JSR LD939                    
D8E3  20 2C DA  JSR LDA2C                    
D8E6  20 05 C3  JSR LC305                    
D8E9  A5 1E     LDA $1E                      
D8EB  18        CLC                          
D8EC  69 10     ADC #$10                     
D8EE  85 1E     STA $1E                      
D8F0  C9 90     CMP #$90                     
D8F2  D0 EC     BNE LD8E0                    
D8F4  E6 4D     INC $4D                      
D8F6  A5 4D     LDA $4D                      
D8F8  C5 4E     CMP $4E                      
D8FA  90 3C     BCC LD938                    
D8FC  A9 00     LDA #$00                     
D8FE  85 4D     STA $4D                      
D900  A6 4C     LDX $4C                      
D902  BD 0F 04  LDA $040F,X                  
D905  C9 1A     CMP #$1A                     
D907  D0 22     BNE LD92B                    
D909  BD 07 04  LDA $0407,X                  
D90C  D0 1D     BNE LD92B                    
D90E  9D 00 04  STA $0400,X                  
D911  9D 02 04  STA $0402,X                  
D914  A9 1D     LDA #$1D                     
D916  9D 01 04  STA $0401,X                  
D919  A9 06     LDA #$06                     
D91B  9D 03 04  STA $0403,X                  
D91E  9D 04 04  STA $0404,X                  
D921  A9 1C     LDA #$1C                     
D923  9D 0F 04  STA $040F,X                  
D926  A9 00     LDA #$00                     
D928  9D 08 04  STA $0408,X                  
D92B  8A        TXA                          
D92C  18        CLC                          
D92D  69 10     ADC #$10                     
D92F  AA        TAX                          
D930  E0 90     CPX #$90                     
D932  D0 02     BNE LD936                    
D934  A2 10     LDX #$10                     
D936  86 4C     STX $4C                      
D938  60        RTS                          
D939  A0 0D     LDY #$0D                     
D93B  A5 1E     LDA $1E                      
D93D  F0 4B     BEQ LD98A                    
D93F  A9 00     LDA #$00                     
D941  91 1E     STA ($1E),Y                  
D943  A5 1E     LDA $1E                      
D945  C9 20     CMP #$20                     
D947  90 02     BCC LD94B                    
D949  F0 4D     BEQ LD998                    
D94B  A0 0F     LDY #$0F                     
D94D  B1 1E     LDA ($1E),Y                  
D94F  C9 02     CMP #$02                     
D951  F0 44     BEQ LD997                    
D953  C9 0C     CMP #$0C                     
D955  D0 40     BNE LD997                    
D957  AD 0F 04  LDA $040F                    
D95A  C9 0C     CMP #$0C                     
D95C  D0 12     BNE LD970                    
D95E  A0 00     LDY #$00                     
D960  B1 1E     LDA ($1E),Y                  
D962  38        SEC                          
D963  ED 00 04  SBC $0400                    
D966  C8        INY                          
D967  B1 1E     LDA ($1E),Y                  
D969  ED 01 04  SBC $0401                    
D96C  C9 02     CMP #$02                     
D96E  90 27     BCC LD997                    
D970  A0 0A     LDY #$0A                     
D972  B1 1E     LDA ($1E),Y                  
D974  29 FC     AND #$FC                     
D976  09 01     ORA #$01                     
D978  A0 03     LDY #$03                     
D97A  D1 1E     CMP ($1E),Y                  
D97C  D0 19     BNE LD997                    
D97E  A0 0A     LDY #$0A                     
D980  B1 1E     LDA ($1E),Y                  
D982  4A        LSR A                        
D983  A0 0D     LDY #$0D                     
D985  B0 2E     BCS LD9B5                    
D987  4C BC D9  JMP LD9BC                    
D98A  A5 42     LDA $42                      
D98C  F0 39     BEQ LD9C7                    
D98E  A5 26     LDA $26                      
D990  91 1E     STA ($1E),Y                  
D992  A5 22     LDA $22                      
D994  C8        INY                          
D995  91 1E     STA ($1E),Y                  
D997  60        RTS                          
D998  AD 2F 04  LDA $042F                    
D99B  C9 02     CMP #$02                     
D99D  F0 F8     BEQ LD997                    
D99F  C9 0C     CMP #$0C                     
D9A1  D0 F4     BNE LD997                    
D9A3  A5 36     LDA $36                      
D9A5  CD 23 04  CMP $0423                    
D9A8  90 ED     BCC LD997                    
D9AA  AD 21 04  LDA $0421                    
D9AD  C9 06     CMP #$06                     
D9AF  90 0B     BCC LD9BC                    
D9B1  C9 34     CMP #$34                     
D9B3  90 0C     BCC LD9C1                    
D9B5  A9 FF     LDA #$FF                     
D9B7  91 1E     STA ($1E),Y                  
D9B9  60        RTS                          
D9BA  30 F9     BMI LD9B5                    
D9BC  A9 01     LDA #$01                     
D9BE  91 1E     STA ($1E),Y                  
D9C0  60        RTS                          
D9C1  AD 26 04  LDA $0426                    
D9C4  91 1E     STA ($1E),Y                  
D9C6  60        RTS                          
D9C7  0E 0E 04  ASL $040E                    
D9CA  A5 3C     LDA $3C                      
D9CC  F0 03     BEQ LD9D1                    
D9CE  C6 3C     DEC $3C                      
D9D0  60        RTS                          
D9D1  A6 3D     LDX $3D                      
D9D3  BD E1 FF  LDA $FFE1,X                  
D9D6  F0 0F     BEQ LD9E7                    
D9D8  0A        ASL A                        
D9D9  0A        ASL A                        
D9DA  85 3C     STA $3C                      
D9DC  BD E1 FF  LDA $FFE1,X                  
D9DF  E8        INX                          
D9E0  86 3D     STX $3D                      
D9E2  0A        ASL A                        
D9E3  B0 D5     BCS LD9BA                    
D9E5  30 05     BMI LD9EC                    
D9E7  A9 00     LDA #$00                     
D9E9  91 1E     STA ($1E),Y                  
D9EB  60        RTS                          
D9EC  EE 0E 04  INC $040E                    
D9EF  60        RTS                          
D9F0  AD 21 04  LDA $0421                    
D9F3  38        SEC                          
D9F4  E9 06     SBC #$06                     
D9F6  C9 2E     CMP #$2E                     
D9F8  B0 08     BCS LDA02                    
D9FA  A5 35     LDA $35                      
D9FC  F0 20     BEQ LDA1E                    
D9FE  A9 00     LDA #$00                     
DA00  85 35     STA $35                      
DA02  A5 36     LDA $36                      
DA04  C9 09     CMP #$09                     
DA06  D0 07     BNE LDA0F                    
DA08  A9 04     LDA #$04                     
DA0A  85 37     STA $37                      
DA0C  4C 17 DA  JMP LDA17                    

; branch target entry
LDA0F:
DA0F  C9 19     CMP #$19                     
DA11  D0 04     BNE LDA17                    
DA13  A9 FC     LDA #$FC                     
DA15  85 37     STA $37                      
DA17  A5 36     LDA $36                      
DA19  18        CLC                          
DA1A  65 37     ADC $37                      
DA1C  85 36     STA $36                      
DA1E  60        RTS                          

; branch target entry
LDA1F:
DA1F  BD 7A E1  LDA $E17A,X                  
DA22  85 1C     STA $1C                      
DA24  BD 7B E1  LDA $E17B,X                  
DA27  85 1D     STA $1D                      
DA29  6C 1C 00  JMP ($001C)                  
DA2C  A0 0F     LDY #$0F                     
DA2E  B1 1E     LDA ($1E),Y                  
DA30  AA        TAX                          
DA31  A5 7C     LDA $7C                      
DA33  D0 EA     BNE LDA1F                    
DA35  BD 42 DA  LDA $DA42,X                  
DA38  85 1C     STA $1C                      
DA3A  BD 43 DA  LDA $DA43,X                  
DA3D  85 1D     STA $1D                      
DA3F  6C 1C 00  JMP ($001C)                  
        .byte $4F,$C1,$70,$DA,$C7,$DA,$94,$DB  ; O.p.....
        .byte $45,$DB,$02,$DC,$5C,$DC,$FE,$DC  ; E...\...
        .byte $62,$DD,$A8,$DD,$C6,$DD,$4F,$C1  ; b.....O.
        .byte $4F,$C1,$D4,$DD,$E0,$DD,$2D,$DE  ; O.....-.
        .byte $61,$DE,$37,$DB,$25,$DE,$7A,$DE  ; a.7.%.z.
        .byte $98,$DE,$55,$DB,$7B,$DB          ; ..U.{.

; reachable via computed jump entry
dyn_DA70:
DA70  A5 1E     LDA $1E                      
DA72  C9 20     CMP #$20                     
DA74  D0 08     BNE LDA7E                    
DA76  AD 2A 04  LDA $042A                    
DA79  F0 03     BEQ LDA7E                    
DA7B  CE 2A 04  DEC $042A                    
DA7E  20 B7 E0  JSR LE0B7                    
DA81  F0 55     BEQ LDAD8                    
DA83  20 90 EA  JSR LEA90                    
DA86  20 B1 F0  JSR LF0B1                    
DA89  20 E7 F0  JSR LF0E7                    
DA8C  D0 03     BNE LDA91                    
DA8E  4C 83 DB  JMP LDB83                    
DA91  A0 08     LDY #$08                     
DA93  B1 1E     LDA ($1E),Y                  
DA95  38        SEC                          
DA96  E9 49     SBC #$49                     
DA98  C9 09     CMP #$09                     
DA9A  B0 06     BCS LDAA2                    
DA9C  20 E9 DE  JSR LDEE9                    
DA9F  4C 72 E9  JMP LE972                    
DAA2  A5 1E     LDA $1E                      
DAA4  C9 20     CMP #$20                     
DAA6  F0 03     BEQ LDAAB                    
DAA8  20 A6 DE  JSR LDEA6                    
DAAB  A9 0B     LDA #$0B                     
DAAD  A0 07     LDY #$07                     
DAAF  91 1E     STA ($1E),Y                  
DAB1  A9 D0     LDA #$D0                     
DAB3  A0 0B     LDY #$0B                     
DAB5  91 1E     STA ($1E),Y                  
DAB7  A9 09     LDA #$09                     
DAB9  C8        INY                          
DABA  91 1E     STA ($1E),Y                  
DABC  A9 04     LDA #$04                     
DABE  A0 0F     LDY #$0F                     
DAC0  91 1E     STA ($1E),Y                  
DAC2  A0 04     LDY #$04                     
DAC4  91 1E     STA ($1E),Y                  
DAC6  60        RTS                          
DAC7  A0 07     LDY #$07                     
DAC9  B1 1E     LDA ($1E),Y                  
DACB  38        SEC                          
DACC  E9 01     SBC #$01                     
DACE  91 1E     STA ($1E),Y                  
DAD0  D0 03     BNE LDAD5                    
DAD2  4C 83 DB  JMP LDB83                    
DAD5  4C 3D E0  JMP LE03D                    
DAD8  A5 1E     LDA $1E                      
DADA  D0 35     BNE LDB11                    
DADC  A9 1E     LDA #$1E                     
DADE  8D 04 04  STA $0404                    
DAE1  A9 00     LDA #$00                     
DAE3  8D 07 04  STA $0407                    
DAE6  A9 08     LDA #$08                     
DAE8  8D 0F 04  STA $040F                    
DAEB  A9 01     LDA #$01                     
DAED  85 4B     STA $4B                      
DAEF  20 BF F4  JSR LF4BF                    
DAF2  A2 10     LDX #$10                     
DAF4  BD 0F 04  LDA $040F,X                  
DAF7  C9 16     CMP #$16                     
DAF9  F0 0C     BEQ LDB07                    
DAFB  C9 20     CMP #$20                     
DAFD  F0 08     BEQ LDB07                    
DAFF  A9 00     LDA #$00                     
DB01  9D 0F 04  STA $040F,X                  
DB04  9D 04 04  STA $0404,X                  
DB07  8A        TXA                          
DB08  18        CLC                          
DB09  69 10     ADC #$10                     
DB0B  AA        TAX                          
DB0C  E0 90     CPX #$90                     
DB0E  D0 E4     BNE LDAF4                    
DB10  60        RTS                          

; branch target entry
LDB11:
DB11  A9 20     LDA #$20                     
DB13  A0 04     LDY #$04                     
DB15  91 1E     STA ($1E),Y                  
DB17  A9 22     LDA #$22                     
DB19  A0 0F     LDY #$0F                     
DB1B  91 1E     STA ($1E),Y                  
DB1D  A0 05     LDY #$05                     
DB1F  B1 1E     LDA ($1E),Y                  
DB21  AA        TAX                          
DB22  A9 78     LDA #$78                     
DB24  E0 03     CPX #$03                     
DB26  D0 02     BNE LDB2A                    
DB28  A5 65     LDA $65                      

; branch target entry
LDB2A:
DB2A  A0 07     LDY #$07                     
DB2C  91 1E     STA ($1E),Y                  
DB2E  BC 33 DB  LDY $DB33,X                  
DB31  4C CA D4  JMP LD4CA                    
        .byte $44,$44,$08,$A0,$07,$B1,$1E,$38  ; DD.....8
        .byte $E9,$01,$91,$1E,$D0,$12,$4C,$17  ; ......L.
        .byte $DD                              ; .

; reachable via computed jump entry
dyn_DB45:
DB45  EE 07 04  INC $0407                    
DB48  AD 07 04  LDA $0407                    
DB4B  C9 20     CMP #$20                     
DB4D  90 05     BCC LDB54                    
DB4F  A9 2A     LDA #$2A                     
DB51  8D 0F 04  STA $040F                    
DB54  60        RTS                          
DB55  AD A5 04  LDA $04A5                    
DB58  0D AD 04  ORA $04AD                    
DB5B  D0 1D     BNE LDB7A                    
DB5D  20 BF F4  JSR LF4BF                    
DB60  A9 01     LDA #$01                     
DB62  8D 0B 06  STA $060B                    
DB65  8D 0C 06  STA $060C                    
DB68  8D 0D 06  STA $060D                    
DB6B  A9 16     LDA #$16                     
DB6D  8D 04 04  STA $0404                    
DB70  A9 00     LDA #$00                     
DB72  8D 07 04  STA $0407                    
DB75  A9 2C     LDA #$2C                     
DB77  8D 0F 04  STA $040F                    
DB7A  60        RTS                          
DB7B  EE 07 04  INC $0407                    
DB7E  10 FA     BPL LDB7A                    
DB80  4C 6F DE  JMP LDE6F                    
DB83  A9 00     LDA #$00                     
DB85  A0 08     LDY #$08                     
DB87  91 1E     STA ($1E),Y                  
DB89  A9 06     LDA #$06                     
DB8B  A0 0F     LDY #$0F                     
DB8D  91 1E     STA ($1E),Y                  
DB8F  A0 04     LDY #$04                     
DB91  91 1E     STA ($1E),Y                  
DB93  60        RTS                          
DB94  20 02 E1  JSR LE102                    
DB97  F0 0B     BEQ LDBA4                    
DB99  A0 08     LDY #$08                     
DB9B  B1 1E     LDA ($1E),Y                  
DB9D  38        SEC                          
DB9E  E9 49     SBC #$49                     
DBA0  C9 07     CMP #$07                     
DBA2  B0 03     BCS LDBA7                    

; branch target entry
LDBA4:
DBA4  4C D8 DA  JMP LDAD8                    
DBA7  A0 03     LDY #$03                     
DBA9  B1 1E     LDA ($1E),Y                  
DBAB  C9 1C     CMP #$1C                     
DBAD  90 03     BCC LDBB2                    
DBAF  4C D8 DA  JMP LDAD8                    
DBB2  20 6A E0  JSR LE06A                    
DBB5  20 69 E4  JSR LE469                    
DBB8  B0 D9     BCS LDB93                    
DBBA  A0 05     LDY #$05                     
DBBC  B1 1E     LDA ($1E),Y                  
DBBE  D0 23     BNE LDBE3                    
DBC0  86 18     STX $18                      
DBC2  A5 42     LDA $42                      
DBC4  8D 0A 06  STA $060A                    
DBC7  A0 3C     LDY #$3C                     
DBC9  20 CA D4  JSR LD4CA                    
DBCC  A6 18     LDX $18                      
DBCE  BD 02 02  LDA $0202,X                  
DBD1  D0 10     BNE LDBE3                    
DBD3  A9 01     LDA #$01                     
DBD5  9D 00 02  STA $0200,X                  
DBD8  A9 09     LDA #$09                     
DBDA  9D 01 02  STA $0201,X                  
DBDD  A9 80     LDA #$80                     
DBDF  9D 02 02  STA $0202,X                  
DBE2  60        RTS                          
DBE3  A0 01     LDY #$01                     
DBE5  BD 01 02  LDA $0201,X                  
DBE8  C9 08     CMP #$08                     
DBEA  90 01     BCC LDBED                    
DBEC  C8        INY                          
DBED  98        TYA                          
DBEE  9D 00 02  STA $0200,X                  
DBF1  8A        TXA                          
DBF2  A0 0B     LDY #$0B                     
DBF4  91 1E     STA ($1E),Y                  
DBF6  A9 00     LDA #$00                     
DBF8  A0 07     LDY #$07                     
DBFA  91 1E     STA ($1E),Y                  
DBFC  A9 0A     LDA #$0A                     
DBFE  A0 0F     LDY #$0F                     
DC00  91 1E     STA ($1E),Y                  
DC02  A0 0B     LDY #$0B                     
DC04  B1 1E     LDA ($1E),Y                  
DC06  AA        TAX                          
DC07  20 A4 E4  JSR LE4A4                    
DC0A  BD 02 02  LDA $0202,X                  
DC0D  10 03     BPL LDC12                    
DC0F  4C 83 DB  JMP LDB83                    
DC12  BD 01 02  LDA $0201,X                  
DC15  C9 07     CMP #$07                     
DC17  D0 3F     BNE LDC58                    
DC19  A0 05     LDY #$05                     
DC1B  B1 1E     LDA ($1E),Y                  
DC1D  D0 03     BNE LDC22                    
DC1F  DE 02 02  DEC $0202,X                  
DC22  A9 00     LDA #$00                     
DC24  A0 08     LDY #$08                     
DC26  91 1E     STA ($1E),Y                  
DC28  A9 0C     LDA #$0C                     
DC2A  A0 0F     LDY #$0F                     
DC2C  91 1E     STA ($1E),Y                  
DC2E  A9 06     LDA #$06                     
DC30  A0 04     LDY #$04                     
DC32  91 1E     STA ($1E),Y                  
DC34  A5 1E     LDA $1E                      
DC36  C9 20     CMP #$20                     
DC38  F0 1F     BEQ LDC59                    
DC3A  A0 0A     LDY #$0A                     
DC3C  B1 1E     LDA ($1E),Y                  
DC3E  29 FC     AND #$FC                     
DC40  09 01     ORA #$01                     
DC42  A0 03     LDY #$03                     
DC44  D1 1E     CMP ($1E),Y                  
DC46  90 10     BCC LDC58                    
DC48  B1 1E     LDA ($1E),Y                  
DC4A  29 FC     AND #$FC                     
DC4C  85 10     STA $10                      
DC4E  A0 0A     LDY #$0A                     
DC50  B1 1E     LDA ($1E),Y                  
DC52  29 01     AND #$01                     
DC54  05 10     ORA $10                      
DC56  91 1E     STA ($1E),Y                  
DC58  60        RTS                          
DC59  4C F0 D9  JMP LD9F0                    
DC5C  20 02 E1  JSR LE102                    
DC5F  D0 03     BNE LDC64                    
DC61  4C D8 DA  JMP LDAD8                    
DC64  A0 03     LDY #$03                     
DC66  B1 1E     LDA ($1E),Y                  
DC68  29 03     AND #$03                     
DC6A  38        SEC                          
DC6B  E9 01     SBC #$01                     
DC6D  C9 02     CMP #$02                     
DC6F  B0 06     BCS LDC77                    
DC71  A0 0D     LDY #$0D                     
DC73  B1 1E     LDA ($1E),Y                  
DC75  D0 56     BNE LDCCD                    
DC77  A0 08     LDY #$08                     
DC79  B1 1E     LDA ($1E),Y                  
DC7B  C9 59     CMP #$59                     
DC7D  F0 12     BEQ LDC91                    
DC7F  38        SEC                          
DC80  E9 30     SBC #$30                     
DC82  C9 20     CMP #$20                     
DC84  90 0B     BCC LDC91                    
DC86  A0 03     LDY #$03                     
DC88  B1 1E     LDA ($1E),Y                  
DC8A  C9 06     CMP #$06                     
DC8C  90 03     BCC LDC91                    
DC8E  4C 84 E0  JMP LE084                    
DC91  A0 03     LDY #$03                     
DC93  B1 1E     LDA ($1E),Y                  
DC95  29 FC     AND #$FC                     
DC97  85 10     STA $10                      
DC99  A5 1E     LDA $1E                      
DC9B  C9 20     CMP #$20                     
DC9D  F0 1E     BEQ LDCBD                    
DC9F  A0 0A     LDY #$0A                     
DCA1  B1 1E     LDA ($1E),Y                  
DCA3  29 FC     AND #$FC                     
DCA5  C5 10     CMP $10                      
DCA7  F0 0B     BEQ LDCB4                    
DCA9  B1 1E     LDA ($1E),Y                  
DCAB  29 03     AND #$03                     
DCAD  05 10     ORA $10                      
DCAF  91 1E     STA ($1E),Y                  
DCB1  4C 83 DB  JMP LDB83                    

; branch target entry
LDCB4:
DCB4  B1 1E     LDA ($1E),Y                  
DCB6  49 01     EOR #$01                     
DCB8  91 1E     STA ($1E),Y                  
DCBA  4C 83 DB  JMP LDB83                    

; branch target entry
LDCBD:
DCBD  A5 10     LDA $10                      
DCBF  09 01     ORA #$01                     
DCC1  38        SEC                          
DCC2  E5 37     SBC $37                      
DCC4  85 36     STA $36                      
DCC6  A9 01     LDA #$01                     
DCC8  85 35     STA $35                      
DCCA  4C 83 DB  JMP LDB83                    
DCCD  A0 06     LDY #$06                     
DCCF  91 1E     STA ($1E),Y                  
DCD1  A0 03     LDY #$03                     
DCD3  B1 1E     LDA ($1E),Y                  
DCD5  29 FE     AND #$FE                     
DCD7  09 02     ORA #$02                     
DCD9  91 1E     STA ($1E),Y                  
DCDB  88        DEY                          
DCDC  A9 00     LDA #$00                     
DCDE  91 1E     STA ($1E),Y                  
DCE0  A9 10     LDA #$10                     
DCE2  A0 07     LDY #$07                     
DCE4  91 1E     STA ($1E),Y                  
DCE6  A9 E0     LDA #$E0                     
DCE8  A0 0B     LDY #$0B                     
DCEA  91 1E     STA ($1E),Y                  
DCEC  A9 04     LDA #$04                     
DCEE  C8        INY                          
DCEF  91 1E     STA ($1E),Y                  
DCF1  A9 0E     LDA #$0E                     
DCF3  A0 0F     LDY #$0F                     
DCF5  91 1E     STA ($1E),Y                  
DCF7  A9 04     LDA #$04                     
DCF9  A0 04     LDY #$04                     
DCFB  91 1E     STA ($1E),Y                  
DCFD  60        RTS                          
DCFE  A0 08     LDY #$08                     
DD00  B1 1E     LDA ($1E),Y                  
DD02  38        SEC                          
DD03  E9 49     SBC #$49                     
DD05  C9 10     CMP #$10                     
DD07  90 37     BCC LDD40                    
DD09  A0 07     LDY #$07                     
DD0B  B1 1E     LDA ($1E),Y                  
DD0D  38        SEC                          
DD0E  E9 01     SBC #$01                     
DD10  91 1E     STA ($1E),Y                  
DD12  F0 03     BEQ LDD17                    
DD14  4C 3D E0  JMP LE03D                    
DD17  A9 00     LDA #$00                     
DD19  A0 02     LDY #$02                     
DD1B  91 1E     STA ($1E),Y                  
DD1D  C8        INY                          
DD1E  B1 1E     LDA ($1E),Y                  
DD20  29 FC     AND #$FC                     
DD22  09 02     ORA #$02                     
DD24  91 1E     STA ($1E),Y                  
DD26  A9 4B     LDA #$4B                     
DD28  A0 08     LDY #$08                     
DD2A  91 1E     STA ($1E),Y                  
DD2C  A0 05     LDY #$05                     
DD2E  B1 1E     LDA ($1E),Y                  
DD30  D0 03     BNE LDD35                    
DD32  20 DE E3  JSR LE3DE                    
DD35  A9 02     LDA #$02                     
DD37  A0 0F     LDY #$0F                     
DD39  91 1E     STA ($1E),Y                  
DD3B  A0 04     LDY #$04                     
DD3D  91 1E     STA ($1E),Y                  
DD3F  60        RTS                          
DD40  A5 1E     LDA $1E                      
DD42  C9 20     CMP #$20                     
DD44  F0 06     BEQ LDD4C                    
DD46  20 A6 DE  JSR LDEA6                    
DD49  4C 4F DD  JMP LDD4F                    

; branch target entry
LDD4C:
DD4C  20 02 DA  JSR LDA02                    
DD4F  A9 00     LDA #$00                     
DD51  38        SEC                          
DD52  A0 06     LDY #$06                     
DD54  F1 1E     SBC ($1E),Y                  
DD56  91 1E     STA ($1E),Y                  
DD58  A9 06     LDA #$06                     
DD5A  C8        INY                          
DD5B  91 1E     STA ($1E),Y                  
DD5D  A9 00     LDA #$00                     
DD5F  4C B3 DA  JMP LDAB3                    
DD62  20 B1 F0  JSR LF0B1                    
DD65  20 E7 F0  JSR LF0E7                    
DD68  F0 38     BEQ LDDA2                    
DD6A  A0 08     LDY #$08                     
DD6C  B1 1E     LDA ($1E),Y                  
DD6E  38        SEC                          
DD6F  E9 49     SBC #$49                     
DD71  C9 09     CMP #$09                     
DD73  B0 30     BCS LDDA5                    
DD75  A5 1E     LDA $1E                      
DD77  D0 03     BNE LDD7C                    
DD79  20 34 E1  JSR LE134                    
DD7C  A9 80     LDA #$80                     
DD7E  20 09 DF  JSR LDF09                    
DD81  A0 07     LDY #$07                     
DD83  B1 1E     LDA ($1E),Y                  
DD85  38        SEC                          
DD86  E9 01     SBC #$01                     
DD88  91 1E     STA ($1E),Y                  
DD8A  D0 15     BNE LDDA1                    
DD8C  A0 05     LDY #$05                     
DD8E  B1 1E     LDA ($1E),Y                  
DD90  D0 03     BNE LDD95                    
DD92  4C 17 DD  JMP LDD17                    
DD95  A5 65     LDA $65                      
DD97  A0 07     LDY #$07                     
DD99  91 1E     STA ($1E),Y                  
DD9B  A9 12     LDA #$12                     
DD9D  A0 0F     LDY #$0F                     
DD9F  91 1E     STA ($1E),Y                  
DDA1  60        RTS                          

; branch target entry
LDDA2:
DDA2  4C 83 DB  JMP LDB83                    

; branch target entry
LDDA5:
DDA5  4C A2 DA  JMP LDAA2                    
DDA8  A0 07     LDY #$07                     
DDAA  B1 1E     LDA ($1E),Y                  
DDAC  38        SEC                          
DDAD  E9 01     SBC #$01                     
DDAF  91 1E     STA ($1E),Y                  
DDB1  D0 EE     BNE LDDA1                    
DDB3  A9 40     LDA #$40                     
DDB5  A0 07     LDY #$07                     
DDB7  91 1E     STA ($1E),Y                  
DDB9  A9 0E     LDA #$0E                     
DDBB  A0 04     LDY #$04                     
DDBD  91 1E     STA ($1E),Y                  
DDBF  A9 14     LDA #$14                     
DDC1  A0 0F     LDY #$0F                     
DDC3  91 1E     STA ($1E),Y                  
DDC5  60        RTS                          
DDC6  A0 07     LDY #$07                     
DDC8  B1 1E     LDA ($1E),Y                  
DDCA  38        SEC                          
DDCB  E9 01     SBC #$01                     
DDCD  91 1E     STA ($1E),Y                  
DDCF  D0 F4     BNE LDDC5                    
DDD1  4C 17 DD  JMP LDD17                    
DDD4  A0 07     LDY #$07                     
DDD6  B1 1E     LDA ($1E),Y                  
DDD8  F0 05     BEQ LDDDF                    
DDDA  38        SEC                          
DDDB  E9 01     SBC #$01                     
DDDD  91 1E     STA ($1E),Y                  
DDDF  60        RTS                          
        .byte $A5,$4B,$05,$4F,$D0,$3E,$A0,$08  ; .K.O.>..
        .byte $B1,$1E,$38,$E9,$49,$C9,$07,$90  ; ..8.I...
        .byte $16,$A0,$03,$B1,$1E,$C9,$1C,$B0  ; ........
        .byte $0B,$20,$6A,$E0,$20,$69,$E4,$B0  ; . j. i..
        .byte $23,$4C,$BA,$DB,$4C,$D8,$DA,$A5  ; #L..L...
        .byte $1E,$C9,$20,$D0,$1D,$A9,$24,$8D  ; .. ...$.
        .byte $2F,$04,$A9,$12,$8D,$24,$04,$A9  ; /....$..
        .byte $78,$8D,$27,$04,$A9,$09,$85,$36  ; x.'....6
        .byte $A9,$04,$85,$37,$60,$CE,$27,$04  ; ...7`.'.
        .byte $D0,$FA,$4C,$17,$DD              ; ..L..

; reachable via computed jump entry
dyn_DE2D:
DE2D  CE 27 04  DEC $0427                    
DE30  F0 27     BEQ LDE59                    
DE32  AD 23 04  LDA $0423                    
DE35  CD 03 04  CMP $0403                    
DE38  D0 3F     BNE LDE79                    
DE3A  AD 21 04  LDA $0421                    
DE3D  38        SEC                          
DE3E  ED 01 04  SBC $0401                    
DE41  C9 02     CMP #$02                     
DE43  B0 34     BCS LDE79                    
DE45  A9 20     LDA #$20                     
DE47  8D 2F 04  STA $042F                    
DE4A  A9 15     LDA #$15                     
DE4C  8D 24 04  STA $0424                    
DE4F  A9 78     LDA #$78                     
DE51  8D 27 04  STA $0427                    
DE54  A0 44     LDY #$44                     
DE56  4C CA D4  JMP LD4CA                    
DE59  A9 10     LDA #$10                     
DE5B  8D 2A 04  STA $042A                    
DE5E  4C 17 DD  JMP LDD17                    
DE61  CE 27 04  DEC $0427                    
DE64  D0 13     BNE LDE79                    
DE66  A5 4B     LDA $4B                      
DE68  05 4F     ORA $4F                      
DE6A  D0 03     BNE LDE6F                    
DE6C  4C 17 DD  JMP LDD17                    
DE6F  A9 00     LDA #$00                     
DE71  A0 0F     LDY #$0F                     
DE73  91 1E     STA ($1E),Y                  
DE75  A0 04     LDY #$04                     
DE77  91 1E     STA ($1E),Y                  
DE79  60        RTS                          
        .byte $A0,$07,$B1,$1E,$38,$E9,$01,$91  ; ....8...
        .byte $1E,$D0,$12,$A9,$28,$A0,$0F,$91  ; ....(...
        .byte $1E,$A9,$24,$A0,$04,$91,$1E,$A9  ; ..$.....
        .byte $40,$A0,$07,$91,$1E,$60,$A0,$07  ; @....`..
        .byte $B1,$1E,$38,$E9,$01,$91,$1E,$D0  ; ..8.....
        .byte $F4,$4C,$83,$DB                  ; .L..

; reachable via computed jump entry
dyn_DEA6:
DEA6  A0 06     LDY #$06                     
DEA8  B1 1E     LDA ($1E),Y                  
DEAA  29 01     AND #$01                     
DEAC  49 01     EOR #$01                     
DEAE  85 10     STA $10                      
DEB0  A0 03     LDY #$03                     
DEB2  B1 1E     LDA ($1E),Y                  
DEB4  29 FC     AND #$FC                     
DEB6  05 10     ORA $10                      
DEB8  85 10     STA $10                      
DEBA  A0 01     LDY #$01                     
DEBC  B1 1E     LDA ($1E),Y                  
DEBE  CD 01 04  CMP $0401                    
DEC1  AD 03 04  LDA $0403                    
DEC4  29 FC     AND #$FC                     
DEC6  69 00     ADC #$00                     
DEC8  A0 0A     LDY #$0A                     
DECA  91 1E     STA ($1E),Y                  
DECC  C5 10     CMP $10                      
DECE  D0 11     BNE LDEE1                    
DED0  A6 21     LDX $21                      
DED2  BD 00 C0  LDA $C000,X                  
DED5  4A        LSR A                        
DED6  A9 04     LDA #$04                     
DED8  90 02     BCC LDEDC                    
DEDA  A9 FC     LDA #$FC                     
DEDC  18        CLC                          
DEDD  71 1E     ADC ($1E),Y                  
DEDF  91 1E     STA ($1E),Y                  
DEE1  60        RTS                          
DEE2  A9 00     LDA #$00                     
DEE4  A0 07     LDY #$07                     
DEE6  91 1E     STA ($1E),Y                  
DEE8  60        RTS                          
DEE9  A5 1E     LDA $1E                      
DEEB  D0 0A     BNE LDEF7                    
DEED  A0 0D     LDY #$0D                     
DEEF  B1 1E     LDA ($1E),Y                  
DEF1  F0 EF     BEQ LDEE2                    
DEF3  A0 06     LDY #$06                     
DEF5  91 1E     STA ($1E),Y                  
DEF7  A0 07     LDY #$07                     
DEF9  B1 1E     LDA ($1E),Y                  
DEFB  18        CLC                          
DEFC  69 01     ADC #$01                     
DEFE  91 1E     STA ($1E),Y                  
DF00  A0 09     LDY #$09                     
DF02  B1 1E     LDA ($1E),Y                  
DF04  D0 E2     BNE LDEE8                    
DF06  20 18 E0  JSR LE018                    
DF09  A2 04     LDX #$04                     
DF0B  85 10     STA $10                      
DF0D  20 8A DF  JSR LDF8A                    
DF10  A0 06     LDY #$06                     
DF12  B1 1E     LDA ($1E),Y                  
DF14  30 3D     BMI LDF53                    
DF16  A0 01     LDY #$01                     
DF18  B1 1E     LDA ($1E),Y                  
DF1A  C9 38     CMP #$38                     
DF1C  F0 18     BEQ LDF36                    
DF1E  88        DEY                          
DF1F  B1 1E     LDA ($1E),Y                  
DF21  18        CLC                          
DF22  65 10     ADC $10                      
DF24  91 1E     STA ($1E),Y                  
DF26  90 2A     BCC LDF52                    
DF28  C8        INY                          
DF29  B1 1E     LDA ($1E),Y                  
DF2B  69 00     ADC #$00                     
DF2D  91 1E     STA ($1E),Y                  
DF2F  C9 38     CMP #$38                     
DF31  B0 03     BCS LDF36                    
DF33  4C CD DF  JMP LDFCD                    
DF36  88        DEY                          
DF37  A9 00     LDA #$00                     
DF39  91 1E     STA ($1E),Y                  
DF3B  A9 4D     LDA #$4D                     
DF3D  A0 08     LDY #$08                     
DF3F  91 1E     STA ($1E),Y                  
DF41  A5 1E     LDA $1E                      
DF43  F0 0D     BEQ LDF52                    
DF45  C9 20     CMP #$20                     
DF47  D0 03     BNE LDF4C                    
DF49  20 F0 D9  JSR LD9F0                    
DF4C  A9 FF     LDA #$FF                     
DF4E  A0 06     LDY #$06                     
DF50  91 1E     STA ($1E),Y                  
DF52  60        RTS                          
DF53  A0 00     LDY #$00                     
DF55  B1 1E     LDA ($1E),Y                  
DF57  38        SEC                          
DF58  E5 10     SBC $10                      
DF5A  91 1E     STA ($1E),Y                  
DF5C  B0 2B     BCS LDF89                    
DF5E  C8        INY                          
DF5F  B1 1E     LDA ($1E),Y                  
DF61  E9 00     SBC #$00                     
DF63  91 1E     STA ($1E),Y                  
DF65  C9 02     CMP #$02                     
DF67  B0 60     BCS LDFC9                    
DF69  A9 02     LDA #$02                     
DF6B  91 1E     STA ($1E),Y                  
DF6D  88        DEY                          
DF6E  A9 00     LDA #$00                     
DF70  91 1E     STA ($1E),Y                  
DF72  A9 4C     LDA #$4C                     
DF74  A0 08     LDY #$08                     
DF76  91 1E     STA ($1E),Y                  
DF78  A5 1E     LDA $1E                      
DF7A  F0 0D     BEQ LDF89                    
DF7C  C9 20     CMP #$20                     
DF7E  D0 03     BNE LDF83                    
DF80  20 F0 D9  JSR LD9F0                    

; branch target entry
LDF83:
DF83  A9 01     LDA #$01                     
DF85  A0 06     LDY #$06                     
DF87  91 1E     STA ($1E),Y                  
DF89  60        RTS                          
DF8A  A0 05     LDY #$05                     
DF8C  B1 1E     LDA ($1E),Y                  
DF8E  D0 24     BNE LDFB4                    
DF90  AD 01 04  LDA $0401                    
DF93  38        SEC                          
DF94  E9 0F     SBC #$0F                     
DF96  C9 1C     CMP #$1C                     
DF98  B0 1A     BCS LDFB4                    
DF9A  AD 06 04  LDA $0406                    
DF9D  30 16     BMI LDFB5                    
DF9F  A5 28     LDA $28                      
DFA1  18        CLC                          
DFA2  65 10     ADC $10                      
DFA4  85 11     STA $11                      
DFA6  A5 29     LDA $29                      
DFA8  69 00     ADC #$00                     
DFAA  C9 1C     CMP #$1C                     
DFAC  B0 06     BCS LDFB4                    
DFAE  85 29     STA $29                      
DFB0  A5 11     LDA $11                      
DFB2  85 28     STA $28                      
DFB4  60        RTS                          
DFB5  A5 28     LDA $28                      
DFB7  38        SEC                          
DFB8  E5 10     SBC $10                      
DFBA  85 11     STA $11                      
DFBC  A5 29     LDA $29                      
DFBE  E9 00     SBC #$00                     
DFC0  90 06     BCC LDFC8                    
DFC2  85 29     STA $29                      
DFC4  A5 11     LDA $11                      
DFC6  85 28     STA $28                      
DFC8  60        RTS                          
DFC9  8A        TXA                          
DFCA  09 04     ORA #$04                     
DFCC  AA        TAX                          
DFCD  A0 01     LDY #$01                     
DFCF  B1 1E     LDA ($1E),Y                  
DFD1  18        CLC                          
DFD2  7D 10 E0  ADC $E010,X                  
DFD5  0A        ASL A                        
DFD6  0A        ASL A                        
DFD7  0A        ASL A                        
DFD8  85 10     STA $10                      
DFDA  A0 03     LDY #$03                     
DFDC  B1 1E     LDA ($1E),Y                  
DFDE  90 02     BCC LDFE2                    
DFE0  09 20     ORA #$20                     
DFE2  18        CLC                          
DFE3  7D 11 E0  ADC $E011,X                  
DFE6  4A        LSR A                        
DFE7  66 10     ROR $10                      
DFE9  4A        LSR A                        
DFEA  66 10     ROR $10                      
DFEC  4A        LSR A                        
DFED  66 10     ROR $10                      
DFEF  09 20     ORA #$20                     
DFF1  85 11     STA $11                      
DFF3  A6 2B     LDX $2B                      
DFF5  A5 10     LDA $10                      
DFF7  9D C0 04  STA $04C0,X                  
DFFA  E8        INX                          
DFFB  A5 11     LDA $11                      
DFFD  9D C0 04  STA $04C0,X                  
E000  E8        INX                          
E001  A5 1E     LDA $1E                      
E003  9D C0 04  STA $04C0,X                  
E006  E8        INX                          
E007  A5 1F     LDA $1F                      
E009  9D C0 04  STA $04C0,X                  
E00C  E8        INX                          
E00D  86 2B     STX $2B                      
E00F  60        RTS                          
        .byte $01,$00,$02,$01,$01,$02,$00,$01  ; ........

; reachable via computed jump entry
dyn_E018:
E018  A0 00     LDY #$00                     
E01A  A5 60     LDA $60                      
E01C  F0 02     BEQ LE020                    
E01E  A0 04     LDY #$04                     
E020  84 10     STY $10                      
E022  A0 05     LDY #$05                     
E024  B1 1E     LDA ($1E),Y                  
E026  F0 0A     BEQ LE032                    
E028  C9 03     CMP #$03                     
E02A  90 09     BCC LE035                    
E02C  A5 64     LDA $64                      
E02E  18        CLC                          
E02F  65 10     ADC $10                      
E031  60        RTS                          
E032  A5 63     LDA $63                      
E034  60        RTS                          
E035  A5 64     LDA $64                      
E037  18        CLC                          
E038  69 04     ADC #$04                     
E03A  65 10     ADC $10                      
E03C  60        RTS                          
E03D  A0 0C     LDY #$0C                     
E03F  B1 1E     LDA ($1E),Y                  
E041  88        DEY                          
E042  18        CLC                          
E043  71 1E     ADC ($1E),Y                  
E045  91 1E     STA ($1E),Y                  
E047  0A        ASL A                        
E048  90 0B     BCC LE055                    
E04A  48        PHA                          
E04B  A0 03     LDY #$03                     
E04D  B1 1E     LDA ($1E),Y                  
E04F  38        SEC                          
E050  E9 01     SBC #$01                     
E052  91 1E     STA ($1E),Y                  
E054  68        PLA                          
E055  A0 02     LDY #$02                     
E057  18        CLC                          
E058  71 1E     ADC ($1E),Y                  
E05A  91 1E     STA ($1E),Y                  
E05C  C8        INY                          
E05D  B1 1E     LDA ($1E),Y                  
E05F  69 00     ADC #$00                     
E061  91 1E     STA ($1E),Y                  
E063  A9 30     LDA #$30                     
E065  A2 02     LDX #$02                     
E067  4C 0B DF  JMP LDF0B                    
E06A  20 18 E0  JSR LE018                    
E06D  18        CLC                          
E06E  69 20     ADC #$20                     
E070  A0 02     LDY #$02                     
E072  71 1E     ADC ($1E),Y                  
E074  91 1E     STA ($1E),Y                  
E076  90 2B     BCC LE0A3                    
E078  C8        INY                          
E079  B1 1E     LDA ($1E),Y                  
E07B  69 00     ADC #$00                     
E07D  91 1E     STA ($1E),Y                  
E07F  A2 04     LDX #$04                     
E081  4C A0 E0  JMP LE0A0                    
E084  20 18 E0  JSR LE018                    
E087  18        CLC                          
E088  69 20     ADC #$20                     
E08A  85 10     STA $10                      
E08C  A0 02     LDY #$02                     
E08E  B1 1E     LDA ($1E),Y                  
E090  38        SEC                          
E091  E5 10     SBC $10                      
E093  91 1E     STA ($1E),Y                  
E095  B0 0C     BCS LE0A3                    
E097  C8        INY                          
E098  B1 1E     LDA ($1E),Y                  
E09A  E9 00     SBC #$00                     
E09C  91 1E     STA ($1E),Y                  
E09E  A2 00     LDX #$00                     
E0A0  20 CD DF  JSR LDFCD                    
E0A3  A0 0D     LDY #$0D                     
E0A5  B1 1E     LDA ($1E),Y                  
E0A7  F0 04     BEQ LE0AD                    
E0A9  A0 06     LDY #$06                     
E0AB  91 1E     STA ($1E),Y                  
E0AD  A0 07     LDY #$07                     
E0AF  B1 1E     LDA ($1E),Y                  
E0B1  18        CLC                          
E0B2  69 01     ADC #$01                     
E0B4  91 1E     STA ($1E),Y                  
E0B6  60        RTS                          
E0B7  A5 1E     LDA $1E                      
E0B9  D0 44     BNE LE0FF                    
E0BB  A5 2E     LDA $2E                      
E0BD  D0 40     BNE LE0FF                    
E0BF  A2 10     LDX #$10                     
E0C1  BD 0F 04  LDA $040F,X                  
E0C4  C9 02     CMP #$02                     
E0C6  D0 2E     BNE LE0F6                    
E0C8  E0 20     CPX #$20                     
E0CA  D0 05     BNE LE0D1                    
E0CC  AD 2A 04  LDA $042A                    
E0CF  D0 25     BNE LE0F6                    
E0D1  BD 03 04  LDA $0403,X                  
E0D4  CD 03 04  CMP $0403                    
E0D7  D0 1D     BNE LE0F6                    
E0D9  BD 00 04  LDA $0400,X                  
E0DC  38        SEC                          
E0DD  ED 00 04  SBC $0400                    
E0E0  BD 01 04  LDA $0401,X                  
E0E3  ED 01 04  SBC $0401                    
E0E6  18        CLC                          
E0E7  69 01     ADC #$01                     
E0E9  C9 02     CMP #$02                     
E0EB  B0 09     BCS LE0F6                    
E0ED  BD 06 04  LDA $0406,X                  
E0F0  8D 06 04  STA $0406                    
E0F3  A9 00     LDA #$00                     
E0F5  60        RTS                          
E0F6  8A        TXA                          
E0F7  18        CLC                          
E0F8  69 10     ADC #$10                     
E0FA  AA        TAX                          
E0FB  E0 90     CPX #$90                     
E0FD  D0 C2     BNE LE0C1                    
E0FF  A9 FF     LDA #$FF                     
E101  60        RTS                          
E102  A5 1E     LDA $1E                      
E104  D0 2B     BNE LE131                    
E106  AD 12 04  LDA $0412                    
E109  38        SEC                          
E10A  ED 02 04  SBC $0402                    
E10D  AD 13 04  LDA $0413                    
E110  ED 03 04  SBC $0403                    
E113  18        CLC                          
E114  69 01     ADC #$01                     
E116  C9 02     CMP #$02                     
E118  B0 17     BCS LE131                    
E11A  AD 10 04  LDA $0410                    
E11D  38        SEC                          
E11E  ED 00 04  SBC $0400                    
E121  AD 11 04  LDA $0411                    
E124  ED 01 04  SBC $0401                    
E127  18        CLC                          
E128  69 01     ADC #$01                     
E12A  C9 02     CMP #$02                     
E12C  B0 03     BCS LE131                    
E12E  A9 00     LDA #$00                     
E130  60        RTS                          
E131  A9 FF     LDA #$FF                     
E133  60        RTS                          

; subroutine entry
sub_E134:
E134  A2 20     LDX #$20                     

; branch target entry
LE136:
E136  BD 0F 04  LDA $040F,X                  
E139  C9 02     CMP #$02                     
E13B  D0 33     BNE LE170                    
E13D  BD 03 04  LDA $0403,X                  
E140  CD 03 04  CMP $0403                    
E143  D0 2B     BNE LE170                    
E145  BD 00 04  LDA $0400,X                  
E148  38        SEC                          
E149  ED 00 04  SBC $0400                    
E14C  BD 01 04  LDA $0401,X                  
E14F  ED 01 04  SBC $0401                    
E152  18        CLC                          
E153  69 01     ADC #$01                     
E155  C9 02     CMP #$02                     
E157  B0 17     BCS LE170                    
E159  AD 06 04  LDA $0406                    
E15C  9D 06 04  STA $0406,X                  
E15F  A9 0C     LDA #$0C                     
E161  9D 04 04  STA $0404,X                  
E164  A9 10     LDA #$10                     
E166  9D 0F 04  STA $040F,X                  
E169  A9 08     LDA #$08                     
E16B  9D 07 04  STA $0407,X                  
E16E  E6 30     INC $30                      

; branch target entry
LE170:
E170  8A        TXA                          
E171  18        CLC                          
E172  69 01     ADC #$01                     
E174  AA        TAX                          
E175  E0 90     CPX #$90                     
E177  D0 BD     BNE LE136                    
E179  60        RTS                          
        .byte $4F,$C1,$9D,$E1,$9C,$E1,$00,$E2  ; O.......
        .byte $30,$E2,$A1,$E2,$AC,$E2,$EE,$E2  ; 0.......
        .byte $E0,$E2,$39,$E3,$A9,$00,$8D,$07  ; ..9.....
        .byte $04,$A9,$01,$85,$4B,$A9,$04,$8D  ; ....K...
        .byte $0F,$04,$60,$A0,$08,$B1,$1E,$38  ; ..`....8
        .byte $E9,$49,$C9,$07,$90,$E6,$A0,$03  ; .I......
        .byte $B1,$1E,$C9,$1C,$B0,$DE,$20,$6A  ; ...... j
        .byte $E0,$20,$69,$E4,$B0,$28,$A0,$05  ; . i..(..
        .byte $B1,$1E,$D0,$23,$86,$18,$A9,$01  ; ...#....
        .byte $8D,$0A,$06,$A0,$3C,$20,$CA,$D4  ; ....< ..
        .byte $A6,$18,$BD,$02,$02,$D0,$10,$A9  ; ........
        .byte $01,$9D,$00,$02,$A9,$09,$9D,$01  ; ........
        .byte $02,$A9,$80,$9D,$02,$02,$60,$A0  ; ......`.
        .byte $01,$BD,$01,$02,$C9,$08,$90,$01  ; ........
        .byte $C8,$98,$9D,$00,$02,$8A,$A0,$0B  ; ........
        .byte $91,$1E,$A9,$00,$A0,$07,$91,$1E  ; ........
        .byte $A9,$06,$A0,$0F,$91,$1E,$A0,$0B  ; ........
        .byte $B1,$1E,$AA,$20,$A4,$E4,$BD,$02  ; ... ....
        .byte $02,$30,$50,$BD,$01,$02,$C9,$07  ; .0P.....
        .byte $D0,$1B,$A0,$05,$B1,$1E,$D0,$03  ; ........
        .byte $DE,$02,$02,$A9,$00,$A0,$08,$91  ; ........
        .byte $1E,$A9,$08,$A0,$0F,$91,$1E,$A9  ; ........
        .byte $06,$A0,$04,$91,$1E,$60,$A0,$03  ; .....`..
        .byte $B1,$1E,$C9,$08,$90,$0F,$29,$03  ; ......).
        .byte $38,$E9,$01,$C9,$02,$B0,$06,$A0  ; 8.......
        .byte $0D,$B1,$1E,$D0,$29,$A0,$08,$B1  ; ....)...
        .byte $1E,$38,$E9,$30,$C9,$20,$90,$0B  ; .8.0. ..
        .byte $A0,$03,$B1,$1E,$C9,$06,$90,$03  ; ........
        .byte $4C,$84,$E0,$A9,$00,$A0,$08,$91  ; L.......
        .byte $1E,$A9,$02,$A0,$0F,$91,$1E,$A9  ; ........
        .byte $06,$A0,$04,$91,$1E,$60,$A0,$06  ; .....`..
        .byte $91,$1E,$A0,$03,$B1,$1E,$29,$FE  ; ......).
        .byte $09,$02,$91,$1E,$88,$A9,$00,$91  ; ........
        .byte $1E,$A9,$21,$A0,$07,$91,$1E,$A9  ; ..!.....
        .byte $E0,$A0,$0B,$91,$1E,$A9,$02,$C8  ; ........
        .byte $91,$1E,$A9,$0A,$A0,$0F,$91,$1E  ; ........
        .byte $A9,$04,$A0,$04,$91,$1E,$60,$A0  ; ......`.
        .byte $08,$B1,$1E,$38,$E9,$49,$C9,$10  ; ...8.I..
        .byte $90,$0E,$A0,$07,$B1,$1E,$38,$E9  ; ......8.
        .byte $01,$91,$1E,$F0,$A6,$4C,$3D,$E0  ; .....L=.
        .byte $A9,$00,$38,$A0,$06,$F1,$1E,$91  ; ..8.....
        .byte $1E,$A9,$06,$C8,$91,$1E,$A9,$00  ; ........
        .byte $A0,$0B,$91,$1E,$A9,$09,$C8,$91  ; ........
        .byte $1E,$A9,$0C,$A0,$0F,$91,$1E,$A9  ; ........
        .byte $04,$A0,$04,$91,$1E,$60,$CE,$37  ; .....`.7
        .byte $04,$D0,$08,$A9,$00,$8D,$34,$04  ; ......4.
        .byte $8D,$3F,$04,$60,$AD,$13,$04,$CD  ; .?.`....
        .byte $03,$04,$D0,$3B,$AD,$11,$04,$38  ; ...;...8
        .byte $ED,$01,$04,$C9,$02,$B0,$30,$E6  ; ......0.
        .byte $51,$A9,$20,$85,$5A,$20,$BF,$F4  ; Q. .Z ..
        .byte $A9,$01,$8D,$06,$06,$A9,$00,$8D  ; ........
        .byte $14,$04,$8D,$1F,$04,$20,$8E,$E1  ; ..... ..
        .byte $A9,$12,$8D,$2F,$04,$A2,$00,$BD  ; .../....
        .byte $32,$E3,$9D,$20,$04,$E8,$E0,$07  ; 2.. ....
        .byte $D0,$F5,$A9,$00,$8D,$2B,$04,$60  ; .....+.`
        .byte $00,$05,$00,$18,$06,$02,$FF,$AD  ; ........
        .byte $28,$04,$38,$E9,$30,$C9,$19,$B0  ; (.8.0...
        .byte $03,$20,$56,$E4,$AD,$23,$04,$C9  ; . V..#..
        .byte $06,$90,$05,$A9,$40,$4C,$8A,$E0  ; ....@L..
        .byte $A9,$00,$8D,$24,$04,$8D,$2F,$04  ; ...$../.
        .byte $60                              ; `

; reachable via computed jump entry
dyn_E35B:
E35B  A6 7A     LDX $7A                      
E35D  BC E1 E4  LDY $E4E1,X                  
E360  B9 F1 E4  LDA $E4F1,Y                  
E363  85 1C     STA $1C                      
E365  B9 F2 E4  LDA $E4F2,Y                  
E368  85 1D     STA $1D                      
E36A  A0 00     LDY #$00                     
E36C  B1 1C     LDA ($1C),Y                  
E36E  C8        INY                          
E36F  85 80     STA $80                      
E371  A2 00     LDX #$00                     
E373  A9 00     LDA #$00                     
E375  9D 00 02  STA $0200,X                  
E378  9D 01 02  STA $0201,X                  
E37B  A9 03     LDA #$03                     
E37D  9D 02 02  STA $0202,X                  
E380  B1 1C     LDA ($1C),Y                  
E382  C8        INY                          
E383  84 1B     STY $1B                      
E385  9D 03 02  STA $0203,X                  
E388  A8        TAY                          
E389  B9 37 E5  LDA $E537,Y                  
E38C  85 10     STA $10                      
E38E  B9 38 E5  LDA $E538,Y                  
E391  85 11     STA $11                      
E393  20 BD E3  JSR LE3BD                    
E396  A5 10     LDA $10                      
E398  9D 04 02  STA $0204,X                  
E39B  A5 11     LDA $11                      
E39D  9D 05 02  STA $0205,X                  
E3A0  A4 1B     LDY $1B                      
E3A2  8A        TXA                          
E3A3  18        CLC                          
E3A4  69 08     ADC #$08                     
E3A6  AA        TAX                          
E3A7  E4 80     CPX $80                      
E3A9  D0 C8     BNE LE373                    
E3AB  A2 00     LDX #$00                     
E3AD  86 1B     STX $1B                      
E3AF  20 27 E4  JSR LE427                    
E3B2  A5 1B     LDA $1B                      
E3B4  18        CLC                          
E3B5  69 08     ADC #$08                     
E3B7  AA        TAX                          
E3B8  E4 80     CPX $80                      
E3BA  D0 F1     BNE LE3AD                    
E3BC  60        RTS                          
E3BD  A5 10     LDA $10                      
E3BF  29 1F     AND #$1F                     
E3C1  06 10     ASL $10                      
E3C3  26 11     ROL $11                      
E3C5  06 10     ASL $10                      
E3C7  26 11     ROL $11                      
E3C9  06 10     ASL $10                      
E3CB  26 11     ROL $11                      
E3CD  85 10     STA $10                      
E3CF  A5 11     LDA $11                      
E3D1  29 20     AND #$20                     
E3D3  05 10     ORA $10                      
E3D5  85 10     STA $10                      
E3D7  A5 11     LDA $11                      
E3D9  29 1F     AND #$1F                     
E3DB  85 11     STA $11                      
E3DD  60        RTS                          
E3DE  A2 00     LDX #$00                     
E3E0  86 1B     STX $1B                      
E3E2  BD 02 02  LDA $0202,X                  
E3E5  30 0C     BMI LE3F3                    
E3E7  C9 03     CMP #$03                     
E3E9  F0 08     BEQ LE3F3                    
E3EB  A9 03     LDA #$03                     
E3ED  9D 02 02  STA $0202,X                  
E3F0  20 27 E4  JSR LE427                    
E3F3  A5 1B     LDA $1B                      
E3F5  18        CLC                          
E3F6  69 08     ADC #$08                     
E3F8  AA        TAX                          
E3F9  E4 80     CPX $80                      
E3FB  D0 E3     BNE LE3E0                    
E3FD  60        RTS                          
E3FE  A2 00     LDX #$00                     
E400  86 1B     STX $1B                      
E402  20 10 E4  JSR LE410                    
E405  A5 1B     LDA $1B                      
E407  18        CLC                          
E408  69 08     ADC #$08                     
E40A  AA        TAX                          
E40B  E4 80     CPX $80                      
E40D  D0 F1     BNE LE400                    
E40F  60        RTS                          
E410  BD 00 02  LDA $0200,X                  
E413  F0 FA     BEQ LE40F                    
E415  FE 01 02  INC $0201,X                  
E418  BD 01 02  LDA $0201,X                  
E41B  C9 0A     CMP #$0A                     
E41D  90 08     BCC LE427                    
E41F  A9 00     LDA #$00                     
E421  9D 01 02  STA $0201,X                  
E424  DE 00 02  DEC $0200,X                  
E427  BC 03 02  LDY $0203,X                  
E42A  B9 37 E5  LDA $E537,Y                  
E42D  85 10     STA $10                      
E42F  B9 38 E5  LDA $E538,Y                  
E432  85 11     STA $11                      
E434  BD 02 02  LDA $0202,X                  
E437  10 09     BPL LE442                    
E439  A9 00     LDA #$00                     
E43B  85 14     STA $14                      
E43D  A0 14     LDY #$14                     
E43F  4C 49 E4  JMP LE449                    
E442  85 14     STA $14                      
E444  BD 01 02  LDA $0201,X                  
E447  0A        ASL A                        
E448  A8        TAY                          
E449  B9 69 E5  LDA $E569,Y                  
E44C  85 12     STA $12                      
E44E  B9 6A E5  LDA $E56A,Y                  
E451  85 13     STA $13                      
E453  4C FB C6  JMP LC6FB                    
        .byte $AD,$37,$E5,$85,$10,$AD,$38,$E5  ; .7....8.
        .byte $85,$11,$A9,$00,$85,$14,$A0,$14  ; ........
        .byte $4C,$49,$E4                      ; LI.

; reachable via computed jump entry
dyn_E469:
E469  A2 00     LDX #$00                     
E46B  BD 02 02  LDA $0202,X                  
E46E  30 27     BMI LE497                    
E470  A0 01     LDY #$01                     
E472  B1 1E     LDA ($1E),Y                  
E474  38        SEC                          
E475  FD 04 02  SBC $0204,X                  
E478  18        CLC                          
E479  69 01     ADC #$01                     
E47B  C9 04     CMP #$04                     
E47D  B0 18     BCS LE497                    
E47F  BD 05 02  LDA $0205,X                  
E482  18        CLC                          
E483  6D CE E4  ADC $E4CE                    
E486  85 11     STA $11                      
E488  A0 02     LDY #$02                     
E48A  B1 1E     LDA ($1E),Y                  
E48C  18        CLC                          
E48D  ED CD E4  SBC $E4CD                    
E490  C8        INY                          
E491  B1 1E     LDA ($1E),Y                  
E493  E5 11     SBC $11                      
E495  F0 0B     BEQ LE4A2                    
E497  8A        TXA                          
E498  18        CLC                          
E499  69 08     ADC #$08                     
E49B  AA        TAX                          
E49C  E4 80     CPX $80                      
E49E  D0 CB     BNE LE46B                    
E4A0  38        SEC                          
E4A1  60        RTS                          
E4A2  18        CLC                          
E4A3  60        RTS                          
E4A4  A9 06     LDA #$06                     
E4A6  A0 04     LDY #$04                     
E4A8  91 1E     STA ($1E),Y                  
E4AA  A0 07     LDY #$07                     
E4AC  B1 1E     LDA ($1E),Y                  
E4AE  0A        ASL A                        
E4AF  A8        TAY                          
E4B0  B9 CE E4  LDA $E4CE,Y                  
E4B3  48        PHA                          
E4B4  B9 CD E4  LDA $E4CD,Y                  
E4B7  A0 02     LDY #$02                     
E4B9  91 1E     STA ($1E),Y                  
E4BB  C8        INY                          
E4BC  68        PLA                          
E4BD  18        CLC                          
E4BE  7D 05 02  ADC $0205,X                  
E4C1  91 1E     STA ($1E),Y                  
E4C3  A0 07     LDY #$07                     
E4C5  B1 1E     LDA ($1E),Y                  
E4C7  18        CLC                          
E4C8  69 01     ADC #$01                     
E4CA  91 1E     STA ($1E),Y                  
E4CC  60        RTS                          
        .byte $40,$FE,$80,$FE,$C0,$FE,$00,$FF  ; @.......
        .byte $C0,$FE,$80,$FE,$40,$FE,$00,$FE  ; ....@...
        .byte $C0,$FD,$00,$FE,$00,$0A,$08,$02  ; ........
        .byte $02,$02,$08,$04,$04,$04,$08,$06  ; ........
        .byte $0C,$06,$08,$00,$FF,$E4,$0B,$E5  ; ........
        .byte $12,$E5,$19,$E5,$2A,$E5,$04,$E5  ; ....*...
        .byte $21,$E5,$20,$0E,$14,$28,$30,$30  ; !. ..(00
        .byte $0E,$14,$28,$30,$06,$22,$30,$04  ; ..(0."0.
        .byte $08,$0E,$18,$20,$30,$30,$04,$0A  ; ... 00..
        .byte $0E,$14,$28,$30,$38,$02,$0C,$0E  ; ..(08...
        .byte $18,$1A,$24,$30,$40,$02,$04,$0C  ; ..$0@...
        .byte $0E,$18,$1A,$24,$30,$60,$00,$08  ; ...$0`..
        .byte $10,$12,$16,$18,$1C,$1E,$26,$2A  ; ......&*
        .byte $2C,$2E,$04,$22,$02,$22,$1C,$22  ; ,.."."."
        .byte $82,$22,$90,$22,$9C,$22,$0C,$23  ; .".".".#
        .byte $82,$23,$8A,$23,$90,$23,$92,$23  ; .#.#.#.#
        .byte $96,$23,$9C,$23,$16,$26,$82,$26  ; .#.#.&.&
        .byte $14,$26,$88,$26,$16,$26,$0C,$27  ; .&.&.&.'
        .byte $82,$27,$86,$27,$88,$27,$8E,$27  ; .'.'.'.'
        .byte $94,$27,$96,$27,$7F,$E5,$8B,$E5  ; .'.'....
        .byte $91,$E5,$97,$E5,$91,$E5,$8B,$E5  ; ........
        .byte $7F,$E5,$9D,$E5,$A9,$E5,$9D,$E5  ; ........
        .byte $B5,$E5,$04,$30,$30,$30,$30,$DC  ; ...0000.
        .byte $04,$00,$00,$00,$00,$00,$04,$31  ; .......1
        .byte $32,$33,$34,$00,$04,$35,$36,$37  ; 234..567
        .byte $38,$00,$04,$39,$3A,$3B,$3C,$00  ; 8..9:;<.
        .byte $04,$3D,$59,$59,$42,$DC,$04,$3E  ; .=YYB..>
        .byte $3F,$40,$41,$00,$04,$43,$59,$59  ; ?@A..CYY
        .byte $48,$DC,$04,$44,$45,$46,$47,$00  ; H..DEFG.
        .byte $04,$85,$00,$00,$86,$1D,$02,$00  ; ........
        .byte $00,$BD,$04,$00,$00,$00,$00,$00  ; ........

; reachable via computed jump entry
dyn_E5C5:
E5C5  AD 98 E7  LDA $E798                    
E5C8  85 1C     STA $1C                      
E5CA  AD 99 E7  LDA $E799                    
E5CD  85 1D     STA $1D                      
E5CF  A0 00     LDY #$00                     
E5D1  B1 1C     LDA ($1C),Y                  
E5D3  85 81     STA $81                      
E5D5  4A        LSR A                        
E5D6  4A        LSR A                        
E5D7  4A        LSR A                        
E5D8  85 7B     STA $7B                      
E5DA  F0 57     BEQ LE633                    
E5DC  C8        INY                          
E5DD  A2 00     LDX #$00                     
E5DF  A9 02     LDA #$02                     
E5E1  9D 60 02  STA $0260,X                  
E5E4  A9 00     LDA #$00                     
E5E6  9D 63 02  STA $0263,X                  
E5E9  B1 1C     LDA ($1C),Y                  
E5EB  C8        INY                          
E5EC  84 1B     STY $1B                      
E5EE  9D 61 02  STA $0261,X                  
E5F1  A8        TAY                          
E5F2  B9 A5 E7  LDA $E7A5,Y                  
E5F5  85 10     STA $10                      
E5F7  B9 A6 E7  LDA $E7A6,Y                  
E5FA  85 11     STA $11                      
E5FC  20 BD E3  JSR LE3BD                    
E5FF  A5 10     LDA $10                      
E601  9D 64 02  STA $0264,X                  
E604  A5 11     LDA $11                      
E606  9D 65 02  STA $0265,X                  
E609  A4 1B     LDY $1B                      
E60B  8A        TXA                          
E60C  18        CLC                          
E60D  69 08     ADC #$08                     
E60F  AA        TAX                          
E610  E4 81     CPX $81                      
E612  D0 CB     BNE LE5DF                    
E614  A2 00     LDX #$00                     
E616  86 31     STX $31                      
E618  86 1B     STX $1B                      
E61A  BD 60 02  LDA $0260,X                  
E61D  C9 02     CMP #$02                     
E61F  D0 08     BNE LE629                    
E621  A9 00     LDA #$00                     
E623  9D 63 02  STA $0263,X                  
E626  20 2C E7  JSR LE72C                    
E629  A5 1B     LDA $1B                      
E62B  18        CLC                          
E62C  69 08     ADC #$08                     
E62E  AA        TAX                          
E62F  E4 81     CPX $81                      
E631  D0 E5     BNE LE618                    
E633  60        RTS                          
E634  A5 81     LDA $81                      
E636  F0 11     BEQ LE649                    
E638  A2 00     LDX #$00                     
E63A  86 1B     STX $1B                      
E63C  20 4A E6  JSR LE64A                    
E63F  A5 1B     LDA $1B                      
E641  18        CLC                          
E642  69 08     ADC #$08                     
E644  AA        TAX                          
E645  E4 81     CPX $81                      
E647  D0 F1     BNE LE63A                    
E649  60        RTS                          
E64A  BC 60 02  LDY $0260,X                  
E64D  B9 5A E6  LDA $E65A,Y                  
E650  85 1C     STA $1C                      
E652  B9 5B E6  LDA $E65B,Y                  
E655  85 1D     STA $1D                      
E657  6C 1C 00  JMP ($001C)                  
        .byte $4F,$C1,$60,$E6,$FA,$E6          ; O.`...

; reachable via computed jump entry
dyn_E660:
E660  20 57 E7  JSR LE757                    
E663  BD 63 02  LDA $0263,X                  
E666  F0 05     BEQ LE66D                    
E668  20 1E E7  JSR LE71E                    
E66B  A6 1B     LDX $1B                      
E66D  BD 65 02  LDA $0265,X                  
E670  CD 03 04  CMP $0403                    
E673  D0 D4     BNE LE649                    
E675  BD 64 02  LDA $0264,X                  
E678  38        SEC                          
E679  ED 01 04  SBC $0401                    
E67C  C9 02     CMP #$02                     
E67E  B0 C9     BCS LE649                    
E680  C6 7B     DEC $7B                      
E682  D0 13     BNE LE697                    
E684  A9 01     LDA #$01                     
E686  85 4F     STA $4F                      
E688  A9 00     LDA #$00                     
E68A  8D 0F 04  STA $040F                    
E68D  8D 04 04  STA $0404                    
E690  8A        TXA                          
E691  48        PHA                          
E692  20 EF DA  JSR LDAEF                    
E695  68        PLA                          
E696  AA        TAX                          
E697  A5 42     LDA $42                      
E699  8D 08 06  STA $0608                    
E69C  A9 04     LDA #$04                     
E69E  9D 60 02  STA $0260,X                  
E6A1  A9 3C     LDA #$3C                     
E6A3  9D 62 02  STA $0262,X                  
E6A6  A9 01     LDA #$01                     
E6A8  85 18     STA $18                      
E6AA  BD 63 02  LDA $0263,X                  
E6AD  F0 07     BEQ LE6B6                    
E6AF  A5 31     LDA $31                      
E6B1  18        CLC                          
E6B2  69 02     ADC #$02                     
E6B4  85 18     STA $18                      
E6B6  BD 61 02  LDA $0261,X                  
E6B9  29 FC     AND #$FC                     
E6BB  20 BE D4  JSR LD4BE                    
E6BE  A6 1B     LDX $1B                      
E6C0  20 0A E7  JSR LE70A                    
E6C3  A6 1B     LDX $1B                      
E6C5  BD 63 02  LDA $0263,X                  
E6C8  D0 2D     BNE LE6F7                    
E6CA  A2 00     LDX #$00                     
E6CC  86 1A     STX $1A                      
E6CE  BD 60 02  LDA $0260,X                  
E6D1  C9 02     CMP #$02                     
E6D3  D0 0D     BNE LE6E2                    
E6D5  BD 63 02  LDA $0263,X                  
E6D8  F0 08     BEQ LE6E2                    
E6DA  A9 00     LDA #$00                     
E6DC  9D 63 02  STA $0263,X                  
E6DF  20 2C E7  JSR LE72C                    
E6E2  A5 1A     LDA $1A                      
E6E4  18        CLC                          
E6E5  69 08     ADC #$08                     
E6E7  AA        TAX                          
E6E8  E4 81     CPX $81                      
E6EA  D0 E0     BNE LE6CC                    
E6EC  A5 1B     LDA $1B                      
E6EE  49 08     EOR #$08                     
E6F0  AA        TAX                          
E6F1  A9 01     LDA #$01                     
E6F3  9D 63 02  STA $0263,X                  
E6F6  60        RTS                          
E6F7  E6 31     INC $31                      
E6F9  60        RTS                          
E6FA  20 F5 E7  JSR LE7F5                    
E6FD  A6 1B     LDX $1B                      
E6FF  DE 62 02  DEC $0262,X                  
E702  D0 19     BNE LE71D                    
E704  A9 00     LDA #$00                     
E706  9D 60 02  STA $0260,X                  
E709  60        RTS                          
E70A  A0 0A     LDY #$0A                     
E70C  B9 B9 E7  LDA $E7B9,Y                  
E70F  85 12     STA $12                      
E711  B9 BA E7  LDA $E7BA,Y                  
E714  85 13     STA $13                      
E716  A9 80     LDA #$80                     
E718  85 14     STA $14                      
E71A  4C 47 E7  JMP LE747                    
E71D  60        RTS                          
E71E  A5 21     LDA $21                      
E720  29 03     AND #$03                     
E722  49 01     EOR #$01                     
E724  D0 F7     BNE LE71D                    
E726  A5 21     LDA $21                      
E728  29 04     AND #$04                     
E72A  F0 DE     BEQ LE70A                    
E72C  BD 61 02  LDA $0261,X                  
E72F  4A        LSR A                        
E730  29 FE     AND #$FE                     
E732  A8        TAY                          
E733  C9 06     CMP #$06                     
E735  A9 00     LDA #$00                     
E737  90 02     BCC LE73B                    
E739  A9 02     LDA #$02                     
E73B  85 14     STA $14                      
E73D  B9 B9 E7  LDA $E7B9,Y                  
E740  85 12     STA $12                      
E742  B9 BA E7  LDA $E7BA,Y                  
E745  85 13     STA $13                      
E747  BC 61 02  LDY $0261,X                  
E74A  B9 A5 E7  LDA $E7A5,Y                  
E74D  85 10     STA $10                      
E74F  B9 A6 E7  LDA $E7A6,Y                  
E752  85 11     STA $11                      
E754  4C FB C6  JMP LC6FB                    
E757  AD 2F 04  LDA $042F                    
E75A  C9 02     CMP #$02                     
E75C  D0 29     BNE LE787                    
E75E  AD 2A 04  LDA $042A                    
E761  D0 24     BNE LE787                    
E763  BD 65 02  LDA $0265,X                  
E766  CD 23 04  CMP $0423                    
E769  D0 1C     BNE LE787                    
E76B  BD 64 02  LDA $0264,X                  
E76E  CD 21 04  CMP $0421                    
E771  D0 14     BNE LE787                    
E773  A9 00     LDA #$00                     
E775  8D 20 04  STA $0420                    
E778  A9 13     LDA #$13                     
E77A  8D 24 04  STA $0424                    
E77D  A9 1E     LDA #$1E                     
E77F  8D 2F 04  STA $042F                    
E782  A9 78     LDA #$78                     
E784  8D 27 04  STA $0427                    
E787  60        RTS                          
        .byte $02,$02,$00,$02,$02,$02,$00,$02  ; ........
        .byte $02,$02,$00,$02,$02,$02,$00,$02  ; ........
        .byte $9A,$E7,$50,$00,$02,$04,$06,$08  ; ..P.....
        .byte $0A,$0C,$0E,$10,$12,$52,$25,$D8  ; .....R%.
        .byte $22,$41,$26,$4A,$27,$49,$21,$42  ; "A&J'I!B
        .byte $27,$D7,$21,$48,$23,$C7,$21,$53  ; '.!H#.!S
        .byte $26,$C5,$E7,$CD,$E7,$D5,$E7,$DD  ; &.......
        .byte $E7,$E5,$E7,$ED,$E7,$02,$8C,$8D  ; ........
        .byte $1E,$02,$8E,$8F,$00,$02,$90,$91  ; ........
        .byte $1E,$02,$92,$93,$00,$02,$94,$95  ; ........
        .byte $1E,$02,$96,$97,$00,$02,$98,$99  ; ........
        .byte $1E,$02,$9A,$9B,$00,$02,$9C,$9D  ; ........
        .byte $1E,$02,$9E,$9F,$00,$02,$00,$00  ; ........
        .byte $1E,$02,$00,$00,$00              ; .....

; reachable via computed jump entry
dyn_E7F5:
E7F5  A9 00     LDA #$00                     
E7F7  85 11     STA $11                      
E7F9  38        SEC                          
E7FA  E5 28     SBC $28                      
E7FC  85 10     STA $10                      
E7FE  BD 64 02  LDA $0264,X                  
E801  E5 29     SBC $29                      
E803  18        CLC                          
E804  69 01     ADC #$01                     
E806  06 10     ASL $10                      
E808  2A        ROL A                        
E809  06 10     ASL $10                      
E80B  2A        ROL A                        
E80C  06 10     ASL $10                      
E80E  2A        ROL A                        
E80F  85 10     STA $10                      
E811  90 02     BCC LE815                    
E813  C6 11     DEC $11                      
E815  BD 65 02  LDA $0265,X                  
E818  38        SEC                          
E819  E9 01     SBC #$01                     
E81B  0A        ASL A                        
E81C  0A        ASL A                        
E81D  0A        ASL A                        
E81E  85 16     STA $16                      
E820  BD 61 02  LDA $0261,X                  
E823  4A        LSR A                        
E824  4A        LSR A                        
E825  18        CLC                          
E826  69 AC     ADC #$AC                     
E828  85 12     STA $12                      
E82A  A9 03     LDA #$03                     
E82C  85 13     STA $13                      
E82E  20 4D E8  JSR LE84D                    
E831  A9 67     LDA #$67                     
E833  85 12     STA $12                      
E835  20 4D E8  JSR LE84D                    
E838  A6 1B     LDX $1B                      
E83A  BD 63 02  LDA $0263,X                  
E83D  F0 22     BEQ LE861                    
E83F  A9 68     LDA #$68                     
E841  85 12     STA $12                      
E843  20 4D E8  JSR LE84D                    
E846  A5 31     LDA $31                      
E848  18        CLC                          
E849  69 B0     ADC #$B0                     
E84B  85 12     STA $12                      
E84D  A9 00     LDA #$00                     
E84F  85 14     STA $14                      
E851  85 15     STA $15                      
E853  20 15 C4  JSR LC415                    
E856  A5 10     LDA $10                      
E858  18        CLC                          
E859  69 08     ADC #$08                     
E85B  85 10     STA $10                      
E85D  90 02     BCC LE861                    
E85F  E6 11     INC $11                      
E861  60        RTS                          
E862  A5 7A     LDA $7A                      
E864  0A        ASL A                        
E865  A8        TAY                          
E866  B9 FC EA  LDA $EAFC,Y                  
E869  85 1C     STA $1C                      
E86B  B9 FD EA  LDA $EAFD,Y                  
E86E  85 1D     STA $1D                      
E870  A0 00     LDY #$00                     
E872  B1 1C     LDA ($1C),Y                  
E874  85 83     STA $83                      
E876  F0 53     BEQ LE8CB                    
E878  C8        INY                          
E879  A2 00     LDX #$00                     
E87B  86 1B     STX $1B                      
E87D  A9 00     LDA #$00                     
E87F  9D B0 02  STA $02B0,X                  
E882  9D B6 02  STA $02B6,X                  
E885  B1 1C     LDA ($1C),Y                  
E887  C8        INY                          
E888  9D B1 02  STA $02B1,X                  
E88B  B1 1C     LDA ($1C),Y                  
E88D  C8        INY                          
E88E  9D B2 02  STA $02B2,X                  
E891  85 10     STA $10                      
E893  B1 1C     LDA ($1C),Y                  
E895  C8        INY                          
E896  9D B3 02  STA $02B3,X                  
E899  85 11     STA $11                      
E89B  20 BD E3  JSR LE3BD                    
E89E  A5 10     LDA $10                      
E8A0  9D B4 02  STA $02B4,X                  
E8A3  A5 11     LDA $11                      
E8A5  9D B5 02  STA $02B5,X                  
E8A8  A5 1B     LDA $1B                      
E8AA  18        CLC                          
E8AB  69 08     ADC #$08                     
E8AD  AA        TAX                          
E8AE  E4 83     CPX $83                      
E8B0  D0 C9     BNE LE87B                    
E8B2  A2 00     LDX #$00                     
E8B4  86 1B     STX $1B                      
E8B6  BD B1 02  LDA $02B1,X                  
E8B9  29 FC     AND #$FC                     
E8BB  9D B1 02  STA $02B1,X                  
E8BE  20 FF E8  JSR LE8FF                    
E8C1  A5 1B     LDA $1B                      
E8C3  18        CLC                          
E8C4  69 08     ADC #$08                     
E8C6  AA        TAX                          
E8C7  E4 83     CPX $83                      
E8C9  D0 E9     BNE LE8B4                    
E8CB  60        RTS                          
E8CC  A5 83     LDA $83                      
E8CE  F0 FB     BEQ LE8CB                    
E8D0  A2 00     LDX #$00                     
E8D2  86 1B     STX $1B                      
E8D4  20 1D E9  JSR LE91D                    
E8D7  A5 1B     LDA $1B                      
E8D9  18        CLC                          
E8DA  69 08     ADC #$08                     
E8DC  AA        TAX                          
E8DD  E4 83     CPX $83                      
E8DF  D0 F1     BNE LE8D2                    
E8E1  A5 21     LDA $21                      
E8E3  29 03     AND #$03                     
E8E5  0A        ASL A                        
E8E6  0A        ASL A                        
E8E7  0A        ASL A                        
E8E8  AA        TAX                          
E8E9  BD B0 02  LDA $02B0,X                  
E8EC  D0 DD     BNE LE8CB                    
E8EE  BD B1 02  LDA $02B1,X                  
E8F1  29 0A     AND #$0A                     
E8F3  49 08     EOR #$08                     
E8F5  D0 D4     BNE LE8CB                    
E8F7  A0 10     LDY #$10                     
E8F9  A5 21     LDA $21                      
E8FB  29 04     AND #$04                     
E8FD  F0 03     BEQ LE902                    
E8FF  BC B1 02  LDY $02B1,X                  
E902  BD B2 02  LDA $02B2,X                  
E905  85 10     STA $10                      
E907  BD B3 02  LDA $02B3,X                  
E90A  85 11     STA $11                      
E90C  B9 4F EC  LDA $EC4F,Y                  
E90F  85 12     STA $12                      
E911  B9 50 EC  LDA $EC50,Y                  
E914  85 13     STA $13                      
E916  A9 80     LDA #$80                     
E918  85 14     STA $14                      
E91A  4C FB C6  JMP LC6FB                    
E91D  BD B0 02  LDA $02B0,X                  
E920  F0 20     BEQ LE942                    
E922  FE B6 02  INC $02B6,X                  
E925  BD B6 02  LDA $02B6,X                  
E928  C9 05     CMP #$05                     
E92A  90 17     BCC LE943                    
E92C  A9 00     LDA #$00                     
E92E  9D B0 02  STA $02B0,X                  
E931  9D B6 02  STA $02B6,X                  
E934  BD B1 02  LDA $02B1,X                  
E937  29 06     AND #$06                     
E939  49 02     EOR #$02                     
E93B  9D B1 02  STA $02B1,X                  
E93E  29 02     AND #$02                     
E940  F0 BD     BEQ LE8FF                    
E942  60        RTS                          
E943  0A        ASL A                        
E944  85 10     STA $10                      
E946  20 4D E9  JSR LE94D                    
E949  A8        TAY                          
E94A  4C 02 E9  JMP LE902                    
E94D  BD B1 02  LDA $02B1,X                  
E950  29 06     AND #$06                     
E952  F0 0C     BEQ LE960                    
E954  C9 04     CMP #$04                     
E956  90 0E     BCC LE966                    
E958  F0 12     BEQ LE96C                    
E95A  A9 22     LDA #$22                     
E95C  38        SEC                          
E95D  E5 10     SBC $10                      
E95F  60        RTS                          
E960  A5 10     LDA $10                      
E962  18        CLC                          
E963  69 10     ADC #$10                     
E965  60        RTS                          

; branch target entry
LE966:
E966  A9 1A     LDA #$1A                     
E968  38        SEC                          
E969  E5 10     SBC $10                      
E96B  60        RTS                          
E96C  A5 10     LDA $10                      
E96E  18        CLC                          
E96F  69 18     ADC #$18                     
E971  60        RTS                          
E972  A5 83     LDA $83                      
E974  F0 FB     BEQ LE971                    
E976  A0 0E     LDY #$0E                     
E978  B1 1E     LDA ($1E),Y                  
E97A  29 03     AND #$03                     
E97C  C9 01     CMP #$01                     
E97E  D0 F1     BNE LE971                    
E980  A0 00     LDY #$00                     
E982  A2 00     LDX #$00                     
E984  20 B8 E9  JSR LE9B8                    
E987  8A        TXA                          
E988  18        CLC                          
E989  69 08     ADC #$08                     
E98B  AA        TAX                          
E98C  E4 83     CPX $83                      
E98E  D0 F4     BNE LE984                    
E990  88        DEY                          
E991  30 DE     BMI LE971                    
E993  B9 12 00  LDA $0012,Y                  
E996  88        DEY                          
E997  B6 12     LDX $12,Y                    
E999  88        DEY                          
E99A  30 08     BMI LE9A4                    
E99C  D9 12 00  CMP $0012,Y                  
E99F  B0 F2     BCS LE993                    
E9A1  88        DEY                          
E9A2  90 F5     BCC LE999                    
E9A4  A9 01     LDA #$01                     
E9A6  9D B0 02  STA $02B0,X                  
E9A9  20 05 EA  JSR LEA05                    
E9AC  BD B1 02  LDA $02B1,X                  
E9AF  29 0A     AND #$0A                     
E9B1  49 08     EOR #$08                     
E9B3  D0 BC     BNE LE971                    
E9B5  4C 04 EE  JMP LEE04                    
E9B8  84 11     STY $11                      
E9BA  A5 1E     LDA $1E                      
E9BC  9D B7 02  STA $02B7,X                  
E9BF  D0 0A     BNE LE9CB                    
E9C1  BD B4 02  LDA $02B4,X                  
E9C4  38        SEC                          
E9C5  E5 29     SBC $29                      
E9C7  C9 21     CMP #$21                     
E9C9  B0 20     BCS LE9EB                    
E9CB  A0 03     LDY #$03                     
E9CD  B1 1E     LDA ($1E),Y                  
E9CF  38        SEC                          
E9D0  FD B5 02  SBC $02B5,X                  
E9D3  C9 02     CMP #$02                     
E9D5  B0 14     BCS LE9EB                    
E9D7  A0 01     LDY #$01                     
E9D9  B1 1E     LDA ($1E),Y                  
E9DB  38        SEC                          
E9DC  FD B4 02  SBC $02B4,X                  
E9DF  85 10     STA $10                      
E9E1  A0 06     LDY #$06                     
E9E3  B1 1E     LDA ($1E),Y                  
E9E5  30 07     BMI LE9EE                    
E9E7  E6 10     INC $10                      
E9E9  30 07     BMI LE9F2                    
E9EB  A4 11     LDY $11                      
E9ED  60        RTS                          
E9EE  A5 10     LDA $10                      
E9F0  30 F9     BMI LE9EB                    
E9F2  A4 11     LDY $11                      
E9F4  96 12     STX $12,Y                    
E9F6  C8        INY                          
E9F7  A5 10     LDA $10                      
E9F9  10 05     BPL LEA00                    
E9FB  A9 00     LDA #$00                     
E9FD  38        SEC                          
E9FE  E5 10     SBC $10                      
EA00  99 12 00  STA $0012,Y                  
EA03  C8        INY                          
EA04  60        RTS                          
EA05  BD B1 02  LDA $02B1,X                  
EA08  29 06     AND #$06                     
EA0A  A8        TAY                          
EA0B  B9 49 EA  LDA $EA49,Y                  
EA0E  85 1C     STA $1C                      
EA10  B9 4A EA  LDA $EA4A,Y                  
EA13  85 1D     STA $1D                      
EA15  A0 00     LDY #$00                     
EA17  C0 10     CPY #$10                     
EA19  F0 21     BEQ LEA3C                    
EA1B  B9 04 04  LDA $0404,Y                  
EA1E  F0 1C     BEQ LEA3C                    
EA20  B9 0F 04  LDA $040F,Y                  
EA23  C9 16     CMP #$16                     
EA25  F0 15     BEQ LEA3C                    
EA27  B9 03 04  LDA $0403,Y                  
EA2A  38        SEC                          
EA2B  FD B5 02  SBC $02B5,X                  
EA2E  C9 02     CMP #$02                     
EA30  B0 0A     BCS LEA3C                    
EA32  BD B4 02  LDA $02B4,X                  
EA35  38        SEC                          
EA36  F9 01 04  SBC $0401,Y                  
EA39  20 46 EA  JSR LEA46                    
EA3C  98        TYA                          
EA3D  18        CLC                          
EA3E  69 10     ADC #$10                     
EA40  A8        TAY                          
EA41  C0 90     CPY #$90                     
EA43  D0 D2     BNE LEA17                    
EA45  60        RTS                          
EA46  6C 1C 00  JMP ($001C)                  
        .byte $5E,$EA,$51,$EA,$69,$EA,$59,$EA  ; ^.Q.i.Y.
        .byte $18,$69,$01,$C9,$04,$90,$18,$60  ; .i.....`
        .byte $C9,$04,$4C,$63,$EA              ; ..Lc.

; reachable via computed jump entry
dyn_EA5E:
EA5E  18        CLC                          
EA5F  69 02     ADC #$02                     
EA61  C9 03     CMP #$03                     
EA63  B0 2A     BCS LEA8F                    
EA65  A9 01     LDA #$01                     
EA67  90 09     BCC LEA72                    
EA69  38        SEC                          
EA6A  E9 02     SBC #$02                     
EA6C  C9 03     CMP #$03                     
EA6E  B0 1F     BCS LEA8F                    
EA70  A9 FF     LDA #$FF                     
EA72  99 06 04  STA $0406,Y                  
EA75  A9 0C     LDA #$0C                     
EA77  99 04 04  STA $0404,Y                  
EA7A  A9 10     LDA #$10                     
EA7C  99 0F 04  STA $040F,Y                  
EA7F  A9 08     LDA #$08                     
EA81  99 07 04  STA $0407,Y                  
EA84  C0 00     CPY #$00                     
EA86  F0 07     BEQ LEA8F                    
EA88  BD B7 02  LDA $02B7,X                  
EA8B  D0 02     BNE LEA8F                    
EA8D  E6 30     INC $30                      
EA8F  60        RTS                          
EA90  A9 00     LDA #$00                     
EA92  A0 09     LDY #$09                     
EA94  91 1E     STA ($1E),Y                  
EA96  A2 00     LDX #$00                     
EA98  BD B0 02  LDA $02B0,X                  
EA9B  D0 4B     BNE LEAE8                    
EA9D  BD B1 02  LDA $02B1,X                  
EAA0  29 02     AND #$02                     
EAA2  D0 44     BNE LEAE8                    
EAA4  A0 03     LDY #$03                     
EAA6  B1 1E     LDA ($1E),Y                  
EAA8  38        SEC                          
EAA9  FD B5 02  SBC $02B5,X                  
EAAC  C9 02     CMP #$02                     
EAAE  B0 38     BCS LEAE8                    
EAB0  A0 06     LDY #$06                     
EAB2  B1 1E     LDA ($1E),Y                  
EAB4  30 28     BMI LEADE                    
EAB6  BD B4 02  LDA $02B4,X                  
EAB9  38        SEC                          
EABA  A0 01     LDY #$01                     
EABC  F1 1E     SBC ($1E),Y                  
EABE  C9 02     CMP #$02                     
EAC0  D0 26     BNE LEAE8                    
EAC2  A5 1E     LDA $1E                      
EAC4  9D B7 02  STA $02B7,X                  
EAC7  F0 0E     BEQ LEAD7                    
EAC9  C9 20     CMP #$20                     
EACB  90 07     BCC LEAD4                    
EACD  BD B1 02  LDA $02B1,X                  
EAD0  29 08     AND #$08                     
EAD2  D0 1E     BNE LEAF2                    
EAD4  20 A4 E9  JSR LE9A4                    
EAD7  A9 01     LDA #$01                     
EAD9  A0 09     LDY #$09                     
EADB  91 1E     STA ($1E),Y                  
EADD  60        RTS                          
EADE  BD B4 02  LDA $02B4,X                  
EAE1  38        SEC                          
EAE2  A0 01     LDY #$01                     
EAE4  D1 1E     CMP ($1E),Y                  
EAE6  F0 DA     BEQ LEAC2                    
EAE8  8A        TXA                          
EAE9  18        CLC                          
EAEA  69 08     ADC #$08                     
EAEC  AA        TAX                          
EAED  E4 83     CPX $83                      
EAEF  D0 A7     BNE LEA98                    
EAF1  60        RTS                          
EAF2  A0 06     LDY #$06                     
EAF4  38        SEC                          
EAF5  A9 00     LDA #$00                     
EAF7  F1 1E     SBC ($1E),Y                  
EAF9  91 1E     STA ($1E),Y                  
EAFB  60        RTS                          
        .byte $1C,$EB,$3B,$EB,$4E,$EC,$5A,$EB  ; ..;.N.Z.
        .byte $73,$EB,$8C,$EB,$4E,$EC,$A8,$EB  ; s...N...
        .byte $C4,$EB,$DD,$EB,$4E,$EC,$F3,$EB  ; ....N...
        .byte $09,$EC,$22,$EC,$4E,$EC,$2F,$EC  ; ..".N./.
        .byte $50,$08,$AC,$21,$08,$2C,$23,$0C  ; P..!.,#.
        .byte $2F,$25,$0C,$AF,$26,$00,$2C,$21  ; /%..&.,!
        .byte $00,$BD,$21,$00,$AC,$22,$04,$BD  ; ..!.."..
        .byte $22,$04,$3D,$23,$04,$2F,$26,$50  ; ".=#./&P
        .byte $08,$2C,$22,$08,$2C,$23,$0C,$2F  ; .,".,#./
        .byte $25,$0C,$2F,$27,$00,$2C,$21,$00  ; %./'.,!.
        .byte $AC,$22,$00,$3D,$23,$00,$2A,$26  ; .".=#.*&
        .byte $04,$3D,$22,$04,$A5,$25,$40,$08  ; .="..%@.
        .byte $2C,$21,$08,$2C,$23,$0C,$B0,$25  ; ,!.,#..%
        .byte $0C,$B0,$26,$00,$25,$27,$04,$2B  ; ..&.%'.+
        .byte $22,$04,$2F,$25,$04,$30,$26,$40  ; "./%.0&@
        .byte $08,$AB,$21,$08,$AB,$22,$0C,$B0  ; ..!.."..
        .byte $25,$0C,$B0,$26,$00,$26,$22,$00  ; %..&.&".
        .byte $2A,$25,$04,$2F,$27,$04,$31,$23  ; *%./'.1#
        .byte $48,$08,$2C,$21,$08,$2C,$23,$0C  ; H.,!.,#.
        .byte $2F,$25,$0C,$B0,$26,$00,$AB,$21  ; /%..&..!
        .byte $00,$A6,$22,$00,$25,$27,$04,$B5  ; ..".%'..
        .byte $25,$04,$30,$26,$48,$08,$AC,$21  ; %.0&H..!
        .byte $08,$39,$22,$08,$2C,$23,$0C,$AF  ; .9".,#..
        .byte $26,$00,$26,$22,$00,$3D,$23,$04  ; &.&".=#.
        .byte $2F,$27,$04,$2F,$25,$04,$B5,$25  ; /'./%..%
        .byte $40,$08,$2C,$23,$08,$AF,$25,$0C  ; @.,#..%.
        .byte $39,$22,$0C,$2F,$25,$00,$2C,$22  ; 9"./%.,"
        .byte $00,$A6,$22,$00,$AF,$26,$04,$3D  ; .."..&.=
        .byte $23,$38,$0C,$AC,$21,$0C,$39,$22  ; #8..!.9"
        .byte $0C,$3D,$23,$0C,$AF,$25,$00,$2C  ; .=#..%.,
        .byte $22,$00,$A6,$22,$00,$2F,$26,$38  ; ".."./&8
        .byte $08,$30,$21,$08,$35,$23,$08,$A6  ; .0!.5#..
        .byte $25,$0C,$35,$22,$00,$A6,$26,$00  ; %.5"..&.
        .byte $26,$27,$04,$26,$25,$40,$08,$30  ; &'.&%@.0
        .byte $21,$08,$26,$26,$0C,$35,$23,$0C  ; !.&&.5#.
        .byte $2B,$25,$00,$30,$22,$00,$A6,$22  ; +%.0".."
        .byte $00,$26,$27,$04,$AB,$25,$20,$08  ; .&'..% .
        .byte $35,$21,$08,$26,$25,$08,$A6,$26  ; 5!.&%..&
        .byte $0C,$B5,$22,$50,$08,$BD,$22,$08  ; .."P..".
        .byte $2C,$23,$0C,$2F,$27,$0C,$BD,$21  ; ,#./'..!
        .byte $00,$2C,$21,$00,$2C,$22,$00,$A6  ; .,!.,"..
        .byte $22,$00,$AA,$26,$04,$2F,$25,$04  ; "..&./%.
        .byte $2F,$26,$00,$71,$EC,$C5,$EC,$7A  ; /&.q...z
        .byte $EC,$01,$ED,$83,$EC,$C5,$EC,$8C  ; ........
        .byte $EC,$01,$ED,$95,$EC,$9E,$EC,$AA  ; ........
        .byte $EC,$B6,$EC,$C5,$EC,$D4,$EC,$E2  ; ........
        .byte $EC,$F0,$EC,$01,$ED,$01,$56,$1F  ; ......V.
        .byte $01,$58,$1F,$01,$56,$00,$01,$56  ; .X..V..V
        .byte $1F,$01,$57,$1F,$01,$56,$00,$01  ; ..W..V..
        .byte $53,$1F,$01,$55,$1F,$01,$53,$00  ; S..U..S.
        .byte $01,$53,$1F,$01,$54,$1F,$01,$53  ; .S..T..S
        .byte $00,$01,$52,$1F,$01,$52,$1F,$01  ; ..R..R..
        .byte $52,$00,$02,$87,$00,$1E,$02,$87  ; R.......
        .byte $00,$1E,$02,$87,$00,$00,$02,$87  ; ........
        .byte $89,$1E,$02,$87,$89,$1E,$02,$87  ; ........
        .byte $89,$00,$03,$87,$88,$00,$1D,$03  ; ........
        .byte $87,$88,$00,$1D,$03,$87,$88,$00  ; ........
        .byte $00,$03,$87,$88,$89,$1D,$03,$87  ; ........
        .byte $88,$89,$1D,$03,$87,$88,$89,$00  ; ........
        .byte $00,$FF,$02,$00,$89,$1E,$02,$00  ; ........
        .byte $89,$1E,$02,$00,$89,$00,$00,$FF  ; ........
        .byte $02,$87,$89,$1E,$02,$87,$89,$1E  ; ........
        .byte $02,$87,$89,$00,$00,$FE,$03,$00  ; ........
        .byte $88,$89,$1D,$03,$00,$88,$89,$1D  ; ........
        .byte $03,$00,$88,$89,$00,$00,$FE,$03  ; ........
        .byte $87,$88,$89,$1D,$03,$87,$88,$89  ; ........
        .byte $1D,$03,$87,$88,$89,$00          ; ......

; reachable via computed jump entry
dyn_ED12:
ED12  A9 60     LDA #$60                     
ED14  20 4D EE  JSR LEE4D                    
ED17  20 05 C3  JSR LC305                    
ED1A  D0 31     BNE LED4D                    
ED1C  A9 30     LDA #$30                     
ED1E  85 4C     STA $4C                      
ED20  A9 00     LDA #$00                     
ED22  A0 05     LDY #$05                     
ED24  91 1E     STA ($1E),Y                  
ED26  A0 04     LDY #$04                     
ED28  91 1E     STA ($1E),Y                  
ED2A  A2 20     LDX #$20                     
ED2C  BD 0B 04  LDA $040B,X                  
ED2F  C5 1E     CMP $1E                      
ED31  D0 11     BNE LED44                    
ED33  BD 0F 04  LDA $040F,X                  
ED36  C9 18     CMP #$18                     
ED38  D0 0A     BNE LED44                    
ED3A  A9 1A     LDA #$1A                     
ED3C  9D 0F 04  STA $040F,X                  
ED3F  A9 3C     LDA #$3C                     
ED41  9D 07 04  STA $0407,X                  
ED44  8A        TXA                          
ED45  18        CLC                          
ED46  69 10     ADC #$10                     
ED48  AA        TAX                          
ED49  E0 90     CPX #$90                     
ED4B  D0 DF     BNE LED2C                    
ED4D  60        RTS                          
ED4E  A9 A0     LDA #$A0                     
ED50  85 1E     STA $1E                      
ED52  A9 04     LDA #$04                     
ED54  85 1F     STA $1F                      
ED56  20 65 ED  JSR LED65                    
ED59  A5 1E     LDA $1E                      
ED5B  18        CLC                          
ED5C  69 08     ADC #$08                     
ED5E  85 1E     STA $1E                      
ED60  C9 C0     CMP #$C0                     
ED62  D0 F2     BNE LED56                    
ED64  60        RTS                          
ED65  A0 05     LDY #$05                     
ED67  B1 1E     LDA ($1E),Y                  
ED69  F0 E2     BEQ LED4D                    
ED6B  C9 02     CMP #$02                     
ED6D  B0 A3     BCS LED12                    
ED6F  A5 42     LDA $42                      
ED71  8D 09 06  STA $0609                    
ED74  20 77 EE  JSR LEE77                    
ED77  20 C9 EE  JSR LEEC9                    
ED7A  A9 08     LDA #$08                     
ED7C  A0 04     LDY #$04                     
ED7E  91 1E     STA ($1E),Y                  
ED80  A5 63     LDA $63                      
ED82  18        CLC                          
ED83  69 08     ADC #$08                     
ED85  20 4D EE  JSR LEE4D                    
ED88  20 05 C3  JSR LC305                    
ED8B  D0 C0     BNE LED4D                    
ED8D  A0 00     LDY #$00                     
ED8F  A2 20     LDX #$20                     
ED91  20 E2 ED  JSR LEDE2                    
ED94  8A        TXA                          
ED95  18        CLC                          
ED96  69 10     ADC #$10                     
ED98  AA        TAX                          
ED99  E0 90     CPX #$90                     
ED9B  D0 F4     BNE LED91                    
ED9D  98        TYA                          
ED9E  D0 03     BNE LEDA3                    
EDA0  4C 1C ED  JMP LED1C                    
EDA3  A2 FD     LDX #$FD                     
EDA5  0A        ASL A                        
EDA6  69 FE     ADC #$FE                     
EDA8  48        PHA                          
EDA9  30 02     BMI LEDAD                    
EDAB  A2 FF     LDX #$FF                     
EDAD  A0 07     LDY #$07                     
EDAF  91 1E     STA ($1E),Y                  
EDB1  A9 02     LDA #$02                     
EDB3  A0 05     LDY #$05                     
EDB5  91 1E     STA ($1E),Y                  
EDB7  A9 10     LDA #$10                     
EDB9  A0 04     LDY #$04                     
EDBB  91 1E     STA ($1E),Y                  
EDBD  A9 00     LDA #$00                     
EDBF  A0 06     LDY #$06                     
EDC1  38        SEC                          
EDC2  F1 1E     SBC ($1E),Y                  
EDC4  91 1E     STA ($1E),Y                  
EDC6  10 02     BPL LEDCA                    
EDC8  A2 FE     LDX #$FE                     
EDCA  A0 01     LDY #$01                     
EDCC  8A        TXA                          
EDCD  18        CLC                          
EDCE  71 1E     ADC ($1E),Y                  
EDD0  91 1E     STA ($1E),Y                  
EDD2  A9 01     LDA #$01                     
EDD4  85 18     STA $18                      
EDD6  68        PLA                          
EDD7  0A        ASL A                        
EDD8  90 02     BCC LEDDC                    
EDDA  E6 18     INC $18                      
EDDC  18        CLC                          
EDDD  69 14     ADC #$14                     
EDDF  4C BE D4  JMP LD4BE                    
EDE2  BD 0B 04  LDA $040B,X                  
EDE5  C5 1E     CMP $1E                      
EDE7  D0 1A     BNE LEE03                    
EDE9  BD 0F 04  LDA $040F,X                  
EDEC  C9 16     CMP #$16                     
EDEE  D0 13     BNE LEE03                    
EDF0  A9 18     LDA #$18                     
EDF2  9D 0F 04  STA $040F,X                  
EDF5  A9 00     LDA #$00                     
EDF7  9D 04 04  STA $0404,X                  
EDFA  C8        INY                          
EDFB  E0 20     CPX #$20                     
EDFD  D0 04     BNE LEE03                    
EDFF  98        TYA                          
EE00  09 40     ORA #$40                     
EE02  A8        TAY                          
EE03  60        RTS                          
EE04  A0 00     LDY #$00                     
EE06  B9 A5 04  LDA $04A5,Y                  
EE09  F0 0A     BEQ LEE15                    
EE0B  98        TYA                          
EE0C  18        CLC                          
EE0D  69 08     ADC #$08                     
EE0F  A8        TAY                          
EE10  C0 20     CPY #$20                     
EE12  D0 F2     BNE LEE06                    
EE14  60        RTS                          
EE15  A9 01     LDA #$01                     
EE17  99 A5 04  STA $04A5,Y                  
EE1A  A9 00     LDA #$00                     
EE1C  99 A0 04  STA $04A0,Y                  
EE1F  99 A2 04  STA $04A2,Y                  
EE22  BD B5 02  LDA $02B5,X                  
EE25  38        SEC                          
EE26  E9 01     SBC #$01                     
EE28  99 A3 04  STA $04A3,Y                  
EE2B  BD B1 02  LDA $02B1,X                  
EE2E  29 04     AND #$04                     
EE30  F0 0F     BEQ LEE41                    
EE32  A9 FF     LDA #$FF                     
EE34  99 A6 04  STA $04A6,Y                  
EE37  BD B4 02  LDA $02B4,X                  
EE3A  38        SEC                          
EE3B  E9 02     SBC #$02                     
EE3D  99 A1 04  STA $04A1,Y                  
EE40  60        RTS                          

; branch target entry
LEE41:
EE41  A9 01     LDA #$01                     
EE43  99 A6 04  STA $04A6,Y                  
EE46  BD B4 02  LDA $02B4,X                  
EE49  99 A1 04  STA $04A1,Y                  
EE4C  60        RTS                          
EE4D  85 10     STA $10                      
EE4F  A0 06     LDY #$06                     
EE51  B1 1E     LDA ($1E),Y                  
EE53  30 11     BMI LEE66                    
EE55  A0 00     LDY #$00                     
EE57  B1 1E     LDA ($1E),Y                  
EE59  18        CLC                          
EE5A  65 10     ADC $10                      
EE5C  91 1E     STA ($1E),Y                  
EE5E  C8        INY                          
EE5F  B1 1E     LDA ($1E),Y                  
EE61  69 00     ADC #$00                     
EE63  91 1E     STA ($1E),Y                  
EE65  60        RTS                          
EE66  A0 00     LDY #$00                     
EE68  B1 1E     LDA ($1E),Y                  
EE6A  38        SEC                          
EE6B  E5 10     SBC $10                      
EE6D  91 1E     STA ($1E),Y                  
EE6F  C8        INY                          
EE70  B1 1E     LDA ($1E),Y                  
EE72  E9 00     SBC #$00                     
EE74  91 1E     STA ($1E),Y                  
EE76  60        RTS                          
EE77  A2 20     LDX #$20                     
EE79  BD 04 04  LDA $0404,X                  
EE7C  F0 41     BEQ LEEBF                    
EE7E  BD 0F 04  LDA $040F,X                  
EE81  38        SEC                          
EE82  E9 16     SBC #$16                     
EE84  C9 06     CMP #$06                     
EE86  90 37     BCC LEEBF                    
EE88  BD 03 04  LDA $0403,X                  
EE8B  A0 03     LDY #$03                     
EE8D  38        SEC                          
EE8E  F1 1E     SBC ($1E),Y                  
EE90  18        CLC                          
EE91  69 01     ADC #$01                     
EE93  C9 04     CMP #$04                     
EE95  B0 28     BCS LEEBF                    
EE97  BD 01 04  LDA $0401,X                  
EE9A  A0 01     LDY #$01                     
EE9C  38        SEC                          
EE9D  F1 1E     SBC ($1E),Y                  
EE9F  48        PHA                          
EEA0  A0 06     LDY #$06                     
EEA2  B1 1E     LDA ($1E),Y                  
EEA4  10 05     BPL LEEAB                    
EEA6  68        PLA                          
EEA7  18        CLC                          
EEA8  69 01     ADC #$01                     
EEAA  48        PHA                          
EEAB  68        PLA                          
EEAC  C9 02     CMP #$02                     
EEAE  B0 0F     BCS LEEBF                    
EEB0  A5 1E     LDA $1E                      
EEB2  9D 0B 04  STA $040B,X                  
EEB5  A9 00     LDA #$00                     
EEB7  9D 07 04  STA $0407,X                  
EEBA  A9 16     LDA #$16                     
EEBC  9D 0F 04  STA $040F,X                  
EEBF  8A        TXA                          
EEC0  18        CLC                          
EEC1  69 10     ADC #$10                     
EEC3  AA        TAX                          
EEC4  E0 90     CPX #$90                     
EEC6  D0 B1     BNE LEE79                    
EEC8  60        RTS                          
EEC9  A2 20     LDX #$20                     
EECB  BD 0B 04  LDA $040B,X                  
EECE  C5 1E     CMP $1E                      
EED0  D0 0F     BNE LEEE1                    
EED2  BD 0F 04  LDA $040F,X                  
EED5  C9 16     CMP #$16                     
EED7  D0 08     BNE LEEE1                    
EED9  A5 63     LDA $63                      
EEDB  18        CLC                          
EEDC  69 08     ADC #$08                     
EEDE  20 EB EE  JSR LEEEB                    
EEE1  8A        TXA                          
EEE2  18        CLC                          
EEE3  69 10     ADC #$10                     
EEE5  AA        TAX                          
EEE6  E0 90     CPX #$90                     
EEE8  D0 E1     BNE LEECB                    
EEEA  60        RTS                          
EEEB  85 10     STA $10                      
EEED  A0 06     LDY #$06                     
EEEF  B1 1E     LDA ($1E),Y                  
EEF1  30 12     BMI LEF05                    
EEF3  BD 00 04  LDA $0400,X                  
EEF6  18        CLC                          
EEF7  65 10     ADC $10                      
EEF9  9D 00 04  STA $0400,X                  
EEFC  BD 01 04  LDA $0401,X                  
EEFF  69 00     ADC #$00                     
EF01  9D 01 04  STA $0401,X                  
EF04  60        RTS                          
EF05  BD 00 04  LDA $0400,X                  
EF08  38        SEC                          
EF09  E5 10     SBC $10                      
EF0B  9D 00 04  STA $0400,X                  
EF0E  BD 01 04  LDA $0401,X                  
EF11  E9 00     SBC #$00                     
EF13  9D 01 04  STA $0401,X                  
EF16  60        RTS                          

; subroutine entry
sub_EF17:
EF17  A5 7A     LDA $7A                      
EF19  38        SEC                          
EF1A  E9 07     SBC #$07                     
EF1C  C9 03     CMP #$03                     
EF1E  A9 00     LDA #$00                     
EF20  B0 0C     BCS LEF2E                    
EF22  A2 00     LDX #$00                     

; branch target entry
LEF24:
EF24  BD 2F EF  LDA $EF2F,X                  
EF27  95 A0     STA $A0,X                    
EF29  E8        INX                          
EF2A  E0 10     CPX #$10                     
EF2C  D0 F6     BNE LEF24                    
EF2E  60        RTS                          
        .byte $00,$03,$00,$06,$0A,$01,$00,$00  ; ........
        .byte $00,$37,$00,$06,$0A,$01,$00,$00  ; .7......

; reachable via computed jump entry
dyn_EF3F:
EF3F  A9 A0     LDA #$A0                     
EF41  85 1E     STA $1E                      
EF43  A9 00     LDA #$00                     
EF45  85 1F     STA $1F                      
EF47  20 4E EF  JSR LEF4E                    
EF4A  A9 A8     LDA #$A8                     
EF4C  85 1E     STA $1E                      
EF4E  A0 05     LDY #$05                     
EF50  B1 1E     LDA ($1E),Y                  
EF52  F0 DA     BEQ LEF2E                    
EF54  C9 02     CMP #$02                     
EF56  90 20     BCC LEF78                    
EF58  20 9B EF  JSR LEF9B                    
EF5B  A0 02     LDY #$02                     
EF5D  B1 1E     LDA ($1E),Y                  
EF5F  18        CLC                          
EF60  69 80     ADC #$80                     
EF62  91 1E     STA ($1E),Y                  
EF64  C8        INY                          
EF65  B1 1E     LDA ($1E),Y                  
EF67  69 00     ADC #$00                     
EF69  91 1E     STA ($1E),Y                  
EF6B  C9 1C     CMP #$1C                     
EF6D  90 06     BCC LEF75                    
EF6F  A9 00     LDA #$00                     
EF71  A0 05     LDY #$05                     
EF73  91 1E     STA ($1E),Y                  

; branch target entry
LEF75:
EF75  4C 05 C3  JMP LC305                    

; branch target entry
LEF78:
EF78  A0 03     LDY #$03                     
EF7A  B1 1E     LDA ($1E),Y                  
EF7C  CD 03 04  CMP $0403                    
EF7F  D0 17     BNE LEF98                    
EF81  A0 01     LDY #$01                     
EF83  B1 1E     LDA ($1E),Y                  
EF85  38        SEC                          
EF86  ED 01 04  SBC $0401                    
EF89  C9 02     CMP #$02                     
EF8B  B0 0B     BCS LEF98                    
EF8D  A5 42     LDA $42                      
EF8F  8D 07 06  STA $0607                    
EF92  A9 02     LDA #$02                     
EF94  A0 05     LDY #$05                     
EF96  91 1E     STA ($1E),Y                  

; branch target entry
LEF98:
EF98  4C 05 C3  JMP LC305                    

; subroutine entry
sub_EF9B:
EF9B  A2 20     LDX #$20                     

; branch target entry
LEF9D:
EF9D  BD 0F 04  LDA $040F,X                  
EFA0  C9 16     CMP #$16                     
EFA2  B0 53     BCS LEFF7                    
EFA4  A0 00     LDY #$00                     
EFA6  B1 1E     LDA ($1E),Y                  
EFA8  38        SEC                          
EFA9  FD 00 04  SBC $0400,X                  
EFAC  C8        INY                          
EFAD  B1 1E     LDA ($1E),Y                  
EFAF  FD 01 04  SBC $0401,X                  
EFB2  18        CLC                          
EFB3  69 01     ADC #$01                     
EFB5  C9 02     CMP #$02                     
EFB7  B0 3E     BCS LEFF7                    
EFB9  C8        INY                          
EFBA  B1 1E     LDA ($1E),Y                  
EFBC  38        SEC                          
EFBD  FD 02 04  SBC $0402,X                  
EFC0  C8        INY                          
EFC1  B1 1E     LDA ($1E),Y                  
EFC3  FD 03 04  SBC $0403,X                  
EFC6  18        CLC                          
EFC7  69 01     ADC #$01                     
EFC9  C9 02     CMP #$02                     
EFCB  B0 2A     BCS LEFF7                    
EFCD  A5 65     LDA $65                      
EFCF  9D 07 04  STA $0407,X                  
EFD2  A9 26     LDA #$26                     
EFD4  9D 0F 04  STA $040F,X                  
EFD7  A9 22     LDA #$22                     
EFD9  9D 04 04  STA $0404,X                  
EFDC  BD 03 04  LDA $0403,X                  
EFDF  C9 19     CMP #$19                     
EFE1  90 05     BCC LEFE8                    
EFE3  A9 19     LDA #$19                     
EFE5  9D 03 04  STA $0403,X                  

; branch target entry
LEFE8:
EFE8  86 1B     STX $1B                      
EFEA  A0 08     LDY #$08                     
EFEC  E0 20     CPX #$20                     
EFEE  D0 02     BNE LEFF2                    
EFF0  A0 44     LDY #$44                     

; branch target entry
LEFF2:
EFF2  20 CA D4  JSR LD4CA                    
EFF5  A6 1B     LDX $1B                      

; branch target entry
LEFF7:
EFF7  8A        TXA                          
EFF8  18        CLC                          
EFF9  69 10     ADC #$10                     
EFFB  AA        TAX                          
EFFC  E0 90     CPX #$90                     
EFFE  D0 9D     BNE LEF9D                    
F000  60        RTS                          
F001  A5 7A     LDA $7A                      
F003  0A        ASL A                        
F004  E9 15     SBC #$15                     
F006  C9 06     CMP #$06                     
F008  B0 36     BCS LF040                    
F00A  0A        ASL A                        
F00B  AA        TAX                          
F00C  A0 00     LDY #$00                     
F00E  20 13 F0  JSR LF013                    
F011  A0 08     LDY #$08                     

; subroutine entry
sub_F013:
F013  A9 02     LDA #$02                     
F015  99 90 00  STA $0090,Y                  
F018  BD 41 F0  LDA $F041,X                  
F01B  E8        INX                          
F01C  99 92 00  STA $0092,Y                  
F01F  85 10     STA $10                      
F021  BD 41 F0  LDA $F041,X                  
F024  E8        INX                          
F025  86 1B     STX $1B                      
F027  99 93 00  STA $0093,Y                  
F02A  85 11     STA $11                      
F02C  20 BD E3  JSR LE3BD                    
F02F  A5 10     LDA $10                      
F031  99 94 00  STA $0094,Y                  
F034  A5 11     LDA $11                      
F036  99 95 00  STA $0095,Y                  
F039  A2 00     LDX #$00                     
F03B  20 6D F0  JSR LF06D                    
F03E  A6 1B     LDX $1B                      
F040  60        RTS                          
        .byte $09,$22,$88,$25,$93,$22,$11,$26  ; .".%.".&
        .byte $09,$22,$07,$26                  ; .".&

; reachable via computed jump entry
dyn_F04D:
F04D  A0 00     LDY #$00                     
F04F  20 54 F0  JSR LF054                    
F052  A0 08     LDY #$08                     
F054  B9 90 00  LDA $0090,Y                  
F057  F0 E7     BEQ LF040                    
F059  C9 02     CMP #$02                     
F05B  90 3F     BCC LF09C                    
F05D  D0 29     BNE LF088                    
F05F  A5 21     LDA $21                      
F061  29 03     AND #$03                     
F063  C9 02     CMP #$02                     
F065  D0 D9     BNE LF040                    
F067  A5 21     LDA $21                      
F069  29 04     AND #$04                     
F06B  4A        LSR A                        
F06C  AA        TAX                          

; subroutine entry
sub_F06D:
F06D  B9 92 00  LDA $0092,Y                  
F070  85 10     STA $10                      
F072  B9 93 00  LDA $0093,Y                  
F075  85 11     STA $11                      
F077  A9 80     LDA #$80                     
F079  85 14     STA $14                      
F07B  BD 28 F1  LDA $F128,X                  
F07E  85 12     STA $12                      
F080  BD 29 F1  LDA $F129,X                  
F083  85 13     STA $13                      
F085  4C FB C6  JMP LC6FB                    

; branch target entry
LF088:
F088  20 CE F0  JSR LF0CE                    
F08B  F0 B3     BEQ LF040                    
F08D  A9 01     LDA #$01                     
F08F  99 90 00  STA $0090,Y                  
F092  A9 78     LDA #$78                     
F094  99 96 00  STA $0096,Y                  
F097  A2 00     LDX #$00                     
F099  4C 6D F0  JMP LF06D                    

; branch target entry
LF09C:
F09C  B9 96 00  LDA $0096,Y                  
F09F  38        SEC                          
F0A0  E9 01     SBC #$01                     
F0A2  99 96 00  STA $0096,Y                  
F0A5  D0 99     BNE LF040                    
F0A7  A9 00     LDA #$00                     
F0A9  99 90 00  STA $0090,Y                  
F0AC  A2 04     LDX #$04                     
F0AE  4C 6D F0  JMP LF06D                    
F0B1  A0 00     LDY #$00                     
F0B3  20 B8 F0  JSR LF0B8                    
F0B6  A0 08     LDY #$08                     
F0B8  B9 90 00  LDA $0090,Y                  
F0BB  C9 02     CMP #$02                     
F0BD  D0 27     BNE LF0E6                    
F0BF  20 CE F0  JSR LF0CE                    
F0C2  D0 22     BNE LF0E6                    
F0C4  A9 03     LDA #$03                     
F0C6  99 90 00  STA $0090,Y                  
F0C9  A2 02     LDX #$02                     
F0CB  4C 6D F0  JMP LF06D                    

; subroutine entry
sub_F0CE:
F0CE  B9 94 00  LDA $0094,Y                  
F0D1  38        SEC                          
F0D2  ED 01 04  SBC $0401                    
F0D5  C9 02     CMP #$02                     
F0D7  B0 0B     BCS LF0E4                    
F0D9  B9 95 00  LDA $0095,Y                  
F0DC  38        SEC                          
F0DD  ED 03 04  SBC $0403                    
F0E0  C9 02     CMP #$02                     
F0E2  F0 02     BEQ LF0E6                    

; branch target entry
LF0E4:
F0E4  A9 FF     LDA #$FF                     
F0E6  60        RTS                          
F0E7  A2 00     LDX #$00                     
F0E9  20 F0 F0  JSR LF0F0                    
F0EC  F0 39     BEQ LF127                    
F0EE  A2 08     LDX #$08                     
F0F0  B5 90     LDA $90,X                    
F0F2  C9 01     CMP #$01                     
F0F4  D0 31     BNE LF127                    
F0F6  B5 95     LDA $95,X                    
F0F8  38        SEC                          
F0F9  A0 03     LDY #$03                     
F0FB  F1 1E     SBC ($1E),Y                  
F0FD  C9 02     CMP #$02                     
F0FF  D0 E3     BNE LF0E4                    
F101  B5 94     LDA $94,X                    
F103  38        SEC                          
F104  A0 01     LDY #$01                     
F106  F1 1E     SBC ($1E),Y                  
F108  F0 0E     BEQ LF118                    
F10A  C9 01     CMP #$01                     
F10C  D0 19     BNE LF127                    
F10E  A0 00     LDY #$00                     
F110  B1 1E     LDA ($1E),Y                  
F112  C9 C0     CMP #$C0                     
F114  90 CE     BCC LF0E4                    
F116  B0 08     BCS LF120                    

; branch target entry
LF118:
F118  A0 00     LDY #$00                     
F11A  B1 1E     LDA ($1E),Y                  
F11C  C9 40     CMP #$40                     
F11E  B0 C4     BCS LF0E4                    

; branch target entry
LF120:
F120  A9 01     LDA #$01                     
F122  8D 07 06  STA $0607                    
F125  A9 00     LDA #$00                     
F127  60        RTS                          
        .byte $2E,$F1,$32,$F1,$36,$F1,$02,$51  ; ..2.6..Q
        .byte $51,$00,$02,$50,$50,$00,$02,$4A  ; Q..PP..J
        .byte $4A,$00                          ; J.

; subroutine entry
sub_F13A:
F13A  A4 7C     LDY $7C                      
F13C  B9 7F F2  LDA $F27F,Y                  
F13F  85 1C     STA $1C                      
F141  B9 80 F2  LDA $F280,Y                  
F144  85 1D     STA $1D                      
F146  A0 00     LDY #$00                     
F148  B1 1C     LDA ($1C),Y                  
F14A  C8        INY                          
F14B  85 53     STA $53                      
F14D  4A        LSR A                        
F14E  4A        LSR A                        
F14F  4A        LSR A                        
F150  85 52     STA $52                      
F152  A9 00     LDA #$00                     
F154  85 50     STA $50                      
F156  85 51     STA $51                      
F158  A2 00     LDX #$00                     

; branch target entry
LF15A:
F15A  95 54     STA $54,X                    
F15C  E8        INX                          
F15D  E0 0C     CPX #$0C                     
F15F  D0 F9     BNE LF15A                    
F161  A2 00     LDX #$00                     

; branch target entry
LF163:
F163  A9 02     LDA #$02                     
F165  9D 60 02  STA $0260,X                  
F168  B1 1C     LDA ($1C),Y                  
F16A  C8        INY                          
F16B  85 10     STA $10                      
F16D  9D 66 02  STA $0266,X                  
F170  B1 1C     LDA ($1C),Y                  
F172  C8        INY                          
F173  85 11     STA $11                      
F175  9D 67 02  STA $0267,X                  
F178  20 BD E3  JSR LE3BD                    
F17B  A5 10     LDA $10                      
F17D  9D 64 02  STA $0264,X                  
F180  A5 11     LDA $11                      
F182  9D 65 02  STA $0265,X                  
F185  8A        TXA                          
F186  18        CLC                          
F187  69 08     ADC #$08                     
F189  AA        TAX                          
F18A  E4 53     CPX $53                      
F18C  D0 D5     BNE LF163                    
F18E  60        RTS                          

; subroutine entry
sub_F18F:
F18F  A5 53     LDA $53                      
F191  F0 11     BEQ LF1A4                    
F193  A2 00     LDX #$00                     

; branch target entry
LF195:
F195  86 1B     STX $1B                      
F197  20 A5 F1  JSR LF1A5                    
F19A  A5 1B     LDA $1B                      
F19C  18        CLC                          
F19D  69 08     ADC #$08                     
F19F  AA        TAX                          
F1A0  E4 53     CPX $53                      
F1A2  D0 F1     BNE LF195                    

; branch target entry
LF1A4:
F1A4  60        RTS                          

; subroutine entry
sub_F1A5:
F1A5  BC 60 02  LDY $0260,X                  
F1A8  B9 B5 F1  LDA $F1B5,Y                  
F1AB  85 1C     STA $1C                      
F1AD  B9 B6 F1  LDA $F1B6,Y                  
F1B0  85 1D     STA $1D                      
F1B2  6C 1C 00  JMP ($001C)                  
        .byte $4F,$C1,$B9,$F1,$20,$33,$F2,$20  ; O... 3. 
        .byte $15,$F2,$A6,$1B,$BD,$60,$02,$C9  ; .....`..
        .byte $02,$D0,$4C,$BD,$65,$02,$CD,$03  ; ..L.e...
        .byte $04,$D0,$44,$BD,$64,$02,$38,$ED  ; ..D.d.8.
        .byte $01,$04,$C9,$02,$B0,$39,$AD,$0F  ; .....9..
        .byte $04,$C9,$08,$D0,$0F,$A9,$00,$8D  ; ........
        .byte $08,$04,$A9,$02,$8D,$0F,$04,$A9  ; ........
        .byte $06,$8D,$04,$04,$A9,$01,$8D,$08  ; ........
        .byte $06,$A9,$00,$9D,$60,$02,$C6,$52  ; ....`..R
        .byte $A0,$06,$20,$E5,$D4,$A0,$08,$20  ; .. .... 
        .byte $E5,$D4,$AD,$77,$F2,$85,$12,$AD  ; ...w....
        .byte $78,$F2,$85,$13,$4C,$50,$F2,$60  ; x...LP.`
        .byte $BD,$65,$02,$CD,$23,$04,$D0,$F7  ; .e..#...
        .byte $BD,$64,$02,$38,$ED,$21,$04,$C9  ; .d.8.!..
        .byte $02,$B0,$EC,$A9,$00,$8D,$2F,$04  ; ....../.
        .byte $8D,$24,$04,$4C,$F1,$F1,$A5,$1B  ; .$.L....
        .byte $4A,$4A,$4A,$45,$21,$29,$0F,$D0  ; JJJE!)..
        .byte $D6,$A5,$21,$29,$10,$4A,$4A,$4A  ; ..!).JJJ
        .byte $A8,$B9,$63,$F2,$85,$12,$B9,$64  ; ..c....d
        .byte $F2,$85,$13,$A6,$1B,$BD,$66,$02  ; ......f.
        .byte $85,$10,$BD,$67,$02,$85,$11,$A9  ; ...g....
        .byte $00,$85,$14,$4C,$FB,$C6,$67,$F2  ; ...L..g.
        .byte $6F,$F2,$02,$28,$29,$1E,$02,$2A  ; o..()..*
        .byte $2B,$00,$02,$2C,$2D,$1E,$02,$2E  ; +..,-...
        .byte $2F,$00,$79,$F2,$02,$00,$00,$1E  ; /.y.....
        .byte $02,$00,$00,$00,$89,$F2,$A8,$F2  ; ........
        .byte $C7,$F2,$C7,$F2,$78,$D5,$24,$55  ; ....x.$U
        .byte $26,$0F,$25,$0C,$26,$E9,$24,$03  ; &.%.&.$.
        .byte $25,$C3,$26,$FD,$20,$9A,$22,$F7  ; %.&. .".
        .byte $20,$94,$21,$F1,$20,$EB,$20,$06  ;  .!. . .
        .byte $21,$C5,$20,$78,$D5,$24,$55,$26  ; !. x.$U&
        .byte $EF,$24,$0C,$26,$49,$25,$C3,$24  ; .$.&I%.$
        .byte $C3,$26,$9D,$21,$9A,$22,$17,$21  ; .&.!.".!
        .byte $D1,$20,$D1,$22,$0B,$22,$EB,$20  ; . .".". 
        .byte $C5,$20,$78,$D5,$24,$55,$26,$CF  ; . x.$U&.
        .byte $24,$29,$25,$C3,$24,$C3,$26,$80  ; $)%.$.&.
        .byte $25,$3D,$21,$9A,$22,$F7,$20,$11  ; %=!.". .
        .byte $21,$D1,$22,$0B,$22,$EB,$20,$E5  ; !.".". .
        .byte $20                              ;  

; reachable via computed jump entry
dyn_F2E6:
F2E6  A5 60     LDA $60                      
F2E8  F0 14     BEQ LF2FE                    
F2EA  C9 02     CMP #$02                     
F2EC  90 41     BCC LF32F                    
F2EE  F0 6B     BEQ LF35B                    
F2F0  A5 61     LDA $61                      
F2F2  C9 3C     CMP #$3C                     
F2F4  F0 07     BEQ LF2FD                    
F2F6  E6 61     INC $61                      
F2F8  A5 42     LDA $42                      
F2FA  8D 05 06  STA $0605                    
F2FD  60        RTS                          
F2FE  E6 61     INC $61                      
F300  A5 61     LDA $61                      
F302  C9 3C     CMP #$3C                     
F304  D0 F7     BNE LF2FD                    
F306  A9 00     LDA #$00                     
F308  85 61     STA $61                      
F30A  E6 62     INC $62                      
F30C  A5 62     LDA $62                      
F30E  C5 66     CMP $66                      
F310  D0 EB     BNE LF2FD                    
F312  A9 01     LDA #$01                     
F314  85 60     STA $60                      
F316  A2 00     LDX #$00                     

; branch target entry
LF318:
F318  BD AA F3  LDA $F3AA,X                  
F31B  9D 90 04  STA $0490,X                  
F31E  E8        INX                          
F31F  E0 08     CPX #$08                     
F321  D0 F5     BNE LF318                    

; jump target entry
jmp_F323:
F323  20 BF F4  JSR LF4BF                    
F326  A9 03     LDA #$03                     
F328  8D F5 06  STA $06F5                    
F32B  8D F6 06  STA $06F6                    
F32E  60        RTS                          

; branch target entry
LF32F:
F32F  20 83 F3  JSR LF383                    
F332  20 B2 F3  JSR LF3B2                    
F335  A5 42     LDA $42                      
F337  8D 05 06  STA $0605                    
F33A  AD 91 04  LDA $0491                    
F33D  F0 BE     BEQ LF2FD                    
F33F  A9 02     LDA #$02                     
F341  85 60     STA $60                      
F343  A9 00     LDA #$00                     
F345  85 61     STA $61                      
F347  85 62     STA $62                      
F349  A6 68     LDX $68                      
F34B  A9 1A     LDA #$1A                     
F34D  9D 0F 04  STA $040F,X                  
F350  A9 01     LDA #$01                     
F352  9D 07 04  STA $0407,X                  
F355  A9 03     LDA #$03                     
F357  9D 05 04  STA $0405,X                  
F35A  60        RTS                          

; branch target entry
LF35B:
F35B  E6 61     INC $61                      
F35D  A5 61     LDA $61                      
F35F  C9 3C     CMP #$3C                     
F361  D0 9A     BNE LF2FD                    
F363  A9 00     LDA #$00                     
F365  85 61     STA $61                      
F367  E6 62     INC $62                      
F369  A5 62     LDA $62                      
F36B  C5 67     CMP $67                      
F36D  D0 8E     BNE LF2FD                    
F36F  A9 03     LDA #$03                     
F371  85 60     STA $60                      
F373  A9 1A     LDA #$1A                     
F375  8D 1F 04  STA $041F                    
F378  A9 01     LDA #$01                     
F37A  8D 17 04  STA $0417                    
F37D  8D 15 04  STA $0415                    
F380  4C 23 F3  JMP LF323                    

; subroutine entry
sub_F383:
F383  A2 00     LDX #$00                     

; branch target entry
LF385:
F385  BD 90 04  LDA $0490,X                  
F388  95 10     STA $10,X                    
F38A  E8        INX                          
F38B  E0 08     CPX #$08                     
F38D  D0 F6     BNE LF385                    
F38F  A5 21     LDA $21                      
F391  29 03     AND #$03                     
F393  85 13     STA $13                      

; branch target entry
LF395:
F395  20 15 C4  JSR LC415                    
F398  A5 10     LDA $10                      
F39A  18        CLC                          
F39B  69 08     ADC #$08                     
F39D  85 10     STA $10                      
F39F  90 02     BCC LF3A3                    
F3A1  E6 11     INC $11                      

; branch target entry
LF3A3:
F3A3  E6 12     INC $12                      
F3A5  C6 17     DEC $17                      
F3A7  D0 EC     BNE LF395                    
F3A9  60        RTS                          
        .byte $F8,$00,$A0,$00,$00,$00,$68,$04  ; ......h.

; subroutine entry
sub_F3B2:
F3B2  AD 90 04  LDA $0490                    
F3B5  38        SEC                          
F3B6  E9 02     SBC #$02                     
F3B8  8D 90 04  STA $0490                    
F3BB  B0 03     BCS LF3C0                    
F3BD  CE 91 04  DEC $0491                    

; branch target entry
LF3C0:
F3C0  60        RTS                          
F3C1  A9 00     LDA #$00                     
F3C3  85 60     STA $60                      
F3C5  85 61     STA $61                      
F3C7  85 62     STA $62                      
F3C9  A5 7D     LDA $7D                      
F3CB  0A        ASL A                        
F3CC  65 7D     ADC $7D                      
F3CE  0A        ASL A                        
F3CF  AA        TAX                          
F3D0  A0 00     LDY #$00                     
F3D2  BD DF F3  LDA $F3DF,X                  
F3D5  99 63 00  STA $0063,Y                  
F3D8  E8        INX                          
F3D9  C8        INY                          
F3DA  C0 06     CPY #$06                     
F3DC  D0 F4     BNE LF3D2                    
F3DE  60        RTS                          
        .byte $20,$1C,$B4,$50,$46,$60,$20,$1E  ;  ..PF` .
        .byte $A0,$3C,$46,$60,$1E,$1C,$B4,$50  ; .<F`...P
        .byte $46,$60,$22,$23,$A0,$46,$37,$60  ; F`"#.F7`
        .byte $22,$24,$A0,$46,$37,$60,$22,$26  ; "$.F7`"&
        .byte $96,$3C,$32,$60,$1E,$1C,$B4,$50  ; .<2`...P
        .byte $46,$60,$24,$26,$8C,$28,$32,$70  ; F`$&.(2p
        .byte $24,$28,$8C,$28,$32,$70,$24,$2A  ; $(.(2p$*
        .byte $78,$1E,$41,$70,$1E,$1C,$B4,$50  ; x.Ap...P
        .byte $46,$60,$26,$28,$78,$28,$2D,$70  ; F`&(x(-p
        .byte $26,$2A,$78,$28,$2D,$70,$26,$2C  ; &*x(-p&,
        .byte $64,$1E,$32,$70,$1E,$1C,$B4,$50  ; d.2p...P
        .byte $46,$60,$28,$2C,$64,$1E,$2D,$70  ; F`(,d.-p
        .byte $28,$2E,$64,$1E,$2D,$70,$28,$30  ; (.d.-p(0
        .byte $5A,$14,$28,$70,$1E,$1C,$B4,$50  ; Z.(p...P
        .byte $46,$60,$2A,$2E,$5A,$1E,$2D,$80  ; F`*.Z.-.
        .byte $2A,$30,$50,$14,$28,$80,$2A,$34  ; *0P.(.*4
        .byte $5A,$1E,$2D,$80,$1E,$1C,$B4,$50  ; Z.-....P
        .byte $46,$60,$2C,$32,$50,$1E,$28,$80  ; F`,2P.(.
        .byte $2C,$32,$3C,$14,$28,$80,$2C,$34  ; ,2<.(.,4
        .byte $50,$1E,$28,$80,$1E,$1C,$B4,$50  ; P.(....P
        .byte $46,$60,$2C,$32,$3C,$14,$28,$80  ; F`,2<.(.
        .byte $2C,$36,$50,$1E,$23,$80,$2C,$38  ; ,6P.#.,8
        .byte $50,$1E,$28,$80,$1E,$1C,$B4,$50  ; P.(....P
        .byte $46,$60,$2C,$38,$3C,$14,$28,$80  ; F`,8<.(.

; subroutine entry
sub_F49F:
F49F  0A        ASL A                        
F4A0  A8        TAY                          
F4A1  C8        INY                          
F4A2  68        PLA                          
F4A3  85 F6     STA $F6                      
F4A5  68        PLA                          
F4A6  85 F7     STA $F7                      
F4A8  B1 F6     LDA ($F6),Y                  
F4AA  AA        TAX                          
F4AB  C8        INY                          
F4AC  B1 F6     LDA ($F6),Y                  
F4AE  85 F7     STA $F7                      
F4B0  86 F6     STX $F6                      
F4B2  6C F6 00  JMP ($00F6)                  

; subroutine entry
sub_F4B5:
F4B5  A9 0F     LDA #$0F                     
F4B7  8D 15 40  STA $4015                    APU: status
F4BA  A9 C0     LDA #$C0                     
F4BC  8D 17 40  STA $4017                    APU frame counter
F4BF  A9 19     LDA #$19                     
F4C1  85 F0     STA $F0                      
F4C3  A9 06     LDA #$06                     
F4C5  85 F1     STA $F1                      
F4C7  A2 00     LDX #$00                     
F4C9  A0 00     LDY #$00                     

; branch target entry
LF4CB:
F4CB  A9 00     LDA #$00                     
F4CD  91 F0     STA ($F0),Y                  
F4CF  9D 00 06  STA $0600,X                  
F4D2  18        CLC                          
F4D3  A5 F0     LDA $F0                      
F4D5  69 08     ADC #$08                     
F4D7  85 F0     STA $F0                      
F4D9  90 02     BCC LF4DD                    
F4DB  E6 F1     INC $F1                      

; branch target entry
LF4DD:
F4DD  E8        INX                          
F4DE  E0 19     CPX #$19                     
F4E0  D0 E9     BNE LF4CB                    
F4E2  A2 19     LDX #$19                     
F4E4  A0 00     LDY #$00                     

; branch target entry
LF4E6:
F4E6  B9 9E F8  LDA $F89E,Y                  
F4E9  99 E2 06  STA $06E2,Y                  
F4EC  C8        INY                          
F4ED  CA        DEX                          
F4EE  D0 F6     BNE LF4E6                    
F4F0  60        RTS                          

; subroutine entry
apu_engine:
F4F1  A5 23     LDA $23                      
F4F3  D0 06     BNE LF4FB                    
F4F5  A9 19     LDA #$19                     
F4F7  85 F5     STA $F5                      
F4F9  10 0E     BPL LF509                    

; branch target entry
LF4FB:
F4FB  A9 01     LDA #$01                     
F4FD  85 F5     STA $F5                      
F4FF  A9 10     LDA #$10                     
F501  8D 04 40  STA $4004                    APU register
F504  A9 00     LDA #$00                     
F506  8D 08 40  STA $4008                    APU register

; branch target entry
LF509:
F509  A9 00     LDA #$00                     
F50B  85 FC     STA $FC                      
F50D  85 FD     STA $FD                      
F50F  85 FE     STA $FE                      
F511  85 FF     STA $FF                      
F513  A5 F5     LDA $F5                      
F515  85 F4     STA $F4                      
F517  A9 19     LDA #$19                     
F519  85 F0     STA $F0                      
F51B  A9 06     LDA #$06                     
F51D  85 F1     STA $F1                      

; branch target entry
LF51F:
F51F  A0 00     LDY #$00                     
F521  B1 F0     LDA ($F0),Y                  
F523  F0 35     BEQ LF55A                    
F525  C9 05     CMP #$05                     
F527  90 0B     BCC LF534                    
F529  38        SEC                          
F52A  E9 05     SBC #$05                     
F52C  AA        TAX                          
F52D  A9 01     LDA #$01                     
F52F  95 FC     STA $FC,X                    
F531  4C 5A F5  JMP LF55A                    

; branch target entry
LF534:
F534  AA        TAX                          
F535  CA        DEX                          
F536  B5 FC     LDA $FC,X                    
F538  D0 20     BNE LF55A                    
F53A  A9 01     LDA #$01                     
F53C  95 FC     STA $FC,X                    
F53E  8A        TXA                          
F53F  A8        TAY                          
F540  18        CLC                          
F541  69 05     ADC #$05                     
F543  A0 00     LDY #$00                     
F545  91 F0     STA ($F0),Y                  
F547  8A        TXA                          
F548  0A        ASL A                        
F549  0A        ASL A                        
F54A  AA        TAX                          
F54B  A9 04     LDA #$04                     
F54D  85 F6     STA $F6                      

; branch target entry
LF54F:
F54F  C8        INY                          
F550  B1 F0     LDA ($F0),Y                  
F552  9D 00 40  STA $4000,X                  APU register
F555  E8        INX                          
F556  C6 F6     DEC $F6                      
F558  D0 F5     BNE LF54F                    

; branch target entry
LF55A:
F55A  18        CLC                          
F55B  A5 F0     LDA $F0                      
F55D  69 08     ADC #$08                     
F55F  85 F0     STA $F0                      
F561  90 02     BCC LF565                    
F563  E6 F1     INC $F1                      

; branch target entry
LF565:
F565  C6 F4     DEC $F4                      
F567  D0 B6     BNE LF51F                    
F569  A2 00     LDX #$00                     

; branch target entry
LF56B:
F56B  86 F6     STX $F6                      
F56D  B5 FC     LDA $FC,X                    
F56F  D0 0C     BNE LF57D                    
F571  8A        TXA                          
F572  0A        ASL A                        
F573  0A        ASL A                        
F574  AA        TAX                          
F575  0A        ASL A                        
F576  29 10     AND #$10                     
F578  49 10     EOR #$10                     
F57A  9D 00 40  STA $4000,X                  APU register

; branch target entry
LF57D:
F57D  A6 F6     LDX $F6                      
F57F  E8        INX                          
F580  E0 04     CPX #$04                     
F582  90 E7     BCC LF56B                    
F584  A0 00     LDY #$00                     
F586  84 F4     STY $F4                      
F588  A9 19     LDA #$19                     
F58A  85 F0     STA $F0                      
F58C  A9 06     LDA #$06                     
F58E  85 F1     STA $F1                      

; branch target entry
LF590:
F590  A6 F4     LDX $F4                      
F592  BD 85 F8  LDA $F885,X                  
F595  F0 0D     BEQ LF5A4                    
F597  BD 00 06  LDA $0600,X                  
F59A  D0 15     BNE LF5B1                    
F59C  A0 00     LDY #$00                     
F59E  B1 F0     LDA ($F0),Y                  
F5A0  F0 16     BEQ LF5B8                    
F5A2  D0 28     BNE LF5CC                    

; branch target entry
LF5A4:
F5A4  BD 00 06  LDA $0600,X                  
F5A7  F0 0F     BEQ LF5B8                    
F5A9  A0 00     LDY #$00                     
F5AB  B1 F0     LDA ($F0),Y                  
F5AD  D0 1D     BNE LF5CC                    
F5AF  F0 28     BEQ LF5D9                    

; branch target entry
LF5B1:
F5B1  A9 00     LDA #$00                     
F5B3  9D 00 06  STA $0600,X                  
F5B6  10 21     BPL LF5D9                    

; branch target entry
LF5B8:
F5B8  18        CLC                          
F5B9  A5 F0     LDA $F0                      
F5BB  69 08     ADC #$08                     
F5BD  85 F0     STA $F0                      
F5BF  90 02     BCC LF5C3                    
F5C1  E6 F1     INC $F1                      

; branch target entry
LF5C3:
F5C3  E6 F4     INC $F4                      
F5C5  A5 F4     LDA $F4                      
F5C7  C5 F5     CMP $F5                      
F5C9  90 C5     BCC LF590                    
F5CB  60        RTS                          

; branch target entry
LF5CC:
F5CC  A0 07     LDY #$07                     
F5CE  B1 F0     LDA ($F0),Y                  
F5D0  38        SEC                          
F5D1  E9 01     SBC #$01                     
F5D3  91 F0     STA ($F0),Y                  
F5D5  F0 5C     BEQ LF633                    
F5D7  D0 DF     BNE LF5B8                    

; branch target entry
LF5D9:
F5D9  A5 F4     LDA $F4                      
F5DB  C9 13     CMP #$13                     
F5DD  F0 10     BEQ LF5EF                    
F5DF  C9 14     CMP #$14                     
F5E1  F0 19     BEQ LF5FC                    
F5E3  A9 00     LDA #$00                     
F5E5  A0 05     LDY #$05                     
F5E7  91 F0     STA ($F0),Y                  
F5E9  20 F4 F7  JSR LF7F4                    
F5EC  4C 06 F6  JMP LF606                    

; branch target entry
LF5EF:
F5EF  AD 79 F8  LDA $F879                    
F5F2  85 F8     STA $F8                      
F5F4  AD 7A F8  LDA $F87A                    
F5F7  85 F9     STA $F9                      
F5F9  4C 06 F6  JMP LF606                    

; branch target entry
LF5FC:
F5FC  AD 7B F8  LDA $F87B                    
F5FF  85 FA     STA $FA                      
F601  AD 7C F8  LDA $F87C                    
F604  85 FB     STA $FB                      

; jump target entry
jmp_F606:
F606  20 0B F8  JSR sound_channel_update     
F609  A0 00     LDY #$00                     
F60B  91 F0     STA ($F0),Y                  
F60D  20 0B F8  JSR sound_channel_update     
F610  A0 01     LDY #$01                     
F612  91 F0     STA ($F0),Y                  
F614  20 0B F8  JSR sound_channel_update     
F617  A0 02     LDY #$02                     
F619  91 F0     STA ($F0),Y                  
F61B  20 0B F8  JSR sound_channel_update     
F61E  A0 04     LDY #$04                     
F620  91 F0     STA ($F0),Y                  
F622  A0 00     LDY #$00                     
F624  B1 F0     LDA ($F0),Y                  
F626  C9 04     CMP #$04                     
F628  D0 0C     BNE LF636                    
F62A  20 0B F8  JSR sound_channel_update     
F62D  A0 03     LDY #$03                     
F62F  91 F0     STA ($F0),Y                  
F631  10 03     BPL LF636                    

; branch target entry
LF633:
F633  20 F4 F7  JSR LF7F4                    

; branch target entry
LF636:
F636  20 0B F8  JSR sound_channel_update     
F639  C9 E8     CMP #$E8                     
F63B  B0 6A     BCS LF6A7                    
F63D  C9 60     CMP #$60                     
F63F  F0 3B     BEQ LF67C                    
F641  B0 5C     BCS LF69F                    
F643  48        PHA                          
F644  29 F8     AND #$F8                     
F646  4A        LSR A                        
F647  4A        LSR A                        
F648  AA        TAX                          
F649  BD 3B F8  LDA $F83B,X                  
F64C  85 F6     STA $F6                      
F64E  BD 3C F8  LDA $F83C,X                  
F651  85 F7     STA $F7                      
F653  68        PLA                          
F654  29 07     AND #$07                     
F656  F0 08     BEQ LF660                    
F658  AA        TAX                          

; branch target entry
LF659:
F659  46 F6     LSR $F6                      
F65B  66 F7     ROR $F7                      
F65D  CA        DEX                          
F65E  D0 F9     BNE LF659                    

; branch target entry
LF660:
F660  A0 04     LDY #$04                     
F662  B1 F0     LDA ($F0),Y                  
F664  29 F8     AND #$F8                     
F666  05 F6     ORA $F6                      
F668  91 F0     STA ($F0),Y                  
F66A  A5 F7     LDA $F7                      
F66C  88        DEY                          
F66D  91 F0     STA ($F0),Y                  
F66F  A0 00     LDY #$00                     
F671  B1 F0     LDA ($F0),Y                  
F673  C9 05     CMP #$05                     
F675  90 05     BCC LF67C                    
F677  38        SEC                          
F678  E9 04     SBC #$04                     
F67A  91 F0     STA ($F0),Y                  

; branch target entry
LF67C:
F67C  A0 06     LDY #$06                     
F67E  B1 F0     LDA ($F0),Y                  
F680  85 F6     STA $F6                      
F682  A6 F4     LDX $F4                      
F684  BD E2 06  LDA $06E2,X                  
F687  85 F7     STA $F7                      
F689  A9 00     LDA #$00                     
F68B  A2 08     LDX #$08                     

; branch target entry
LF68D:
F68D  46 F7     LSR $F7                      
F68F  90 03     BCC LF694                    
F691  18        CLC                          
F692  65 F6     ADC $F6                      

; branch target entry
LF694:
F694  06 F6     ASL $F6                      
F696  CA        DEX                          
F697  D0 F4     BNE LF68D                    
F699  C8        INY                          
F69A  91 F0     STA ($F0),Y                  
F69C  4C B8 F5  JMP LF5B8                    

; branch target entry
LF69F:
F69F  E9 60     SBC #$60                     
F6A1  A0 06     LDY #$06                     
F6A3  91 F0     STA ($F0),Y                  
F6A5  10 8F     BPL LF636                    

; branch target entry
LF6A7:
F6A7  E9 E8     SBC #$E8                     
F6A9  20 9F F4  JSR LF49F                    
F6AC  D0 F6     BNE LF6A4                    
F6AE  DE F6 F0  DEC $F0F6,X                  
F6B1  F6 02     INC $02,X                    
F6B3  F7 14     ISC $14,X                    
F6B5  F7 1E     ISC $1E,X                    
F6B7  F7 28     ISC $28,X                    
F6B9  F7 32     ISC $32,X                    
F6BB  F7 3F     ISC $3F,X                    
F6BD  F7 43     ISC $43,X                    
F6BF  F7 46     ISC $46,X                    
F6C1  F7 5A     ISC $5A,X                    
F6C3  F7 5E     ISC $5E,X                    
F6C5  F7 61     ISC $61,X                    
F6C7  F7 75     ISC $75,X                    
F6C9  F7 79     ISC $79,X                    
F6CB  F7 7C     ISC $7C,X                    
F6CD  F7 C2     ISC $C2,X                    
F6CF  F7 A6     ISC $A6,X                    
F6D1  F4 A9     NOP $A9,X                    
F6D3  00        BRK                          
F6D4  9D 00 06  STA $0600,X                  
F6D7  A0 00     LDY #$00                     
F6D9  91 F0     STA ($F0),Y                  
F6DB  4C B8 F5  JMP LF5B8                    
        .byte $20,$0B,$F8,$85,$F6,$A0,$01,$B1  ;  .......
        .byte $F0,$29,$3F,$05,$F6,$91,$F0,$4C  ; .)?....L
        .byte $36,$F6                          ; 6.

; reachable via computed jump entry
dyn_F6F0:
F6F0  20 0B F8  JSR sound_channel_update     
F6F3  85 F6     STA $F6                      
F6F5  A0 01     LDY #$01                     
F6F7  B1 F0     LDA ($F0),Y                  
F6F9  29 C0     AND #$C0                     
F6FB  05 F6     ORA $F6                      
F6FD  91 F0     STA ($F0),Y                  
F6FF  4C 36 F6  JMP LF636                    
        .byte $20,$0B,$F8,$85,$F6,$A0,$01,$B1  ;  .......
        .byte $F0,$29,$F0,$05,$F6,$91,$F0,$4C  ; .).....L
        .byte $36,$F6,$20,$0B,$F8,$A0,$02,$91  ; 6. .....
        .byte $F0,$4C,$36,$F6,$20,$0B,$F8,$A0  ; .L6. ...
        .byte $04,$91,$F0,$4C,$36,$F6,$20,$0B  ; ...L6. .
        .byte $F8,$A0,$01,$91,$F0,$4C,$36,$F6  ; .....L6.

; reachable via computed jump entry
dyn_F732:
F732  A9 00     LDA #$00                     
F734  A2 08     LDX #$08                     
F736  9D 61 01  STA $0161,X                  
F739  CA        DEX                          
F73A  10 FA     BPL LF736                    
F73C  4C 36 F6  JMP LF636                    
        .byte $A2,$00,$F0,$05,$A2,$01,$2C,$A2  ; ......,.
        .byte $02,$20,$0B,$F8,$FE,$61,$01,$DD  ; . ...a..
        .byte $61,$01,$D0,$6F,$A9,$00,$9D,$61  ; a..o...a
        .byte $01,$F0,$36,$A2,$00,$F0,$05,$A2  ; ..6.....
        .byte $01,$2C,$A2,$02,$20,$0B,$F8,$FE  ; .,.. ...
        .byte $64,$01,$DD,$64,$01,$D0,$22,$A9  ; d..d..".
        .byte $00,$9D,$64,$01,$F0,$4D          ; ..d..M

; reachable via computed jump entry
dyn_F775:
F775  A2 00     LDX #$00                     
F777  F0 05     BEQ LF77E                    
F779  A2 01     LDX #$01                     
F77B  2C A2 02  BIT $02A2                    
F77E  20 0B F8  JSR sound_channel_update     
F781  FE 67 01  INC $0167,X                  
F784  DD 67 01  CMP $0167,X                  
F787  D0 07     BNE LF790                    
F789  A9 00     LDA #$00                     
F78B  9D 67 01  STA $0167,X                  
F78E  F0 32     BEQ LF7C2                    
F790  A5 F4     LDA $F4                      
F792  C9 13     CMP #$13                     
F794  F0 10     BEQ LF7A6                    
F796  C9 14     CMP #$14                     
F798  F0 1A     BEQ LF7B4                    
F79A  A0 05     LDY #$05                     
F79C  B1 F0     LDA ($F0),Y                  
F79E  18        CLC                          
F79F  69 01     ADC #$01                     
F7A1  91 F0     STA ($F0),Y                  
F7A3  4C 36 F6  JMP LF636                    
F7A6  A5 F8     LDA $F8                      
F7A8  18        CLC                          
F7A9  69 02     ADC #$02                     
F7AB  85 F8     STA $F8                      
F7AD  90 02     BCC LF7B1                    
F7AF  E6 F9     INC $F9                      
F7B1  4C 36 F6  JMP LF636                    
F7B4  A5 FA     LDA $FA                      
F7B6  18        CLC                          
F7B7  69 02     ADC #$02                     
F7B9  85 FA     STA $FA                      
F7BB  90 02     BCC LF7BF                    
F7BD  E6 FB     INC $FB                      
F7BF  4C 36 F6  JMP LF636                    

; branch target entry
LF7C2:
F7C2  A5 F4     LDA $F4                      
F7C4  C9 13     CMP #$13                     
F7C6  F0 0E     BEQ LF7D6                    
F7C8  C9 14     CMP #$14                     
F7CA  F0 19     BEQ LF7E5                    
F7CC  20 0B F8  JSR sound_channel_update     
F7CF  A0 05     LDY #$05                     
F7D1  91 F0     STA ($F0),Y                  
F7D3  4C 36 F6  JMP LF636                    

; branch target entry
LF7D6:
F7D6  20 0B F8  JSR sound_channel_update     
F7D9  48        PHA                          
F7DA  20 0B F8  JSR sound_channel_update     
F7DD  85 F9     STA $F9                      
F7DF  68        PLA                          
F7E0  85 F8     STA $F8                      
F7E2  4C 36 F6  JMP LF636                    

; branch target entry
LF7E5:
F7E5  20 0B F8  JSR sound_channel_update     
F7E8  48        PHA                          
F7E9  20 0B F8  JSR sound_channel_update     
F7EC  85 FB     STA $FB                      
F7EE  68        PLA                          
F7EF  85 FA     STA $FA                      
F7F1  4C 36 F6  JMP LF636                    

; subroutine entry
sub_F7F4:
F7F4  A5 F4     LDA $F4                      
F7F6  C9 13     CMP #$13                     
F7F8  F0 10     BEQ LF80A                    
F7FA  C9 14     CMP #$14                     
F7FC  F0 0C     BEQ LF80A                    
F7FE  0A        ASL A                        
F7FF  AA        TAX                          
F800  BD 53 F8  LDA $F853,X                  
F803  85 F2     STA $F2                      
F805  BD 54 F8  LDA $F854,X                  
F808  85 F3     STA $F3                      

; branch target entry
LF80A:
F80A  60        RTS                          

; subroutine entry
sound_channel_update:
F80B  A5 F4     LDA $F4                      
F80D  C9 13     CMP #$13                     
F80F  F0 14     BEQ LF825                    
F811  C9 14     CMP #$14                     
F813  F0 1B     BEQ LF830                    
F815  A0 05     LDY #$05                     
F817  B1 F0     LDA ($F0),Y                  
F819  A8        TAY                          
F81A  B1 F2     LDA ($F2),Y                  
F81C  48        PHA                          
F81D  C8        INY                          
F81E  98        TYA                          
F81F  A0 05     LDY #$05                     
F821  91 F0     STA ($F0),Y                  
F823  68        PLA                          
F824  60        RTS                          

; branch target entry
LF825:
F825  A0 00     LDY #$00                     
F827  B1 F8     LDA ($F8),Y                  
F829  E6 F8     INC $F8                      
F82B  D0 02     BNE LF82F                    
F82D  E6 F9     INC $F9                      

; branch target entry
LF82F:
F82F  60        RTS                          

; branch target entry
LF830:
F830  A0 00     LDY #$00                     
F832  B1 FA     LDA ($FA),Y                  
F834  E6 FA     INC $FA                      
F836  D0 02     BNE LF83A                    
F838  E6 FB     INC $FB                      

; branch target entry
LF83A:
F83A  60        RTS                          
        .byte $07,$F2,$07,$80,$07,$14,$06,$AE  ; ........
        .byte $06,$43,$05,$F4,$05,$9E,$05,$4E  ; .C.....N
        .byte $05,$02,$04,$BA,$04,$76,$04,$36  ; .....v.6
        .byte $86,$FE,$92,$FE,$13,$FB,$2B,$FB  ; ......+.
        .byte $3D,$FB,$BA,$FD,$A6,$FD,$9F,$FD  ; =.......
        .byte $89,$FD,$64,$FD,$56,$FD,$1A,$FD  ; ..d.V...
        .byte $38,$FD,$47,$FD,$55,$FB,$F5,$FB  ; 8.G.U...
        .byte $69,$FC,$5A,$FE,$72,$FE,$B7,$F8  ; i.Z.r...
        .byte $14,$FA,$C2,$FD,$F9,$FD,$2A,$FE  ; ......*.
        .byte $0D,$FF,$00,$00,$00,$00,$00,$00  ; ........
        .byte $00,$00,$01,$00,$01,$00,$00,$00  ; ........
        .byte $00,$00,$00,$00,$00,$00,$00,$00  ; ........
        .byte $00,$00,$00,$01,$01,$01,$01,$01  ; ........
        .byte $01,$01,$01,$01,$01,$01,$01,$01  ; ........
        .byte $01,$01,$01,$01,$01,$01,$04,$04  ; ........
        .byte $01,$01,$01,$01,$01,$03,$7F,$40  ; .......@
        .byte $EF,$64,$32,$13,$0B,$13,$EA,$20  ; .d2.... 
        .byte $67,$1B,$69,$13,$EA,$03,$64,$03  ; g.i...d.
        .byte $13,$63,$03,$61,$52,$63,$3A,$EA  ; .c.aRc:.
        .byte $20,$71,$03,$EA,$03,$64,$2A,$03  ;  q...d*.
        .byte $5A,$03,$EA,$20,$67,$13,$69,$03  ; Z.. g.i.
        .byte $EA,$03,$64,$52,$03,$63,$52,$64  ; ..dR.cRd
        .byte $3A,$EA,$20,$71,$2A,$EA,$03,$63  ; :. q*..c
        .byte $12,$61,$2A,$63,$52,$61,$12,$63  ; .a*cRa.c
        .byte $2A,$61,$52,$63,$12,$61,$52,$63  ; *aRc.aRc
        .byte $1A,$61,$3A,$63,$52,$61,$22,$63  ; .a:cRa"c
        .byte $3A,$61,$52,$63,$22,$61,$52,$F6  ; :aRc"aR.
        .byte $04,$FE,$F9,$64,$60,$63,$13,$61  ; ...d`c.a
        .byte $0B,$64,$03,$63,$2A,$65,$52,$64  ; .d.c*eRd
        .byte $52,$4A,$3A,$F3,$03,$97,$F9,$F0  ; RJ:.....
        .byte $02,$BC,$F8,$63,$12,$61,$4A,$63  ; ...c.aJc
        .byte $32,$61,$12,$63,$4A,$61,$32,$F0  ; 2a.cJa2.
        .byte $05,$2E,$F9,$63,$12,$61,$4A,$63  ; ...c.aJc
        .byte $02,$61,$3A,$63,$22,$61,$02,$63  ; .a:c"a.c
        .byte $3A,$61,$22,$F0,$05,$42,$F9,$64  ; :a"..B.d
        .byte $02,$63,$51,$61,$02,$63,$12,$61  ; .cQa.c.a
        .byte $51,$63,$02,$61,$12,$63,$1A,$61  ; Qc.a.c.a
        .byte $02,$63,$12,$61,$1A,$63,$2A,$61  ; .c.a.c*a
        .byte $12,$63,$1A,$61,$2A,$63,$3A,$61  ; .c.a*c:a
        .byte $1A,$63,$2A,$61,$3A,$63,$4A,$61  ; .c*a:cJa
        .byte $2A,$63,$3A,$61,$4A,$63,$52,$61  ; *c:aJcRa
        .byte $03,$64,$13,$63,$0B,$61,$13,$63  ; .d.c.a.c
        .byte $0B,$61,$13,$63,$0B,$61,$13,$F0  ; .a.c.a..
        .byte $02,$BC,$F8,$E8,$64,$60,$13,$0B  ; ....d`..
        .byte $13,$1B,$13,$0B,$13,$F3,$02,$C6  ; ........
        .byte $F9,$64,$3A,$4B,$3B,$13,$EA,$0F  ; .d:K;...
        .byte $70,$52,$EA,$03,$64,$60,$03,$5A  ; pR..d`.Z
        .byte $03,$13,$03,$13,$23,$2A,$2B,$1B  ; ....#*+.
        .byte $13,$68,$03,$EA,$0D,$0B,$EA,$03  ; .h......
        .byte $F9,$97,$F9,$64,$60,$52,$13,$2B  ; ...d`R.+
        .byte $63,$4B,$61,$3B,$63,$4B,$64,$3B  ; cKa;cKd;
        .byte $61,$3B,$63,$33,$65,$3B,$EA,$3C  ; a;c3e;.<
        .byte $68,$53,$EA,$03,$63,$3B,$61,$13  ; hS..c;a.
        .byte $63,$2B,$61,$3B,$63,$13,$61,$2B  ; c+a;c.a+
        .byte $63,$3B,$61,$0B,$63,$13,$65,$52  ; c;a.c.eR
        .byte $64,$4A,$3A,$2A,$67,$52,$69,$52  ; dJ:*gRiR
        .byte $F9,$BC,$F8,$63,$52,$61,$03,$63  ; ...cRa.c
        .byte $13,$61,$52,$64,$3A,$2A,$63,$2A  ; .aRd:*c*
        .byte $61,$3A,$64,$4A,$68,$52,$F9,$54  ; a:dJhR.T
        .byte $F9,$03,$23,$7F,$08,$68,$3A,$67  ; ..#..h:g
        .byte $12,$64,$3A,$61,$3A,$64,$12,$63  ; .d:a:d.c
        .byte $3A,$61,$4A,$64,$5A,$68,$03,$67  ; :aJdZh.g
        .byte $3A,$64,$03,$61,$03,$64,$52,$4A  ; :d.a.dRJ
        .byte $3A,$68,$2A,$67,$02,$64,$2A,$61  ; :h*g.d*a
        .byte $2A,$64,$02,$63,$2A,$61,$3A,$64  ; *d.c*a:d
        .byte $4A,$68,$52,$67,$2A,$64,$52,$61  ; JhRg*dRa
        .byte $52,$64,$2A,$22,$1A,$51,$52,$51  ; Rd*".QRQ
        .byte $52,$02,$03,$0A,$0B,$F8,$04,$0A  ; R.......
        .byte $FB,$74,$12,$64,$52,$03,$0B,$F5  ; .t.dR...
        .byte $03,$AA,$FA,$F2,$02,$18,$FA,$EE  ; ........
        .byte $7F,$68,$12,$66,$32,$62,$4A,$64  ; .h.f2bJd
        .byte $5A,$68,$13,$64,$5A,$68,$4A,$5A  ; Zh.dZhJZ
        .byte $64,$32,$6C,$4A,$68,$02,$66,$22  ; d2lJh.f"
        .byte $62,$3A,$64,$4A,$68,$03,$64,$4A  ; b:dJh.dJ
        .byte $68,$3A,$4A,$64,$22,$6C,$3A,$EE  ; h:Jd"l:.
        .byte $23,$64,$51,$52,$02,$03,$12,$13  ; #dQR....
        .byte $1A,$1B,$2A,$2B,$3A,$3B,$4A,$4A  ; ..*+:;JJ
        .byte $32,$12,$F2,$02,$18,$FA,$E8,$68  ; 2......h
        .byte $13,$67,$4A,$64,$13,$61,$13,$64  ; .gJd.a.d
        .byte $4A,$63,$13,$61,$23,$64,$33,$68  ; Jc.a#d3h
        .byte $3B,$67,$13,$64,$3B,$61,$3B,$64  ; ;g.d;a;d
        .byte $2B,$63,$23,$61,$23,$64,$13,$68  ; +c#a#d.h
        .byte $03,$67,$3A,$64,$03,$61,$03,$64  ; .g:d.a.d
        .byte $3A,$63,$03,$61,$13,$64,$23,$78  ; :c.a.d#x
        .byte $2B,$68,$2B,$13,$67,$4A,$64,$13  ; +h+.gJd.
        .byte $61,$13,$64,$1B,$63,$13,$61,$13  ; a.d.c.a.
        .byte $64,$03,$68,$52,$64,$13,$2B,$3B  ; d.hRd.+;
        .byte $68,$5B,$64,$3B,$1B,$1B,$1B,$1B  ; h[d;....
        .byte $2B,$2B,$2B,$2B,$2A,$2A,$3A,$4A  ; ++++**:J
        .byte $67,$52,$69,$52,$F9,$18,$FA,$74  ; gRiR...t
        .byte $60,$64,$2A,$68,$52,$F9,$94,$FA  ; `d*hR...
        .byte $01,$04,$7F,$40,$6C,$2B,$64,$13  ; ...@l+d.
        .byte $6C,$52,$64,$13,$70,$2B,$3B,$EA  ; lRd.p+;.
        .byte $20,$8D,$4B,$EA,$10,$73,$4B,$E8  ;  .K..sK.
        .byte $03,$23,$7F,$08,$70,$52,$53,$3A  ; .#..pRS:
        .byte $3B,$EE,$FF,$8D,$32,$EE,$13,$73  ; ;...2..s
        .byte $32,$E8,$02,$04,$7F,$40,$6C,$60  ; 2....@l`
        .byte $64,$52,$6C,$2A,$64,$52,$70,$13  ; dRl*dRp.
        .byte $13,$EA,$20,$8D,$13,$EA,$10,$73  ; .. ....s
        .byte $13,$E8,$01,$07,$7F,$40,$EF,$6C  ; .....@.l
        .byte $2B,$66,$2B,$2B,$68,$2B,$13,$2B  ; +f++h+.+
        .byte $78,$3B,$72,$43,$66,$43,$EA,$0F  ; x;rCfC..
        .byte $CC,$4B,$EA,$05,$7E,$42,$6A,$1A  ; .K..~Bj.
        .byte $03,$7E,$1B,$2B,$74,$03,$6A,$52  ; .~.+t.jR
        .byte $74,$42,$2A,$42,$F3,$02,$51,$6A  ; tB*B..Qj
        .byte $42,$2A,$03,$BA,$52,$F0,$02,$1A  ; B*..R...
        .byte $74,$60,$6A,$2A,$42,$42,$2A,$42  ; t`j*BB*B
        .byte $52,$03,$74,$1B,$2B,$7E,$03,$74  ; R.t.+~.t
        .byte $52,$52,$6A,$1B,$7E,$03,$88,$42  ; RRj.~..B
        .byte $92,$43,$E8,$6A,$2A,$74,$42,$BA  ; .C.j*tB.
        .byte $1A,$74,$60,$6A,$2A,$42,$42,$2A  ; .t`j*BB*
        .byte $42,$52,$F3,$02,$75,$6A,$3A,$74  ; BR..uj:t
        .byte $1A,$92,$2A,$74,$2A,$74,$42,$6A  ; ..*t*tBj
        .byte $42,$2A,$42,$BA,$1A,$F9,$57,$6A  ; B*B...Wj
        .byte $03,$74,$52,$92,$42,$74,$52,$52  ; .tR.BtRR
        .byte $6A,$52,$74,$03,$EA,$3F,$BA,$1B  ; jRt..?..
        .byte $EA,$05,$7E,$2B,$6A,$03,$1B,$7E  ; ..~+j..~
        .byte $2B,$1B,$74,$03,$6A,$52,$74,$42  ; +.t.jRtB
        .byte $2A,$42,$6A,$42,$2A,$03,$BA,$52  ; *BjB*..R
        .byte $F9,$1A,$02,$07,$7F,$40,$6C,$13  ; .....@l.
        .byte $66,$13,$13,$68,$13,$52,$13,$78  ; f..h.R.x
        .byte $13,$72,$1B,$66,$1B,$EA,$0F,$CC  ; .r.f....
        .byte $23,$E9,$80,$EA,$03,$7E,$41,$02  ; #....~A.
        .byte $74,$1A,$7E,$29,$41,$74,$02,$7E  ; t.~)At.~
        .byte $51,$0A,$74,$2A,$7E,$1A,$51,$74  ; Q.t*~.Qt
        .byte $19,$F1,$02,$1B,$7E,$09,$6A,$09  ; ....~.j.
        .byte $29,$7E,$41,$6A,$39,$02,$01,$74  ; )~Aj9..t
        .byte $29,$6A,$41,$74,$02,$F7,$03,$65  ; )jAt...e
        .byte $F4,$02,$55,$7E,$51,$0A,$74,$2A  ; ..U~Q.t*
        .byte $7E,$1A,$51,$74,$19,$F9,$32,$7E  ; ~.Qt..2~
        .byte $51,$12,$74,$2A,$6A,$1A,$1A,$0A  ; Q.t*j...
        .byte $0A,$02,$02,$51,$51,$F9,$1B,$6A  ; ...QQ..j
        .byte $51,$12,$74,$2A,$6A,$1A,$51,$74  ; Q.t*j.Qt
        .byte $19,$88,$41,$92,$42,$E8,$03,$15  ; ..A.B...
        .byte $7F,$08,$6C,$53,$66,$53,$53,$68  ; ..lSfSSh
        .byte $53,$2B,$53,$EE,$8F,$78,$53,$EE  ; S+S..xS.
        .byte $15,$72,$04,$66,$04,$EE,$8F,$9C  ; .r.f....
        .byte $14,$EE,$05,$90,$14,$EE,$10,$6A  ; .......j
        .byte $43,$65,$43,$04,$6A,$1C,$04,$44  ; CeC.j..D
        .byte $1C,$04,$43,$2B,$65,$2B,$43,$6A  ; ..C+e+Cj
        .byte $04,$43,$2C,$04,$43,$2B,$2B,$65  ; .C,.C++e
        .byte $2B,$43,$6A,$0C,$43,$2C,$0C,$43  ; +Cj.C,.C
        .byte $2B,$1B,$65,$1B,$3B,$6A,$53,$3B  ; +.e.;jS;
        .byte $1C,$53,$3B,$1B,$F2,$02,$21,$6A  ; .S;...!j
        .byte $2B,$65,$2B,$43,$6A,$0C,$43,$2C  ; +e+Cj.C,
        .byte $0C,$43,$2B,$1B,$2B,$3B,$74,$43  ; .C+.+;tC
        .byte $6A,$53,$74,$04,$F8,$03,$9E,$F5  ; jSt.....
        .byte $02,$85,$6A,$2B,$65,$2B,$43,$6A  ; ..j+e+Cj
        .byte $0C,$43,$2C,$0C,$43,$2B,$1B,$65  ; .C,.C+.e
        .byte $1B,$3B,$6A,$53,$3B,$1C,$53,$3B  ; .;jS;.S;
        .byte $1B,$F9,$51,$6A,$2B,$65,$2B,$53  ; ..Qj+e+S
        .byte $6A,$14,$53,$2C,$14,$53,$2B,$1B  ; j.S,.S+.
        .byte $65,$1B,$3B,$6A,$53,$3B,$1C,$53  ; e.;jS;.S
        .byte $3B,$1B,$F9,$21,$6A,$2B,$65,$2B  ; ;..!j+e+
        .byte $43,$6A,$0C,$43,$1B,$65,$1B,$3B  ; Cj.C.e.;
        .byte $6A,$53,$3B,$88,$43,$04,$E8,$01  ; jS;.C...
        .byte $05,$7F,$40,$6C,$52,$64,$2B,$6C  ; ..@lRd+l
        .byte $13,$64,$52,$6C,$2B,$64,$13,$6C  ; .dRl+d.l
        .byte $52,$64,$3A,$EA,$20,$80,$32,$EA  ; Rd:. .2.
        .byte $05,$70,$2A,$60,$E8,$03,$2A,$7F  ; .p*`..*.
        .byte $08,$70,$2C,$14,$53,$3B,$80,$1B  ; .p,.S;..
        .byte $70,$03,$60,$E8,$02,$86,$7F,$40  ; p.`....@
        .byte $70,$50,$51,$50,$51,$EA,$07,$80  ; pPQPQ...
        .byte $59,$49,$E8,$02,$FF,$7F,$40,$61  ; YI....@a
        .byte $52,$5A,$03,$0B,$EA,$02,$6A,$13  ; RZ....j.
        .byte $E8,$02,$DF,$7F,$38,$62,$53,$04  ; ....8bS.
        .byte $14,$2C,$3C,$53,$3C,$2C,$14,$04  ; .,<S<,..
        .byte $F7,$04,$24,$F4,$03,$20,$F1,$02  ; ..$.. ..
        .byte $1C,$E9,$40,$F9,$04,$E9,$80,$F9  ; ..@.....
        .byte $04,$E9,$00,$F9,$04,$E8,$02,$CB  ; ........
        .byte $7F,$48,$61,$04,$5B,$53,$4B,$43  ; .Ha.[SKC
        .byte $3B,$33,$2B,$04,$5B,$53,$4B,$43  ; ;3+.[SKC
        .byte $3B,$33,$2B,$E8,$02,$89,$7F,$40  ; ;3+....@
        .byte $72,$13,$E8,$02,$7F,$7F,$38,$62  ; r.....8b
        .byte $1C,$14,$0C,$04,$5B,$53,$4B,$43  ; ....[SKC
        .byte $3B,$33,$2B,$EA,$0F,$23,$E8,$01  ; ;3+..#..
        .byte $8F,$7F,$68,$63,$0C,$04,$E8,$01  ; ..hc....
        .byte $07,$7F,$40,$6E,$2B,$67,$23,$6E  ; ..@n+g#n
        .byte $1B,$67,$13,$8A,$0B,$6E,$03,$67  ; .g...n.g
        .byte $52,$6E,$4A,$67,$3A,$8A,$2A,$6E  ; RnJg:.*n
        .byte $1A,$67,$22,$6E,$2A,$67,$32,$8A  ; .g"n*g2.
        .byte $3A,$6E,$2A,$67,$32,$6E,$3A,$67  ; :n*g2n:g
        .byte $42,$8A,$4A,$6E,$13,$67,$0B,$6E  ; B.Jn.g.n
        .byte $03,$67,$5A,$8A,$52,$E8,$02,$07  ; .gZ.R...
        .byte $7F,$40,$75,$13,$6E,$03,$67,$52  ; .@u.n.gR
        .byte $75,$4A,$2A,$3A,$2A,$8A,$13,$6E  ; uJ*:*..n
        .byte $03,$67,$13,$6E,$1B,$67,$13,$75  ; .g.n.g.u
        .byte $03,$3A,$6E,$03,$67,$13,$6E,$1B  ; .:n.g.n.
        .byte $67,$23,$8A,$2B,$6E,$52,$67,$2B  ; g#.+nRg+
        .byte $6E,$23,$67,$1B,$8A,$13,$E8,$03  ; n#g.....
        .byte $5D,$7F,$08,$75,$52,$6E,$53,$67  ; ]..uRnSg
        .byte $2B,$75,$2A,$2B,$52,$6E,$53,$67  ; +u*+RnSg
        .byte $2B,$75,$52,$53,$1A,$6E,$1B,$67  ; +uRS.n.g
        .byte $52,$75,$1A,$1B,$2A,$6E,$2B,$67  ; Ru..*n+g
        .byte $03,$75,$2A,$2B,$6E,$52,$67,$2B  ; .u*+nRg+
        .byte $6E,$53,$67,$2B,$8A,$52,$E8,$01  ; nSg+.R..
        .byte $03,$7F,$40,$6C,$52,$64,$03,$6C  ; ..@lRd.l
        .byte $13,$64,$52,$70,$3A,$2A,$6C,$2A  ; .dRp:*l*
        .byte $64,$3A,$70,$4A,$80,$52,$E8,$02  ; d:pJ.R..
        .byte $C4,$7F,$40,$6C,$52,$64,$03,$6C  ; ..@lRd.l
        .byte $13,$64,$52,$70,$3A,$2A,$60,$29  ; .dRp:*`)
        .byte $80,$51,$E8,$01,$87,$7F,$40,$68  ; .Q....@h
        .byte $3B,$64,$23,$2B,$72,$3B,$E8,$01  ; ;d#+r;..
        .byte $05,$7F,$40,$EF,$6C,$0B,$63,$03  ; ..@.l.c.
        .byte $69,$52,$63,$1A,$69,$32,$63,$3A  ; iRc.i2c:
        .byte $69,$1A,$63,$0A,$F6,$03,$35,$F3  ; i.c...5.
        .byte $02,$35,$F0,$02,$27,$6C,$1A,$69  ; .5..'l.i
        .byte $0A,$63,$1A,$78,$60,$E8,$69,$1A  ; .c.x`.i.
        .byte $63,$0A,$69,$1A,$63,$32,$69,$60  ; c.i.c2i`
        .byte $6C,$3A,$F9,$05,$69,$1A,$63,$0A  ; l:..i.c.
        .byte $69,$1A,$63,$0A,$69,$60,$6C,$1A  ; i.c.i`l.
        .byte $F3,$02,$62,$6C,$33,$63,$2B,$69  ; ..bl3c+i
        .byte $1B,$63,$42,$69,$5A,$63,$03,$69  ; .cBiZc.i
        .byte $42,$63,$32,$69,$42,$63,$32,$69  ; Bc2iBc2i
        .byte $42,$63,$5A,$69,$60,$6C,$03,$F9  ; BcZi`l..
        .byte $05,$6C,$43,$63,$3B,$69,$2B,$63  ; .lCc;i+c
        .byte $1B,$69,$2B,$6C,$3B,$33,$63,$2B  ; .i+l;3c+
        .byte $69,$1B,$63,$0B,$69,$1B,$6C,$2B  ; i.c.i.l+
        .byte $F9,$05,$02,$90,$7F,$40,$EF,$63  ; .....@.c
        .byte $60,$EA,$03,$6C,$18,$19,$09,$01  ; `..l....
        .byte $69,$50,$63,$50,$F7,$03,$21,$F4  ; iPcP..!.
        .byte $02,$21,$F1,$02,$1B,$6C,$40,$38  ; .!...l@8
        .byte $28,$F9,$09,$6C,$30,$28,$18,$F4  ; (..l0(..
        .byte $02,$36,$40,$41,$31,$29,$69,$19  ; .6@A1)i.
        .byte $63,$19,$6C,$09,$01,$50,$F9,$09  ; c.l..P..
        .byte $6C,$50,$69,$51,$6C,$41,$63,$41  ; lPiQlAcA
        .byte $6C,$39,$40,$69,$41,$6C,$31,$63  ; l9@iAl1c
        .byte $31,$6C,$29,$18,$19,$09,$01,$69  ; 1l)....i
        .byte $50,$63,$30,$69,$28,$6F,$18,$6C  ; Pc0i(o.l
        .byte $60,$E8                          ; `.

; reachable via computed jump entry
dyn_FF65:
FF65  A9 00     LDA #$00                     
FF67  85 7A     STA $7A                      
FF69  85 7D     STA $7D                      
FF6B  A9 01     LDA #$01                     
FF6D  85 77     STA $77                      
FF6F  20 A7 CA  JSR LCAA7                    
FF72  20 41 C2  JSR ppu_rendering_off        
FF75  20 49 CD  JSR LCD49                    
FF78  20 5B E3  JSR LE35B                    
FF7B  20 C5 E5  JSR LE5C5                    
FF7E  20 62 E8  JSR LE862                    
FF81  20 01 F0  JSR LF001                    
FF84  20 39 C2  JSR clear_update_queue       
FF87  A2 00     LDX #$00                     
FF89  BD 00 02  LDA $0200,X                  
FF8C  9D 00 03  STA $0300,X                  
FF8F  E8        INX                          
FF90  D0 F7     BNE LFF89                    
FF92  20 C1 F3  JSR LF3C1                    
FF95  20 F1 D7  JSR LD7F1                    
FF98  20 46 D8  JSR LD846                    
FF9B  A9 00     LDA #$00                     
FF9D  85 4B     STA $4B                      
FF9F  85 4F     STA $4F                      
FFA1  85 31     STA $31                      
FFA3  85 3C     STA $3C                      
FFA5  85 3D     STA $3D                      
FFA7  A9 02     LDA #$02                     
FFA9  8D 0F 04  STA $040F                    
FFAC  A2 20     LDX #$20                     
FFAE  A9 02     LDA #$02                     
FFB0  9D 0F 04  STA $040F,X                  
FFB3  8A        TXA                          
FFB4  18        CLC                          
FFB5  69 10     ADC #$10                     
FFB7  AA        TAX                          
FFB8  E4 68     CPX $68                      
FFBA  D0 F2     BNE LFFAE                    
FFBC  20 41 C1  JSR stack_frame_swap         
FFBF  20 60 CB  JSR LCB60                    
FFC2  20 E6 F2  JSR LF2E6                    
FFC5  A5 4F     LDA $4F                      
FFC7  05 4B     ORA $4B                      
FFC9  D0 10     BNE LFFDB                    
FFCB  A5 24     LDA $24                      
FFCD  29 03     AND #$03                     
FFCF  C9 01     CMP #$01                     
FFD1  F0 08     BEQ LFFDB                    
FFD3  A5 25     LDA $25                      
FFD5  29 03     AND #$03                     
FFD7  C9 01     CMP #$01                     
FFD9  D0 E1     BNE LFFBC                    
FFDB  20 41 C1  JSR stack_frame_swap         
FFDE  4C 4F C8  JMP title_screen_loop        
        .byte $85,$11,$C8,$40,$D5,$21,$C4,$85  ; ...@.!..
        .byte $15,$84,$40,$C5,$09,$E5,$0D,$B2  ; ..@.....
        .byte $CE,$E1,$11,$C8,$40,$D9,$99,$FF  ; ....@...
        .byte $FF,$EF,$C2,$31,$C0,$04,$C3      ; ...1...
