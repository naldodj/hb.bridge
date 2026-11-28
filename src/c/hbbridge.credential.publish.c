/* Released to Public Domain. Restricted, cooperative file publication probe. */
#if ! defined( _WIN32 ) && ! defined( _GNU_SOURCE )
    #define _GNU_SOURCE
#endif
#include "hbapi.h"
#include "hbapicdp.h"
#include <stddef.h>
#include <string.h>

#if defined( HB_OS_WIN ) && defined( HBBRIDGE_PUBLISH_TEST )
    #include <windows.h>
    #include <aclapi.h>
    #include <sddl.h>
    #include <wchar.h>
#endif

#if defined( HB_OS_LINUX )
    #include <errno.h>
    #include <fcntl.h>
    #include <linux/fs.h>
    #include <stdio.h>
    #include <stdlib.h>
    #if defined( HBBRIDGE_PUBLISH_TEST )
        #include <signal.h>
    #endif
    #include <sys/file.h>
    #include <sys/ioctl.h>
    #include <sys/random.h>
    #include <sys/stat.h>
    #include <sys/types.h>
    #include <sys/xattr.h>
    #include <unistd.h>
#endif

/* Status 8 means the rename succeeded but directory synchronization failed.
 * A caller must inspect the destination instead of repeating the operation. */
enum
{
    HB_PUBLISH_OK = 0,
    HB_PUBLISH_INVALID = 1,
    HB_PUBLISH_UNSUPPORTED = 2,
    HB_PUBLISH_UNSAFE = 3,
    HB_PUBLISH_CONFLICT = 4,
    HB_PUBLISH_BUSY = 5,
    HB_PUBLISH_IO = 6,
    HB_PUBLISH_CLEANUP = 7,
    HB_PUBLISH_NOT_DURABLE = 8,
    HB_PUBLISH_PRIVILEGE_REQUIRED = 9
};

#if defined( HB_OS_LINUX )
#define HB_CREDENTIAL_SNAPSHOT_MAX ( 1024 * 1024 )

static void HBBridgePublishWipe( void * buffer, size_t size )
{
    volatile unsigned char * data = ( volatile unsigned char * ) buffer;
    while( size-- > 0 ) *data++ = 0;
}

static HB_BOOL HBBridgePublishCompare( int fd, const unsigned char * expected, size_t size )
{
    unsigned char buffer[ 8192 ];
    size_t offset = 0;
    HB_BOOL matches = HB_TRUE;

    while( offset < size )
    {
        size_t amount = size - offset < sizeof( buffer ) ? size - offset : sizeof( buffer );
        ssize_t count = pread( fd, buffer, amount, ( off_t ) offset );
        if( count < 0 && errno == EINTR ) continue;
        if( count <= 0 || memcmp( buffer, expected + offset, ( size_t ) count ) != 0 )
        {
            matches = HB_FALSE;
            break;
        }
        offset += ( size_t ) count;
    }
    HBBridgePublishWipe( buffer, sizeof( buffer ) );
    return matches && offset == size;
}

static HB_BOOL HBBridgePublishRandom( unsigned char * output, size_t size )
{
    size_t offset = 0;
    while( offset < size )
    {
        ssize_t count = getrandom( output + offset, size - offset, 0 );
        if( count < 0 && errno == EINTR ) continue;
        if( count <= 0 ) return HB_FALSE;
        offset += ( size_t ) count;
    }
    return HB_TRUE;
}

static HB_BOOL HBBridgePublishSameFile( const struct stat * first, const struct stat * second )
{
    return first->st_dev == second->st_dev && first->st_ino == second->st_ino &&
        first->st_size == second->st_size && first->st_mode == second->st_mode &&
        first->st_uid == second->st_uid && first->st_gid == second->st_gid &&
        first->st_nlink == second->st_nlink &&
        first->st_mtim.tv_sec == second->st_mtim.tv_sec && first->st_mtim.tv_nsec == second->st_mtim.tv_nsec &&
        first->st_ctim.tv_sec == second->st_ctim.tv_sec && first->st_ctim.tv_nsec == second->st_ctim.tv_nsec;
}

/* Pin each directory before opening its child. A trusted sticky ancestor
 * permits private subdirectories of /tmp; the publication directory itself
 * must never be group- or other-writable. */
static int HBBridgePublishOpenParent( char * parent )
{
    char * component = parent;
    const int flags = O_PATH | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW;
    int dirfd = open( "/", flags );
    uid_t owner = geteuid();

    while( dirfd >= 0 )
    {
        char * end;
        struct stat info;
        int next;

        while( *component == '/' ) component++;
        if( fstat( dirfd, &info ) != 0 || ( info.st_uid != owner && info.st_uid != 0 ) ||
            ( ( info.st_mode & ( S_IWGRP | S_IWOTH ) ) != 0 &&
                ( ! *component || ( info.st_mode & S_ISVTX ) == 0 ) ) )
            break;
        if( ! *component )
        {
            /* fsync needs a readable handle only for this final directory. */
            next = openat( dirfd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC );
            close( dirfd );
            return next;
        }
        end = strchrnul( component, '/' );
        if( *end ) *end++ = '\0';
        if( ! strcmp( component, ".." ) ) break;
        next = openat( dirfd, component, flags );
        close( dirfd );
        dirfd = next;
        component = end;
    }
    if( dirfd >= 0 ) close( dirfd );
    return -1;
}

static int HBBridgeCredentialDirectory( const char * path, const char ** base, int * dirfd )
{
    const char * slash = strrchr( path, '/' );
    size_t length;
    char * parent;

    if( path[ 0 ] != '/' || ! slash || ! slash[ 1 ] ) return HB_PUBLISH_INVALID;
    *base = slash + 1;
    if( ! strcmp( *base, "." ) || ! strcmp( *base, ".." ) ) return HB_PUBLISH_INVALID;
    length = slash == path ? 1 : ( size_t ) ( slash - path );
    parent = hb_strndup( path, length );
    *dirfd = HBBridgePublishOpenParent( parent );
    hb_xfree( parent );
    return *dirfd >= 0 ? HB_PUBLISH_OK : HB_PUBLISH_UNSAFE;
}

