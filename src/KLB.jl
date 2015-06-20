module KLB

function readheader(
    filepath::String
    )
  imagesize = zeros(Uint32, 5)
  blocksize = zeros(Uint32, 5)
  sampling = ones(Float32, 5)
  datatype = Cint[0]
  compressiontype = Cint[0]
  metadata = repeat(" ", 256)

  retval = ccall( (:readKLBheader, "klb"), Int32,
                 (Ptr{Uint8}, Ptr{Uint32}, Ptr{Cint}, Ptr{Float32}, Ptr{Uint32}, Ptr{Cint}, Ptr{Uint8}),
                 filepath, imagesize, datatype, sampling, blocksize, compressiontype, metadata)

  println(imagesize)
  println(blocksize)
  println(sampling)
  println(datatype)
  println(compressiontype)
  println(metadata)
end


function readimage(
    filepath::String,
    numthreads::Integer=1
    )
  imagesize = zeros(Uint32, 5)
  blocksize = zeros(Uint32, 5)
  sampling = ones(Float32, 5)
  datatype = Cint[0]
  compressiontype = Cint[0]
  metadata = repeat(" ", 256)

  voidptr = ccall( (:readKLBstack, "klb"), Ptr{Void},
                  (Ptr{Uint8}, Ptr{Uint32}, Ptr{Cint}, Cint, Ptr{Float32}, Ptr{Uint32}, Ptr{Cint}, Ptr{Uint8}),
                  filepath, imagesize, datatype, numthreads, sampling, blocksize, compressiontype, metadata)

  if datatype[1] == 0
    typedptr = convert(Ptr{Uint8}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 1
    typedptr = convert(Ptr{Uint16}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 2
    typedptr = convert(Ptr{Uint32}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 3
    typedptr = convert(Ptr{Uint64}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 4
    typedptr = convert(Ptr{Int8}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 5
    typedptr = convert(Ptr{Int16}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 6
    typedptr = convert(Ptr{Int32}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 7
    typedptr = convert(Ptr{Int64}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 8
    typedptr = convert(Ptr{Float32}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  elseif datatype[1] == 9
    typedptr = convert(Ptr{Float64}, voidptr)
    return pointer_to_array(typedptr, (imagesize[1], imagesize[2], imagesize[3], imagesize[4], imagesize[5]), true)
  else
    return None
  end
end

end # module
