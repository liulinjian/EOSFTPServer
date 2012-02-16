/*******************************************************************************
 * Copyright (c) 2012, Jean-David Gadina <macmade@eosgarden.com>
 * Distributed under the Boost Software License, Version 1.0.
 * 
 * Boost Software License - Version 1.0 - August 17th, 2003
 * 
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 * 
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 * FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 ******************************************************************************/

/* $Id$ */

/*!
 * @file            ...
 * @author          Jean-David Gadina <macmade@eosgarden>
 * @copyright       (c) 2012, eosgarden
 * @abstract        ...
 */

/*******************************************************************************
 * Copyright notice:
 * 
 * This file is based AsyncSocket project, originally created by Dustin Voss,
 * updated and maintained by Deusty Designs and the Mac development community.
 * 
 * The original project is placed in the public domain, and available
 * in GitHub: https://github.com/robbiehanson/CocoaAsyncSocket
 ******************************************************************************/

#import "EOSSocket+Private.h"

static void __CFSocketCallBack( CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void * data, void * info );
static void __CFReadStreamClientCallBack( CFReadStreamRef stream, CFStreamEventType type, void * info );
static void __CFWriteStreamClientCallBack( CFWriteStreamRef stream, CFStreamEventType type, void * info );

static void __CFSocketCallBack( CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void * data, void * info )
{
    EOSSocket * s;
    
    @autoreleasepool
    {
        s = [ [ ( EOSSocket * )info retain ] autorelease ];
        
        [ s CFSocketCallBack: type socket: socket address: address data: data ];
    }
}

static void __CFReadStreamClientCallBack( CFReadStreamRef stream, CFStreamEventType type, void * info )
{
    EOSSocket * s;
    
    @autoreleasepool
    {
        s = [ [ ( EOSSocket * )info retain ] autorelease ];
        
        [ s CFReadStreamClientCallback: type stream: stream ];
    }	
}

static void __CFWriteStreamClientCallBack( CFWriteStreamRef stream, CFStreamEventType type, void * info )
{
    EOSSocket * s;
    
    @autoreleasepool
    {
        s = [ [ ( EOSSocket * )info retain ] autorelease ];
        
        [ s CFWriteStreamClientCallback: type stream: stream ];
    }
}

@implementation EOSSocket( Private )

- ( CFSocketRef )createAcceptSocketForAddress: ( struct sockaddr * )address error: ( NSError ** )error
{
    CFSocketRef socket;
    sa_family_t family;
    
    if( address == NULL )
    {
        return NULL;
    }
    
    family = address->sa_family;
    socket = CFSocketCreate
    (
        kCFAllocatorDefault,
        family,
        SOCK_STREAM,
        0,
        kCFSocketAcceptCallBack,
        ( CFSocketCallBack )&__CFSocketCallBack,
        &_socketContext
    );
    
    if( socket == NULL && error != NULL )
    {
        *( error ) = [ NSError errorWithDomain: @"EOSSocketError" code: EOSSocketErrorCFSocket userInfo: nil ];
    }
    
    return socket;
}

- ( BOOL )attachSocketsToRunLoop: ( NSRunLoop * )runLoop error: ( NSError ** )error
{
    if( error != NULL )
    {
        *( error ) = nil;
    }
    
    _runLoop = ( runLoop == nil ) ? CFRunLoopGetCurrent() : [ runLoop getCFRunLoop ];
    
    if( _ipv4Socket != nil )
    {
        _ipv4Source = CFSocketCreateRunLoopSource( kCFAllocatorDefault, _ipv4Socket, 0 );
        
        CFRunLoopAddSource( _runLoop, _ipv4Source, kCFRunLoopDefaultMode );
    }
    
    if( _ipv6Socket != nil )
    {
        _ipv6Source = CFSocketCreateRunLoopSource( kCFAllocatorDefault, _ipv6Socket, 0 );
        
        CFRunLoopAddSource( _runLoop, _ipv6Source, kCFRunLoopDefaultMode );
    }
    
    return YES;
}

