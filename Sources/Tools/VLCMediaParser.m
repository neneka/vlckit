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
#import "VLCLibVLCBridging.h"
#import "VLCEventsHandler.h"
#include <vlc/libvlc.h>

static VLCMediaParser * sharedParser = nil;

@interface VLCMediaParser()
{
    libvlc_parser_t *_parser;
    NSMutableDictionary *_mediaDict;
    VLCEventsHandler *_eventHandler;
}

- (void)parseEndedForMedia:(libvlc_media_t *)p_media withStatus:(VLCMediaParsedStatus)status;

@end

static VLCMediaParsedStatus VLCMediaParsedStatusFromParserStatus(libvlc_parser_status_t status)
{
    switch (status) {
        case libvlc_parser_status_failed:
            return VLCMediaParsedStatusFailed;
        case libvlc_parser_status_timeout:
            return VLCMediaParsedStatusTimeout;
        case libvlc_parser_status_cancelled:
            return VLCMediaParsedStatusCancelled;
        case libvlc_parser_status_done:
            return VLCMediaParsedStatusDone;
    }
    return VLCMediaParsedStatusNone;
}

static void media_parse_ended(void *opaque, libvlc_parser_task *task,
                              libvlc_parser_status_t status)
{
    @autoreleasepool {
        VLCEventsHandler *eventsHandler = (__bridge VLCEventsHandler *)opaque;
        [eventsHandler handleEvent:^(id _Nonnull object) {
            VLCMediaParser *parser = (VLCMediaParser *)object;
            libvlc_media_t *media = libvlc_parser_task_get_media(task);
            [parser parseEndedForMedia:media withStatus:VLCMediaParsedStatusFromParserStatus(status)];
            libvlc_parser_task_release(task);
        }];
    }
}

static const struct libvlc_parser_cbs parser_cbs = {
    .version = 0,
    .on_parsed = media_parse_ended,
};

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
    return [self initWithLibrary:[VLCLibrary sharedLibrary] timeout:-1];
}

- (instancetype)initWithLibrary:(VLCLibrary *)library timeout:(int)timeout
{
    self = [super init];
    if (self) {
        const struct libvlc_parser_cfg cfg = {
            .version = 0,
            .max_parser_threads = 0,
            .max_thumbnailer_threads = 0,
            .timeout = timeout,
        };
        _eventHandler = [VLCEventsHandler handlerWithObject:self configuration:[VLCLibrary sharedEventsConfiguration]];
        _parser = libvlc_parser_new(library.instance, &cfg);
        _mediaDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    libvlc_parser_destroy(_parser);
}

- (void)parseEndedForMedia:(libvlc_media_t *)p_media withStatus:(VLCMediaParsedStatus)status
{
    NSValue *valueKey = [NSValue valueWithPointer:p_media];
    VLCMedia *media = [_mediaDict objectForKey:valueKey];

    [_mediaDict removeObjectForKey:valueKey];

    [media parsingFinishedWithStatus:status];

    if (self.delegate && [self.delegate respondsToSelector:@selector(mediaFinishedParsing:withStatus:)]) {
        [self.delegate mediaFinishedParsing:media withStatus:status];
    }
}

- (int)queueMedia:(VLCMedia *)media options:(VLCMediaParsingOptions)options
{
    if (media == nil) {
        return -1;
    }
    libvlc_media_t *p_media = [media libVLCMediaDescriptor];
    if (p_media == NULL) {
        return -1;
    }

    const libvlc_parser_request_t request = {
        .version = 0,
        .media = p_media,
        .parse_flags = (libvlc_media_parse_flag_t)options,
    };

    NSValue *valueKey = [NSValue valueWithPointer:p_media];
    [_mediaDict setObject:media forKey:valueKey];

    /* On success the task handle is owned by us until the on_parsed callback
     * fires; it is released there (see media_parse_ended). */
    libvlc_parser_task *task = libvlc_parser_queue(_parser, &request, &parser_cbs, (__bridge void *)_eventHandler);
    if (task == NULL) {
        [_mediaDict removeObjectForKey:valueKey];
        return -1;
    }
    return 0;
}

@end