/* Inode flags such as nodump do not appear in the extended attribute list.
 * Only the filesystem's extent marker is supported on the test filesystems. */
static HB_BOOL HBBridgeCredentialMetadata( int file, int * flags )
{
    return flistxattr( file, NULL, 0 ) == 0 && ioctl( file, FS_IOC_GETFLAGS, flags ) == 0 &&
        ( *flags & ~FS_EXTENT_FL ) == 0;
}

static int HBBridgeCredentialOpenOriginal( int dirfd, const char * base, struct stat * info, int * flags )
{
    struct stat byName;
    int file;

    if( fstatat( dirfd, base, &byName, AT_SYMLINK_NOFOLLOW ) != 0 || ! S_ISREG( byName.st_mode ) )
        return -1;
    file = openat( dirfd, base, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK );
    if( file >= 0 && ( fstat( file, info ) != 0 || ! HBBridgePublishSameFile( info, &byName ) ||
        info->st_nlink != 1 || info->st_uid != geteuid() || ( info->st_mode & ( 07000 | S_IWGRP | S_IWOTH ) ) != 0 ||
        ! HBBridgeCredentialMetadata( file, flags ) ) )
    {
        close( file );
        return -1;
    }
    return file;
}

/* Return the bytes only after checking that both the descriptor and its
 * directory entry still identify the same snapshot. No lock or stage is created. */
static int HBBridgeCredentialReadSnapshot( const char * path )
{
    const char * base;
    char * contents = NULL;
    struct stat before, after, byName;
    size_t offset = 0, size = 0;
    int dirfd = -1, file = -1, flags;
    int status = HBBridgeCredentialDirectory( path, &base, &dirfd );

    if( status != HB_PUBLISH_OK ) return status;
    file = HBBridgeCredentialOpenOriginal( dirfd, base, &before, &flags );
    if( file < 0 ) { status = HB_PUBLISH_UNSAFE; goto cleanup; }
    if( before.st_size <= 0 || before.st_size > HB_CREDENTIAL_SNAPSHOT_MAX )
    {
        status = HB_PUBLISH_INVALID;
        goto cleanup;
    }
    size = ( size_t ) before.st_size;
    contents = ( char * ) hb_xgrab( size + 1 );
    while( offset < size )
    {
        ssize_t count = read( file, contents + offset, size - offset );
        if( count < 0 && errno == EINTR ) continue;
        if( count <= 0 )
        {
            status = count == 0 ? HB_PUBLISH_CONFLICT : HB_PUBLISH_IO;
            goto cleanup;
        }
        offset += ( size_t ) count;
    }
#if defined( HBBRIDGE_PUBLISH_TEST )
    if( getenv( "HBBRIDGE_TEST_SNAPSHOT_PAUSE_BEFORE_RECHECK" ) ) raise( SIGSTOP );
#endif
    if( fstat( file, &after ) != 0 || fstatat( dirfd, base, &byName, AT_SYMLINK_NOFOLLOW ) != 0 ||
        ! HBBridgePublishSameFile( &before, &after ) || ! HBBridgePublishSameFile( &before, &byName ) )
    {
        status = HB_PUBLISH_CONFLICT;
        goto cleanup;
    }
    contents[ size ] = '\0';
    hb_retclen_buffer( contents, size );
    contents = NULL;
cleanup:
    if( contents ) { HBBridgePublishWipe( contents, offset ); hb_xfree( contents ); }
    if( file >= 0 ) close( file );
    close( dirfd );
    return status;
}