- ( void )CFSocketCallBack: ( CFSocketCallBackType )type socket: ( CFSocketRef )socket address: ( CFDataRef )address data: ( const void * )data
{
    ( void )address;
    
    if( socket != _ipv4Socket || socket != _ipv6Socket )
    {
        @throw [ NSException exceptionWithName: EOSSocketException reason: @"Wrong CFSocket object" userInfo: nil ];
    }
    
    switch( type )
    {
        case kCFSocketConnectCallBack:
            
            if( data != NULL )
            {
                [ self openSocket: socket withCFSocketError: kCFSocketError ];
            }
            else
            {
                [ self openSocket: socket withCFSocketError: kCFSocketSuccess ];
            }
            
            break;
            
        case kCFSocketAcceptCallBack:
            
            [ self acceptSocket: ( CFSocketNativeHandle )( *( ( CFSocketNativeHandle * )data ) ) ];
            break;
            
        default:
            
            @throw [ NSException exceptionWithName: EOSSocketException reason: @"Unexpected CFSocketCallBackType" userInfo: nil ];
            break;
    }
}

- ( void )CFReadStreamClientCallback: ( CFStreamEventType )type stream: ( CFReadStreamRef )stream
{
    CFStreamError error;
    
    ( void )stream;
    
    if( _readStream == NULL )
    {
        @throw [ NSException exceptionWithName: EOSSocketException reason: @"No read stream" userInfo: nil ];
    }
    
    switch( type )
    {
        case kCFStreamEventOpenCompleted:
            
            [ self openStream ];
            break;
            
        case kCFStreamEventHasBytesAvailable:
            
            [ self bytesAvailable ];
            break;
            
        case kCFStreamEventErrorOccurred:
            
            error = CFReadStreamGetError( _readStream );
            
            [ self closeWithError: [ self errorFromCFStreamError: error ] ];
            break;
            
        default:
            
            @throw [ NSException exceptionWithName: EOSSocketException reason: @"Unexpected CFStreamEventType" userInfo: nil ];
            break;
    }
}

- ( void )CFWriteStreamClientCallback: ( CFStreamEventType )type stream: ( CFWriteStreamRef )stream
{
    CFStreamError error;
    
    ( void )stream;
    
    if( _readStream == NULL )
    {
        @throw [ NSException exceptionWithName: EOSSocketException reason: @"No write stream" userInfo: nil ];
    }
    
    switch( type )
    {
        case kCFStreamEventOpenCompleted:
            
            [ self openStream ];
            break;
            
        case kCFStreamEventCanAcceptBytes:
            
            [ self sendBytes ];
            break;
            
        case kCFStreamEventErrorOccurred:
        case kCFStreamEventEndEncountered:
        
            error = CFWriteStreamGetError( _writeStream );
            
            [ self closeWithError: [ self errorFromCFStreamError: error ] ];
            break;
            
        default:
            
            @throw [ NSException exceptionWithName: EOSSocketException reason: @"Unexpected CFStreamEventType" userInfo: nil ];
            break;
    }
}

- ( void )openSocket: ( CFSocketRef )socket withCFSocketError: ( CFSocketError )socketError
{
    BOOL                 status;
    CFSocketNativeHandle nativeSocket;
    NSError            * error;
    
    error = nil;
    
    if( socket != _ipv4Socket || socket != _ipv6Socket )
    {
        @throw [ NSException exceptionWithName: EOSSocketException reason: @"Wrong CFSocket object" userInfo: nil ];
    }
    
    if( socketError == kCFSocketTimeout )
    {
        [ self closeWithError: [ NSError errorWithDomain: EOSSocketException code: socketError userInfo: nil ] ];
        
        return;
    }
    else if( socketError == kCFSocketError )
    {
        [ self closeWithError: [ NSError errorWithDomain: EOSSocketException code: socketError userInfo: nil ] ];
        
        return;
    }
    
    nativeSocket = CFSocketGetNative( socket );
    
    CFSocketSetSocketFlags( socket, 0);
    
    CFSocketInvalidate( socket );
    CFRelease( socket );
    
    _ipv4Socket = NULL;
    _ipv6Socket = NULL;
    status      = YES;
    
    if( status == YES && [ self createStreamsFromNative: nativeSocket error: &error ] == NO )
    {
        status = NO;
    }
    
    if( status == YES && [ self attachStreamsToRunLoop: nil error: &error ] == NO )
    {
        status = NO;
    }
    
    if( status == YES && [ self openStreamsAndReturnError: &error ] == NO )
    {
        status = NO;
    }
    
    if( status == NO )
    {
        [ self closeWithError: error ];
    }
}

