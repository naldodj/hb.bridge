/* Released to Public Domain. Private key-file bridge for the Zig provider. */
#if ! defined( _WIN32 ) && ! defined( _GNU_SOURCE )
    #define _GNU_SOURCE
#endif
#include "hbapi.h"
#include "hbapicdp.h"
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#if defined( HB_OS_WIN )
    #include <windows.h>
    #include <aclapi.h>
    #include <sddl.h>
#elif defined( HB_OS_UNIX )
    #include <sys/types.h>
    #include <sys/stat.h>
    #include <fcntl.h>
    #include <unistd.h>
    #include <errno.h>
#endif

#define HB_CREDENTIAL_KEY_SIZE 32
#define HB_CREDENTIAL_PASSWORD_MAX 4096
#define HB_CREDENTIAL_ENVELOPE_MAX 5523

extern int HBBridgeCredentialRandomKey( unsigned char * key, size_t keySize );
extern int HBBridgeCredentialV1Encrypt( const unsigned char * key, size_t keySize,
    const unsigned char * input, size_t inputSize, const unsigned char * aad,
    size_t aadSize, unsigned char * output, size_t capacity, size_t * written );
extern int HBBridgeCredentialV1Decrypt( const unsigned char * key, size_t keySize,
    const unsigned char * input, size_t inputSize, const unsigned char * aad,
    size_t aadSize, unsigned char * output, size_t capacity, size_t * written );

static void HBBridgeCredentialWipe( void * buffer, size_t size )
{
    volatile unsigned char * data = ( volatile unsigned char * ) buffer;
    while( size-- > 0 )
        *data++ = 0;
}

static HB_BOOL HBBridgeCredentialPathValid( int argument )
{
    const char * path = hb_parc( argument );
    HB_SIZE size = hb_parclen( argument );
    return path != NULL && size > 0 && strlen( path ) == size &&
        hb_cdpUTF8Validate( path, size );
}

#if defined( HBBRIDGE_CREDENTIAL_TEST_PAUSE )
/* Compiled only into the synthetic interruption probe. */
static void HBBridgeCredentialTestPause( void )
{
    const char * marker = getenv( "HBBRIDGE_CREDENTIAL_TEST_MARKER" );
    FILE * file;

    if( marker == NULL || *marker == '\0' ) return;
    file = fopen( marker, "wb" );
    if( file == NULL ) return;
    fputs( "ready", file );
    fclose( file );
#if defined( HB_OS_WIN )
    Sleep( 60000 );
#elif defined( HB_OS_UNIX )
    sleep( 60 );
#endif
}

static HB_BOOL HBBridgeCredentialTestFailCleanup( void )
{
    const char * value = getenv( "HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP" );
    return value != NULL && strcmp( value, "1" ) == 0;
}
#endif

#if defined( HB_OS_WIN )
static PSECURITY_DESCRIPTOR HBBridgeCredentialSecurity( void )
{
    HANDLE token = NULL;
    DWORD size = 0;
    PTOKEN_USER user = NULL;
    LPWSTR sid = NULL, text = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;

    if( ! OpenThreadToken( GetCurrentThread(), TOKEN_QUERY, TRUE, &token ) &&
        ( GetLastError() != ERROR_NO_TOKEN || ! OpenProcessToken( GetCurrentProcess(), TOKEN_QUERY, &token ) ) )
        return NULL;
    GetTokenInformation( token, TokenUser, NULL, 0, &size );
    if( size == 0 )
        goto cleanup;
    user = ( PTOKEN_USER ) hb_xgrab( size );
    if( ! GetTokenInformation( token, TokenUser, user, size, &size ) ||
        ! ConvertSidToStringSidW( user->User.Sid, &sid ) )
        goto cleanup;
    size = ( DWORD ) ( wcslen( sid ) + 50 );
    text = ( LPWSTR ) hb_xgrab( size * sizeof( WCHAR ) );
    if( _snwprintf( text, size, L"D:P(A;;FA;;;SY)(A;;FA;;;%ls)", sid ) < 0 ||
        ! ConvertStringSecurityDescriptorToSecurityDescriptorW( text, SDDL_REVISION_1, &descriptor, NULL ) )
        descriptor = NULL;
cleanup:
    if( text ) hb_xfree( text );
    if( sid ) LocalFree( sid );
    if( user ) hb_xfree( user );
    if( token ) CloseHandle( token );
    return descriptor;
}

