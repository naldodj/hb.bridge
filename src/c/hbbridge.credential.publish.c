/* Released to Public Domain. Restricted, cooperative file publication probe. */
#if ! defined( _WIN32 ) && ! defined( _GNU_SOURCE )
    #define _GNU_SOURCE
#endif
#include "hbapi.h"
#include "hbapicdp.h"
#include <stddef.h>
#include <string.h>

#if defined( HB_OS_LINUX )
    #include <errno.h>
    #include <fcntl.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <sys/file.h>
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
    HB_PUBLISH_NOT_DURABLE = 8
};

#if defined( HB_OS_LINUX )
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

static int HBBridgePublishLinux( const char * path, const unsigned char * expected, size_t expectedSize,
    const unsigned char * replacement, size_t replacementSize )
{
    const char * slash = strrchr( path, '/' );
    const char * base;
    const char hex[] = "0123456789abcdef";
    const char lockSuffix[] = ".hbbridge.lock";
    const char stagePrefix[] = ".hbbridge-stage-";
    unsigned char random[ 16 ] = { 0 };
    char stageName[ sizeof( stagePrefix ) + 32 ] = { 0 };
    char * parent = NULL, * lockName = NULL;
    size_t parentLength, baseLength, index, offset = 0;
    struct stat directory, original, current, byName, staging, lockInfo;
    int dirfd = -1, file = -1, lock = -1, stage = -1, status = HB_PUBLISH_IO;
    HB_BOOL stageExists = HB_FALSE;

    if( path[ 0 ] != '/' || ! slash || ! slash[ 1 ] ) return HB_PUBLISH_INVALID;
    base = slash + 1;
    baseLength = strlen( base );
    if( ! strcmp( base, "." ) || ! strcmp( base, ".." ) ||
        baseLength > ( size_t ) -1 - sizeof( lockSuffix ) ) return HB_PUBLISH_INVALID;
    parentLength = slash == path ? 1 : ( size_t ) ( slash - path );
    parent = ( char * ) hb_xgrab( parentLength + 1 );
    memcpy( parent, path, parentLength );
    parent[ parentLength ] = '\0';
    lockName = ( char * ) hb_xgrab( baseLength + sizeof( lockSuffix ) );
    memcpy( lockName, base, baseLength );
    memcpy( lockName + baseLength, lockSuffix, sizeof( lockSuffix ) );

    dirfd = open( parent, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW );
    if( dirfd < 0 || fstat( dirfd, &directory ) != 0 || ! S_ISDIR( directory.st_mode ) ||
        ( directory.st_mode & ( S_IWGRP | S_IWOTH ) ) != 0 ||
        ( directory.st_uid != geteuid() && directory.st_uid != 0 ) )
    {
        status = HB_PUBLISH_UNSAFE;
        goto cleanup;
    }
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
    file = openat( dirfd, base, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK );
    if( file < 0 || fstat( file, &original ) != 0 || ! S_ISREG( original.st_mode ) ||
        original.st_nlink != 1 || original.st_uid != geteuid() ||
        ( original.st_mode & ( 07000 | S_IWGRP | S_IWOTH ) ) != 0 ||
        flistxattr( file, NULL, 0 ) != 0 )
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
        ( staging.st_mode & ( S_IRWXG | S_IRWXO ) ) != 0 || flistxattr( stage, NULL, 0 ) != 0 )
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
        ( staging.st_mode & 07777 ) != ( original.st_mode & 07777 ) || flistxattr( stage, NULL, 0 ) != 0 ) goto cleanup;
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
    if( parent ) hb_xfree( parent );
    HBBridgePublishWipe( random, sizeof( random ) );
    return status;
}
#endif

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

    if( path && pathSize > 0 && strlen( path ) == pathSize && hb_cdpUTF8Validate( path, pathSize ) &&
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
