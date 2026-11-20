/* Released to Public Domain. Test-only terminal-mode snapshot. */
#include "hbapi.h"
#if defined( HB_OS_WIN )
    #include <windows.h>
#elif defined( HB_OS_UNIX )
    #include <termios.h>
    #include <unistd.h>
#endif

HB_FUNC( HBBRIDGETERMINALTESTMODE )
{
#if defined( HB_OS_WIN )
    DWORD mode;
    if( GetConsoleMode( GetStdHandle( STD_INPUT_HANDLE ), &mode ) )
        hb_retnint( mode );
    else
        hb_ret();
#elif defined( HB_OS_UNIX )
    struct termios mode;
    if( tcgetattr( STDIN_FILENO, &mode ) == 0 )
        hb_retnint( mode.c_lflag );
    else
        hb_ret();
#else
    hb_ret();
#endif
}
