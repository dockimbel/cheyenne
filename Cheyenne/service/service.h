#pragma once


#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <process.h>
#include <Winsock2.h>

#define APPNAME	"Cheyenne"

SERVICE_STATUS          SvcStatus; 
SERVICE_STATUS_HANDLE   SvcStatusHandle;
 
void WINAPI ServiceStart(DWORD argc, LPTSTR *argv); 
void WINAPI ServiceCtrlHandler(DWORD opcode); 

SERVICE_TABLE_ENTRY DispatchTable[] = 
{ 
    {APPNAME, ServiceStart}, 
    {NULL, NULL}
}; 