static int HBBridgePublishLinux( const char * path, const unsigned char * expected, size_t expectedSize,
    const unsigned char * replacement, size_t replacementSize )
{
    const char * base;
    const char hex[] = "0123456789abcdef";
    const char lockSuffix[] = ".hbbridge.lock";
    const char stagePrefix[] = ".hbbridge-stage-";
    unsigned char random[ 16 ] = { 0 };
    char stageName[ sizeof( stagePrefix ) + 32 ] = { 0 };
    char * lockName = NULL;
    size_t baseLength, index, offset = 0;
    struct stat original, current, byName, staging, lockInfo;
    int dirfd = -1, file = -1, lock = -1, stage = -1, originalFlags, stageFlags, status;
    HB_BOOL stageExists = HB_FALSE;

    /* A successfully written INI must remain readable for the next update. */
    if( expectedSize > HB_CREDENTIAL_SNAPSHOT_MAX || replacementSize > HB_CREDENTIAL_SNAPSHOT_MAX )
        return HB_PUBLISH_INVALID;
    status = HBBridgeCredentialDirectory( path, &base, &dirfd );
    if( status != HB_PUBLISH_OK ) return status;
    status = HB_PUBLISH_IO;
    baseLength = strlen( base );
    if( baseLength > ( size_t ) -1 - sizeof( lockSuffix ) ) { status = HB_PUBLISH_INVALID; goto cleanup; }
    lockName = ( char * ) hb_xgrab( baseLength + sizeof( lockSuffix ) );
    memcpy( lockName, base, baseLength );
    memcpy( lockName + baseLength, lockSuffix, sizeof( lockSuffix ) );

    lock = openat( dirfd, lockName, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600 );
    if( lock < 0 || fstat( lock, &lockInfo ) != 0 || ! S_ISREG( lockInfo.st_mode ) ||
        lockInfo.st_nlink != 1 || lockInfo.st_uid != geteuid() ||
        ( lockInfo.st_mode & ( S_IRWXG | S_IRWXO ) ) != 0 )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
    if( flock( lock, LOCK_EX | LOCK_NB ) != 0 )
    {
        status = errno == EWOULDBLOCK || errno == EAGAIN ? HB_PUBLISH_BUSY : HB_PUBLISH_IO;
        goto cleanup;
    }
    file = HBBridgeCredentialOpenOriginal( dirfd, base, &original, &originalFlags );
    if( file < 0 )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
    if( original.st_size < 0 || ( unsigned long long ) original.st_size != ( unsigned long long ) expectedSize ||
        ! HBBridgePublishCompare( file, expected, expectedSize ) )
    {
        status = HB_PUBLISH_CONFLICT;
        goto cleanup;
    }
    if( ! HBBridgePublishRandom( random, sizeof( random ) ) ) goto cleanup;
    memcpy( stageName, stagePrefix, sizeof( stagePrefix ) - 1 );
    for( index = 0; index < sizeof( random ); index++ )
    {
        stageName[ sizeof( stagePrefix ) - 1 + index * 2 ] = hex[ random[ index ] >> 4 ];
        stageName[ sizeof( stagePrefix ) + index * 2 ] = hex[ random[ index ] & 15 ];
    }
    stage = openat( dirfd, stageName, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600 );
    if( stage < 0 ) goto cleanup;
    stageExists = HB_TRUE;
    if( fstat( stage, &staging ) != 0 || ! S_ISREG( staging.st_mode ) || staging.st_nlink != 1 ||
        ( staging.st_mode & ( S_IRWXG | S_IRWXO ) ) != 0 || ! HBBridgeCredentialMetadata( stage, &stageFlags ) )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
    while( offset < replacementSize )
    {
        ssize_t count = write( stage, replacement + offset, replacementSize - offset );
        if( count < 0 && errno == EINTR ) continue;
        if( count <= 0 ) goto cleanup;
        offset += ( size_t ) count;
    }
    if( ( staging.st_uid != original.st_uid || staging.st_gid != original.st_gid ) &&
        fchown( stage, original.st_uid, original.st_gid ) != 0 ) goto cleanup;
    if( fchmod( stage, original.st_mode & 0777 ) != 0 || fsync( stage ) != 0 ||
        fstat( stage, &staging ) != 0 || staging.st_uid != original.st_uid || staging.st_gid != original.st_gid ||
        ( staging.st_mode & 07777 ) != ( original.st_mode & 07777 ) ) goto cleanup;
    if( ! HBBridgeCredentialMetadata( stage, &stageFlags ) || stageFlags != originalFlags )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
#if defined( HBBRIDGE_PUBLISH_TEST )
    if( getenv( "HBBRIDGE_TEST_PUBLISH_PAUSE_BEFORE_RECHECK" ) ) raise( SIGSTOP );
#endif
    if( fstat( file, &current ) != 0 || fstatat( dirfd, base, &byName, AT_SYMLINK_NOFOLLOW ) != 0 ||
        ! HBBridgePublishSameFile( &original, &current ) || ! HBBridgePublishSameFile( &original, &byName ) ||
        ! HBBridgePublishCompare( file, expected, expectedSize ) )
    {
        status = HB_PUBLISH_CONFLICT;
        goto cleanup;
    }
#if defined( HBBRIDGE_PUBLISH_TEST )
    if( getenv( "HBBRIDGE_TEST_PUBLISH_BEFORE_RENAME" ) ) goto cleanup;
#endif
    if( renameat( dirfd, stageName, dirfd, base ) != 0 ) goto cleanup;
    stageExists = HB_FALSE;
#if defined( HBBRIDGE_PUBLISH_TEST )
    if( getenv( "HBBRIDGE_TEST_PUBLISH_DIRSYNC_FAIL" ) )
    {
        status = HB_PUBLISH_NOT_DURABLE;
        goto cleanup;
    }
#endif
    status = fsync( dirfd ) == 0 ? HB_PUBLISH_OK : HB_PUBLISH_NOT_DURABLE;
cleanup:
    if( stage >= 0 ) close( stage );
    if( stageExists && unlinkat( dirfd, stageName, 0 ) != 0 ) status = HB_PUBLISH_CLEANUP;
    if( file >= 0 ) close( file );
    if( lock >= 0 ) close( lock );
    if( dirfd >= 0 ) close( dirfd );
    if( lockName ) hb_xfree( lockName );
    HBBridgePublishWipe( random, sizeof( random ) );
    return status;
}
#endif

/* Stream enumeration is a test-only building block, not a safety decision. */
#if defined( HB_OS_WIN ) && defined( HBBRIDGE_PUBLISH_TEST )
static WCHAR * HBBridgePublishWindowsPath( const char * path, size_t size )
{
    WCHAR * wide;
    int wideSize;

    if( ! path || size == 0 || strlen( path ) != size || ! hb_cdpUTF8Validate( path, size ) )
        return NULL;
    wideSize = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0 );
    if( wideSize == 0 ) return NULL;
    wide = ( WCHAR * ) hb_xgrab( ( size_t ) wideSize * sizeof( WCHAR ) );
    if( MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, wideSize ) != wideSize )
    {
        hb_xfree( wide );
        return NULL;
    }
    return wide;
}

typedef struct { const char * stage; DWORD code; } HB_AUDIT_DIAGNOSTIC;

static void HBBridgeAuditDiagnostic( HB_AUDIT_DIAGNOSTIC * detail, const char * stage, DWORD code )
{
    if( detail ) { detail->stage = stage; detail->code = code; }
}

/* Reading the SACL is necessary but not sufficient for safe publication. */
static int HBBridgeInspectSecurity( HANDLE file, HB_AUDIT_DIAGNOSTIC * detail )
{
    PSECURITY_DESCRIPTOR descriptor = NULL;
    PACL dacl = NULL, sacl = NULL;
    PSID owner = NULL, group = NULL;
    BOOL present = FALSE, defaulted = FALSE;
    DWORD result;
    int status = HB_PUBLISH_IO;
    result = GetSecurityInfo( file, SE_FILE_OBJECT,
        OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | SACL_SECURITY_INFORMATION,
        &owner, &group, &dacl, &sacl, &descriptor );
    if( result != ERROR_SUCCESS || ! descriptor || ! IsValidSecurityDescriptor( descriptor ) ||
        ! owner || ! IsValidSid( owner ) || ! group || ! IsValidSid( group ) ||
        ( dacl && ! IsValidAcl( dacl ) ) ||
        ! GetSecurityDescriptorSacl( descriptor, &present, &sacl, &defaulted ) ||
        ( present && sacl && ! IsValidAcl( sacl ) ) )
    {
        HBBridgeAuditDiagnostic( detail, result ? "inspect.GetSecurityInfo" : "inspect.validateDescriptor", result );
        goto cleanup;
    }
    status = HB_PUBLISH_OK;
cleanup:
    if( descriptor ) LocalFree( descriptor );
    return status;
}

