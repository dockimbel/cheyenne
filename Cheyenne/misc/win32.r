REBOL []

app-name: "Cheyenne"

kernel32: load/library %kernel32.dll
advapi32: load/library %advapi32.dll
shell32:  load/library %shell32.dll

int: :to-integer

; === General API ===

FORMAT_MESSAGE_FROM_SYSTEM:	   int #{00001000}
FORMAT_MESSAGE_IGNORE_INSERTS: int #{00000200}
ERROR_ACCESS_DENIED: 			5
CSIDL_DESKTOPDIRECTORY:			int #{00000010}
CSIDL_COMMON_APPDATA:			int #{00000023}
SHGFP_TYPE_CURRENT:				0
fmt-msg-flags: 
	FORMAT_MESSAGE_FROM_SYSTEM
	or FORMAT_MESSAGE_IGNORE_INSERTS

HRESULT: reduce [
	int #{8000FFFF}	"Unexpected failure"
	int #{80004001}	"Not implemented"
	int #{8007000E}	"Failed to allocate necessary memory"
	int #{80070057}	"One or more arguments are invalid"
	int #{80004002}	"No such interface supported"
	int #{80004003}	"Invalid pointer"
	int #{80070006}	"Invalid handle"
	int #{80004004}	"Operation aborted"
	int #{80004005}	"Unspecified failure"
	int #{80070005}	"General access denied error"
]

CloseHandle: make routine! [
	hObject	[integer!]
	return: [integer!]
] kernel32 "CloseHandle"

GetLastError: make routine! [
	return: [integer!]
] kernel32 "GetLastError"

FormatMessage: make routine! [
	dwFlags		 [integer!]
	lpSource	 [integer!]
	dwMessageId  [integer!]
	dwLanguageId [integer!]
	lpBuffer	 [string!]
	nSize		 [integer!]
	Arguments	 [integer!]
	return:		 [integer!]
] kernel32 "FormatMessageA"

_setenv: make routine! [
	name	[string!]
	value	[string!]
	return: [integer!]
] kernel32 "SetEnvironmentVariableA"

_getenv: make routine! [
	lpName	 [string!]
	lpBuffer [string!]
	nSize	 [integer!]
	return:	 [integer!]
] kernel32 "GetEnvironmentVariableA"

GetCurrentDirectory: make routine! [
	nBufferLength 	[integer!]
	lpBuffer		[string!]
	return: 		[integer!]
] kernel32 "GetCurrentDirectoryA"

SetCurrentDirectory: make routine! [
	lpPathName	[string!]
	return: 	[integer!]
] kernel32 "SetCurrentDirectoryA"

SHGetFolderPath: make routine! [
	hwndOwner 	[integer!]
	nFolder		[integer!]
	hToken		[integer!]
	dwFlags		[integer!]
	pszPath		[string!]
	return: 	[integer!]
] shell32 "SHGetFolderPathA"

; === Service API ===

SC_MANAGER_ALL_ACCESS:		 int #{000F003F}
SERVICE_ALL_ACCESS:			 int #{000F01FF}
SERVICE_WIN32_OWN_PROCESS:	 int #{00000010}
SERVICE_ERROR_NORMAL:		 int #{00000001}
SERVICE_AUTO_START: 		 int #{00000002}
SERVICE_DEMAND_START:		 int #{00000003}
DELETE:						 int #{00010000}
SERVICE_CONTROL_STOP:		 int #{00000001}
SERVICE_CONTROL_INTERROGATE: int #{00000004}
SERVICE_RUNNING:			 int #{00000004}
SERVICE_START_PENDING:		 int #{00000002}
SERVICE_CONTINUE_PENDING:	 int #{00000005}
SERVICE_ANY_RUNNING: reduce [
	SERVICE_RUNNING 
	SERVICE_START_PENDING
	SERVICE_CONTINUE_PENDING
]
ERROR_SERVICE_DOES_NOT_EXIST: 1060


SERVICE_STATUS: make struct! struct-service-status: [
	dwServiceType			  [integer!]
	dwCurrentState			  [integer!]
	dwControlsAccepted 		  [integer!]
	dwWin32ExitCode			  [integer!]
	dwServiceSpecificExitCode [integer!]
	dwCheckPoint			  [integer!]
	dwWaitHint				  [integer!]
] none

