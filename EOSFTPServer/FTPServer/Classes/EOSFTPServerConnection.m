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

#import "EOSFTPServerConnection.h"
#import "EOSFTPServerConnection+Private.h"
#import "EOSFTPServerConnection+AsyncSocketDelegate.h"
#import "AsyncSocket.h"
#import "EOSFTPServer.h"
#import "NSData+EOS.h"

@implementation EOSFTPServerConnection

- ( id )initWithSocket: ( AsyncSocket * )socket server: ( EOSFTPServer * )server
{
    NSString * message;
    
    if( ( self = [ super init ] ) )
    {
        _connectionSocket   = [ socket retain ];
        _server             = [ server retain ];
        _transferMode       = EOSFTPServerTransferModePASV;
        _dataPort           = 2001;
        _queuedData         = [ [ NSMutableArray alloc ] initWithCapacity: 100 ];
        
        [ _connectionSocket setDelegate: self ];
        
        if( _server.welcomeMessage.length > 0 )
        {
            message = [ NSString stringWithFormat: @"220 %@ %@\r\n", [ _server messageForReplyCode: 220 ], _server.welcomeMessage ];
        }
        else
        {
            message = [ NSString stringWithFormat: @"220 %@\r\n", [ _server messageForReplyCode: 220 ] ];
        }
        
        [ _connectionSocket writeData: [ message dataUsingEncoding: NSUTF8StringEncoding ] withTimeout: -1 tag: 0 ];
        [ _connectionSocket readDataToData: [ NSData CRLFData ] withTimeout: EOS_FTP_SERVER_READ_TIMEOUT tag: EOS_FTP_SERVER_CLIENT_REQUEST ];
    }
    
    return self;
}

- ( void )dealloc
{
    [ _connectionSocket release ];
    [ _dataConnection   release ];
    [ _server           release ];
    [ _queuedData       release ];
    
    [ super dealloc ];
}

@end