static HB_BOOL HBBridgeCredentialACLValid( HANDLE file, PSECURITY_DESCRIPTOR expectedDescriptor )
{
    PSECURITY_DESCRIPTOR actualDescriptor = NULL;
    PACL expected = NULL, actual = NULL;
    BOOL present = FALSE, defaulted = FALSE;
    SECURITY_DESCRIPTOR_CONTROL control;
    DWORD revision, index, candidate, used = 0;
    HB_BOOL valid = HB_FALSE;

    if( ! GetSecurityDescriptorDacl( expectedDescriptor, &present, &expected, &defaulted ) ||
        ! present || ! expected || expected->AceCount != 2 ||
        GetSecurityInfo( file, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION, NULL, NULL,
            &actual, NULL, &actualDescriptor ) != ERROR_SUCCESS )
        goto cleanup;
    if( ! actual || actual->AceCount != 2 ||
        ! GetSecurityDescriptorControl( actualDescriptor, &control, &revision ) ||
        !( control & SE_DACL_PROTECTED ) )
        goto cleanup;
    for( index = 0; index < actual->AceCount; index++ )
    {
        ACCESS_ALLOWED_ACE * current = NULL;
        HB_BOOL found = HB_FALSE;
        if( ! GetAce( actual, index, ( void ** ) &current ) ||
            current->Header.AceType != ACCESS_ALLOWED_ACE_TYPE )
            goto cleanup;
        for( candidate = 0; candidate < expected->AceCount; candidate++ )
        {
            ACCESS_ALLOWED_ACE * permitted = NULL;
            if( !( used & ( 1U << candidate ) ) && GetAce( expected, candidate, ( void ** ) &permitted ) &&
                permitted->Header.AceType == ACCESS_ALLOWED_ACE_TYPE &&
                current->Header.AceFlags == permitted->Header.AceFlags && current->Mask == permitted->Mask &&
                EqualSid( &current->SidStart, &permitted->SidStart ) )
            {
                used |= 1U << candidate;
                found = HB_TRUE;
                break;
            }
        }
        if( ! found ) goto cleanup;
    }
    valid = HB_TRUE;
cleanup:
    if( actualDescriptor ) LocalFree( actualDescriptor );
    return valid;
}