- ( void )acceptSocket: ( CFSocketNativeHandle )handle
{
    BOOL        status;
    EOSSocket * newSocket;
    NSRunLoop * runLoop;
    
    newSocket = [ EOSSocket new ];
    runLoop   = nil;
    
    if( newSocket != nil )
    {
        [ newSocket autorelease ];
        
        newSocket.delegate = _delegate;
        
        if( [ _delegate respondsToSelector: @selector( socket: didAcceptNewSocket: ) ] )
        {
            [ _delegate socket: self didAcceptNewSocket: newSocket ];
        }
        
        if( [ _delegate respondsToSelector: @selector( socket: runLoopForNewSocket: ) ] )
        {
            runLoop = [ _delegate socket: self runLoopForNewSocket: newSocket ];
        }
        
        status = YES;
        
        if( status == YES && [ newSocket createStreamsFromNativeSocketHandle: handle error: NULL ] == NO )
        {
            status = NO;
        }
        
        if( status == YES && [ newSocket attachStreamsToRunLoop: runLoop error: NULL ] == NO )
        {
            status = NO;
        }
        
        if( status == YES && [ newSocket configureStreams: NULL ] == NO )
        {
            status = NO;
        }
        
        if( status == YES && [ newSocket openStreams: NULL ] == NO )
        {
            status = NO;
        }
        
        if( status == YES )
        {
            newSocket->_flags |= EOSSocketFlagsConnected;
        }
        else
        {
            [ newSocket close ];
        }
    }
}

- ( BOOL )createStreamsFromNativeSocketHandle: ( CFSocketNativeHandle )handle error: ( NSError ** )error
{
    if( error != NULL )
    {
        *( error ) = nil;
    }
    
    CFStreamCreatePairWithSocket
    (
        kCFAllocatorDefault,
        handle,
        &_readStream,
        &_writeStream
    );
    
    if( _readStream == NULL || _writeStream == NULL )
    {
        if( error != NULL )
        {
            *( error ) = [ NSError errorWithDomain: EOSSocketException code: 0 userInfo: nil ];
        }
        
        return NO;
    }
    
    CFReadStreamSetProperty
    (
        _readStream,
        kCFStreamPropertyShouldCloseNativeSocket,
        kCFBooleanTrue
    );
    
    CFWriteStreamSetProperty(
        _writeStream,
        kCFStreamPropertyShouldCloseNativeSocket,
        kCFBooleanTrue
    );
    
    return YES;
}

- ( BOOL )attachStreamsToRunLoop: ( NSRunLoop * )runLoop error: ( NSError ** )error
{
    Boolean status;
    
    _runLoop = ( runLoop == nil ) ? CFRunLoopGetCurrent() : [ runLoop getCFRunLoop ];
    
    status = CFReadStreamSetClient
    (
        _readStream,
        kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
        ( CFReadStreamClientCallBack )( &__CFReadStreamClientCallBack ),
        ( CFStreamClientContext * )( &_socketContext )
    );
    
    if( !status )
    {
        NSError *err = [self getStreamError];
        
        NSLog (@"AsyncSocket %p couldn't attach read stream to run-loop,", self);
        NSLog (@"Error: %@", err);
        
        if (errPtr) *errPtr = err;
        return NO;
    }
    
    CFReadStreamScheduleWithRunLoop
    (
        _readStream,
        _runLoop,
        kCFRunLoopDefaultMode
    );
    
    status = CFWriteStreamSetClient
    (
        _writeStream,
         kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
         ( CFWriteStreamClientCallBack )( &__CFWriteStreamClientCallBack ),
         ( CFStreamClientContext * )( &theContext )
    );
    
    if( !status )
    {
        NSError *err = [self getStreamError];
        
        NSLog (@"AsyncSocket %p couldn't attach write stream to run-loop,", self);
        NSLog (@"Error: %@", err);
        
        if (errPtr) *errPtr = err;
        return NO;
        
    }
    
    CFWriteStreamScheduleWithRunLoop
    (
        _writeStream,
        _runLoop,
        kCFRunLoopDefaultMode
    );
    
    return YES;
}