static int HBBridgeInspectStreams( HANDLE file, DWORD unsupportedAttributes, HB_AUDIT_DIAGNOSTIC * detail )
{
    BY_HANDLE_FILE_INFORMATION info;
    unsigned char * data = NULL;
    DWORD capacity = 4096, offset = 0, streams = 0;
    int status = HB_PUBLISH_INVALID;

    if( ! GetFileInformationByHandle( file, &info ) )
    {
        HBBridgeAuditDiagnostic( detail, "inspect.GetFileInformationByHandle", GetLastError() );
        status = HB_PUBLISH_IO;
        goto cleanup;
    }
    if( info.nNumberOfLinks != 1 || ( info.dwFileAttributes & unsupportedAttributes ) != 0 )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
    for( ;; )
    {
        DWORD error;
        data = ( unsigned char * ) hb_xgrab( capacity );
        memset( data, 0, capacity );
        if( GetFileInformationByHandleEx( file, FileStreamInfo, data, capacity ) ) break;
        error = GetLastError();
        hb_xfree( data );
        data = NULL;
        if( ( error != ERROR_MORE_DATA && error != ERROR_INSUFFICIENT_BUFFER ) || capacity >= 4194304 )
        {
            HBBridgeAuditDiagnostic( detail, "inspect.FileStreamInfo", error );
            status = HB_PUBLISH_IO;
            goto cleanup;
        }
        capacity *= 2;
    }
    for( ;; )
    {
        FILE_STREAM_INFO * entry;
        size_t header = offsetof( FILE_STREAM_INFO, StreamName );
        DWORD next;
        if( offset > capacity || capacity - offset < header )
        {
            status = HB_PUBLISH_IO;
            goto cleanup;
        }
        entry = ( FILE_STREAM_INFO * ) ( data + offset );
        next = entry->NextEntryOffset;
        if( entry->StreamNameLength > capacity - offset - header ||
            ( next && ( next < header || next > capacity - offset ||
                entry->StreamNameLength > next - header ) ) )
        {
            status = HB_PUBLISH_IO;
            goto cleanup;
        }
        streams++;
        if( streams != 1 || entry->StreamNameLength != sizeof( L"::$DATA" ) - sizeof( wchar_t ) ||
            wmemcmp( entry->StreamName, L"::$DATA", 7 ) != 0 )
        {
            status = HB_PUBLISH_UNSAFE;
            goto cleanup;
        }
        if( next == 0 ) break;
        offset += next;
    }
    status = streams == 1 ? HB_PUBLISH_OK : HB_PUBLISH_UNSAFE;
cleanup:
    if( data ) hb_xfree( data );
    return status;
}

enum { HB_METADATA_STREAMS, HB_METADATA_SECURITY, HB_METADATA_COMBINED };

static HB_BOOL HBBridgeDrivePath( const WCHAR * path )
{
    return ( ( path[ 0 ] >= L'A' && path[ 0 ] <= L'Z' ) || ( path[ 0 ] >= L'a' && path[ 0 ] <= L'z' ) ) &&
        path[ 1 ] == L':' && ( path[ 2 ] == L'\\' || path[ 2 ] == L'/' ) && ! wcschr( path + 2, L':' );
}

static int HBBridgeInspectWindowsFile( WCHAR * path, int mode, HB_AUDIT_DIAGNOSTIC * detail )
{
    const DWORD flags = FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS;
    DWORD access = FILE_READ_ATTRIBUTES, share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    DWORD error;
    HANDLE file = INVALID_HANDLE_VALUE;
    HB_BOOL missingPrivilege = HB_FALSE;
    int status = HB_PUBLISH_INVALID;

    if( ! path ) return status;
    if( mode == HB_METADATA_COMBINED )
    {
        /* The combined probe accepts an ordinary drive-qualified path to its unnamed stream. */
        if( ! HBBridgeDrivePath( path ) ) return status;
        access |= FILE_READ_DATA;
        share = FILE_SHARE_READ;
    }
    if( mode != HB_METADATA_STREAMS ) access |= READ_CONTROL | ACCESS_SYSTEM_SECURITY;
    file = CreateFileW( path, access, share, NULL, OPEN_EXISTING, flags, NULL );
    if( file == INVALID_HANDLE_VALUE && mode == HB_METADATA_COMBINED && GetLastError() == ERROR_PRIVILEGE_NOT_HELD )
    {
        /* No initial handle was obtained. Gather only refusal evidence on the fallback handle. */
        missingPrivilege = HB_TRUE;
        file = CreateFileW( path, FILE_READ_ATTRIBUTES | FILE_READ_DATA, share, NULL, OPEN_EXISTING, flags, NULL );
    }
    if( file == INVALID_HANDLE_VALUE )
    {
        error = GetLastError();
        HBBridgeAuditDiagnostic( detail, "inspect.CreateFileW", error );
        if( error == ERROR_PRIVILEGE_NOT_HELD ) return HB_PUBLISH_PRIVILEGE_REQUIRED;
        if( error == ERROR_SHARING_VIOLATION ) return HB_PUBLISH_BUSY;
        return HB_PUBLISH_IO;
    }
    if( mode == HB_METADATA_COMBINED )
    {
        if( GetFileType( file ) != FILE_TYPE_DISK )
            status = HB_PUBLISH_UNSAFE;
        else
            status = HBBridgeInspectStreams( file, ~( FILE_ATTRIBUTE_NORMAL | FILE_ATTRIBUTE_ARCHIVE ), detail );
        if( status == HB_PUBLISH_OK )
            status = missingPrivilege ? HB_PUBLISH_PRIVILEGE_REQUIRED : HBBridgeInspectSecurity( file, detail );
    }
    else
        status = mode == HB_METADATA_SECURITY ? HBBridgeInspectSecurity( file, detail ) :
            HBBridgeInspectStreams( file, FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY, detail );
    CloseHandle( file );
    return status;
}

