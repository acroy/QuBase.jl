###################
# AbstractQuArray #
###################
    abstract AbstractQuArray{B<:AbstractBasis,T,N}

    # all subtypes of AbstractQuArray have to implement the following functions
    #   - coefftype
    #   - rawcoeffs 
    #   - rawbases 
    #   - copy
    #   - similar_type

    coeffs(qarr::AbstractQuArray) = rawcoeffs(qarr)
    
    # works generally as long as the single index form is defined
    bases(qarr::AbstractQuArray, i) = rawbases(qarr, i)
    bases(qarr::AbstractQuArray) = ntuple(ndims(qarr), i->bases(qarr, i))
    
    ########################
    # Array-like functions #
    ########################
    Base.size(qarr::AbstractQuArray, i...) = size(rawcoeffs(qarr), i...)
    Base.ndims(qarr::AbstractQuArray) = ndims(rawcoeffs(qarr))
    Base.length(qarr::AbstractQuArray) = length(rawcoeffs(qarr))

    Base.getindex(qarr::AbstractQuArray, i...) = getindex(rawcoeffs(qarr), i...)
    Base.setindex!(qarr::AbstractQuArray, i...) = setindex!(rawcoeffs(qarr), i...)

    Base.in(c, qarr::AbstractQuArray) = in(c, rawcoeffs(qarr))

    Base.(:(==))(a::AbstractQuArray, b::AbstractQuArray) = coeffs(a)==coeffs(b) && bases(a)==bases(b)
    
    typealias AbstractQuVector{B<:AbstractBasis,T} AbstractQuArray{B,T,1}
    typealias AbstractQuMatrix{B<:AbstractBasis,T} AbstractQuArray{B,T,2}


###########
# QuArray #
###########
    type QuArray{B<:AbstractBasis,T,N,A} <: AbstractQuArray{B,T,N}
        coeffs::A
        bases::NTuple{N,B}
        function QuArray(coeffs::AbstractArray{T,N}, bases::NTuple{N,B})
            if checkbases(coeffs, bases)
                new(coeffs, bases)
            else
                error("Coefficient array does not conform to input bases")
            end
        end
    end

    QuArray{B<:AbstractBasis,T,N}(coeffs::AbstractArray{T,N}, bases::NTuple{N,B}) = QuArray{B,T,N,typeof(coeffs)}(coeffs, bases)
    QuArray(coeffs, bases::AbstractBasis...) = QuArray(coeffs, bases)
    QuArray(coeffs) = QuArray(coeffs, map(FiniteBasis, size(coeffs)))

    typealias QuVector{B<:AbstractBasis,T,A} QuArray{B,T,1,A}
    typealias QuMatrix{B<:AbstractBasis,T,A} QuArray{B,T,2,A}

    # returns an appropriate outer constructor for the given (sub)type;
    # the constructor should construct an instance from a coefficient container
    # and a tuple of bases (see  QuArray(coeffs, bases) above)
    similar_type{Q<:QuArray}(::Type{Q}) = QuArray


    ######################
    # Accessor functions #
    ######################
    coefftype{B,T,N,A}(::QuArray{B,T,N,A}) = A

    rawcoeffs(qarr::QuArray) = qarr.coeffs

    rawbases(qarr::QuArray) = qarr.bases
    rawbases(qarr::QuArray, i) = qarr.bases[i]

    Base.copy(qa::QuArray) = QuArray(copy(qa.coeffs), copy(qa.bases))


