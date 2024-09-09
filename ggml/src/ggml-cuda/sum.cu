#if !defined(GGML_USE_HIPBLAS) && !defined(GGML_USE_MUSA)
// On Windows CUB uses libraries with variables called CC_PASCAL which conflict with the define in common.cuh.
// For this reason CUB must be included BEFORE anything else.
#include <cub/cub.cuh>
using namespace cub;
#endif // !defined(GGML_USE_HIPBLAS) && !defined(GGML_USE_MUSA)

#include "sumrows.cuh"
#include "sum.cuh"

#include <cstdint>

void sum_f32_cuda(ggml_cuda_pool & pool, const float * x, float * dst, const int64_t ne, cudaStream_t stream) {
#if !defined(GGML_USE_HIPBLAS) && !defined(GGML_USE_MUSA)
    size_t tmp_size = 0;
    DeviceReduce::Sum(nullptr,       tmp_size, x, dst, ne, stream);
    ggml_cuda_pool_alloc<uint8_t> tmp_alloc(pool, tmp_size);
    DeviceReduce::Sum(tmp_alloc.ptr, tmp_size, x, dst, ne, stream);
#else
    // Use (inefficient) sum_rows implementation as a fallback.
    // For AMD there is rocPRIM which could be used as a drop-in replacement via hipcub but this would require C++11 -> C++14.
    sum_rows_f32_cuda(x, dst, ne, 1, stream);
    GGML_UNUSED(pool);
#endif // !defined(GGML_USE_HIPBLAS) && !defined(GGML_USE_MUSA)
}

void ggml_cuda_op_sum(ggml_backend_cuda_context & ctx, ggml_tensor * dst) {
    const ggml_tensor * src0 = dst->src[0];

    GGML_ASSERT(src0->type == GGML_TYPE_F32);
    GGML_ASSERT( dst->type == GGML_TYPE_F32);
    GGML_ASSERT(ggml_is_contiguous(src0));

    const float * src0_d = (const float *) src0->data;
    float * dst_d = (float *) dst->data;

    const int64_t ne = ggml_nelements(src0);

    ggml_cuda_pool & pool = ctx.pool();
    cudaStream_t stream = ctx.stream();

    sum_f32_cuda(pool, src0_d, dst_d, ne, stream);
}