static void HBBridgeWindowsProbeResult( int mode )
{
    WCHAR * wide = HBBridgePublishWindowsPath( hb_parc( 1 ), hb_parclen( 1 ) );
    int status = HBBridgeInspectWindowsFile( wide, mode, NULL );
    if( wide ) hb_xfree( wide );
    hb_retni( status );
}

HB_FUNC( HBBRIDGECREDENTIALSACLPROBE )
{
    HBBridgeWindowsProbeResult( HB_METADATA_SECURITY );
}

HB_FUNC( HBBRIDGECREDENTIALSTREAMPROBE )
{
    HBBridgeWindowsProbeResult( HB_METADATA_STREAMS );
}

HB_FUNC( HBBRIDGECREDENTIALMETADATAPROBE )
{
    HBBridgeWindowsProbeResult( HB_METADATA_COMBINED );
}

/* Only the explicit audit fixture creates a file. CREATE_NEW prevents editing
 * an existing object. The caller owns the new file in its test directory. */
#define HB_AUDIT_REQUIRE( condition, stageName, errorCode ) \
    do { if( !( condition ) ) { HBBridgeAuditDiagnostic( detail, stageName, errorCode ); goto cleanup; } } while( 0 )

/* Only this test mode returns 10: a rename completed but verification or
 * restoration failed. No retry may interpret this result as non-publication. */
#define HB_AUDIT_PUBLISHED_UNVERIFIED 10

/* The fixture owns the parent directory. NTFS renames a directory entry,
 * so a preflight identity check cannot exclude a non-cooperating rename. */
static PSECURITY_DESCRIPTOR HBBridgeAuditDescriptor( HANDLE file, DWORD * size )
{
    const SECURITY_INFORMATION parts = OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION |
        DACL_SECURITY_INFORMATION | SACL_SECURITY_INFORMATION;
    PSECURITY_DESCRIPTOR descriptor;
    DWORD needed = 0, used = 0;
    if( GetKernelObjectSecurity( file, parts, NULL, 0, &needed ) ||
        GetLastError() != ERROR_INSUFFICIENT_BUFFER || ! needed || needed > 262144 ) return NULL;
    descriptor = ( PSECURITY_DESCRIPTOR ) hb_xgrabz( needed );
    if( ! GetKernelObjectSecurity( file, parts, descriptor, needed, &used ) || used != needed ||
        ! IsValidSecurityDescriptor( descriptor ) )
    {
        hb_xfree( descriptor );
        return NULL;
    }
    *size = used;
    return descriptor;
}

static HB_BOOL HBBridgeAuditSameFile( const BY_HANDLE_FILE_INFORMATION * a, const BY_HANDLE_FILE_INFORMATION * b )
{
    return a->dwVolumeSerialNumber == b->dwVolumeSerialNumber &&
        a->nFileIndexHigh == b->nFileIndexHigh && a->nFileIndexLow == b->nFileIndexLow;
}

static HB_BOOL HBBridgeAuditHasBytes( HANDLE file, const char * expected )
{
    BYTE buffer[ 64 ];
    DWORD count;
    LARGE_INTEGER zero;
    size_t length = strlen( expected );
    zero.QuadPart = 0;
    return length < sizeof( buffer ) && SetFilePointerEx( file, zero, NULL, FILE_BEGIN ) &&
        ReadFile( file, buffer, sizeof( buffer ), &count, NULL ) && count == length &&
        memcmp( buffer, expected, length ) == 0;
}

