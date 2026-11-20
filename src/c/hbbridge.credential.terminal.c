/* Released to Public Domain. Local, interactive credential input. */
#if ! defined( _WIN32 ) && ! defined( _POSIX_C_SOURCE )
    #define _POSIX_C_SOURCE 200809L
#endif
#include "hbapi.h"
#include "hbapicdp.h"
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#if defined( HB_OS_WIN )
    #include <windows.h>
#elif defined( HB_OS_UNIX )
    #include <errno.h>
    #include <poll.h>
    #include <signal.h>
    #include <termios.h>
    #include <unistd.h>
#endif

#define HB_CREDENTIAL_TERMINAL_MAX 4096

static void HBBridgeTerminalWipe( void * buffer, size_t length )
{
    volatile unsigned char * bytes = ( volatile unsigned char * ) buffer;
    while( length-- > 0 ) *bytes++ = 0;
}

#if defined( HB_OS_WIN )
static volatile LONG s_terminalInterrupted = 0;

static BOOL WINAPI HBBridgeTerminalControl( DWORD event )
{
    if( event == CTRL_C_EVENT || event == CTRL_BREAK_EVENT )
    {
        InterlockedExchange( &s_terminalInterrupted, 1 );
        return TRUE;
    }
    return FALSE;
}

static int HBBridgeTerminalRead( char * output, size_t * length )
{
    HANDLE input = GetStdHandle( STD_INPUT_HANDLE );
    WCHAR wide[ HB_CREDENTIAL_TERMINAL_MAX + 2 ] = { 0 };
    DWORD original = 0, readCount = 0, index;
    int status = 2, utf8Length;
    BOOL modeChanged = FALSE, handlerInstalled = FALSE;

    if( input == INVALID_HANDLE_VALUE || input == NULL || ! GetConsoleMode( input, &original ) )
        return 1;
    InterlockedExchange( &s_terminalInterrupted, 0 );
    if( ! SetConsoleCtrlHandler( HBBridgeTerminalControl, TRUE ) ) goto cleanup;
    handlerInstalled = TRUE;
    if( ! SetConsoleMode( input, ( original | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT ) & ~ENABLE_ECHO_INPUT ) )
        goto cleanup;
    modeChanged = TRUE;
    if( fputs( "Password: ", stderr ) == EOF || fflush( stderr ) != 0 ) goto cleanup;
    if( ! ReadConsoleW( input, wide, HB_CREDENTIAL_TERMINAL_MAX + 2, &readCount, NULL ) ||
        InterlockedCompareExchange( &s_terminalInterrupted, 0, 0 ) != 0 )
    {
        if( InterlockedCompareExchange( &s_terminalInterrupted, 0, 0 ) != 0 ) status = 4;
        goto cleanup;
    }
    if( readCount == 0 || wide[ readCount - 1 ] != L'\n' )
    {
        status = 3;
        goto cleanup;
    }
    readCount--;
    if( readCount > 0 && wide[ readCount - 1 ] == L'\r' ) readCount--;
    if( readCount == 0 || wmemchr( wide, L'\0', readCount ) != NULL ||
        wmemchr( wide, L'\r', readCount ) != NULL || wmemchr( wide, L'\n', readCount ) != NULL )
    {
        status = 3;
        goto cleanup;
    }
    for( index = 0; index < readCount; index++ )
    {
        if( ( wide[ index ] < 0x20 && wide[ index ] != L'\t' ) || wide[ index ] == 0x7f )
        {
            status = 3;
            goto cleanup;
        }
    }
    utf8Length = WideCharToMultiByte( CP_UTF8, WC_ERR_INVALID_CHARS, wide, ( int ) readCount,
        output, HB_CREDENTIAL_TERMINAL_MAX, NULL, NULL );
    if( utf8Length <= 0 )
    {
        status = 3;
        goto cleanup;
    }
    *length = ( size_t ) utf8Length;
    status = 0;
cleanup:
    if( modeChanged && ! FlushConsoleInputBuffer( input ) ) status = 5;
    if( modeChanged && ! SetConsoleMode( input, original ) ) status = 5;
    if( status != 5 && InterlockedCompareExchange( &s_terminalInterrupted, 0, 0 ) != 0 ) status = 4;
    if( handlerInstalled && ! SetConsoleCtrlHandler( HBBridgeTerminalControl, FALSE ) ) status = 5;
    if( modeChanged ) { fputc( '\n', stderr ); fflush( stderr ); }
    HBBridgeTerminalWipe( wide, sizeof( wide ) );
    return status;
}
#elif defined( HB_OS_UNIX )
static volatile sig_atomic_t s_terminalSignal = 0;

static void HBBridgeTerminalSignal( int signalNumber )
{
    if( s_terminalSignal == 0 ) s_terminalSignal = signalNumber;
}

static int HBBridgeTerminalSetMode( const struct termios * mode, int action )
{
    int result;
    do { result = tcsetattr( STDIN_FILENO, action, mode ); } while( result != 0 && errno == EINTR );
    return result;
}

