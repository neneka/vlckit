/*****************************************************************************
 * VLCMediaParser.h
 *****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCMediaParser.h"
#import "VLCLibrary.h"
#import "VLCMedia.h"
#import "VLCMedia+Internal.h"
#include <vlc/libvlc.h>

static VLCMediaParser * sharedParser = nil;

@interface VLCMediaParser()
{
    libvlc_parser_t *_parser;
    NSMutableDictionary *_mediaDict;
}

- (void)parseEndedForMedia:(libvlc_media_t *)md withStatus:(libvlc_media_parsed_status_t)status;

@end

static void media_parse_ended(void *opaque, libvlc_parser_request_t *req,
                              libvlc_media_parsed_status_t status)
{
    @autoreleasepool {
        VLCMediaParser *parser = (__bridge VLCMediaParser*)opaque;
        libvlc_media_t *media = libvlc_parser_request_get_media(req);
        [parser parseEndedForMedia:media withStatus:status];
        libvlc_parser_request_destroy(req);
    }
}

@implementation VLCMediaParser

+ (instancetype)sharedParser
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedParser = [[VLCMediaParser alloc] init];
    });
    return sharedParser;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        static const struct libvlc_parser_cbs cbs = {
            .on_parsed = media_parse_ended,
        };
        _parser = libvlc_parser_new([VLCLibrary sharedLibrary].instance, LIBVLC_PARSER_CBS_VER_0, &cbs, (__bridge void *)self);
        _mediaDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithLibrary:(VLCLibrary *)library
{
    self = [super init];
    if (self) {
        static const struct libvlc_parser_cbs cbs = {
            .on_parsed = media_parse_ended,
        };
        _parser = libvlc_parser_new(library.instance, LIBVLC_PARSER_CBS_VER_0, &cbs, (__bridge void *)self);
    }
    return self;
}

- (void)parseEndedForMedia:(libvlc_media_t *)md withStatus:(libvlc_media_parsed_status_t)status
{
    NSValue *valueKey = [NSValue valueWithPointer:md];
    VLCMedia *media = [_mediaDict objectForKey:valueKey];
    [media parsingFinished];

    [_mediaDict removeObjectForKey:valueKey];
}

- (int)queueMedia:(VLCMedia *)media withDescriptor:(libvlc_media_t *)md options:(int)options timeout:(int)timeout
{
    libvlc_parser_request_t *request = libvlc_parser_request_new(md);
    libvlc_parser_request_set_timeout(request, timeout);
    libvlc_parser_request_set_flags(request, options);

    NSValue *valueKey = [NSValue valueWithPointer:md];
    [_mediaDict setObject:media forKey:valueKey];

    return libvlc_parser_queue(_parser, request);
}

@end