- ( NSError * )errorFromCFStreamError: ( CFStreamError )error
{
    NSString * domain;;
    
    if( error.domain == 0 && error.error == 0 )
    {
        return nil;
    }
    
    if( error.domain == kCFStreamErrorDomainPOSIX )
    {
        domain = NSPOSIXErrorDomain;
    }
    else if( error.domain == kCFStreamErrorDomainMacOSStatus )
    {
        domain = NSOSStatusErrorDomain;
    }
    else if( error.domain == kCFStreamErrorDomainMach )
    {
        domain = NSMachErrorDomain;
    }
    else if( error.domain == kCFStreamErrorDomainNetDB )
    {
        domain = @"kCFStreamErrorDomainNetDB";
    }
    else if( error.domain == kCFStreamErrorDomainNetServices )
    {
        domain = @"kCFStreamErrorDomainNetServices";
    }
    else if( error.domain == kCFStreamErrorDomainSOCKS )
    {
        domain = @"kCFStreamErrorDomainSOCKS";
    }
    else if( error.domain == kCFStreamErrorDomainSystemConfiguration )
    {
        domain = @"kCFStreamErrorDomainSystemConfiguration";
    }
    else if( error.domain == kCFStreamErrorDomainSSL )
    {
        domain = @"kCFStreamErrorDomainSSL";
    }
    else
    {
        domain = @"CFStreamError";
    }
    
    return [ NSError errorWithDomain: domain code: error.error userInfo: nil ];
}

- ( NSError * )streamError
{
    CFStreamError error;
    
    if( _readStream != NULL )
    {
        error = CFReadStreamGetError( _readStream );
        
        if( error.error != 0 )
        {
            return [ self errorFromCFStreamError: error ];
        }
    }
    
    if( _writeStream != NULL )
    {
        error = CFWriteStreamGetError( _writeStream );
        
        if( error.error != 0 )
        {
            return [ self errorFromCFStreamError: error ];
        }
    }
    
    return nil;
}

- ( void )unsetReadStream
{
    if( _readStream != NULL )
    {
        CFReadStreamSetClient( _readStream, kCFStreamEventNone, NULL, NULL );
        CFReadStreamUnscheduleFromRunLoop( _readStream, _runLoop, kCFRunLoopDefaultMode );
        CFReadStreamClose( _readStream );
        CFRelease( _readStream );
        
        _readStream = NULL;
    }
}

- ( void )unsetWriteStream
{
    if( _writeStream != NULL )
    {
        CFWriteStreamSetClient( _writeStream, kCFStreamEventNone, NULL, NULL );
        CFWriteStreamUnscheduleFromRunLoop( _writeStream, _runLoop, kCFRunLoopDefaultMode );
        CFWriteStreamClose( _writeStream );
        CFRelease( _writeStream );
        
        _writeStream = NULL;
    }
}

- ( void )unsetIPv4Socket
{
    if( _ipv4Socket != NULL )
    {
        CFSocketInvalidate( _ipv4Socket );
        CFRelease( _ipv4Socket );
        
        _ipv4Socket = NULL;
    }
}

- ( void )unsetIPv6Socket
{
    if( _ipv6Socket != NULL )
    {
        CFSocketInvalidate( _ipv6Socket );
        CFRelease( _ipv6Socket );
        
        _ipv6Socket = NULL;
    }
}

- ( void )unsetIPv4Source
{
    if( _ipv4Source != NULL )
    {
        CFRunLoopRemoveSource( _runLoop, _ipv4Source, kCFRunLoopDefaultMode) ;
        CFRelease( _ipv4Source );
        
        _ipv4Source = NULL;
    }
}

- ( void )unsetIPv6Source
{
    if( _ipv6Source != NULL )
    {
        CFRunLoopRemoveSource( _runLoop, _ipv6Source, kCFRunLoopDefaultMode );
        CFRelease( _ipv6Source );
        
        _ipv6Source = NULL;
    }
}

- ( void )close
{
    // Empty queues.
    [self emptyQueues];
    [partialReadBuffer release];
    partialReadBuffer = nil;
    
    [ NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector( disconnect ) object: nil ];
    
    [ self unsetReadStream ];
    [ self unsetWriteStream ];
    [ self unsetIPv4Socket ];
    [ self unsetIPv6Socket ];
    [ self unsetIPv4Source ];
    [ self unsetIPv6Source ];
    
    _runLoop = NULL;
    
    if( _flags & EOSSocketFlagsConnected )
    {
        if( [ _delegate respondsToSelector: @selector( socketDidDisconnect: ) ] )
        {
            [ _delegate socketDidDisconnect: self ];
        }
    }
    
    _flags = 0;
}

- ( void )closeWithError: ( NSError * )error
{
    _flags |= EOSSocketFlagsClosedWithError;
    
    if ( _flags & EOSSocketFlagsConnected )
    {
        [ self recoverUnreadData ];
        
        if( [ _delegate respondsToSelector: @selector( socket:willDisconnectWithError: ) ] )
        {
            [ _delegate socket: self willDisconnectWithError: error ];
        }
    }
    
    [ self close ];
}

@end