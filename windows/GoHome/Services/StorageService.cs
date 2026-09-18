using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using GoHome.Models;

namespace GoHome.Services;

/// <summary>
/// %APPDATA%\gohome\work_records.json 에 날짜키 → 기록 형태로 저장.
/// macOS 버전(~/Library/Application Support/gohome/work_records.json)과 구조는 같지만
/// 날짜 인코딩이 달라서 파일은 서로 호환되지 않는다. (README 참고)
/// </summary>
public sealed class StorageService
{
    public static readonly StorageService Shared = new();

    private readonly string _dir;
    private readonly string _path;
    private readonly object _gate = new();

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private StorageService()
    {
        _dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "gohome");
        Directory.CreateDirectory(_dir);
        _path = Path.Combine(_dir, "work_records.json");
    }

    public string FilePath => _path;

    private Dictionary<string, WorkRecord> LoadAll()
    {
        try
        {
            if (!File.Exists(_path)) return new Dictionary<string, WorkRecord>();
            var text = File.ReadAllText(_path);
            if (string.IsNullOrWhiteSpace(text)) return new Dictionary<string, WorkRecord>();
            return JsonSerializer.Deserialize<Dictionary<string, WorkRecord>>(text, JsonOpts)
                   ?? new Dictionary<string, WorkRecord>();
        }
        catch (Exception)
        {
            // 파일이 깨졌으면 기록을 잃는 대신 빈 상태로 시작한다.
            return new Dictionary<string, WorkRecord>();
        }
    }

    /// <summary>
    /// 임시 파일에 쓰고 교체한다. 쓰는 중 크래시로 전체 기록이 날아가는 걸 막기 위함.
    /// (macOS 버전은 곧바로 덮어써서 이 위험이 있다.)
    /// </summary>
    private void SaveAll(Dictionary<string, WorkRecord> all)
    {
        try
        {
            var tmp = _path + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(all, JsonOpts));
            File.Move(tmp, _path, overwrite: true);
        }
        catch (Exception)
        {
            // 저장 실패는 조용히 넘긴다. 다음 이벤트에서 다시 시도된다.
        }
    }

    public WorkRecord? Today()
    {
        lock (_gate)
        {
            return LoadAll().TryGetValue(KoreaTime.DateKeyToday(), out var r) ? r : null;
        }
    }

    public IReadOnlyList<WorkRecord> Recent(int limit = 10)
    {
        lock (_gate)
        {
            return LoadAll()
                .OrderByDescending(kv => kv.Key, StringComparer.Ordinal)
                .Take(limit)
                .Select(kv => kv.Value)
                .ToList();
        }
    }

    /// <summary>이미 출근 기록이 있으면 아무것도 하지 않는다. 실제로 기록했으면 true.</summary>
    public bool CheckIn()
    {
        lock (_gate)
        {
            var now = DateTimeOffset.Now;
            var all = LoadAll();
            var key = KoreaTime.DateKeyToday();

            if (!all.TryGetValue(key, out var record))
                record = new WorkRecord { Date = now };

            if (record.CheckIn is not null) return false;

            record.CheckIn = now;
            all[key] = record;
            SaveAll(all);
            return true;
        }
    }

    /// <summary>출근 기록이 있을 때만 시각을 고친다. macOS 버전 updateCheckIn(date:) 대응.</summary>
    public bool UpdateCheckIn(DateTimeOffset date)
    {
        lock (_gate)
        {
            var all = LoadAll();
            var key = KoreaTime.DateKeyToday();

            if (!all.TryGetValue(key, out var record) || record.CheckIn is null) return false;

            record.CheckIn = date;
            all[key] = record;
            SaveAll(all);
            return true;
        }
    }

    /// <summary>출근 기록이 있고 아직 퇴근 안 했을 때만 기록한다.</summary>
    public bool CheckOut()
    {
        lock (_gate)
        {
            var all = LoadAll();
            var key = KoreaTime.DateKeyToday();

            if (!all.TryGetValue(key, out var record)) return false;
            if (record.CheckIn is null || record.CheckOut is not null) return false;

            record.CheckOut = DateTimeOffset.Now;
            all[key] = record;
            SaveAll(all);
            return true;
        }
    }

    public void SetHalfDay(bool value)
    {
        lock (_gate)
        {
            var all = LoadAll();
            var key = KoreaTime.DateKeyToday();

            if (!all.TryGetValue(key, out var record))
                record = new WorkRecord { Date = DateTimeOffset.Now };

            record.HalfDay = value;
            all[key] = record;
            SaveAll(all);
        }
    }
}
