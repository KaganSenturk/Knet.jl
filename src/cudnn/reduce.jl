import Base: unsafe_convert
using Knet.KnetArrays: DevArray
using CUDA: CuArray

using CUDA.CUDNN:
    #cudnnReduceTensor,
    cudnnGetReductionIndicesSize,
    cudnnGetReductionWorkspaceSize,
    cudnnReduceTensorDescriptor_t,
        cudnnCreateReduceTensorDescriptor,
        cudnnSetReduceTensorDescriptor,
        cudnnGetReduceTensorDescriptor,
        cudnnDestroyReduceTensorDescriptor,
    cudnnReduceTensorOp_t,
        CUDNN_REDUCE_TENSOR_ADD,          # 0,
        CUDNN_REDUCE_TENSOR_MUL,          # 1,
        CUDNN_REDUCE_TENSOR_MIN,          # 2,
        CUDNN_REDUCE_TENSOR_MAX,          # 3,
        CUDNN_REDUCE_TENSOR_AMAX,         # 4,
        CUDNN_REDUCE_TENSOR_AVG,          # 5,
        CUDNN_REDUCE_TENSOR_NORM1,        # 6,
        CUDNN_REDUCE_TENSOR_NORM2,        # 7,
        CUDNN_REDUCE_TENSOR_MUL_NO_ZEROS, # 8,
    cudnnReduceTensorIndices_t,
        CUDNN_REDUCE_TENSOR_NO_INDICES,        # 0,
        CUDNN_REDUCE_TENSOR_FLATTENED_INDICES, # 1,
    cudnnIndicesType_t,
        CUDNN_32BIT_INDICES, # 0,
        CUDNN_64BIT_INDICES, # 1,
        CUDNN_16BIT_INDICES, # 2,
        CUDNN_8BIT_INDICES,  # 3,
    handle


cudnnReduceTensor(x; o...)                       = cudnnReduceTensorWithDefaults(x; o...)
cudnnReduceTensor(x, reduceTensorDesc; o...)     = cudnnReduceTensorWithDefaults(x; reduceTensorDesc, o...)
cudnnReduceTensor!(y, x; o...)                   = cudnnReduceTensorWithDefaults(x; y, o...)
cudnnReduceTensor!(y, x, reduceTensorDesc; o...) = cudnnReduceTensorWithDefaults(x; y, reduceTensorDesc, o...)


# This is unfortunately 10x slower than libknet8, 2x slower than CUDA.jl
function cudnnReduceTensorWithDefaults(
    x::R;
    dims::Dims = ntuple(i->1,N),
    reduceTensorOp::cudnnReduceTensorOp_t = CUDNN_REDUCE_TENSOR_ADD,
    reduceTensorCompType::DataType = (T <: Float64 ? Float64 : Float32),
    reduceTensorNanOpt::cudnnNanPropagation_t = CUDNN_NOT_PROPAGATE_NAN,
    reduceTensorIndices::cudnnReduceTensorIndices_t = CUDNN_REDUCE_TENSOR_NO_INDICES,
    reduceTensorIndicesType::cudnnIndicesType_t = CUDNN_32BIT_INDICES,
    reduceTensorDesc::cudnnReduceTensorDescriptor = cudnnReduceTensorDescriptor(reduceTensorOp, DT(reduceTensorCompType), reduceTensorNanOpt, reduceTensorIndices, reduceTensorIndicesType),
    alpha::Real = 1,
    xDesc::cudnnTensorDescriptor = TD(x),
    beta::Real = 0,
    y::R = similar(x, dims),
    yDesc::cudnnTensorDescriptor = TD(y),
    indices::Union{DevArray,Nothing} = nothing,
    workspace::DevArray = cudnnReductionWorkspace(reduceTensorDesc, xDesc, yDesc),
) where {T,N,R<:DevArray{T,N}}
    alpha, beta = scalr(alpha,x), scalr(beta,x)
    cudnnReduceTensorAutoGrad(x; reduceTensorDesc, alpha, xDesc, beta, yDesc, y, indices, workspace)
end


function cudnnReduceTensorAutoGrad(x; reduceTensorDesc, alpha, xDesc, beta, yDesc, y, indices, workspace)
    CUDA.CUDNN.cudnnReduceTensor(handle(), reduceTensorDesc, c_null(indices), sizeof(indices), workspace, sizeof(workspace), alpha, xDesc, x, beta, yDesc, y)
    return y
end


# TODO: define backward function


function cudnnReductionWorkspace(reduceTensorDesc::cudnnReduceTensorDescriptor, xDesc::cudnnTensorDescriptor, yDesc::cudnnTensorDescriptor)
    sz = Csize_t[0]; cudnnGetReductionWorkspaceSize(handle(), reduceTensorDesc, xDesc, yDesc, sz)
    return cudnnWorkspace(sz[1])
end