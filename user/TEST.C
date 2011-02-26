/*
*********************************************************************************************************
*                                                uC/OS-II
*                                          The Real-Time Kernel
*
*                           (c) Copyright 1992-2002, Jean J. Labrosse, Weston, FL
*                                           All Rights Reserved
*
*                                               EXAMPLE #1
*********************************************************************************************************
*/

#include "../source/includes.h"

/*
*********************************************************************************************************
*                                               CONSTANTS
*********************************************************************************************************
*/

/*
*********************************************************************************************************
*                                               VARIABLES
*********************************************************************************************************
*/

OS_STK   xdata     TaskStk[TASK_STK_SIZE];        /* Tasks stacks                                  */
OS_STK xdata TaskLedStk[TASK_STK_SIZE]; 

/*
*********************************************************************************************************
*                                           FUNCTION PROTOTYPES
*********************************************************************************************************
*/

        void  Task(void *data1) RUNSISI_LARGE_REENTRANT;                       /* Function prototypes of tasks                  */
		void TaskLed(void* data1) RUNSISI_LARGE_REENTRANT;
		void InitTimer0();
		int ReentrantTest(int* a, int* b, long c)RUNSISI_LARGE_REENTRANT;

/*$PAGE*/
/*
*********************************************************************************************************
*                                                MAIN
*********************************************************************************************************
*/

void  main (void)
{
    OSInit();                                              /* Initialize uC/OS-II                      */
	InitTimer0();
    OSTaskCreate(Task, 2, &TaskStk[0], 2);
	OSTaskCreate(TaskLed, 1, &TaskLedStk[0], 5);
    OSStart();                                             /* Start multitasking                       */
}


/*
*********************************************************************************************************
*                                              STARTUP TASK
*********************************************************************************************************
*/
void  Task (void *pdata1) RUNSISI_LARGE_REENTRANT
{
#if OS_CRITICAL_METHOD == 3                                /* Allocate storage for CPU status register */
    OS_CPU_SR  cpu_sr;
#endif
	void* param;
	int a = 1;
	int b = 2;
	long c = 3;
	pdata1 = pdata1;
	param = pdata1;
	TR0 = 1;	//Start timer0, it is the heart of the OS.
	//EA = 1;	//EA already been set by OS_EXIT_CRITICAL() when OS_TaskIdle is created!
	for (;;)
	{
		ReentrantTest(&a, &b, c);
		P1 = 0xf0;
		OSTimeDlyHMSM(0, 0, 1, 0);
		P1 = 0x0f;
		OSTimeDlyHMSM(0, 0, 1, 0);	
	}
}

void TaskLed(void* data1) RUNSISI_LARGE_REENTRANT
{
	int a = 1;
	int b = 2;
	long c = 3;
	data1 = data1;
	for (;;)
	{
		ReentrantTest(&a, &b, c);
		P0 = 0x06;
		P2 = 0x00;
		P2 |= 0x07;
		OSTimeDlyHMSM(0, 0, 1, 0);
		P0 &= 0x00;
		OSTimeDlyHMSM(0, 0, 1, 0);
	}
}

int ReentrantTest(int* a, int* b, long c)RUNSISI_LARGE_REENTRANT
{
	int va = *a;
	int vb = *b;
	long lc = c;
	a = b;
	return a;	
}

void InitTimer0()
{
	TMOD &= 0xf0;
	TMOD |= 0x01;
	TH0 = 0xb1;
	TL0 = 0xe0;
	ET0 = 1;
}