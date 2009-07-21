#include "service.h"

void SendQuitMsg(void)
{
	WORD version;
	WSADATA wsaData;
	SOCKET server;
	struct sockaddr_in dst;
	int err;

	version = MAKEWORD( 1, 1 );
	err = WSAStartup(version, &wsaData);
	if (err != 0) return;

	server = socket(AF_INET ,SOCK_DGRAM, IPPROTO_UDP);
	if (server == INVALID_SOCKET) return;

	dst.sin_family = AF_INET;
	dst.sin_addr.s_addr = inet_addr("127.0.0.1");
	dst.sin_port = htons(10000);

	sendto(server, "Q", 1, 0, (SOCKADDR *)&dst, sizeof(dst));

	closesocket(server);
	WSACleanup();
}

BOOL APIENTRY DllMain(HANDLE hModule, DWORD  reason, LPVOID lpReserved)
{
    return TRUE;
}

void WINAPI ServiceCtrlHandler(DWORD Opcode) 
{ 
	if (Opcode == SERVICE_CONTROL_STOP) {
        SvcStatus.dwWin32ExitCode = 0; 
        SvcStatus.dwCurrentState  = SERVICE_STOPPED; 
        SvcStatus.dwCheckPoint    = 0; 
        SvcStatus.dwWaitHint      = 0; 
	}
	SetServiceStatus(SvcStatusHandle,  &SvcStatus);
	return; 
}

void WINAPI ServiceStart(DWORD argc, LPTSTR *argv) 
{  
    SvcStatus.dwServiceType        = SERVICE_WIN32; 
    SvcStatus.dwCurrentState       = SERVICE_RUNNING; 
    SvcStatus.dwControlsAccepted   = SERVICE_ACCEPT_STOP; 
    SvcStatus.dwWin32ExitCode      = 0; 
    SvcStatus.dwServiceSpecificExitCode = 0; 
    SvcStatus.dwCheckPoint         = 0; 
    SvcStatus.dwWaitHint           = 0; 
 
    SvcStatusHandle = RegisterServiceCtrlHandler(APPNAME, ServiceCtrlHandler);
	SetServiceStatus(SvcStatusHandle, &SvcStatus); 
    return; 
} 

void ServiceInit(void)
{
	StartServiceCtrlDispatcher(DispatchTable);	// blocking call
	SendQuitMsg();
}


__declspec(dllexport) void ServiceLaunch(void)
{
	_beginthread((void *)ServiceInit, 0, NULL);
}
