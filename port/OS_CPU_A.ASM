;********************************************************************************************************
;                                               uC/OS-II
;                                         The Real-Time Kernel
;
;                          (c) Copyright 1992-2002, Jean J. Labrosse, Weston, FL
;                                          All Rights Reserved
;
;
;                                STC89C52RC(256RAM + 256 XRAM) Specific code
;                                          SMALL MEMORY MODEL
;
;                                           Keil uVision V4.02
;
; File         : OS_CPU_A.ASM
; By           : runsisi@163.com @HUST
; Note: 1. I use large memory mode in this version, so uC/OS-II's global variable will be in xdata area 
; by default, do not make stupid pointer mistakes when you are to modify this assembly file.
;		2. 51's SP(stack pointer) width is 1 byte, i use SP to push/pop on task stack directly, so task 
; stack is put in idata area, or SP can not operate on task stack, most other ports use another method: 
; copy stack content between task stack and hardware stack(in fact this is only a block of memory SP 
; pointed to), we do not use SP to operate on task stack directly, so task stack can be put in xdata area, 
; of course, you need to modify this file and other data structures to fit this need. 
;********************************************************************************************************

;********************************************************************************************************
;                                    PUBLIC and EXTERNAL REFERENCES
;********************************************************************************************************

$NOMOD51

//Begin of module OS_CPU_A.
NAME OS_CPU_A

?PR?OSStartHighRdy?OS_CPU_A SEGMENT CODE
?PR?OSCtxSw?OS_CPU_A SEGMENT CODE
?PR?OSIntCtxSw?OS_CPU_A SEGMENT CODE
?PR?OSTickISR?OS_CPU_A SEGMENT CODE

PUBLIC OSStartHighRdy
PUBLIC OSCtxSw
PUBLIC OSIntCtxSw
PUBLIC OSTickISR

EXTRN DATA(?C_XBP)
EXTRN DATA(OSTCBCur)
EXTRN DATA(OSTCBHighRdy)
EXTRN DATA(OSRunning)
EXTRN DATA(OSPrioCur)
EXTRN DATA(OSPrioHighRdy)
EXTRN IDATA(OSStkStart)

EXTRN CODE(OSTaskSwHook)
EXTRN CODE(OSIntEnter)
EXTRN CODE(OSIntExit)
EXTRN CODE(OSTimeTick)

EA	BIT	0A8H.7
TR0	BIT	088H.4
TH0	DATA 08CH
TL0	DATA 08AH

PUSHALL MACRO
	PUSH ACC
	PUSH B
	PUSH PSW
	PUSH DPH
	PUSH DPL
	IRP reg, <R7, R6, R5, R4, R3, R2, R1, R0>
		MOV A, reg
		PUSH ACC
	ENDM
	//Push reentrant stack pointer.
	PUSH ?C_XBP
	PUSH ?C_XBP + 1
ENDM

POPALL MACRO
	POP ?C_XBP + 1
	POP ?C_XBP
	IRP reg, <R0, R1, R2, R3, R4, R5, R6, R7>
		POP ACC
		MOV reg, A		
	ENDM
	POP DPL
	POP DPH
	POP PSW
	POP B
	POP ACC
ENDM

STORE_SP MACRO
LOCAL StoreHardwareStack
	//Get OSTCBCur.
	MOV R0, OSTCBCur + 2	//OSTCBCur is a generic pointer, point to idata area.
	//Get OSTCBCur->OSTCBStkPtr.
	INC R0
	MOV DPH, @R0
	INC R0
	MOV DPL, @R0
	//Get hardware stack length.
	MOV A, SP
	CLR C
	SUBB A, #OSStkStart
	INC A	//OSStkStart point to first byte of hardware stack.
	MOV R1, A
	//Get OSStkStart address.
	MOV R0, #OSStkStart
	//Store hardware stack length.
	MOV A, R1
	MOVX @DPTR, A
	INC DPTR
StoreHardwareStack:
	MOV A, @R0
	MOVX @DPTR, A
	INC DPTR
	INC R0
	DJNZ R1, StoreHardwareStack
	//Copy finished, set SP to #OSStkStart - 1.
	//MOV R0, #OSStkStart
	//DEC R0
	//MOV SP, R0
ENDM

RESTORE_SP MACRO
LOCAL RestoreHardwareStack
	//Get OSTCBHighRdy.
	MOV R0, OSTCBHighRdy + 2		//Generic pointer, you can change it to more specific pointer.
	//Get OSTCBHighRdy->OSTCBStkPtr.
	INC R0
	MOV DPH, @R0
	INC R0
	MOV DPL, @R0
	//Get content length in task stack.
	MOVX A, @DPTR
	MOV R1, A
	INC DPTR
	//Get OSStkStart address.
	MOV R0, #OSStkStart
	//Now DPTR point to task stack first byte, R0 point to hardware stack first byte.
	//Copy from task stack to hardware stack.
RestoreHardwareStack:
	MOVX A, @DPTR
	MOV @R0, A
	INC DPTR
	INC R0
	DJNZ R1, RestoreHardwareStack
	//Copy finished, restore SP.
	DEC R0
	MOV SP, R0
ENDM

//void OSStartHighRdy(void);
RSEG ?PR?OSStartHighRdy?OS_CPU_A
OSStartHighRdy:
	//Call void OSTaskSwHook(void);
	LCALL OSTaskSwHook
	//Set OSRunning to true.
	MOV OSRunning, #0x01
	RESTORE_SP
	//Restore registers.
	POPALL
	//Enable interrupt.
	SETB EA
	RETI
//End of void OSStartHighRdy(void);

//void OSCtxSw(void);
RSEG ?PR?OSCtxSw?OS_CPU_A
OSCtxSw:
	//Store all registers.
	PUSHALL
	STORE_SP
DoCtxSw:
	//Call void OSTaskSwHook(void);
	LCALL OSTaskSwHook
	//OSTCBCur = OSTCBHighRdy.
	MOV OSTCBCur + 1, OSTCBHighRdy + 1
	MOV OSTCBCur + 2, OSTCBHighRdy + 2
	//OSPrioCur = OSPrioHighRdy.
	MOV OSPrioCur, OSPrioHighRdy
	RESTORE_SP
	//Restore registers.
	POPALL
	SETB EA		//Note: this is very important, because before OS_TASK_SW()
				//interrupt is disabled by OS_ENTER_CRITICAL()!
	RETI
//End of void OSCtxSw(void);

//void OSIntCtxSw(void);
RSEG ?PR?OSIntCtxSw?OS_CPU_A
OSIntCtxSw:
	//In your ISR you have to store SP to OSTCBCur->OSTCBStkPtr after
	//store all cpu registers.
	LJMP DoCtxSw
//End of void OSIntCtxSw(void);

//void OSTickISR(void);
CSEG AT 000BH
LJMP OSTickISR
RSEG ?PR?OSTickISR?OS_CPU_A
OSTickISR:
	CLR EA
	PUSHALL
	STORE_SP
	LCALL OSIntEnter
	SETB EA
	
	CLR TR0
	MOV TH0, #0xB1
	MOV TL0, #0xE0
	SETB TR0
	
	LCALL OSTimeTick
	LCALL OSIntExit
	POPALL
	RETI
//End of void OSTickISR(void);

//End of module OS_CPU_A.
END