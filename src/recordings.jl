module Recordings

import SignalAnalysis: signal, framerate, nchannels
import Statistics: mean
import DataFrames: DataFrame, DataFrameRow
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import Dates: unix2datetime, datetime2unix, now

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
      t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz)
      filesize = stat(filename).size
      nch = NCHANNELS
      fs = FRAMERATE
      if filesize > 24
        open(filename, "r") do io
          x = Base.read(io, UInt64)
          if x == MAGIC
            Base.read(io, Int64)
            fs = Int(Base.read(io, Int32))
            nch = Int(Base.read(io, Int16))
          end
        end
      end
      d = filesize / (4 * nch * fs)
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
    Base.write(io, MAGIC)
    Base.write(io, round(Int64, 1000 * datetime2unix(now())))
    Base.write(io, round(Int32, fs))
    Base.write(io, Int16(nchannels(x)))
    Base.write(io, zeros(Int16, 5))
    Base.write(io, Float32.(x'))
  end
  nothing
end

end # module