/* Accept explicit access for the file owner, the current identity and SYSTEM. */
static HB_BOOL HBBridgeCredentialReadACLValid( HANDLE file )
{
    PSECURITY_DESCRIPTOR expectedDescriptor = HBBridgeCredentialSecurity();
    PSECURITY_DESCRIPTOR actualDescriptor = NULL;
    PACL expected = NULL, actual = NULL;
    PSID owner = NULL;
    BOOL present = FALSE, defaulted = FALSE;
    SECURITY_DESCRIPTOR_CONTROL control;
    ACCESS_ALLOWED_ACE * systemAce = NULL, * currentAce = NULL;
    DWORD revision, index;
    HB_BOOL valid = HB_FALSE;

    if( ! expectedDescriptor ||
        ! GetSecurityDescriptorDacl( expectedDescriptor, &present, &expected, &defaulted ) ||
        ! present || ! expected || expected->AceCount != 2 ||
        ! GetAce( expected, 0, ( void ** ) &systemAce ) ||
        ! GetAce( expected, 1, ( void ** ) &currentAce ) ||
        GetSecurityInfo( file, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            &owner, NULL, &actual, NULL, &actualDescriptor ) != ERROR_SUCCESS )
        goto cleanup;
    if( ! owner || ! IsValidSid( owner ) || ! actual || ! IsValidAcl( actual ) ||
        ! GetSecurityDescriptorControl( actualDescriptor, &control, &revision ) ||
        !( control & SE_DACL_PROTECTED ) )
        goto cleanup;
    for( index = 0; index < actual->AceCount; index++ )
    {
        ACCESS_ALLOWED_ACE * entry = NULL;
        if( ! GetAce( actual, index, ( void ** ) &entry ) ||
            entry->Header.AceType != ACCESS_ALLOWED_ACE_TYPE ||
            ( entry->Header.AceFlags & INHERITED_ACE ) != 0 || ! IsValidSid( &entry->SidStart ) ||
            !( EqualSid( &entry->SidStart, owner ) || EqualSid( &entry->SidStart, &systemAce->SidStart ) ||
                EqualSid( &entry->SidStart, &currentAce->SidStart ) ) )
            goto cleanup;
    }
    valid = HB_TRUE;
cleanup:
    if( actualDescriptor ) LocalFree( actualDescriptor );
    if( expectedDescriptor ) LocalFree( expectedDescriptor );
    return valid;
}

static int HBBridgeCredentialReadKey( const char * path, unsigned char * key )
{
    HB_WCHAR * wide = hb_osStrU16Encode( path );
    HANDLE file;
    BY_HANDLE_FILE_INFORMATION info;
    DWORD count = 0;
    int status = 6;

    if( ! wide ) return status;
    file = CreateFileW( ( LPCWSTR ) wide, GENERIC_READ | READ_CONTROL, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL );
    hb_xfree( wide );
    if( file == INVALID_HANDLE_VALUE ) return status;
    if( GetFileInformationByHandle( file, &info ) &&
        !( info.dwFileAttributes & ( FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT ) ) )
    {
        status = 7;
        if( info.nFileSizeHigh == 0 && info.nFileSizeLow == HB_CREDENTIAL_KEY_SIZE )
        {
            status = 11;
            if( HBBridgeCredentialReadACLValid( file ) )
            {
                status = 6;
                if( ReadFile( file, key, HB_CREDENTIAL_KEY_SIZE, &count, NULL ) && count == HB_CREDENTIAL_KEY_SIZE )
                    status = 0;
            }
        }
    }
    CloseHandle( file );
    return status;
}