OpenSCManager: make routine! [
	lpMachineName	[integer!]
	lpDatabaseName	[integer!]
	dwDesiredAccess	[integer!]
	return:   		[integer!]
] advapi32 "OpenSCManagerA"

CreateService: make routine! [
	hSCManager   		[integer!]
	lpServiceName		[string!]
	lpDisplayName   	[string!]
	dwDesiredAccess		[integer!]
  	dwServiceType		[integer!]
	dwStartType			[integer!]
 	dwErrorControl		[integer!]
  	lpBinaryPathName 	[string!]
	lpLoadOrderGroup 	[integer!]
	lpdwTagId			[integer!]
	lpDependencies		[integer!]
	lpServiceStartName	[integer!]
	lpPassword			[integer!]
	return:   			[integer!]
] advapi32 "CreateServiceA"

DeleteService: make routine! [
	hService	[integer!]
	return:		[integer!]
] advapi32 "DeleteService"

OpenService: make routine! [
	hSCManager 		[integer!]
	lpServiceName 	[string!]
	dwDesiredAccess [integer!]
	return:  		[integer!]
] advapi32 "OpenServiceA"

CloseServiceHandle: make routine! [
	hSCObject	[integer!]
	return:		[integer!]
] advapi32 "CloseServiceHandle"

ControlService: make routine! compose/deep [
	hService	[integer!]
	dwControl	[integer!]
	lpServiceStatus [struct! [(struct-service-status)]]
	return: 	[integer!]
] advapi32 "ControlService"

StartService: make routine! [
	hService 			[integer!]
	dwNumServiceArgs	[integer!]
	lpServiceArgVectors [integer!]
	return: 			[integer!]
] advapi32 "StartServiceA"

QueryServiceStatus: make routine! compose/deep [
	hService		[integer!]
	lpServiceStatus [struct! [(struct-service-status)]]
	return: 		[integer!]
] advapi32 "QueryServiceStatus"


; === Process API ===

STARTF_USESTDHANDLES: 	int #{00000100}
STARTF_USESHOWWINDOW: 	1
SW_HIDE: 				0

SECURITY_ATTRIBUTES: make struct! [
	nLength 			 [integer!]
	lpSecurityDescriptor [integer!]
	bInheritHandle 		 [integer!]
] none

STARTUPINFO: make struct! startup-info-struct: [
	cb 				[integer!]
	lpReserved 		[integer!]
	lpDesktop		[integer!]
	lpTitle			[integer!]
	dwX				[integer!]
	dwY				[integer!]
	dwXSize			[integer!]
	dwYSize			[integer!]
	dwXCountChars 	[integer!]
	dwYCountChars 	[integer!]
	dwFillAttribute	[integer!]
	dwFlags			[integer!]
	wShowWindow		[short]
	cbReserved2		[short]
	lpReserved2		[integer!]
	hStdInput		[integer!]
	hStdOutput		[integer!]
	hStdError		[integer!]
] none

PROCESS_INFORMATION: make struct! process-info-struct: [
	hProcess	[integer!]
	hThread 	[integer!]
	dwProcessID	[integer!]
	dwThreadID	[integer!]
] none

CreateProcess: make routine! compose/deep [
	lpApplicationName	 [integer!]
	lpCommandLine		 [string!]	
	lpProcessAttributes	 [integer!]
	lpThreadAttributes	 [integer!]
	bInheritHandles		 [char!]
	dwCreationFlags		 [integer!]
	lpEnvironment		 [integer!]
	lpCurrentDirectory	 [integer!]
	lpStartupInfo		 [struct! [(startup-info-struct)]]
	lpProcessInformation [struct! [(process-info-struct)]]
	return:				 [integer!]
] kernel32 "CreateProcessA"

TerminateProcess: make routine! [
	hProcess  [integer!]
	uExitCode [integer!]
	return:   [integer!]
] kernel32 "TerminateProcess"

GetCurrentProcessId: make routine! [
	return:   [integer!]
] kernel32 "GetCurrentProcessId"

; === helper functions ===

null: to-char 0
last-error: none

make-null-string!: func [len [integer!]][
	head insert/dup make string! len null len
]

