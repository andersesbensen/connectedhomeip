/**
 *
 *    Copyright (c) 2023 Project CHIP Authors
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

/**
 * @file API declarations for time sync cluster.
 */

#pragma once

#include "TimeSyncDataProvider.h"

#include <app/server/Server.h>
#include <app/util/af-types.h>
#include <app/util/config.h>
#include <lib/core/TLV.h>

#include <app-common/zap-generated/cluster-objects.h>
#include <lib/support/Span.h>

namespace chip {
namespace app {
namespace Clusters {
namespace TimeSynchronization {

/**
 * @brief Describes the state of time zone and DSTOffset in use.
 */
enum class TimeState : uint8_t
{
    kInvalid = 0, // No valid offset available
    kActive  = 1, // An offset is currently being used
    kChanged = 2, // An offset expired or changed to a new value
    kStopped = 3, // Permanent item in use
};

/**
 * @brief Flags for tracking event types to emit.
 */
enum class TimeSyncEventFlag : uint8_t
{
    kNone            = 0,
    kDSTTableEmpty   = 1,
    kDSTStatus       = 2,
    kTimeZoneStatus  = 4,
    kTimeFailure     = 8,
    kMissingTTSource = 16,
};

class TimeSynchronizationServer
{
public:
    void Init();

    static TimeSynchronizationServer & Instance(void);
    TimeSyncDataProvider & GetDataProvider(void) { return mTimeSyncDataProvider; }

    CHIP_ERROR SetTrustedTimeSource(const DataModel::Nullable<Structs::TrustedTimeSourceStruct::Type> & tts);
    CHIP_ERROR SetDefaultNTP(const DataModel::Nullable<chip::CharSpan> & dntp);
    void InitTimeZone(void);
    CHIP_ERROR SetTimeZone(const DataModel::DecodableList<Structs::TimeZoneStruct::Type> & tzL);
    CHIP_ERROR LoadTimeZone(void);
    CHIP_ERROR ClearTimeZone(void);
    void InitDSTOffset(void);
    CHIP_ERROR SetDSTOffset(const DataModel::DecodableList<Structs::DSTOffsetStruct::Type> & dstL);
    CHIP_ERROR LoadDSTOffset(void);
    CHIP_ERROR ClearDSTOffset(void);
    DataModel::Nullable<Structs::TrustedTimeSourceStruct::Type> & GetTrustedTimeSource(void);
    Span<TimeSyncDataProvider::TimeZoneStore> & GetTimeZone(void);
    DataModel::List<Structs::DSTOffsetStruct::Type> & GetDSTOffset(void);
    CHIP_ERROR GetDefaultNtp(MutableCharSpan & dntp);

    CHIP_ERROR SetUTCTime(chip::EndpointId ep, uint64_t utcTime, GranularityEnum granularity, TimeSourceEnum source);
    CHIP_ERROR GetLocalTime(chip::EndpointId ep, DataModel::Nullable<uint64_t> & localTime);
    GranularityEnum & GetGranularity() { return mGranularity; }

    void ScheduleDelayedAction(System::Clock::Seconds32 delay, System::TimerCompleteCallback action, void * aAppState);

    TimeState UpdateTimeZoneState();
    TimeState UpdateDSTOffsetState();
    TimeSyncEventFlag GetEventFlag(void);
    void ClearEventFlag(TimeSyncEventFlag flag);

private:
    DataModel::Nullable<Structs::TrustedTimeSourceStruct::Type> mTrustedTimeSource;
    TimeSyncDataProvider::TimeZoneObj mTimeZoneObj{ Span<TimeSyncDataProvider::TimeZoneStore>(mTz), 0 };
    TimeSyncDataProvider::DSTOffsetObj mDstOffsetObj{ DataModel::List<Structs::DSTOffsetStruct::Type>(mDst), 0 };
    GranularityEnum mGranularity;

    TimeSyncDataProvider::TimeZoneStore mTz[CHIP_CONFIG_TIME_ZONE_LIST_MAX_SIZE];
    Structs::DSTOffsetStruct::Type mDst[CHIP_CONFIG_DST_OFFSET_LIST_MAX_SIZE];

    TimeSyncDataProvider mTimeSyncDataProvider;
    static TimeSynchronizationServer sTimeSyncInstance;
    TimeSyncEventFlag mEventFlag = TimeSyncEventFlag::kNone;
};

} // namespace TimeSynchronization
} // namespace Clusters
} // namespace app
} // namespace chip
