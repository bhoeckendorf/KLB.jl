module KLB

using Images


function readheader(
    filepath::String
    )
  imagesize = zeros(Uint32, 5)
  blocksize = zeros(Uint32, 5)
  sampling = ones(Float32, 5)
  datatype = Cint[-1]
  compressiontype = Cint[-1]
  metadata = repeat(" ", 256)

  errid = ccall( (:readKLBheader, "klb"), Cint,
                (Ptr{Uint8}, Ptr{Uint32}, Ptr{Cint}, Ptr{Float32}, Ptr{Uint32}, Ptr{Cint}, Ptr{Uint8}),
                filepath, imagesize, datatype, sampling, blocksize, compressiontype, metadata)

  if errid != 0
    error("Could not read KLB header of file '$filepath'. Error code $errid")
  end

  header = Dict{String, Any}()
  header["imagesize"] = imagesize
  header["blocksize"] = blocksize
  header["pixelspacing"] = sampling
  header["metadata"] = strip(metadata)
  header["datatype"] = juliatype(datatype[1])
  header["compressiontype"] = compressiontype[1]
  header["spatialorder"] = ["x", "y", "z"]
  header["timedim"] = 5
  return header
end


function readimage(
    filepath::String,
    numthreads::Integer=1
    )
  imagesize = zeros(Uint32, 5)
  blocksize = zeros(Uint32, 5)
  sampling = ones(Float32, 5)
  datatype = Cint[-1]
  compressiontype = Cint[-1]
  metadata = repeat(" ", 256)

  voidptr = ccall( (:readKLBstack, "klb"), Ptr{Void},
                  (Ptr{Uint8}, Ptr{Uint32}, Ptr{Cint}, Cint, Ptr{Float32}, Ptr{Uint32}, Ptr{Cint}, Ptr{Uint8}),
                  filepath, imagesize, datatype, numthreads, sampling, blocksize, compressiontype, metadata)

  header = Dict{String, Any}()
  #header["imagesize"] = imagesize
  header["blocksize"] = blocksize
  header["pixelspacing"] = sampling
  header["metadata"] = strip(metadata)
  #header["datatype"] = juliatype(datatype[1])
  header["compressiontype"] = compressiontype[1]
  header["spatialorder"] = ["x", "y", "z"]
  header["timedim"] = 5

  typedptr = convert( Ptr{ juliatype(datatype[1]) }, voidptr )
  arr = pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)

  return Image(arr, header)
end


function readarray(
    filepath::String,
    numthreads::Integer=1
    )
  imagesize = zeros(Uint32, 5)
  datatype = Cint[-1]

  voidptr = ccall( (:readKLBstack, "klb"), Ptr{Void},
                  (Ptr{Uint8}, Ptr{Uint32}, Ptr{Cint}, Cint, Ptr{Float32}, Ptr{Uint32}, Ptr{Cint}, Ptr{Uint8}),
                  filepath, imagesize, datatype, numthreads, C_NULL, C_NULL, C_NULL, C_NULL)

  typedptr = convert( Ptr{ juliatype(datatype[1]) }, voidptr )
  return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
end


function juliatype( klbtype::Integer )
  if klbtype == 0
    return Uint8
  elseif klbtype == 1
    return Uint16
  elseif klbtype == 2
    return Uint32
  elseif klbtype == 3
    return Uint64
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

end # module