start-info: make struct! STARTUPINFO none
start-info/cb: length? third start-info
start-info/dwFlags: STARTF_USESHOWWINDOW
start-info/wShowWindow: SW_HIDE

get-error-msg: has [out][
	out: make-null-string! 256
	FormatMessage fmt-msg-flags 0 last-error: GetLastError 0 out 256 0
	trim/tail out
]

try*: func [body [block!] /quiet /local res][
	if all [zero? res: do body not quiet][
		log/error reform [
			mold first body "failed :" get-error-msg
		]
	]
	res
]

try**: func [body [block!] /local res][
	unless zero? res: do body [
		log/error reform [
			mold first body "failed :" select HRESULT res
		]
	]
	res
]

with-SCM: func [body2 [block!] /local scm res][
	scm: try* [OpenSCManager 0 0 SC_MANAGER_ALL_ACCESS]
	if zero? scm [return last-error]
	res: do bind body2 'scm
	try* [CloseServiceHandle scm]
	res
]

with-service: func [body [block!] /quiet /local srv res cmd][
	bind body 'srv
	with-SCM [
		cmd: [OpenService scm app-name DELETE or SERVICE_ALL_ACCESS]
		srv: either quiet [try*/quiet cmd][try* cmd]
		unless zero? srv [
			res: do body
			try* [CloseServiceHandle srv]
		]
		res
	]
]

; === Cheyenne's internal API ===

set 'OS-change-dir func [dir][
	dir: to-local-file dir
	try* [SetCurrentDirectory dir: join dir null]
]

set 'OS-get-dir func [dir [word!] /local type path][
	type: get select [
		desktop		CSIDL_DESKTOPDIRECTORY
		all-users	CSIDL_COMMON_APPDATA
	] dir
	path: make-null-string! 255
	try** [SHGetFolderPath 0 type 0 SHGFP_TYPE_CURRENT path]
	dirize to-rebol-file trim path
]

set 'launch-app func [cmd [string!] /local si pi ret][
	si: make struct! start-info second start-info
	pi: make struct! PROCESS_INFORMATION none
	cmd: join cmd null
	ret: CreateProcess 0 cmd 0 0 #"^(00)" 0 0 0 si pi
	ret: either zero? ret [
		reduce ['ERROR get-error-msg]
	][
		reduce ['OK pi/hProcess]	
	]
	CloseHandle pi/hThread
	ret
]
set 'kill-app func [pid][
	TerminateProcess pid 0
	CloseHandle pid
]
set 'set-env func [name [string!] value [string!]][
	_setenv name value
]

set 'process-id? does [GetCurrentProcessId]

set 'launch-service has [file][
	file: join cheyenne/data-dir %service.dll
	unless exists? file [
		write/binary file read-cache %misc/service.dll
	]
	do make routine! [] load/library file "ServiceLaunch"
]

set 'install-NT-service has [srv][
	ERROR_ACCESS_DENIED <> with-SCM [
		unless zero? srv: try* [
			CreateService
				scm
				app-name
				"Cheyenne Web Server"
				SERVICE_ALL_ACCESS
				SERVICE_WIN32_OWN_PROCESS
				SERVICE_AUTO_START
				SERVICE_ERROR_NORMAL
				join to-local-file system/options/boot join " -s" cheyenne/sub-args
				0 0 0 0 0
		][
			try* [CloseServiceHandle srv]
		]
	]
]

set 'uninstall-NT-service does [
	with-service [try* [DeleteService srv]]	
]

set 'NT-service? does [
	true = with-service/quiet [
		if zero? srv [
			if ERROR_SERVICE_DOES_NOT_EXIST <> GetLastError [
				log/error ["Opening service failed : " get-error-msg]
			]
		]
		not zero? srv
	]
]

set 'control-service func [/start /stop /local ss][
	with-service [
		if start [
			try* [StartService srv 0 0]
		]
		if stop [
			ss: make struct! SERVICE_STATUS none
			try* [ControlService srv SERVICE_CONTROL_STOP ss]
		]
	]
]

set 'NT-service-running? has [ss][
	ss: make struct! SERVICE_STATUS none
	with-service [try* [QueryServiceStatus srv ss]]
	to logic! find SERVICE_ANY_RUNNING ss/dwCurrentState
]

set [setuid setgid] none