static int HBBridgeReplaceAuditFixture( WCHAR * path, HANDLE original, const char * originalBytes,
    HB_AUDIT_DIAGNOSTIC * detail )
{
    /* FileRenameInfoEx is value 22; older SDK target levels hide its enum
     * and DWORD Flags member. The remaining layout matches FILE_RENAME_INFO. */
    typedef struct { DWORD flags; HANDLE root; DWORD nameBytes; WCHAR name[ 1 ]; } HB_RENAME_EX;
    const DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    const DWORD access = GENERIC_READ | READ_CONTROL | ACCESS_SYSTEM_SECURITY;
    const char replacement[] = "[fixture]\r\nrevision=2\r\n";
    SECURITY_ATTRIBUTES attributes = { sizeof( SECURITY_ATTRIBUTES ), NULL, FALSE };
    FILE_DISPOSITION_INFO disposition = { TRUE };
    BY_HANDLE_FILE_INFORMATION prior, staged, observed;
    PSECURITY_DESCRIPTOR source = NULL, stageSD = NULL, finalSD = NULL;
    DWORD sourceSize = 0, stageSize = 0, finalSize = 0, count = 0, revision;
    SECURITY_DESCRIPTOR_CONTROL control;
    WCHAR filesystem[ 32 ];
    HANDLE stage = INVALID_HANDLE_VALUE, check = INVALID_HANDLE_VALUE;
    size_t chars = wcslen( path ), bytes = chars * sizeof( WCHAR );
    WCHAR * stagePath = NULL;
    HB_RENAME_EX * rename = NULL;
    DWORD renameSize;
    HB_BOOL published = HB_FALSE;
    int status = HB_PUBLISH_IO;

    HB_AUDIT_REQUIRE( chars < 32760, "replace.pathLength", 0 );
    HB_AUDIT_REQUIRE( GetVolumeInformationByHandleW( original, NULL, 0, NULL, NULL, NULL, filesystem, 32 ),
        "replace.volumeInfo", GetLastError() );
    HB_AUDIT_REQUIRE( wcscmp( filesystem, L"NTFS" ) == 0, "replace.requiresNTFS", 0 );
    HB_AUDIT_REQUIRE( HBBridgeInspectStreams( original, ~( FILE_ATTRIBUTE_NORMAL | FILE_ATTRIBUTE_ARCHIVE ), detail )
        == HB_PUBLISH_OK, "replace.sourceStreams", 0 );
    HB_AUDIT_REQUIRE( GetFileInformationByHandle( original, &prior ), "replace.sourceInfo", GetLastError() );
    HB_AUDIT_REQUIRE( prior.nFileIndexHigh || prior.nFileIndexLow, "replace.sourceIdentity", 0 );
    source = HBBridgeAuditDescriptor( original, &sourceSize );
    HB_AUDIT_REQUIRE( source, "replace.sourceDescriptor", GetLastError() );
    HB_AUDIT_REQUIRE( GetSecurityDescriptorControl( source, &control, &revision ), "replace.getControl", GetLastError() );
    HB_AUDIT_REQUIRE( ( control & SE_DACL_PROTECTED ) && ( control & SE_SACL_PROTECTED ), "replace.protectedACLs", 0 );
    attributes.lpSecurityDescriptor = source;
    stagePath = ( WCHAR * ) hb_xgrab( bytes + sizeof( L".stage" ) );
    memcpy( stagePath, path, bytes );
    memcpy( stagePath + chars, L".stage", sizeof( L".stage" ) );
    stage = CreateFileW( stagePath, access | GENERIC_WRITE | DELETE, FILE_SHARE_READ, &attributes, CREATE_NEW,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_ATTRIBUTE_NORMAL, NULL );
    HB_AUDIT_REQUIRE( stage != INVALID_HANDLE_VALUE, "replace.createStage", GetLastError() );
    stageSD = HBBridgeAuditDescriptor( stage, &stageSize );
    HB_AUDIT_REQUIRE( stageSD, "replace.stageDescriptor", GetLastError() );
    HB_AUDIT_REQUIRE( sourceSize == stageSize && memcmp( source, stageSD, sourceSize ) == 0,
        "replace.stageDescriptorMismatch", 0 );
    HB_AUDIT_REQUIRE( WriteFile( stage, replacement, sizeof( replacement ) - 1, &count, NULL ) &&
        count == sizeof( replacement ) - 1, "replace.writeStage", GetLastError() );
    HB_AUDIT_REQUIRE( FlushFileBuffers( stage ), "replace.flushStage", GetLastError() );
    HB_AUDIT_REQUIRE( HBBridgeInspectStreams( stage, ~( FILE_ATTRIBUTE_NORMAL | FILE_ATTRIBUTE_ARCHIVE ), detail )
        == HB_PUBLISH_OK, "replace.stageStreams", 0 );
    HB_AUDIT_REQUIRE( GetFileInformationByHandle( stage, &staged ), "replace.stageInfo", GetLastError() );
    HB_AUDIT_REQUIRE( ( staged.nFileIndexHigh || staged.nFileIndexLow ) &&
        ! HBBridgeAuditSameFile( &prior, &staged ), "replace.stageIdentity", 0 );
    check = CreateFileW( path, GENERIC_READ, share, NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL );
    HB_AUDIT_REQUIRE( check != INVALID_HANDLE_VALUE, "replace.preflightOpen", GetLastError() );
    HB_AUDIT_REQUIRE( GetFileInformationByHandle( check, &observed ) && HBBridgeAuditSameFile( &prior, &observed ) &&
        HBBridgeAuditHasBytes( check, originalBytes ), "replace.preflightSnapshot", 0 );
    CloseHandle( check );
    check = INVALID_HANDLE_VALUE;

    renameSize = ( DWORD ) ( offsetof( HB_RENAME_EX, name ) + bytes + sizeof( WCHAR ) );
    rename = ( HB_RENAME_EX * ) hb_xgrabz( renameSize );
    rename->flags = 0x1 | 0x2; /* REPLACE_IF_EXISTS | POSIX_SEMANTICS */
    rename->nameBytes = ( DWORD ) bytes;
    memcpy( rename->name, path, bytes );
    HB_AUDIT_REQUIRE( SetFileInformationByHandle( stage, ( FILE_INFO_BY_HANDLE_CLASS ) 22,
        rename, renameSize ), "replace.FileRenameInfoEx", GetLastError() );
    published = HB_TRUE;
    HB_AUDIT_REQUIRE( HBBridgeAuditHasBytes( original, originalBytes ), "published.originalReader", 0 );
    check = CreateFileW( path, access, share, NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL );
    HB_AUDIT_REQUIRE( check != INVALID_HANDLE_VALUE, "published.open", GetLastError() );
    HB_AUDIT_REQUIRE( GetFileInformationByHandle( check, &observed ) && HBBridgeAuditSameFile( &staged, &observed ) &&
        HBBridgeAuditHasBytes( check, replacement ), "published.identityAndBytes", 0 );
    finalSD = HBBridgeAuditDescriptor( check, &finalSize );
    HB_AUDIT_REQUIRE( finalSD, "published.descriptor", GetLastError() );
    HB_AUDIT_REQUIRE( finalSize == sourceSize && memcmp( finalSD, source, sourceSize ) == 0,
        "published.descriptorMismatch", 0 );
    HBBridgeAuditDiagnostic( detail, "complete", 0 );
    status = HB_PUBLISH_OK;
cleanup:
    if( check != INVALID_HANDLE_VALUE ) CloseHandle( check );
    if( stage != INVALID_HANDLE_VALUE )
    {
        if( ! published && ! SetFileInformationByHandle( stage, FileDispositionInfo, &disposition, sizeof( disposition ) ) )
        {
            HBBridgeAuditDiagnostic( detail, "cleanup.stage", GetLastError() );
            status = HB_PUBLISH_CLEANUP;
        }
        CloseHandle( stage );
    }
    if( rename ) hb_xfree( rename );
    if( stagePath ) hb_xfree( stagePath );
    if( finalSD ) hb_xfree( finalSD );
    if( stageSD ) hb_xfree( stageSD );
    if( source ) hb_xfree( source );
    return published && status != HB_PUBLISH_OK ? HB_AUDIT_PUBLISHED_UNVERIFIED : status;
}