static int HBBridgeCredentialCreateFile( const char * path, const unsigned char * key )
{
    HB_WCHAR * wide = hb_osStrU16Encode( path );
    PSECURITY_DESCRIPTOR descriptor = HBBridgeCredentialSecurity();
    SECURITY_ATTRIBUTES attributes;
    HANDLE file;
    WCHAR * temporary = NULL;
    unsigned char random[ HB_CREDENTIAL_KEY_SIZE ] = { 0 };
    const WCHAR hex[] = L"0123456789abcdef";
    size_t length, index;
    DWORD count = 0, error;
    int status = 9;

    if( ! wide || ! descriptor )
    {
        if( wide ) hb_xfree( wide );
        if( descriptor ) LocalFree( descriptor );
        return status;
    }
    if( HBBridgeCredentialRandomKey( random, sizeof( random ) ) != 0 )
    {
        status = 5;
        goto cleanup;
    }
    length = wcslen( ( LPCWSTR ) wide );
    temporary = ( WCHAR * ) hb_xgrab( ( length + 39 ) * sizeof( WCHAR ) );
    memcpy( temporary, wide, length * sizeof( WCHAR ) );
    memcpy( temporary + length, L".tmp.", 5 * sizeof( WCHAR ) );
    for( index = 0; index < 16; index++ )
    {
        temporary[ length + 5 + index * 2 ] = hex[ random[ index ] >> 4 ];
        temporary[ length + 6 + index * 2 ] = hex[ random[ index ] & 15 ];
    }
    temporary[ length + 37 ] = L'\0';
    attributes.nLength = sizeof( attributes );
    attributes.lpSecurityDescriptor = descriptor;
    attributes.bInheritHandle = FALSE;
    file = CreateFileW( temporary, GENERIC_WRITE | DELETE | READ_CONTROL, FILE_SHARE_DELETE, &attributes,
        CREATE_NEW, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, NULL );
    error = GetLastError();
    if( file != INVALID_HANDLE_VALUE )
    {
        if( HBBridgeCredentialACLValid( file, descriptor ) &&
            WriteFile( file, key, HB_CREDENTIAL_KEY_SIZE, &count, NULL ) &&
            count == HB_CREDENTIAL_KEY_SIZE && FlushFileBuffers( file ) )
        {
#if defined( HBBRIDGE_CREDENTIAL_TEST_PAUSE )
            HBBridgeCredentialTestPause();
#endif
            if( MoveFileExW( temporary, ( LPCWSTR ) wide, MOVEFILE_WRITE_THROUGH ) )
                status = 0;
            else
            {
                error = GetLastError();
                if( error == ERROR_FILE_EXISTS || error == ERROR_ALREADY_EXISTS ) status = 8;
            }
        }
        if( status != 0 )
        {
            FILE_DISPOSITION_INFO disposition;
            disposition.DeleteFile = TRUE;
            if(
#if defined( HBBRIDGE_CREDENTIAL_TEST_PAUSE )
                HBBridgeCredentialTestFailCleanup() ||
#endif
                ! SetFileInformationByHandle( file, FileDispositionInfo, &disposition, sizeof( disposition ) ) )
                status = 10;
        }
        CloseHandle( file );
    }
    /* A collision on the random temporary name is not a destination collision. */
    HB_SYMBOL_UNUSED( error );
cleanup:
    HBBridgeCredentialWipe( random, sizeof( random ) );
    if( temporary ) hb_xfree( temporary );
    LocalFree( descriptor );
    hb_xfree( wide );
    return status;
}
#elif defined( HB_OS_UNIX )
static int HBBridgeCredentialReadKey( const char * path, unsigned char * key )
{
    int file = open( path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK );
    struct stat info;
    size_t offset = 0;
    int status = 6;

    if( file < 0 ) return status;
    if( fstat( file, &info ) == 0 && S_ISREG( info.st_mode ) )
    {
        status = 7;
        if( info.st_size == HB_CREDENTIAL_KEY_SIZE )
        {
            if( ( info.st_mode & ( S_IRWXG | S_IRWXO ) ) != 0 )
            {
                close( file );
                return 11;
            }
            while( offset < HB_CREDENTIAL_KEY_SIZE )
            {
                ssize_t count = read( file, key + offset, HB_CREDENTIAL_KEY_SIZE - offset );
                if( count < 0 && errno == EINTR ) continue;
                if( count <= 0 ) break;
                offset += ( size_t ) count;
            }
            if( offset == HB_CREDENTIAL_KEY_SIZE ) status = 0;
        }
    }
    close( file );
    return status;
}