/* This process-wide signal handling is reserved for the local CLI before
 * listeners or application worker threads are started. */
static int HBBridgeTerminalRead( char * output, size_t * length )
{
    static const int signals[] = { SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGTSTP };
    struct sigaction oldActions[ sizeof( signals ) / sizeof( signals[ 0 ] ) ];
    struct sigaction action;
    sigset_t blocked, previousMask;
    struct termios original, hidden;
    struct pollfd pollInput;
    size_t installed = 0, count = 0, index;
    int status = 2;
    HB_BOOL modeChanged = HB_FALSE, invalid = HB_FALSE, maskChanged;

    if( ! isatty( STDIN_FILENO ) || tcgetattr( STDIN_FILENO, &original ) != 0 ||
        tcgetpgrp( STDIN_FILENO ) != getpgrp() ) return 1;
    memset( &action, 0, sizeof( action ) );
    action.sa_handler = HBBridgeTerminalSignal;
    sigemptyset( &action.sa_mask );
    s_terminalSignal = 0;
    for( index = 0; index < sizeof( signals ) / sizeof( signals[ 0 ] ); index++ )
    {
        if( sigaction( signals[ index ], &action, &oldActions[ index ] ) != 0 ) goto cleanup;
        installed++;
    }
    if( s_terminalSignal != 0 ) goto cleanup;
    hidden = original;
    hidden.c_lflag &= ( tcflag_t ) ~( ECHO | ECHONL | ICANON );
    hidden.c_lflag |= ISIG;
    hidden.c_cc[ VMIN ] = 1;
    hidden.c_cc[ VTIME ] = 0;
    if( HBBridgeTerminalSetMode( &hidden, TCSAFLUSH ) != 0 ) goto cleanup;
    modeChanged = HB_TRUE;
    if( s_terminalSignal != 0 ) goto cleanup;
    if( fputs( "Password: ", stderr ) == EOF || fflush( stderr ) != 0 ) goto cleanup;
    pollInput.fd = STDIN_FILENO;
    pollInput.events = POLLIN;
    pollInput.revents = 0;
    while( s_terminalSignal == 0 )
    {
        unsigned char ch;
        ssize_t received;
        int ready = poll( &pollInput, 1, 100 );
        if( ready < 0 && errno == EINTR ) continue;
        if( ready < 0 || ( ready > 0 && ( pollInput.revents & ( POLLERR | POLLHUP | POLLNVAL ) ) ) ) break;
        if( ready == 0 || !( pollInput.revents & POLLIN ) ) continue;
        received = read( STDIN_FILENO, &ch, 1 );
        if( received < 0 && errno == EINTR ) continue;
        if( received != 1 ) break;
        if( ch == '\n' || ch == '\r' )
        {
            status = ! invalid && count > 0 && hb_cdpUTF8Validate( output, count ) ? 0 : 3;
            *length = status == 0 ? count : 0;
            break;
        }
        if( ch == 0x7f || ch == 0x08 )
        {
            if( count > 0 )
            {
                count--;
                while( count > 0 && ( ( unsigned char ) output[ count ] & 0xc0 ) == 0x80 ) count--;
            }
            continue;
        }
        if( ch < 0x20 && ch != '\t' ) { invalid = HB_TRUE; continue; }
        if( count < HB_CREDENTIAL_TERMINAL_MAX ) output[ count++ ] = ( char ) ch;
        else invalid = HB_TRUE;
    }
    if( s_terminalSignal != 0 ) status = 4;
cleanup:
    sigemptyset( &blocked );
    for( index = 0; index < sizeof( signals ) / sizeof( signals[ 0 ] ); index++ )
        sigaddset( &blocked, signals[ index ] );
    maskChanged = sigprocmask( SIG_BLOCK, &blocked, &previousMask ) == 0;
    if( ! maskChanged ) status = 5;
    if( modeChanged && HBBridgeTerminalSetMode( &original, TCSAFLUSH ) != 0 ) status = 5;
    if( s_terminalSignal != 0 && status != 5 ) status = 4;
    while( installed > 0 )
    {
        installed--;
        if( sigaction( signals[ installed ], &oldActions[ installed ], NULL ) != 0 ) status = 5;
    }
    if( maskChanged && sigprocmask( SIG_SETMASK, &previousMask, NULL ) != 0 ) status = 5;
    if( modeChanged ) { fputc( '\n', stderr ); fflush( stderr ); }
    return status;
}
#endif

/* Returns NIL on failure. The caller owns the Harbour string on success. */
HB_FUNC( HBBRIDGECREDENTIALREADSECRET )
{
    char buffer[ HB_CREDENTIAL_TERMINAL_MAX ] = { 0 };
    size_t length = 0;
    int status = 1;

#if defined( HB_OS_WIN ) || defined( HB_OS_UNIX )
    status = HBBridgeTerminalRead( buffer, &length );
#endif
    if( status == 0 ) hb_retclen( buffer, length );
    else hb_ret();
    HBBridgeTerminalWipe( buffer, sizeof( buffer ) );
    hb_storni( status, 1 );
}