static int HBBridgeCheckAuditFixture( WCHAR * path, HB_BOOL replace, HB_AUDIT_DIAGNOSTIC * detail )
{
    const char * contents = replace ? "[fixture]\r\nrevision=1\r\n" : "synthetic audit fixture";
    DWORD length = ( DWORD ) strlen( contents );
    SECURITY_ATTRIBUTES attributes = { sizeof( SECURITY_ATTRIBUTES ), NULL, FALSE };
    const DWORD security = SACL_SECURITY_INFORMATION | PROTECTED_SACL_SECURITY_INFORMATION;
    PSECURITY_DESCRIPTOR supplied = NULL, first = NULL, last = NULL;
    PACL source = NULL, before = NULL, after = NULL;
    SYSTEM_AUDIT_ACE * ace;
    BOOL present, defaulted;
    SECURITY_DESCRIPTOR_CONTROL control;
    DWORD revision, written, result;
    HANDLE file = INVALID_HANDLE_VALUE;
    int status = HB_PUBLISH_IO;

    HB_AUDIT_REQUIRE( ConvertStringSecurityDescriptorToSecurityDescriptorW(
        replace ? L"D:P(A;;FA;;;OW)(A;;FA;;;SY)S:P(AU;SA;0x1;;;WD)" : L"S:P(AU;SA;0x1;;;WD)",
        SDDL_REVISION_1, &supplied, NULL ), "fixture.parseSDDL", GetLastError() );
    HB_AUDIT_REQUIRE( GetSecurityDescriptorSacl( supplied, &present, &source, &defaulted ),
        "fixture.GetSecurityDescriptorSacl", GetLastError() );
    HB_AUDIT_REQUIRE( present && source, "fixture.sourceSACL", 0 );
    attributes.lpSecurityDescriptor = supplied;
    file = CreateFileW( path, GENERIC_WRITE | READ_CONTROL | ACCESS_SYSTEM_SECURITY | ( replace ? GENERIC_READ : 0 ),
        replace ? FILE_SHARE_READ | FILE_SHARE_DELETE : 0, replace ? &attributes : NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL );
    HB_AUDIT_REQUIRE( file != INVALID_HANDLE_VALUE, "fixture.CreateFileW", GetLastError() );
    HB_AUDIT_REQUIRE( WriteFile( file, contents, length, &written, NULL ),
        "fixture.WriteFile", GetLastError() );
    HB_AUDIT_REQUIRE( written == length, "fixture.shortWrite", 0 );
    result = SetSecurityInfo( file, SE_FILE_OBJECT, security, NULL, NULL, NULL, source );
    HB_AUDIT_REQUIRE( result == ERROR_SUCCESS, "fixture.SetSecurityInfo", result );
    result = GetSecurityInfo( file, SE_FILE_OBJECT, SACL_SECURITY_INFORMATION, NULL, NULL, NULL, &before, &first );
    HB_AUDIT_REQUIRE( result == ERROR_SUCCESS, "before.GetSecurityInfo", result );
    HB_AUDIT_REQUIRE( before && IsValidAcl( before ), "before.validSACL", 0 );
    HB_AUDIT_REQUIRE( GetSecurityDescriptorControl( first, &control, &revision ), "before.getControl", GetLastError() );
    HB_AUDIT_REQUIRE( control & SE_SACL_PROTECTED, "before.protected", 0 );
    HB_AUDIT_REQUIRE( before->AceCount == 1, "before.aceCount", 0 );
    HB_AUDIT_REQUIRE( GetAce( before, 0, ( void ** ) &ace ), "before.GetAce", GetLastError() );
    HB_AUDIT_REQUIRE( ace->Header.AceType == SYSTEM_AUDIT_ACE_TYPE, "before.auditType", 0 );
    HB_AUDIT_REQUIRE( ace->Header.AceFlags == SUCCESSFUL_ACCESS_ACE_FLAG, "before.auditFlags", 0 );
    HB_AUDIT_REQUIRE( ace->Mask == FILE_READ_DATA, "before.auditMask", 0 );
    HB_AUDIT_REQUIRE( IsWellKnownSid( &ace->SidStart, WinWorldSid ), "before.auditTrustee", 0 );
    if( replace )
    {
        status = HBBridgeReplaceAuditFixture( path, file, contents, detail );
        goto cleanup;
    }
    CloseHandle( file );
    file = INVALID_HANDLE_VALUE;
    HBBridgeAuditDiagnostic( detail, "inspect.metadata", 0 );
    status = HBBridgeInspectWindowsFile( path, HB_METADATA_COMBINED, detail );
    if( status != HB_PUBLISH_OK ) goto cleanup;
    status = HB_PUBLISH_IO;
    file = CreateFileW( path, READ_CONTROL | ACCESS_SYSTEM_SECURITY, FILE_SHARE_READ, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT, NULL );
    HB_AUDIT_REQUIRE( file != INVALID_HANDLE_VALUE, "after.CreateFileW", GetLastError() );
    result = GetSecurityInfo( file, SE_FILE_OBJECT, SACL_SECURITY_INFORMATION, NULL, NULL, NULL, &after, &last );
    HB_AUDIT_REQUIRE( result == ERROR_SUCCESS, "after.GetSecurityInfo", result );
    HB_AUDIT_REQUIRE( after && IsValidAcl( after ), "after.validSACL", 0 );
    HB_AUDIT_REQUIRE( GetSecurityDescriptorControl( last, &control, &revision ), "after.getControl", GetLastError() );
    HB_AUDIT_REQUIRE( control & SE_SACL_PROTECTED, "after.protected", 0 );
    HB_AUDIT_REQUIRE( before->AclSize == after->AclSize, "after.aclSize", 0 );
    HB_AUDIT_REQUIRE( memcmp( before, after, before->AclSize ) == 0, "after.aclBytes", 0 );
    HBBridgeAuditDiagnostic( detail, "complete", 0 );
    status = HB_PUBLISH_OK;
cleanup:
    if( file != INVALID_HANDLE_VALUE ) CloseHandle( file );
    if( last ) LocalFree( last );
    if( first ) LocalFree( first );
    if( supplied ) LocalFree( supplied );
    return status;
}