static int HBBridgeCredentialCreateFile( const char * path, const unsigned char * key )
{
    const size_t pathLength = strlen( path );
    const char suffix[] = ".tmp.XXXXXX";
    char * temporary;
    int file;
    struct stat info;
    size_t offset = 0;
    int status = 9;

    if( pathLength > ( size_t ) -1 - sizeof( suffix ) ) return status;
    temporary = ( char * ) hb_xgrab( pathLength + sizeof( suffix ) );
    memcpy( temporary, path, pathLength );
    memcpy( temporary + pathLength, suffix, sizeof( suffix ) );
    file = mkstemp( temporary );
    if( file < 0 )
    {
        hb_xfree( temporary );
        return status;
    }
    if( fcntl( file, F_SETFD, FD_CLOEXEC ) != 0 || fstat( file, &info ) != 0 ||
        ! S_ISREG( info.st_mode ) || ( info.st_mode & ( S_IRWXG | S_IRWXO ) ) != 0 )
        goto cleanup;
    while( offset < HB_CREDENTIAL_KEY_SIZE )
    {
        ssize_t count = write( file, key + offset, HB_CREDENTIAL_KEY_SIZE - offset );
        if( count < 0 && errno == EINTR ) continue;
        if( count <= 0 ) break;
        offset += ( size_t ) count;
    }
    if( offset == HB_CREDENTIAL_KEY_SIZE && fsync( file ) == 0 )
    {
#if defined( HBBRIDGE_CREDENTIAL_TEST_PAUSE )
        HBBridgeCredentialTestPause();
#endif
        if( link( temporary, path ) == 0 ) status = 0;
        else if( errno == EEXIST ) status = 8;
    }
cleanup:
    close( file );
    /* A crash before cleanup can leave a private temporary key file. A trusted
     * directory is required so another process cannot replace this path. */
    if(
#if defined( HBBRIDGE_CREDENTIAL_TEST_PAUSE )
        HBBridgeCredentialTestFailCleanup() ||
#endif
        unlink( temporary ) != 0 ) status = 10;
    hb_xfree( temporary );
    return status;
}
#endif

HB_FUNC( HBBRIDGECREDENTIALFILECREATE )
{
    unsigned char key[ HB_CREDENTIAL_KEY_SIZE ] = { 0 };
    int status = 1;

#if defined( HB_OS_WIN ) || defined( HB_OS_UNIX )
    if( HBBridgeCredentialPathValid( 1 ) )
    {
        status = HBBridgeCredentialRandomKey( key, sizeof( key ) );
        if( status == 0 ) status = HBBridgeCredentialCreateFile( hb_parc( 1 ), key );
    }
#endif
    HBBridgeCredentialWipe( key, sizeof( key ) );
    hb_storni( status, 2 );
    hb_retl( status == 0 );
}

static void HBBridgeCredentialTransform( HB_BOOL encrypt )
{
    unsigned char key[ HB_CREDENTIAL_KEY_SIZE ] = { 0 };
    unsigned char output[ HB_CREDENTIAL_ENVELOPE_MAX ] = { 0 };
    const unsigned char * input = ( const unsigned char * ) hb_parc( 2 );
    const unsigned char * aad = ( const unsigned char * ) hb_parc( 3 );
    size_t written = 0;
    int status = 1;

#if defined( HB_OS_WIN ) || defined( HB_OS_UNIX )
    if( HBBridgeCredentialPathValid( 1 ) && input && aad )
    {
        status = HBBridgeCredentialReadKey( hb_parc( 1 ), key );
        if( status == 0 )
            status = encrypt ? HBBridgeCredentialV1Encrypt( key, sizeof( key ), input, hb_parclen( 2 ),
                aad, hb_parclen( 3 ), output, sizeof( output ), &written ) :
                HBBridgeCredentialV1Decrypt( key, sizeof( key ), input, hb_parclen( 2 ),
                aad, hb_parclen( 3 ), output, HB_CREDENTIAL_PASSWORD_MAX, &written );
    }
#else
    HB_SYMBOL_UNUSED( encrypt );
#endif
    if( status == 0 ) hb_retclen( ( const char * ) output, written );
    else hb_ret();
    HBBridgeCredentialWipe( key, sizeof( key ) );
    HBBridgeCredentialWipe( output, sizeof( output ) );
    hb_storni( status, 4 );
}

HB_FUNC( HBBRIDGECREDENTIALFILEENCRYPT )
{
    HBBridgeCredentialTransform( HB_TRUE );
}

HB_FUNC( HBBRIDGECREDENTIALFILEDECRYPT )
{
    HBBridgeCredentialTransform( HB_FALSE );
}
