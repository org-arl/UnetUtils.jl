module Recordings

import SignalAnalysis: signal
import Statistics: mean
import DataFrames: DataFrame, DataFrameRow
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import Dates: unix2datetime

# defaults from old file format without header
const FRAMERATE = 32000.0
const NCHANNELS = 4

function read(filename; tz=localzone())
  isfile(filename) && return readrec(filename)
  df = DataFrame(time=ZonedDateTime[], filename=String[], duration=Float64[])
  for filename ∈ readdir(filename; join=true)
    m = match(r"/?rec\-(\d+)\.dat", filename)
    if m !== nothing
      t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz)
      d = stat(filename).size / (4 * NCHANNELS * FRAMERATE)
      push!(df, (t, filename, d))
    end
  end
  sort!(df, :time)
end

read(filenames::AbstractVector; tz=localzone()) = sort!(vcat(read.(filenames; tz)...), :time)

read(row::DataFrameRow) = readrec(row.filename)
read(df::DataFrame, i) = readrec(df.filename[i])

Base.@kwdef struct RecordingHeader
  magic::UInt64 = hton(0x43c04d126f173001)
  millis::Int64 = round(Int64, 1000 * time())
  framerate::Int32
  nchannels::Int16 = 1
end

function Base.read(io::IO, ::Type{RecordingHeader})
  p = position(io)
  try
    if read(io, UInt64) == hton(0x43c04d126f173001)
      return RecordingHeader(
        millis = read(io, Int64),
        framerate = read(io, Int32),
        nchannels = read(io, Int16))
    end
  catch EOFError
    # ignore
  end
  seek(io, p)
  nothing
end

function readrec(filename)
  open(filename, "r") do f
    nch = NCHANNELS
    fs = FRAMERATE
    hdr = read(f, RecordingHeader)
    if hdr !== nothing
      nch = hdr.nchannels
      fs = hdr.framerate
    end
    bytes = Base.read(f)
    raw = reinterpret(Float32, bytes)
    x = signal(reshape(raw, nch, :)', fs)
    x .- mean(1.0x; dims=1)
  end
end

end # module
