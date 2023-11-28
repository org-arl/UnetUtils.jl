module Signals

using SignalAnalysis: signal
using Statistics: mean
using DataFrames: DataFrame, DataFrameRow
using TimeZones: ZonedDateTime, localzone, @tz_str, astimezone
using Dates: unix2datetime
using Base64: base64decode
import PooledArrays: PooledArray

function read(filename; tz=localzone())
  df = DataFrame(
    time = ZonedDateTime[],
    rxtime = Int64[],
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
      rxtime = tryparse(Int64, ps["rxTime"]) || tryparse(Int64, ps["rxStartTime"])
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

function read(filenames::AbstractVector; tz=localzone())
  df = vcat(read.(filenames; tz)...)
  df.filename = PooledArray(df.filename)
  sort!(df, :time)
end

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
