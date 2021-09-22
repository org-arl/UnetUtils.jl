using SignalAnalysis
using DataFrames
using TimeZones
using Dates

export listrecs, getrec, readrec

const FRAMERATE = 32000.0
const NCHANNELS = 4

function listrecs(dirname; tz=tz"UTC")
  df = DataFrame(time=ZonedDateTime[], filename=String[], duration=Float64[])
  for filename ∈ readdir(dirname; join=true)
    m = match(r"/?rec\-(\d+)\.dat", filename)
    if m !== nothing
      t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz)
      d = stat(filename).size / (4 * NCHANNELS * FRAMERATE)
      push!(df, (t, filename, d))
    end
  end
  sort(df, :time)
end

listrecs(dirnames::AbstractVector; tz=tz"UTC") = vcat(listrecs.(dirnames; tz)...)

getrec(row::DataFrameRow) = readrec(row.filename)
getrec(df::DataFrame, i) = readrec(df.filename[i])

function readrec(filename)
  open(filename, "r") do f
    bytes = read(f)
    raw = reinterpret(Float32, bytes)
    signal(reshape(raw, NCHANNELS, :)', FRAMERATE)
  end
end
