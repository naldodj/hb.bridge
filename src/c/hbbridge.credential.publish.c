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

/* Reading the SACL is necessary but not sufficient for safe publication. */
HB_FUNC( HBBRIDGECREDENTIALSACLPROBE )
{
    WCHAR * wide = HBBridgePublishWindowsPath( hb_parc( 1 ), hb_parclen( 1 ) );
    HANDLE file = INVALID_HANDLE_VALUE;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    PACL dacl = NULL, sacl = NULL;
    PSID owner = NULL, group = NULL;
    BOOL present = FALSE, defaulted = FALSE;
    DWORD result;
    int status = HB_PUBLISH_INVALID;

    if( ! wide ) goto cleanup;
    file = CreateFileW( wide, READ_CONTROL | ACCESS_SYSTEM_SECURITY | FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL );
    if( file == INVALID_HANDLE_VALUE )
    {
        result = GetLastError();
        status = result == ERROR_PRIVILEGE_NOT_HELD ? HB_PUBLISH_PRIVILEGE_REQUIRED : HB_PUBLISH_IO;
        goto cleanup;
    }
    result = GetSecurityInfo( file, SE_FILE_OBJECT,
        OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | SACL_SECURITY_INFORMATION,
        &owner, &group, &dacl, &sacl, &descriptor );
    if( result != ERROR_SUCCESS || ! descriptor || ! IsValidSecurityDescriptor( descriptor ) ||
        ! owner || ! IsValidSid( owner ) || ! group || ! IsValidSid( group ) ||
        ( dacl && ! IsValidAcl( dacl ) ) ||
        ! GetSecurityDescriptorSacl( descriptor, &present, &sacl, &defaulted ) ||
        ( present && sacl && ! IsValidAcl( sacl ) ) )
    {
        status = HB_PUBLISH_IO;
        goto cleanup;
    }
    status = HB_PUBLISH_OK;
cleanup:
    if( descriptor ) LocalFree( descriptor );
    if( file != INVALID_HANDLE_VALUE ) CloseHandle( file );
    if( wide ) hb_xfree( wide );
    hb_retni( status );
}

HB_FUNC( HBBRIDGECREDENTIALSTREAMPROBE )
{
    const char * path = hb_parc( 1 );
    size_t pathSize = hb_parclen( 1 );
    WCHAR * wide = HBBridgePublishWindowsPath( path, pathSize );
    HANDLE file = INVALID_HANDLE_VALUE;
    BY_HANDLE_FILE_INFORMATION info;
    unsigned char * data = NULL;
    DWORD capacity = 4096, offset = 0, streams = 0;
    int status = HB_PUBLISH_INVALID;

    if( ! wide ) goto cleanup;
    file = CreateFileW( wide, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL );
    if( file == INVALID_HANDLE_VALUE || ! GetFileInformationByHandle( file, &info ) )
    {
        status = HB_PUBLISH_IO;
        goto cleanup;
    }
    if( info.nNumberOfLinks != 1 ||
        ( info.dwFileAttributes & ( FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY ) ) != 0 )
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
    if( file != INVALID_HANDLE_VALUE ) CloseHandle( file );
    if( wide ) hb_xfree( wide );
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