HB_FUNC( HBBRIDGECREDENTIALAUDITFIXTURE )
{
    HB_AUDIT_DIAGNOSTIC diagnostic = { "fixture.path", 0 };
    HB_AUDIT_DIAGNOSTIC * detail = &diagnostic;
    WCHAR * path = HBBridgePublishWindowsPath( hb_parc( 1 ), hb_parclen( 1 ) );
    const WCHAR * base;
    HANDLE token = NULL;
    TOKEN_PRIVILEGES requested, previous;
    DWORD size, error;
    BOOL adjusted = FALSE, impersonated = FALSE;
    HB_BOOL replace = hb_parl( 4 ), published = HB_FALSE;
    int status = HB_PUBLISH_INVALID;

    if( ! path || ! HBBridgeDrivePath( path ) ) goto cleanup;
    base = wcsrchr( path, L'\\' );
    if( ! base || wcscmp( base + 1,
        replace ? L"hbbridge-audit-replace.ini" : L"hbbridge-audit-fixture.ini" ) != 0 ) goto cleanup;
    status = HB_PUBLISH_IO;
    /* Use a private thread token in this standalone probe; preserve a caller
     * that is already impersonating by refusing to change its token. */
    if( OpenThreadToken( GetCurrentThread(), TOKEN_QUERY, TRUE, &token ) )
    {
        HBBridgeAuditDiagnostic( detail, "token.alreadyImpersonating", 0 );
        goto cleanup;
    }
    error = GetLastError();
    HB_AUDIT_REQUIRE( error == ERROR_NO_TOKEN, "token.queryOriginal", error );
    HB_AUDIT_REQUIRE( ImpersonateSelf( SecurityImpersonation ), "token.ImpersonateSelf", GetLastError() );
    impersonated = TRUE;
    HB_AUDIT_REQUIRE( OpenThreadToken( GetCurrentThread(), TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES, TRUE, &token ),
        "token.OpenThreadToken", GetLastError() );
    HB_AUDIT_REQUIRE( LookupPrivilegeValueW( NULL, L"SeSecurityPrivilege", &requested.Privileges[ 0 ].Luid ),
        "token.LookupPrivilegeValueW", GetLastError() );
    requested.PrivilegeCount = 1;
    requested.Privileges[ 0 ].Attributes = SE_PRIVILEGE_ENABLED;
    SetLastError( ERROR_SUCCESS );
    adjusted = AdjustTokenPrivileges( token, FALSE, &requested, sizeof( previous ), &previous, &size );
    error = GetLastError();
    HB_AUDIT_REQUIRE( adjusted, "token.AdjustTokenPrivileges", error );
    if( error == ERROR_NOT_ALL_ASSIGNED ) status = HB_PUBLISH_PRIVILEGE_REQUIRED;
    HB_AUDIT_REQUIRE( error == ERROR_SUCCESS, "token.enablePrivilege", error );
    status = HBBridgeCheckAuditFixture( path, replace, detail );
    published = replace && ( status == HB_PUBLISH_OK || status == HB_AUDIT_PUBLISHED_UNVERIFIED );
cleanup:
    if( adjusted && previous.PrivilegeCount > 0 )
    {
        SetLastError( ERROR_SUCCESS );
        if( ! AdjustTokenPrivileges( token, FALSE, &previous, 0, NULL, NULL ) || GetLastError() != ERROR_SUCCESS )
        {
            HBBridgeAuditDiagnostic( detail, "token.restorePrivilege", GetLastError() );
            status = published ? HB_AUDIT_PUBLISHED_UNVERIFIED : HB_PUBLISH_IO;
        }
    }
    if( token ) CloseHandle( token );
    if( impersonated && ! RevertToSelf() )
    {
        HBBridgeAuditDiagnostic( detail, "token.RevertToSelf", GetLastError() );
        status = published ? HB_AUDIT_PUBLISHED_UNVERIFIED : HB_PUBLISH_IO;
    }
    if( path ) hb_xfree( path );
    hb_storc( diagnostic.stage, 2 );
    hb_stornint( ( HB_MAXINT ) diagnostic.code, 3 );
    hb_retni( status );
}
#endif

static HB_BOOL HBBridgeCredentialPathValid( const char * path, size_t size )
{
    return path && size > 0 && strlen( path ) == size && hb_cdpUTF8Validate( path, size );
}

HB_FUNC( HBBRIDGECREDENTIALSNAPSHOT )
{
    const char * path = hb_parc( 1 );
    int status = HB_PUBLISH_INVALID;

    if( HBBridgeCredentialPathValid( path, hb_parclen( 1 ) ) )
    {
#if defined( HB_OS_LINUX )
        status = HBBridgeCredentialReadSnapshot( path );
#else
        status = HB_PUBLISH_UNSUPPORTED;
#endif
    }
    if( status != HB_PUBLISH_OK ) hb_ret();
    hb_storni( status, 2 );
}

/* This primitive is deliberately not registered as a network service. */
HB_FUNC( HBBRIDGECREDENTIALPUBLISH )
{
    const char * path = hb_parc( 1 );
    const unsigned char * expected = ( const unsigned char * ) hb_parc( 2 );
    const unsigned char * replacement = ( const unsigned char * ) hb_parc( 3 );
    size_t pathSize = hb_parclen( 1 );
    size_t expectedSize = hb_parclen( 2 );
    size_t replacementSize = hb_parclen( 3 );
    int status = HB_PUBLISH_INVALID;

    if( HBBridgeCredentialPathValid( path, pathSize ) &&
        expected && expectedSize > 0 && replacement && replacementSize > 0 )
    {
#if defined( HB_OS_LINUX )
        status = HBBridgePublishLinux( path, expected, expectedSize, replacement, replacementSize );
#else
        status = HB_PUBLISH_UNSUPPORTED;
#endif
    }
    hb_storni( status, 4 );
    hb_retl( status == HB_PUBLISH_OK );
}
