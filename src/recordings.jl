module Recordings

import SignalAnalysis: signal, framerate, nchannels, samples
import Statistics: mean
import DataFrames: DataFrame, DataFrameRow
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import Dates: unix2datetime, datetime2unix, now, UTC
import WAV: wavwrite

const MAGIC = hton(0x43c04d126f173001)

# defaults from old file format without header
const FRAMERATE = 32000.0
const NCHANNELS = 4

function read(filename; tz=localzone())
  isfile(filename) && return readrec(filename)
  df = DataFrame(time=ZonedDateTime[], filename=String[], duration=Float64[], nchannels=Int[], framerate=Float64[])
  for filename ∈ readdir(filename; join=true)
    m = match(r"/?rec\-(\d+)\.dat", filename)
    if m !== nothing
      t = 0
      filesize = stat(filename).size
      nch = NCHANNELS
      fs = FRAMERATE
      if filesize > 24
        open(filename, "r") do f
          hdr = read(f, RecordingHeader)
          if hdr !== nothing
            t = astimezone(ZonedDateTime(unix2datetime(hdr.millis / 1000), tz"UTC"), tz)
            nch = hdr.nchannels
            fs = hdr.framerate
          end
        end
      end
      d = filesize / (4 * nch * fs)
      t == 0 && (t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz))
      push!(df, (t, filename, d, nch, Float64(fs)))
    end
  end
  sort!(df, :time)
end

read(filenames::AbstractVector; tz=localzone()) = sort!(vcat(read.(filenames; tz)...), :time)

read(row::DataFrameRow) = readrec(row.filename)
read(df::DataFrame, i) = readrec(df.filename[i])

Base.@kwdef struct RecordingHeader
  magic::UInt64 = MAGIC
  millis::Int64 = round(Int64, 1000 * time())
  framerate::Int32
  nchannels::Int16 = 1
end

function read(io::IO, ::Type{RecordingHeader})
  p = position(io)
  try
    x = Base.read(io, UInt64)
    if x == MAGIC
      hdr = RecordingHeader(
        millis = Base.read(io, Int64),
        framerate = Base.read(io, Int32),
        nchannels = Base.read(io, Int16))
      [Base.read(io, UInt16) for _ in 1:5]
      return hdr
    end
  catch ex
    ex isa EOFError || @warn "$ex"
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
    x .- mean(x; dims=1)
  end
end

function write(filename, x; fs=framerate(x))
  open(filename, "w") do io
    hdr = RecordingHeader(
      millis = round(Int64, 1000 * datetime2unix(now(UTC))),
      framerate = round(Int32, fs),
      nchannels = nchannels(x))
    Base.write(io, hdr.magic)
    Base.write(io, hdr.millis)
    Base.write(io, hdr.framerate)
    Base.write(io, hdr.nchannels)
    Base.write(io, UInt16[0, 0, 0, 0, 0])
    Base.write(io, Float32.(x'))
  end
  nothing
end

function towav(filename)
  x = readrec(filename)
  wavfilename = replace(filename, r"\.dat$" => "") * ".wav"
  wavwrite(samples(x), wavfilename; Fs=framerate(x))
end

end # module
