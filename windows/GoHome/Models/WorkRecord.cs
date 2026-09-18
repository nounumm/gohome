using System;
using System.Text.Json.Serialization;

namespace GoHome.Models;

/// <summary>
/// 하루치 출퇴근 기록. macOS 버전의 WorkRecord.swift 와 같은 역할.
/// </summary>
public sealed class WorkRecord
{
    [JsonPropertyName("date")]
    public DateTimeOffset Date { get; set; }

    [JsonPropertyName("checkIn")]
    public DateTimeOffset? CheckIn { get; set; }

    [JsonPropertyName("checkOut")]
    public DateTimeOffset? CheckOut { get; set; }

    /// <summary>
    /// 반차 여부. macOS 버전은 구글 캘린더에서 읽었지만 Windows 버전은 수동 토글이다.
    /// </summary>
    [JsonPropertyName("halfDay")]
    public bool HalfDay { get; set; }

    [JsonIgnore]
    public TimeSpan? Worked =>
        CheckIn is { } inTime && CheckOut is { } outTime ? outTime - inTime : null;

    [JsonIgnore]
    public bool IsOvertime => Worked is { } w && w > TimeSpan.FromHours(9);
}
