module Signals

using SignalAnalysis: signal
using Statistics: mean
using DataFrames: DataFrame, DataFrameRow
using TimeZones: ZonedDateTime, localzone, @tz_str, astimezone
using Dates: unix2datetime
using Base64: base64decode
import PooledArrays: PooledArray

"""
    read(filename)
    read(filename; tz)

Read signals from signal dump `filename` and return a `DataFrame` with an index
of all available signals. By default, the timestamps in the index are in the
local timezone. If a different timezone is desired, it can be specified using
the keyword argument `tz`.
"""
function read(filename; tz=localzone())
  df = DataFrame(
    time = ZonedDateTime[],
    rxtime = Union{Int64,Missing}[],
    rssi = Union{Float64,Missing}[],
    preamble = Int64[],
    channels = Int64[],
    fc = Float64[],
    fs = Float64[],
    len = Int64[],
    lno = Int64[],
    filename = PooledArray(String[]),
    dtype = DataType[])
  for (lno, line) ∈ enumerate(eachline(filename))
    if contains(line, "|RxBasebandSignalNtf:INFORM[")
      m = match(r"^(\d+)\|RxBasebandSignalNtf:INFORM\[(.*) \((\d+) .*samples\)\]", line)
      t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz)
      len = parse(Int64, m[3])
      ps = Dict(=>(split(p, ':')...) for p ∈ split(m[2], ' '; keepempty=false))
      rxtime = missing
      "rxStartTime" ∈ keys(ps) && (rxtime = parse(Int64, ps["rxStartTime"]))
      "rxTime" ∈ keys(ps) && (rxtime = parse(Int64, ps["rxTime"]))
      rssi = "rssi" ∈ keys(ps) ? parse(Float64, ps["rssi"]) : missing
      pre = "preamble" ∈ keys(ps) ? parse(Int64, ps["preamble"]) : 0
      ch = "channels" ∈ keys(ps) ? parse(Int64, ps["channels"]) : 1
      fc = parse(Float64, ps["fc"])
      fs = parse(Float64, ps["fs"])
      dt = fc == 0 ? Float32 : ComplexF32
      push!(df, (t, rxtime, rssi, pre, ch, fc, fs, len, lno+1, filename, dt))
    end
  end
  df
end

"""
    read(filenames)
    read(filenames; tz)

Read signals from a set of signal dump files (`filenames`) and return a single
`DataFrame` with an index of all available signals. By default, the timestamps
in the index are in the local timezone. If a different timezone is desired,
it can be specified using the keyword argument `tz`.
"""
function read(filenames::AbstractVector; tz=localzone())
  df = vcat(read.(filenames; tz)...)
  df.filename = PooledArray(df.filename)
  sort!(df, :time)
end

"""
    read(row::DataFrameRow)
    read(row::DataFrame, i)

Read a signal from a signal dump. The signal is specified by the `DataFrame` row
(or index `i`) from the index returned by `read()` on the signal file. The returned
signal is a real or complex matrix, depending on whether the signal is in passband
or baseband respectively. The number of columns is equal to the number of channels
in the signal.

Signals are returned as `SampledSignals` from [`SignalAnalysis`](https://github.com/org-arl/SignalAnalysis.jl),
and have sampling rate information embedded in them.
"""
function read(row::DataFrameRow)
  for (n, line) ∈ enumerate(eachline(row.filename))
    if n == row.lno
      raw = ntoh.(Array{row.dtype}(reinterpret(row.dtype, base64decode(line))))
      x = signal(collect(transpose(reshape(raw, row.channels, :))), row.fs)
      return x .- mean(1.0x; dims=1)
    end
  end
  throw(ErrorException("Signal not found"))
end

read(df::DataFrame, i) = read(df[i,:])

end # module
