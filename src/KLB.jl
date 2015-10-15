module KLB

function readheader(
    filepath::AbstractString
    )
  imagesize = zeros(UInt32, 5)
  blocksize = zeros(UInt32, 5)
  pixelspacing = ones(Float32, 5)
  ktype = Ref{Cint}(-1)
  compressiontype = Ref{Cint}(-1)
  metadata = repeat(" ", 256)

  errid = ccall( (:readKLBheader, "klb"), Cint,
    (Cstring, Ptr{UInt32}, Ref{Cint}, Ptr{Float32}, Ptr{UInt32}, Ref{Cint}, Ptr{Cchar}),
    filepath, imagesize, ktype, pixelspacing, blocksize, compressiontype, metadata)

  if errid != 0
    error("Could not read KLB header of file '$filepath'. Error code $errid")
  end
  
  header = Dict{AbstractString, Any}()
  header["imagesize"] = round(Int, imagesize)
  header["blocksize"] = round(Int, blocksize)
  header["pixelspacing"] = pixelspacing
  header["metadata"] = strip(metadata)
  header["datatype"] = juliatype(ktype[])
  header["compressiontype"] = compressiontype[]
  header["spatialorder"] = ["x", "y", "z"]
  header["colordim"] = 4
  header["timedim"]  = 5
  return header
end


function readarray(
    filepath::AbstractString,
    numthreads::Integer=1
    )
  header = readheader(filepath)
  imagesize = header["imagesize"]
  jtype = header["datatype"]
  ktype = Ref{Cint}( klbtype(jtype) )
  A = Array(jtype, imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5])

  errid = ccall( (:readKLBstackInPlace, "klb"), Cint,
    (Cstring, Ptr{Void}, Ref{Cint}, Cint),
    filepath, A, ktype, numthreads)

  if errid != 0
    error("Could not read KLB file '$filepath'. Error code $errid")
  end

  return A
end


function readarray!(
    A::Array,
    filepath::AbstractString,
    numthreads::Integer=1
    ;
    nochecks::Bool=false
    )
  if !nochecks
    header = readheader(filepath)
    assert( header["datatype"] == eltype(A) )
    imagesize = header["imagesize"]
    for d in 1:5
      assert( imagesize[d] == size(A, d) )
    end
  end

  errid = ccall( (:readKLBstackInPlace, "klb"), Cint,
    (Cstring, Ptr{Void}, Ref{Cint}, Cint),
    filepath, A, Ref{Cint}(0), numthreads)

  if errid != 0
    error("Could not read KLB file '$filepath'. Error code $errid")
  end
end


function readarray(
    filepath::AbstractString,
    lower_bounds::Vector{UInt32},
    upper_bounds::Vector{UInt32},
    numthreads::Integer=1
    )
  header = readheader(filepath)
  jtype = header["datatype"]
  ktype = Ref{Cint}( klbtype(jtype) )
  lb = lower_bounds - 1
  ub = upper_bounds - 1
  roisize = 1 + ub - lb
  A = Array(jtype, roisize[1], roisize[2], roisize[3], roisize[4], roisize[5])

  errid = ccall( (:readKLBroiInPlace, "klb"), Cint,
    (Cstring, Ptr{Void}, Ref{Cint}, Ptr{UInt32}, Ptr{UInt32}, Cint),
    filepath, A, ktype, lb, ub, numthreads)

  if errid != 0
    error("Could not read KLB file '$filepath'. Error code $errid")
  end

  return A
end


function readarray!(
    A::Array,
    filepath::AbstractString,
    lower_bounds::Vector{UInt32},
    upper_bounds::Vector{UInt32},
    numthreads::Integer=1
    ;
    nochecks::Bool=false
    )
  lb = lower_bounds - 1
  ub = upper_bounds - 1

  if !nochecks
    header = readheader(filepath)
    assert( header["datatype"] == eltype(A) )
    roisize = 1 + ub - lb
    for d in 1:5
      assert( roisize[d] == size(A, d) )
    end
  end

  errid = ccall( (:readKLBroiInPlace, "klb"), Cint,
    (Cstring, Ptr{Void}, Ref{Cint}, Ptr{UInt32}, Ptr{UInt32}, Cint),
    filepath, A, Ref{Cint}(0), lb, ub, numthreads)

  if errid != 0
    error("Could not read KLB file '$filepath'. Error code $errid")
  end

  return A
end


function writearray(
    filepath::AbstractString,
    A::Array,
    numthreads::Integer=1
    ;
    pixelspacing=C_NULL,
    blocksize=C_NULL,
    compressiontype=C_NULL,
    metadata=C_NULL
    )
  ktype = klbtype(eltype(A))
  imagesize = UInt32[i for i in size(A)]
  while length(imagesize) < 5
    push!(imagesize, 1)
  end

  errid = ccall( (:writeKLBstack, "klb"), Cint,
    (Ptr{Void}, Cstring, Ptr{UInt32}, Cint, Cint, Ptr{Float32}, Ptr{UInt32}, Cint, Ptr{Cchar}),
    A, filepath, imagesize, ktype, numthreads, pixelspacing, blocksize, compressiontype, metadata)

  if errid != 0
    error("Could not write KLB file '$filepath'. Error code $errid")
  end
end


function juliatype( klbtype::Integer )
  if klbtype == 0
    return UInt8
  elseif klbtype == 1
    return UInt16
  elseif klbtype == 2
    return UInt32
  elseif klbtype == 3
    return UInt64
  elseif klbtype == 4
    return Int8
  elseif klbtype == 5
    return Int16
  elseif klbtype == 6
    return Int32
  elseif klbtype == 7
    return Int64
  elseif klbtype == 8
    return Float32
  elseif klbtype == 9
    return Float64
  end
  error( "Unknown or unsupported data type of KLB array: $klbtype" )
end


function klbtype( juliatype::Type )
  if juliatype == UInt8
    return 0
  elseif juliatype == UInt16
    return 1
  elseif juliatype == UInt32
    return 2
  elseif juliatype == UInt64
    return 3
  elseif juliatype == Int8
    return 4
  elseif juliatype == Int16
    return 5
  elseif juliatype == Int32
    return 6
  elseif juliatype == Int64
    return 7
  elseif juliatype == Float32
    return 8
  elseif juliatype == Float64
    return 9
  end
  error( "Unknown or unsupported data type of KLB array: $juliatype" )
end

end # module