##############
# CTranspose #
##############
    immutable CTranspose{B<:AbstractBasis,T,N,A} <: AbstractQuArray{B,T,N}
        qarr::QuArray{B,T,N,A}
        CTranspose(qarr::QuVector{B,T,A}) = new(qarr)
        CTranspose(qarr::QuMatrix{B,T,A}) = new(qarr)
        CTranspose(qarr::QuArray) = error("Conjugate transpose is unsupported for QuArrays of dimension $N")
    end

    CTranspose{B<:AbstractBasis,T,N,A}(qa::QuArray{B,T,N,A}) = CTranspose{B,T,N,A}(qa)
    CTranspose{B<:AbstractBasis,T,N}(coeffs::AbstractArray{T,N}, bases::NTuple{N,B}) = CTranspose(QuArray(coeffs, bases))

    typealias DualVector{B,T,A} CTranspose{B,T,1,A}
    typealias DualMatrix{B,T,A} CTranspose{B,T,2,A}

    similar_type{QC<:CTranspose}(::Type{QC}) = CTranspose
    
    
    ######################
    # Accessor functions #
    ######################
    coefftype{B,T,N,A}(::CTranspose{B,T,N,A}) = A

    rawcoeffs(ct::CTranspose) = rawcoeffs(ct.qarr)
    coeffs(ct::CTranspose) = rawcoeffs(ct)'

    revind(len, i) = len - (i-1)

    rawbases(ct::CTranspose, i) = rawbases(ct.qarr, i)
    rawbases(ct::CTranspose) =  rawbases(ct.qarr)

    bases(ct::CTranspose, i) = rawbases(ct, revind(ndims(ct), i))


    ########################
    # Array-like functions #
    ########################
    Base.copy(ct::CTranspose) = CTranspose(copy(ct.qarr))

    Base.ndims(ct::CTranspose) = ndims(ct.qarr)
    Base.length(ct::CTranspose) = length(ct.qarr)

    Base.size(ct::CTranspose) = reverse(size(ct.qarr))
    Base.size(ct::CTranspose, i) = size(ct, revind(ndims(ct), i))

    Base.getindex(ct::CTranspose, i, j) = getindex(ct.qarr, j, i)'
    Base.getindex(dv::DualVector, i) = getindex(dv.qarr, i)'

    Base.setindex!(ct::CTranspose, x, i, j) = setindex!(ct.qarr, x', j, i)
    Base.setindex!(dv::DualVector, x, i) = setindex!(dv.qarr, x', i)

    Base.ctranspose(qarr::QuArray) = CTranspose(qarr)
    Base.ctranspose(ct::CTranspose) = ct.qarr


################
# LabelQuArray #
################
    typealias LabelQuArray{B<:LabelBasis,T,N,A} QuArray{B,T,N,A}
    typealias TupleArray{T<:Tuple,N} Array{T,N}

    Base.getindex(larr::LabelQuArray, tups::Union(Tuple,TupleArray)...) = getindex(larr, map(getindex, bases(larr), tups)...)
    Base.setindex!(larr::LabelQuArray, x, tups::Union(Tuple,TupleArray)...) = setindex!(larr, x, map(getindex, bases(larr), tups)...)


###################
# Promotion rules #
###################

    Base.promote_rule{B1,B2,T1,T2,N,A1,A2}(::Type{CTranspose{B1,T1,N,A1}}, ::Type{QuArray{B2,T2,N,A2}}) = QuArray{promote_type(B1,B2),promote_type(T1,T2),N,promote_type(A1,A2)}

######################
# Printing Functions #
######################
    Base.summary{B}(qarr::AbstractQuArray{B}) = "$(sizenotation(size(qarr))) $(typerepr(qarr)) in $B"
    Base.summary(larr::LabelQuArray) = "$(sizenotation(size(larr))) $(typerepr(larr)) in labeled bases $(bases(larr))"

    function Base.show(io::IO, qarr::AbstractQuArray)
        println(io, summary(qarr)*":")
        println(io, "...coefficients: $(coefftype(qarr))")
        print(io, repr(coeffs(qarr)))
    end


####################
# Helper Functions #
####################
    typerepr(qa::AbstractQuArray) = "$(typeof(qa).name)"
    typerepr(::QuVector) = "QuVector"
    typerepr(::QuMatrix) = "QuMatrix"
    typerepr(::DualVector) = "DualVector"
    typerepr(::DualMatrix) = "DualMatrix"
    typerepr(::QuArray) = "QuArray"

    sizenotation(@compat(tup::Tuple{Int})) = "$(first(tup))-element"
    sizenotation(@compat(tup::Tuple{Vararg{Int}})) = reduce(*, map(s->"$(s)x", tup))[1:end-1]

    function checkbases{N}(coeffs, bases::NTuple{N,AbstractBasis})
        if ndims(coeffs) == length(bases)
            return reduce(&, [checkcoeffs(coeffs, i, bases[i]) for i=1:N])
        end
        return false
    end

export QuArray, QuVector, QuMatrix, CTranspose, DualVector, DualMatrix,
    rawcoeffs,
    coeffs,
    coefftype,
    rawbases,
    bases
