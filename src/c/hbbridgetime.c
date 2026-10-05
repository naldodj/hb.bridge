/* Released to Public Domain. */
/* A deadline must never depend on the date/time configured by the operator. */
#if defined( _WIN32 ) && ( ! defined( _WIN32_WINNT ) || _WIN32_WINNT < 0x0600 )
    #undef _WIN32_WINNT
    #define _WIN32_WINNT 0x0600
#endif
#if ! defined( _WIN32 ) && ! defined( _POSIX_C_SOURCE )
    #define _POSIX_C_SOURCE 199309L
#endif

#include "hbapi.h"
#include "hbapierr.h"

#if defined( HB_OS_WIN )
    #include <windows.h>
#elif defined( HB_OS_UNIX )
    #include <time.h>
#endif

HB_FUNC( HBBRIDGEMONOTONICMS )
{
    HB_MAXUINT milliseconds = 0;
    HB_BOOL valid = HB_FALSE;

#if defined( HB_OS_WIN )
    /* Native 64-bit counter: no shared state and no 32-bit wrap extension. */
    milliseconds = ( HB_MAXUINT ) GetTickCount64();
    valid = HB_TRUE;
#elif defined( HB_OS_UNIX ) && defined( CLOCK_MONOTONIC )
    {
        struct timespec value;

        if( clock_gettime( CLOCK_MONOTONIC, &value ) == 0 && value.tv_sec >= 0 &&
            ( HB_MAXUINT ) value.tv_sec <= ( HB_MAXUINT ) HB_VMLONG_MAX / 1000 )
        {
            milliseconds = ( HB_MAXUINT ) value.tv_sec * 1000 + value.tv_nsec / 1000000;
            valid = HB_TRUE;
        }
    }
#endif
    if( valid && milliseconds <= ( HB_MAXUINT ) HB_VMLONG_MAX )
        hb_retnint( ( HB_MAXINT ) milliseconds );
    else
        /* Do not silently fall back to civil time when monotonic time fails. */
        hb_errRT_BASE( EG_UNSUPPORTED, 3012, "Monotonic clock unavailable",
            HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}
