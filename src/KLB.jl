module KLB

using FileIO

export klbheader, loadklb, loadklb!


function FileIO.load(
    file::File{format"KLB"}
    ;
    bounds::Array{UInt32} = UInt32[0],
    numthreads::Int = CPU_CORES,
    inplace::AbstractArray = UInt8[0],
    nochecks::Bool = false
    )
    if length(bounds) != 1
        if length(inplace) != 1
            loadklb!(inplace, filename(file), bounds[:,1], bounds[:,2], numthreads=numthreads, nochecks=nochecks)
        else
            loadklb(filename(file), bounds[:,1], bounds[:,2], numthreads=numthreads)
        end
    else
        if length(inplace) != 1
            loadklb!(inplace, filename(file), numthreads=numthreads, nochecks=nochecks)
        else
            loadklb(filename(file), numthreads=numthreads)
        end
    end
end


function FileIO.save(
    file::File{format"KLB"},
    A::AbstractArray
    ;
    numthreads::Int = CPU_CORES
    )
    writearray(filename(file), A, numthreads)
end


function klbheader( file::AbstractString )
    imagesize = zeros(UInt32, 5)
    blocksize = zeros(UInt32, 5)
    pixelspacing = ones(Float32, 5)
    ktype = Ref{Cint}(-1)
    compressiontype = Ref{Cint}(-1)
    metadata = repeat(" ", 256)

    errid = ccall( (:readKLBheader, "klb"), Cint,
        (Cstring, Ptr{UInt32}, Ref{Cint}, Ptr{Float32}, Ptr{UInt32}, Ref{Cint}, Ptr{Cchar}),
        file, imagesize, ktype, pixelspacing, blocksize, compressiontype, metadata)

    if errid != 0
        error("Could not read KLB header of file '$file'. Error code $errid")
    end

    Dict{AbstractString, Any}(
        "imagesize" => round(Int, imagesize),
        "blocksize" => round(Int, blocksize),
        "pixelspacing" => pixelspacing,
        "metadata" => strip(metadata),
        "datatype" => juliatype(ktype[]),
        "compressiontype" => compressiontype[],
        "spatialorder" => ["x", "y", "z"],
        "colordim" => 4,
        "timedim" => 5)
end


function loadklb(
    file::AbstractString
    ;
    numthreads::Int = CPU_CORES
    )
    header = klbheader(file)
    A = Array(header["datatype"], header["imagesize"]...)
    loadklb!(A, file, numthreads=numthreads, nochecks=true)
    A
end


function loadklb!(
    A::AbstractArray,
    file::AbstractString
    ;
    numthreads::Int = CPU_CORES,
    nochecks::Bool = false
    )
    if !nochecks
        header = klbheader(file)
        assert( header["datatype"] == eltype(A) )
        imagesize = header["imagesize"]
        for d in 1:5
            assert( imagesize[d] == size(A, d) )
        end
    end

    errid = ccall( (:readKLBstackInPlace, "klb"), Cint,
        (Cstring, Ptr{Void}, Ref{Cint}, Cint),
        file, A, Ref{Cint}(0), numthreads)

    if errid != 0
        error("Could not read KLB file '$file'. Error code $errid")
    end
end


function loadklb(
    file::AbstractString,
    lower_bounds::Vector{UInt32},
    upper_bounds::Vector{UInt32}
    ;
    numthreads::Int = CPU_CORES
    )
    header = klbheader(file)
    roisize = 1 + upper_bounds - lower_bounds
    A = Array(header["datatype"], roisize...)
    loadklb!(A, file, lower_bounds, upper_bounds, numthreads=numthreads, nochecks=true)
    A
end


function loadklb!(
    A::AbstractArray,
    file::AbstractString,
    lower_bounds::Vector{UInt32},
    upper_bounds::Vector{UInt32}
    ;
    numthreads::Int = CPU_CORES,
    nochecks::Bool = false
    )
    lb = lower_bounds - UInt32(1)
    ub = upper_bounds - UInt32(1)

    if !nochecks
        header = klbheader(file)
        assert( header["datatype"] == eltype(A) )
        roisize = 1 + ub - lb
        for d in 1:5
            assert( roisize[d] == size(A, d) )
        end
    end

    errid = ccall( (:readKLBroiInPlace, "klb"), Cint,
        (Cstring, Ptr{Void}, Ptr{UInt32}, Ptr{UInt32}, Cint),
        file, A, lb, ub, numthreads)

    if errid != 0
        error("Could not read KLB file '$file'. Error code $errid")
    end
    A
end


function writearray(
    filepath::AbstractString,
    A::AbstractArray,
    numthreads::Int = CPU_CORES
    ;
    pixelspacing = C_NULL,
    blocksize = C_NULL,
    compressiontype::Int = 1,
    metadata = C_NULL
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


function juliatype( klbtype::Cint )
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
