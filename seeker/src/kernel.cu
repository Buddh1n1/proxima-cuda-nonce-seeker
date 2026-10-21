// CUDA/NVRTC adaptation of the attributed and licensed OpenCL source below.
typedef unsigned char uchar;
typedef unsigned int uint;
typedef unsigned long long ulong;
typedef unsigned long long size_t;
#define get_global_id(dimension) ((size_t)blockIdx.x*blockDim.x+threadIdx.x)
#define get_local_id(dimension) threadIdx.x
#define get_local_size(dimension) blockDim.x
__device__ inline uint min(uint a,uint b){return a<b?a:b;}
__device__ inline int abs(int x){return x<0?-x:x;}
/* ALTERED SOURCE: Proxima ECVRF GPU seeker and offline validation,
 * OpenCL port and variable-base multiplication wrapper. Ed25519 ref10 arithmetic adapted
 * from solana-labs/solana-perf-libs commit
 * 233c4457fd8d425da99cb3db46b2be8eb8b98997.
 * SHA-512 adapted from public-domain TweetNaCl, 20140427.
 * Kernel receives a scalar from the trusted local host; no wallet or network API.
 * Offline validation uses only public synthetic test keys.
Copyright (c) 2015 Orson Peters <orsonpeters@gmail.com>

This software is provided 'as-is', without any express or implied warranty. In no event will the
authors be held liable for any damages arising from the use of this software.

Permission is granted to anyone to use this software for any purpose, including commercial
applications, and to alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the
   original software. If you use this software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be misrepresented as
   being the original software.

3. This notice may not be removed or altered from any source distribution.

================================

Copyright (c) 2017-2019 isis agora lovecruft. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 */
typedef uchar u8;
typedef ulong u64;
typedef int int32_t;
typedef long long int64_t;
typedef uint uint32_t;
typedef ulong uint64_t;
#define FOR(i,n) for (i=0;i<n;++i)


#ifndef FE_H
#define FE_H




/*
    fe means field element.
    Here the field is \Z/(2^255-19).
    An element t, entries t[0]...t[9], represents the integer
    t[0]+2^26 t[1]+2^51 t[2]+2^77 t[3]+2^102 t[4]+...+2^230 t[9].
    Bounds on each t[i] vary depending on context.
*/


typedef int32_t fe[10];


__device__ __forceinline__ long long vrf_mulwide(int a,int b) {
    long long r;asm("mul.wide.s32 %0, %1, %2;":"=l"(r):"r"(a),"r"(b));return r;
}
__device__ void fe_0(fe h);
__device__ void fe_1(fe h);
__device__ int fe_is_0(fe h);
__device__ int fe_is_1(fe h);

__device__ void fe_frombytes(fe h, const unsigned char *s);
__device__ void fe_tobytes(unsigned char *s, const fe h);

__device__ void fe_copy(fe h, const fe f);
__device__ int fe_isnegative(const fe f);
__device__ int fe_isnonzero(const fe f);
__device__ void fe_cmov(fe f, const fe g, unsigned int b);
__device__ void fe_cswap(fe f, fe g, unsigned int b);

__device__ void fe_neg(fe h, const fe f);
__device__ void fe_add(fe h, const fe f, const fe g);
__device__ void fe_invert(fe out, const fe z);
__device__ void fe_sq(fe h, const fe f);
__device__ void fe_sq2(fe h, const fe f);
__device__ void fe_mul(fe h, const fe f, const fe g);

__device__ void fe_mul_pair(fe a,fe b,const fe af,const fe ag,const fe bf,const fe bg){

    int32_t af0 = af[0];
    int32_t af1 = af[1];
    int32_t af2 = af[2];
    int32_t af3 = af[3];
    int32_t af4 = af[4];
    int32_t af5 = af[5];
    int32_t af6 = af[6];
    int32_t af7 = af[7];
    int32_t af8 = af[8];
    int32_t af9 = af[9];
    int32_t ag0 = ag[0];
    int32_t ag1 = ag[1];
    int32_t ag2 = ag[2];
    int32_t ag3 = ag[3];
    int32_t ag4 = ag[4];
    int32_t ag5 = ag[5];
    int32_t ag6 = ag[6];
    int32_t ag7 = ag[7];
    int32_t ag8 = ag[8];
    int32_t ag9 = ag[9];
    int32_t ag1_19 = 19 * ag1; /* 1.959375*2^29 */
    int32_t ag2_19 = 19 * ag2; /* 1.959375*2^30; still ok */
    int32_t ag3_19 = 19 * ag3;
    int32_t ag4_19 = 19 * ag4;
    int32_t ag5_19 = 19 * ag5;
    int32_t ag6_19 = 19 * ag6;
    int32_t ag7_19 = 19 * ag7;
    int32_t ag8_19 = 19 * ag8;
    int32_t ag9_19 = 19 * ag9;
    int32_t af1_2 = 2 * af1;
    int32_t af3_2 = 2 * af3;
    int32_t af5_2 = 2 * af5;
    int32_t af7_2 = 2 * af7;
    int32_t af9_2 = 2 * af9;

    

    int32_t bf0 = bf[0];
    int32_t bf1 = bf[1];
    int32_t bf2 = bf[2];
    int32_t bf3 = bf[3];
    int32_t bf4 = bf[4];
    int32_t bf5 = bf[5];
    int32_t bf6 = bf[6];
    int32_t bf7 = bf[7];
    int32_t bf8 = bf[8];
    int32_t bf9 = bf[9];
    int32_t bg0 = bg[0];
    int32_t bg1 = bg[1];
    int32_t bg2 = bg[2];
    int32_t bg3 = bg[3];
    int32_t bg4 = bg[4];
    int32_t bg5 = bg[5];
    int32_t bg6 = bg[6];
    int32_t bg7 = bg[7];
    int32_t bg8 = bg[8];
    int32_t bg9 = bg[9];
    int32_t bg1_19 = 19 * bg1; /* 1.959375*2^29 */
    int32_t bg2_19 = 19 * bg2; /* 1.959375*2^30; still ok */
    int32_t bg3_19 = 19 * bg3;
    int32_t bg4_19 = 19 * bg4;
    int32_t bg5_19 = 19 * bg5;
    int32_t bg6_19 = 19 * bg6;
    int32_t bg7_19 = 19 * bg7;
    int32_t bg8_19 = 19 * bg8;
    int32_t bg9_19 = 19 * bg9;
    int32_t bf1_2 = 2 * bf1;
    int32_t bf3_2 = 2 * bf3;
    int32_t bf5_2 = 2 * bf5;
    int32_t bf7_2 = 2 * bf7;
    int32_t bf9_2 = 2 * bf9;

    
    int64_t ca=0,cb=0;
    int64_t ha0=((vrf_mulwide(af0,ag0)) + (vrf_mulwide(af1_2,ag9_19)) + (vrf_mulwide(af2,ag8_19)) + (vrf_mulwide(af3_2,ag7_19)) + (vrf_mulwide(af4,ag6_19)) + (vrf_mulwide(af5_2,ag5_19)) + (vrf_mulwide(af6,ag4_19)) + (vrf_mulwide(af7_2,ag3_19)) + (vrf_mulwide(af8,ag2_19)) + (vrf_mulwide(af9_2,ag1_19)))+ca;
    int64_t hb0=((vrf_mulwide(bf0,bg0)) + (vrf_mulwide(bf1_2,bg9_19)) + (vrf_mulwide(bf2,bg8_19)) + (vrf_mulwide(bf3_2,bg7_19)) + (vrf_mulwide(bf4,bg6_19)) + (vrf_mulwide(bf5_2,bg5_19)) + (vrf_mulwide(bf6,bg4_19)) + (vrf_mulwide(bf7_2,bg3_19)) + (vrf_mulwide(bf8,bg2_19)) + (vrf_mulwide(bf9_2,bg1_19)))+cb;
    ca=(ha0+(1LL<<25))>>26;cb=(hb0+(1LL<<25))>>26;
    a[0]=(int)(ha0-ca*(1LL<<26));b[0]=(int)(hb0-cb*(1LL<<26));
    int64_t ha1=((vrf_mulwide(af0,ag1)) + (vrf_mulwide(af1,ag0))   + (vrf_mulwide(af2,ag9_19)) + (vrf_mulwide(af3,ag8_19)) + (vrf_mulwide(af4,ag7_19)) + (vrf_mulwide(af5,ag6_19)) + (vrf_mulwide(af6,ag5_19)) + (vrf_mulwide(af7,ag4_19)) + (vrf_mulwide(af8,ag3_19)) + (vrf_mulwide(af9,ag2_19)))+ca;
    int64_t hb1=((vrf_mulwide(bf0,bg1)) + (vrf_mulwide(bf1,bg0))   + (vrf_mulwide(bf2,bg9_19)) + (vrf_mulwide(bf3,bg8_19)) + (vrf_mulwide(bf4,bg7_19)) + (vrf_mulwide(bf5,bg6_19)) + (vrf_mulwide(bf6,bg5_19)) + (vrf_mulwide(bf7,bg4_19)) + (vrf_mulwide(bf8,bg3_19)) + (vrf_mulwide(bf9,bg2_19)))+cb;
    ca=(ha1+(1LL<<24))>>25;cb=(hb1+(1LL<<24))>>25;
    a[1]=(int)(ha1-ca*(1LL<<25));b[1]=(int)(hb1-cb*(1LL<<25));
    int64_t ha2=((vrf_mulwide(af0,ag2)) + (vrf_mulwide(af1_2,ag1)) + (vrf_mulwide(af2,ag0))   + (vrf_mulwide(af3_2,ag9_19)) + (vrf_mulwide(af4,ag8_19)) + (vrf_mulwide(af5_2,ag7_19)) + (vrf_mulwide(af6,ag6_19)) + (vrf_mulwide(af7_2,ag5_19)) + (vrf_mulwide(af8,ag4_19)) + (vrf_mulwide(af9_2,ag3_19)))+ca;
    int64_t hb2=((vrf_mulwide(bf0,bg2)) + (vrf_mulwide(bf1_2,bg1)) + (vrf_mulwide(bf2,bg0))   + (vrf_mulwide(bf3_2,bg9_19)) + (vrf_mulwide(bf4,bg8_19)) + (vrf_mulwide(bf5_2,bg7_19)) + (vrf_mulwide(bf6,bg6_19)) + (vrf_mulwide(bf7_2,bg5_19)) + (vrf_mulwide(bf8,bg4_19)) + (vrf_mulwide(bf9_2,bg3_19)))+cb;
    ca=(ha2+(1LL<<25))>>26;cb=(hb2+(1LL<<25))>>26;
    a[2]=(int)(ha2-ca*(1LL<<26));b[2]=(int)(hb2-cb*(1LL<<26));
    int64_t ha3=((vrf_mulwide(af0,ag3)) + (vrf_mulwide(af1,ag2))   + (vrf_mulwide(af2,ag1))   + (vrf_mulwide(af3,ag0))   + (vrf_mulwide(af4,ag9_19)) + (vrf_mulwide(af5,ag8_19)) + (vrf_mulwide(af6,ag7_19)) + (vrf_mulwide(af7,ag6_19)) + (vrf_mulwide(af8,ag5_19)) + (vrf_mulwide(af9,ag4_19)))+ca;
    int64_t hb3=((vrf_mulwide(bf0,bg3)) + (vrf_mulwide(bf1,bg2))   + (vrf_mulwide(bf2,bg1))   + (vrf_mulwide(bf3,bg0))   + (vrf_mulwide(bf4,bg9_19)) + (vrf_mulwide(bf5,bg8_19)) + (vrf_mulwide(bf6,bg7_19)) + (vrf_mulwide(bf7,bg6_19)) + (vrf_mulwide(bf8,bg5_19)) + (vrf_mulwide(bf9,bg4_19)))+cb;
    ca=(ha3+(1LL<<24))>>25;cb=(hb3+(1LL<<24))>>25;
    a[3]=(int)(ha3-ca*(1LL<<25));b[3]=(int)(hb3-cb*(1LL<<25));
    int64_t ha4=((vrf_mulwide(af0,ag4)) + (vrf_mulwide(af1_2,ag3)) + (vrf_mulwide(af2,ag2))   + (vrf_mulwide(af3_2,ag1)) + (vrf_mulwide(af4,ag0))   + (vrf_mulwide(af5_2,ag9_19)) + (vrf_mulwide(af6,ag8_19)) + (vrf_mulwide(af7_2,ag7_19)) + (vrf_mulwide(af8,ag6_19)) + (vrf_mulwide(af9_2,ag5_19)))+ca;
    int64_t hb4=((vrf_mulwide(bf0,bg4)) + (vrf_mulwide(bf1_2,bg3)) + (vrf_mulwide(bf2,bg2))   + (vrf_mulwide(bf3_2,bg1)) + (vrf_mulwide(bf4,bg0))   + (vrf_mulwide(bf5_2,bg9_19)) + (vrf_mulwide(bf6,bg8_19)) + (vrf_mulwide(bf7_2,bg7_19)) + (vrf_mulwide(bf8,bg6_19)) + (vrf_mulwide(bf9_2,bg5_19)))+cb;
    ca=(ha4+(1LL<<25))>>26;cb=(hb4+(1LL<<25))>>26;
    a[4]=(int)(ha4-ca*(1LL<<26));b[4]=(int)(hb4-cb*(1LL<<26));
    int64_t ha5=((vrf_mulwide(af0,ag5)) + (vrf_mulwide(af1,ag4))   + (vrf_mulwide(af2,ag3))   + (vrf_mulwide(af3,ag2))   + (vrf_mulwide(af4,ag1))   + (vrf_mulwide(af5,ag0))   + (vrf_mulwide(af6,ag9_19)) + (vrf_mulwide(af7,ag8_19)) + (vrf_mulwide(af8,ag7_19)) + (vrf_mulwide(af9,ag6_19)))+ca;
    int64_t hb5=((vrf_mulwide(bf0,bg5)) + (vrf_mulwide(bf1,bg4))   + (vrf_mulwide(bf2,bg3))   + (vrf_mulwide(bf3,bg2))   + (vrf_mulwide(bf4,bg1))   + (vrf_mulwide(bf5,bg0))   + (vrf_mulwide(bf6,bg9_19)) + (vrf_mulwide(bf7,bg8_19)) + (vrf_mulwide(bf8,bg7_19)) + (vrf_mulwide(bf9,bg6_19)))+cb;
    ca=(ha5+(1LL<<24))>>25;cb=(hb5+(1LL<<24))>>25;
    a[5]=(int)(ha5-ca*(1LL<<25));b[5]=(int)(hb5-cb*(1LL<<25));
    int64_t ha6=((vrf_mulwide(af0,ag6)) + (vrf_mulwide(af1_2,ag5)) + (vrf_mulwide(af2,ag4))   + (vrf_mulwide(af3_2,ag3)) + (vrf_mulwide(af4,ag2))   + (vrf_mulwide(af5_2,ag1)) + (vrf_mulwide(af6,ag0))   + (vrf_mulwide(af7_2,ag9_19)) + (vrf_mulwide(af8,ag8_19)) + (vrf_mulwide(af9_2,ag7_19)))+ca;
    int64_t hb6=((vrf_mulwide(bf0,bg6)) + (vrf_mulwide(bf1_2,bg5)) + (vrf_mulwide(bf2,bg4))   + (vrf_mulwide(bf3_2,bg3)) + (vrf_mulwide(bf4,bg2))   + (vrf_mulwide(bf5_2,bg1)) + (vrf_mulwide(bf6,bg0))   + (vrf_mulwide(bf7_2,bg9_19)) + (vrf_mulwide(bf8,bg8_19)) + (vrf_mulwide(bf9_2,bg7_19)))+cb;
    ca=(ha6+(1LL<<25))>>26;cb=(hb6+(1LL<<25))>>26;
    a[6]=(int)(ha6-ca*(1LL<<26));b[6]=(int)(hb6-cb*(1LL<<26));
    int64_t ha7=((vrf_mulwide(af0,ag7)) + (vrf_mulwide(af1,ag6))   + (vrf_mulwide(af2,ag5))   + (vrf_mulwide(af3,ag4))   + (vrf_mulwide(af4,ag3))   + (vrf_mulwide(af5,ag2))   + (vrf_mulwide(af6,ag1))   + (vrf_mulwide(af7,ag0))   + (vrf_mulwide(af8,ag9_19)) + (vrf_mulwide(af9,ag8_19)))+ca;
    int64_t hb7=((vrf_mulwide(bf0,bg7)) + (vrf_mulwide(bf1,bg6))   + (vrf_mulwide(bf2,bg5))   + (vrf_mulwide(bf3,bg4))   + (vrf_mulwide(bf4,bg3))   + (vrf_mulwide(bf5,bg2))   + (vrf_mulwide(bf6,bg1))   + (vrf_mulwide(bf7,bg0))   + (vrf_mulwide(bf8,bg9_19)) + (vrf_mulwide(bf9,bg8_19)))+cb;
    ca=(ha7+(1LL<<24))>>25;cb=(hb7+(1LL<<24))>>25;
    a[7]=(int)(ha7-ca*(1LL<<25));b[7]=(int)(hb7-cb*(1LL<<25));
    int64_t ha8=((vrf_mulwide(af0,ag8)) + (vrf_mulwide(af1_2,ag7)) + (vrf_mulwide(af2,ag6))   + (vrf_mulwide(af3_2,ag5)) + (vrf_mulwide(af4,ag4))   + (vrf_mulwide(af5_2,ag3)) + (vrf_mulwide(af6,ag2))   + (vrf_mulwide(af7_2,ag1)) + (vrf_mulwide(af8,ag0))   + (vrf_mulwide(af9_2,ag9_19)))+ca;
    int64_t hb8=((vrf_mulwide(bf0,bg8)) + (vrf_mulwide(bf1_2,bg7)) + (vrf_mulwide(bf2,bg6))   + (vrf_mulwide(bf3_2,bg5)) + (vrf_mulwide(bf4,bg4))   + (vrf_mulwide(bf5_2,bg3)) + (vrf_mulwide(bf6,bg2))   + (vrf_mulwide(bf7_2,bg1)) + (vrf_mulwide(bf8,bg0))   + (vrf_mulwide(bf9_2,bg9_19)))+cb;
    ca=(ha8+(1LL<<25))>>26;cb=(hb8+(1LL<<25))>>26;
    a[8]=(int)(ha8-ca*(1LL<<26));b[8]=(int)(hb8-cb*(1LL<<26));
    int64_t ha9=((vrf_mulwide(af0,ag9)) + (vrf_mulwide(af1,ag8))   + (vrf_mulwide(af2,ag7))   + (vrf_mulwide(af3,ag6))   + (vrf_mulwide(af4,ag5))   + (vrf_mulwide(af5,ag4))   + (vrf_mulwide(af6,ag3))   + (vrf_mulwide(af7,ag2))   + (vrf_mulwide(af8,ag1))   + (vrf_mulwide(af9,ag0))   )+ca;
    int64_t hb9=((vrf_mulwide(bf0,bg9)) + (vrf_mulwide(bf1,bg8))   + (vrf_mulwide(bf2,bg7))   + (vrf_mulwide(bf3,bg6))   + (vrf_mulwide(bf4,bg5))   + (vrf_mulwide(bf5,bg4))   + (vrf_mulwide(bf6,bg3))   + (vrf_mulwide(bf7,bg2))   + (vrf_mulwide(bf8,bg1))   + (vrf_mulwide(bf9,bg0))   )+cb;
    ca=(ha9+(1LL<<24))>>25;cb=(hb9+(1LL<<24))>>25;
    a[9]=(int)(ha9-ca*(1LL<<25));b[9]=(int)(hb9-cb*(1LL<<25));
    int64_t wa=(int64_t)a[0]+ca*19,wb=(int64_t)b[0]+cb*19;
    ca=(wa+(1LL<<25))>>26;cb=(wb+(1LL<<25))>>26;
    a[0]=(int)(wa-ca*(1LL<<26));b[0]=(int)(wb-cb*(1LL<<26));
    a[1]+=(int)ca;b[1]+=(int)cb;
}

__device__ void fe_mul121666(fe h, fe f);
__device__ void fe_pow22523(fe out, const fe z);
__device__ void fe_sub(fe h, const fe f, const fe g);

#endif

#ifndef GE_H
#define GE_H




/*
ge means group element.

Here the group is the set of pairs (x,y) of field elements (see fe.h)
satisfying -x^2 + y^2 = 1 + d x^2y^2
where d = -121665/121666.

Representations:
  ge_p2 (projective): (X:Y:Z) satisfying x=X/Z, y=Y/Z
  ge_p3 (extended): (X:Y:Z:T) satisfying x=X/Z, y=Y/Z, XY=ZT
  ge_p1p1 (completed): ((X:Z),(Y:T)) satisfying x=X/Z, y=Y/T
  ge_precomp (Duif): (y+x,y-x,2dxy)
*/

typedef struct {
  fe X;
  fe Y;
  fe Z;
} ge_p2;

typedef struct {
  fe X;
  fe Y;
  fe Z;
  fe T;
} ge_p3;

typedef struct {
  fe X;
  fe Y;
  fe Z;
  fe T;
} ge_p1p1;

typedef struct {
  fe yplusx;
  fe yminusx;
  fe xy2d;
} ge_precomp;

typedef struct {
  fe YplusX;
  fe YminusX;
  fe Z;
  fe T2d;
} ge_cached;

#define GE_LOOKUP_SIZE 8

__device__ void ge_p3_tobytes(unsigned char *s, const ge_p3 *h);
__device__ void ge_tobytes(unsigned char *s, const ge_p2 *h);
__device__ int ge_frombytes_negate_vartime(ge_p3 *h, const unsigned char *s);

__device__ void ge_add(ge_p1p1 *r, const ge_p3 *p, const ge_cached *q);
__device__ void ge_sub(ge_p1p1 *r, const ge_p3 *p, const ge_cached *q);
__device__ void ge_addsub(ge_p1p1 *r, const ge_p3 *p, const ge_cached *q, bool add);
__device__ void ge_double_scalarmult_vartime(ge_p2 *r, const unsigned char *a, const ge_cached *A, const unsigned char *b);
__device__ void ge_madd(ge_p1p1 *r, const ge_p3 *p, const ge_precomp *q);
__device__ void ge_msub(ge_p1p1 *r, const ge_p3 *p, const ge_precomp *q);
__device__ void ge_maddsub(ge_p1p1 *r, const ge_p3 *p, const ge_precomp *q, bool add);
__device__ void ge_scalarmult_base(ge_p3 *h, const unsigned char *a);

__device__ void ge_p1p1_to_p2(ge_p2 *r, const ge_p1p1 *p);
__device__ void ge_p1p1_to_p3(ge_p3 *r, const ge_p1p1 *p);
__device__ void ge_p2_0(ge_p2 *h);
__device__ void ge_p2_dbl(ge_p1p1 *r, const ge_p2 *p);
__device__ void ge_p3_0(ge_p3 *h);
__device__ void ge_p3_dbl(ge_p1p1 *r, const ge_p3 *p);
__device__ void ge_p3_to_cached(ge_cached *r, const ge_p3 *p);
__device__ void ge_p3_to_p2(ge_p2 *r, const ge_p3 *p);

#endif


#ifndef COMMON_CU
#define COMMON_CU

__device__ static uint64_t load_3(const unsigned char *in) {
    uint64_t result;

    result = (uint64_t) in[0];
    result |= ((uint64_t) in[1]) << 8;
    result |= ((uint64_t) in[2]) << 16;

    return result;
}

__device__ static uint64_t load_4(const unsigned char *in) {
    uint64_t result;

    result = (uint64_t) in[0];
    result |= ((uint64_t) in[1]) << 8;
    result |= ((uint64_t) in[2]) << 16;
    result |= ((uint64_t) in[3]) << 24;
    
    return result;
}

__device__ static uint64_t load_7(const unsigned char *in) {
    uint64_t result;

    result = (uint64_t) in[0];
    result |= ((uint64_t) in[1]) << 8;
    result |= ((uint64_t) in[2]) << 16;
    result |= ((uint64_t) in[3]) << 24;
    result |= ((uint64_t) in[4]) << 32;
    result |= ((uint64_t) in[5]) << 40;
    result |= ((uint64_t) in[6]) << 48;

    return result;
}


#endif





#ifndef FE_CU
#define FE_CU


/*
    h = 0
*/

__device__ void fe_0(fe h) {
    h[0] = 0;
    h[1] = 0;
    h[2] = 0;
    h[3] = 0;
    h[4] = 0;
    h[5] = 0;
    h[6] = 0;
    h[7] = 0;
    h[8] = 0;
    h[9] = 0;
}



/*
    h = 1
*/

__device__ void fe_1(fe h) {
    h[0] = 1;
    h[1] = 0;
    h[2] = 0;
    h[3] = 0;
    h[4] = 0;
    h[5] = 0;
    h[6] = 0;
    h[7] = 0;
    h[8] = 0;
    h[9] = 0;
}


__device__ int fe_is_1(fe h) {
    if (h[0] != 1) {
        return 0;
    }
    for (int i = 1; i < 9; i++) {
        if (h[i] != 0) {
            return 0;
        }
    }
    return 1;
}

__device__ int fe_is_0(fe h) {
    for (int i = 0; i < 9; i++) {
        if (h[i] != 0) {
            return 0;
        }
    }
    return 1;
}



/*
    h = f + g
    Can overlap h with f or g.

    Preconditions:
       |f| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.
       |g| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.

    Postconditions:
       |h| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.
*/

__device__ void fe_add(fe h, const fe f, const fe g) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t h0 = f0 + g0;
    int32_t h1 = f1 + g1;
    int32_t h2 = f2 + g2;
    int32_t h3 = f3 + g3;
    int32_t h4 = f4 + g4;
    int32_t h5 = f5 + g5;
    int32_t h6 = f6 + g6;
    int32_t h7 = f7 + g7;
    int32_t h8 = f8 + g8;
    int32_t h9 = f9 + g9;
    
    h[0] = h0;
    h[1] = h1;
    h[2] = h2;
    h[3] = h3;
    h[4] = h4;
    h[5] = h5;
    h[6] = h6;
    h[7] = h7;
    h[8] = h8;
    h[9] = h9;
}



/*
    Replace (f,g) with (g,g) if b == 1;
    replace (f,g) with (f,g) if b == 0.

    Preconditions: b in {0,1}.
*/

__device__ void fe_cmov(fe f, const fe g, unsigned int b) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t x0 = f0 ^ g0;
    int32_t x1 = f1 ^ g1;
    int32_t x2 = f2 ^ g2;
    int32_t x3 = f3 ^ g3;
    int32_t x4 = f4 ^ g4;
    int32_t x5 = f5 ^ g5;
    int32_t x6 = f6 ^ g6;
    int32_t x7 = f7 ^ g7;
    int32_t x8 = f8 ^ g8;
    int32_t x9 = f9 ^ g9;

    b = (unsigned int) (- (int) b); /* silence warning */
    x0 &= b;
    x1 &= b;
    x2 &= b;
    x3 &= b;
    x4 &= b;
    x5 &= b;
    x6 &= b;
    x7 &= b;
    x8 &= b;
    x9 &= b;
    
    f[0] = f0 ^ x0;
    f[1] = f1 ^ x1;
    f[2] = f2 ^ x2;
    f[3] = f3 ^ x3;
    f[4] = f4 ^ x4;
    f[5] = f5 ^ x5;
    f[6] = f6 ^ x6;
    f[7] = f7 ^ x7;
    f[8] = f8 ^ x8;
    f[9] = f9 ^ x9;
}

/*
    Replace (f,g) with (g,f) if b == 1;
    replace (f,g) with (f,g) if b == 0.

    Preconditions: b in {0,1}.
*/

__device__ void fe_cswap(fe f,fe g,unsigned int b) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t x0 = f0 ^ g0;
    int32_t x1 = f1 ^ g1;
    int32_t x2 = f2 ^ g2;
    int32_t x3 = f3 ^ g3;
    int32_t x4 = f4 ^ g4;
    int32_t x5 = f5 ^ g5;
    int32_t x6 = f6 ^ g6;
    int32_t x7 = f7 ^ g7;
    int32_t x8 = f8 ^ g8;
    int32_t x9 = f9 ^ g9;
    b = (unsigned int) (- (int) b); /* silence warning */
    x0 &= b;
    x1 &= b;
    x2 &= b;
    x3 &= b;
    x4 &= b;
    x5 &= b;
    x6 &= b;
    x7 &= b;
    x8 &= b;
    x9 &= b;
    f[0] = f0 ^ x0;
    f[1] = f1 ^ x1;
    f[2] = f2 ^ x2;
    f[3] = f3 ^ x3;
    f[4] = f4 ^ x4;
    f[5] = f5 ^ x5;
    f[6] = f6 ^ x6;
    f[7] = f7 ^ x7;
    f[8] = f8 ^ x8;
    f[9] = f9 ^ x9;
    g[0] = g0 ^ x0;
    g[1] = g1 ^ x1;
    g[2] = g2 ^ x2;
    g[3] = g3 ^ x3;
    g[4] = g4 ^ x4;
    g[5] = g5 ^ x5;
    g[6] = g6 ^ x6;
    g[7] = g7 ^ x7;
    g[8] = g8 ^ x8;
    g[9] = g9 ^ x9;
}



/*
    h = f
*/

__device__ void fe_copy(fe h, const fe f) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    
    h[0] = f0;
    h[1] = f1;
    h[2] = f2;
    h[3] = f3;
    h[4] = f4;
    h[5] = f5;
    h[6] = f6;
    h[7] = f7;
    h[8] = f8;
    h[9] = f9;
}



/*
    Ignores top bit of h.
*/

__device__ void fe_frombytes(fe h, const unsigned char *s) {
    int64_t h0 = load_4(s);
    int64_t h1 = load_3(s + 4) << 6;
    int64_t h2 = load_3(s + 7) << 5;
    int64_t h3 = load_3(s + 10) << 3;
    int64_t h4 = load_3(s + 13) << 2;
    int64_t h5 = load_4(s + 16);
    int64_t h6 = load_3(s + 20) << 7;
    int64_t h7 = load_3(s + 23) << 5;
    int64_t h8 = load_3(s + 26) << 4;
    int64_t h9 = (load_3(s + 29) & 8388607) << 2;
    int64_t carry0;
    int64_t carry1;
    int64_t carry2;
    int64_t carry3;
    int64_t carry4;
    int64_t carry5;
    int64_t carry6;
    int64_t carry7;
    int64_t carry8;
    int64_t carry9;

    carry9 = (h9 + (int64_t) (1 << 24)) >> 25;
    h0 += carry9 * 19;
    h9 -= carry9 << 25;
    carry1 = (h1 + (int64_t) (1 << 24)) >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    carry3 = (h3 + (int64_t) (1 << 24)) >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    carry5 = (h5 + (int64_t) (1 << 24)) >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;
    carry7 = (h7 + (int64_t) (1 << 24)) >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;
    carry0 = (h0 + (int64_t) (1 << 25)) >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    carry2 = (h2 + (int64_t) (1 << 25)) >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    carry4 = (h4 + (int64_t) (1 << 25)) >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    carry6 = (h6 + (int64_t) (1 << 25)) >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;
    carry8 = (h8 + (int64_t) (1 << 25)) >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;

    h[0] = (int32_t) h0;
    h[1] = (int32_t) h1;
    h[2] = (int32_t) h2;
    h[3] = (int32_t) h3;
    h[4] = (int32_t) h4;
    h[5] = (int32_t) h5;
    h[6] = (int32_t) h6;
    h[7] = (int32_t) h7;
    h[8] = (int32_t) h8;
    h[9] = (int32_t) h9;
}



__device__ void fe_invert(fe out, const fe z) {
    fe t0;
    fe t1;
    fe t2;
    fe t3;
    int i;

    fe_sq(t0, z);

    for (i = 1; i < 1; ++i) {
        fe_sq(t0, t0);
    }

    fe_sq(t1, t0);

    for (i = 1; i < 2; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t1, z, t1);
    fe_mul(t0, t0, t1);
    fe_sq(t2, t0);

    for (i = 1; i < 1; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t1, t2);
    fe_sq(t2, t1);

    for (i = 1; i < 5; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t2, t1);
    fe_sq(t2, t1);

    for (i = 1; i < 10; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t2, t2, t1);
    fe_sq(t3, t2);

    for (i = 1; i < 20; ++i) {
        fe_sq(t3, t3);
    }

    fe_mul(t2, t3, t2);
    fe_sq(t2, t2);

    for (i = 1; i < 10; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t2, t1);
    fe_sq(t2, t1);

    for (i = 1; i < 50; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t2, t2, t1);
    fe_sq(t3, t2);

    for (i = 1; i < 100; ++i) {
        fe_sq(t3, t3);
    }

    fe_mul(t2, t3, t2);
    fe_sq(t2, t2);

    for (i = 1; i < 50; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t2, t1);
    fe_sq(t1, t1);

    for (i = 1; i < 5; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(out, t1, t0);
}



/*
    return 1 if f is in {1,3,5,...,q-2}
    return 0 if f is in {0,2,4,...,q-1}

    Preconditions:
       |f| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.
*/

__device__ int fe_isnegative(const fe f) {
    unsigned char s[32];

    fe_tobytes(s, f);
    
    return s[0] & 1;
}



/*
    return 1 if f == 0
    return 0 if f != 0

    Preconditions:
       |f| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.
*/

__device__ int fe_isnonzero(const fe f) {
    unsigned char s[32];
    unsigned char r;

    fe_tobytes(s, f);

    r = s[0];
    #define F(i) r |= s[i]
    F(1);
    F(2);
    F(3);
    F(4);
    F(5);
    F(6);
    F(7);
    F(8);
    F(9);
    F(10);
    F(11);
    F(12);
    F(13);
    F(14);
    F(15);
    F(16);
    F(17);
    F(18);
    F(19);
    F(20);
    F(21);
    F(22);
    F(23);
    F(24);
    F(25);
    F(26);
    F(27);
    F(28);
    F(29);
    F(30);
    F(31);
    #undef F

    return r != 0;
}



/*
    h = f * g
    Can overlap h with f or g.

    Preconditions:
       |f| bounded by 1.65*2^26,1.65*2^25,1.65*2^26,1.65*2^25,etc.
       |g| bounded by 1.65*2^26,1.65*2^25,1.65*2^26,1.65*2^25,etc.

    Postconditions:
       |h| bounded by 1.01*2^25,1.01*2^24,1.01*2^25,1.01*2^24,etc.
    */

    /*
    Notes on implementation strategy:

    Using schoolbook multiplication.
    Karatsuba would save a little in some cost models.

    Most multiplications by 2 and 19 are 32-bit precomputations;
    cheaper than 64-bit postcomputations.

    There is one remaining multiplication by 19 in the carry chain;
    one *19 precomputation can be merged into this,
    but the resulting data flow is considerably less clean.

    There are 12 carries below.
    10 of them are 2-way parallelizable and vectorizable.
    Can get away with 11 carries, but then data flow is much deeper.

    With tighter constraints on inputs can squeeze carries into int32.
*/

__device__ void fe_mul(fe h, const fe f, const fe g) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t g1_19 = 19 * g1; /* 1.959375*2^29 */
    int32_t g2_19 = 19 * g2; /* 1.959375*2^30; still ok */
    int32_t g3_19 = 19 * g3;
    int32_t g4_19 = 19 * g4;
    int32_t g5_19 = 19 * g5;
    int32_t g6_19 = 19 * g6;
    int32_t g7_19 = 19 * g7;
    int32_t g8_19 = 19 * g8;
    int32_t g9_19 = 19 * g9;
    int32_t f1_2 = 2 * f1;
    int32_t f3_2 = 2 * f3;
    int32_t f5_2 = 2 * f5;
    int32_t f7_2 = 2 * f7;
    int32_t f9_2 = 2 * f9;

    // Experimental streamed carry schedule. Same field product.
    int64_t carry=0;
    int64_t h0=((vrf_mulwide(f0,g0)) + (vrf_mulwide(f1_2,g9_19)) + (vrf_mulwide(f2,g8_19)) + (vrf_mulwide(f3_2,g7_19)) + (vrf_mulwide(f4,g6_19)) + (vrf_mulwide(f5_2,g5_19)) + (vrf_mulwide(f6,g4_19)) + (vrf_mulwide(f7_2,g3_19)) + (vrf_mulwide(f8,g2_19)) + (vrf_mulwide(f9_2,g1_19)))+carry;
    carry=(h0+(1L<<25))>>26;
    h[0]=(int32_t)(h0-carry*(1L<<26));
    int64_t h1=((vrf_mulwide(f0,g1)) + (vrf_mulwide(f1,g0))   + (vrf_mulwide(f2,g9_19)) + (vrf_mulwide(f3,g8_19)) + (vrf_mulwide(f4,g7_19)) + (vrf_mulwide(f5,g6_19)) + (vrf_mulwide(f6,g5_19)) + (vrf_mulwide(f7,g4_19)) + (vrf_mulwide(f8,g3_19)) + (vrf_mulwide(f9,g2_19)))+carry;
    carry=(h1+(1L<<24))>>25;
    h[1]=(int32_t)(h1-carry*(1L<<25));
    int64_t h2=((vrf_mulwide(f0,g2)) + (vrf_mulwide(f1_2,g1)) + (vrf_mulwide(f2,g0))   + (vrf_mulwide(f3_2,g9_19)) + (vrf_mulwide(f4,g8_19)) + (vrf_mulwide(f5_2,g7_19)) + (vrf_mulwide(f6,g6_19)) + (vrf_mulwide(f7_2,g5_19)) + (vrf_mulwide(f8,g4_19)) + (vrf_mulwide(f9_2,g3_19)))+carry;
    carry=(h2+(1L<<25))>>26;
    h[2]=(int32_t)(h2-carry*(1L<<26));
    int64_t h3=((vrf_mulwide(f0,g3)) + (vrf_mulwide(f1,g2))   + (vrf_mulwide(f2,g1))   + (vrf_mulwide(f3,g0))   + (vrf_mulwide(f4,g9_19)) + (vrf_mulwide(f5,g8_19)) + (vrf_mulwide(f6,g7_19)) + (vrf_mulwide(f7,g6_19)) + (vrf_mulwide(f8,g5_19)) + (vrf_mulwide(f9,g4_19)))+carry;
    carry=(h3+(1L<<24))>>25;
    h[3]=(int32_t)(h3-carry*(1L<<25));
    int64_t h4=((vrf_mulwide(f0,g4)) + (vrf_mulwide(f1_2,g3)) + (vrf_mulwide(f2,g2))   + (vrf_mulwide(f3_2,g1)) + (vrf_mulwide(f4,g0))   + (vrf_mulwide(f5_2,g9_19)) + (vrf_mulwide(f6,g8_19)) + (vrf_mulwide(f7_2,g7_19)) + (vrf_mulwide(f8,g6_19)) + (vrf_mulwide(f9_2,g5_19)))+carry;
    carry=(h4+(1L<<25))>>26;
    h[4]=(int32_t)(h4-carry*(1L<<26));
    int64_t h5=((vrf_mulwide(f0,g5)) + (vrf_mulwide(f1,g4))   + (vrf_mulwide(f2,g3))   + (vrf_mulwide(f3,g2))   + (vrf_mulwide(f4,g1))   + (vrf_mulwide(f5,g0))   + (vrf_mulwide(f6,g9_19)) + (vrf_mulwide(f7,g8_19)) + (vrf_mulwide(f8,g7_19)) + (vrf_mulwide(f9,g6_19)))+carry;
    carry=(h5+(1L<<24))>>25;
    h[5]=(int32_t)(h5-carry*(1L<<25));
    int64_t h6=((vrf_mulwide(f0,g6)) + (vrf_mulwide(f1_2,g5)) + (vrf_mulwide(f2,g4))   + (vrf_mulwide(f3_2,g3)) + (vrf_mulwide(f4,g2))   + (vrf_mulwide(f5_2,g1)) + (vrf_mulwide(f6,g0))   + (vrf_mulwide(f7_2,g9_19)) + (vrf_mulwide(f8,g8_19)) + (vrf_mulwide(f9_2,g7_19)))+carry;
    carry=(h6+(1L<<25))>>26;
    h[6]=(int32_t)(h6-carry*(1L<<26));
    int64_t h7=((vrf_mulwide(f0,g7)) + (vrf_mulwide(f1,g6))   + (vrf_mulwide(f2,g5))   + (vrf_mulwide(f3,g4))   + (vrf_mulwide(f4,g3))   + (vrf_mulwide(f5,g2))   + (vrf_mulwide(f6,g1))   + (vrf_mulwide(f7,g0))   + (vrf_mulwide(f8,g9_19)) + (vrf_mulwide(f9,g8_19)))+carry;
    carry=(h7+(1L<<24))>>25;
    h[7]=(int32_t)(h7-carry*(1L<<25));
    int64_t h8=((vrf_mulwide(f0,g8)) + (vrf_mulwide(f1_2,g7)) + (vrf_mulwide(f2,g6))   + (vrf_mulwide(f3_2,g5)) + (vrf_mulwide(f4,g4))   + (vrf_mulwide(f5_2,g3)) + (vrf_mulwide(f6,g2))   + (vrf_mulwide(f7_2,g1)) + (vrf_mulwide(f8,g0))   + (vrf_mulwide(f9_2,g9_19)))+carry;
    carry=(h8+(1L<<25))>>26;
    h[8]=(int32_t)(h8-carry*(1L<<26));
    int64_t h9=((vrf_mulwide(f0,g9)) + (vrf_mulwide(f1,g8))   + (vrf_mulwide(f2,g7))   + (vrf_mulwide(f3,g6))   + (vrf_mulwide(f4,g5))   + (vrf_mulwide(f5,g4))   + (vrf_mulwide(f6,g3))   + (vrf_mulwide(f7,g2))   + (vrf_mulwide(f8,g1))   + (vrf_mulwide(f9,g0))   )+carry;
    carry=(h9+(1L<<24))>>25;
    h[9]=(int32_t)(h9-carry*(1L<<25));
    int64_t wrap=(int64_t)h[0]+carry*19;
    carry=(wrap+(1L<<25))>>26;
    h[0]=(int32_t)(wrap-carry*(1L<<26));
    h[1]+=(int32_t)carry;

}


/*
h = f * 121666
Can overlap h with f.

Preconditions:
   |f| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.

Postconditions:
   |h| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.
*/

__device__ void fe_mul121666(fe h, fe f) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int64_t h0 = f0 * (int64_t) 121666;
    int64_t h1 = f1 * (int64_t) 121666;
    int64_t h2 = f2 * (int64_t) 121666;
    int64_t h3 = f3 * (int64_t) 121666;
    int64_t h4 = f4 * (int64_t) 121666;
    int64_t h5 = f5 * (int64_t) 121666;
    int64_t h6 = f6 * (int64_t) 121666;
    int64_t h7 = f7 * (int64_t) 121666;
    int64_t h8 = f8 * (int64_t) 121666;
    int64_t h9 = f9 * (int64_t) 121666;
    int64_t carry0;
    int64_t carry1;
    int64_t carry2;
    int64_t carry3;
    int64_t carry4;
    int64_t carry5;
    int64_t carry6;
    int64_t carry7;
    int64_t carry8;
    int64_t carry9;

    carry9 = (h9 + (int64_t) (1<<24)) >> 25; h0 += carry9 * 19; h9 -= carry9 << 25;
    carry1 = (h1 + (int64_t) (1<<24)) >> 25; h2 += carry1; h1 -= carry1 << 25;
    carry3 = (h3 + (int64_t) (1<<24)) >> 25; h4 += carry3; h3 -= carry3 << 25;
    carry5 = (h5 + (int64_t) (1<<24)) >> 25; h6 += carry5; h5 -= carry5 << 25;
    carry7 = (h7 + (int64_t) (1<<24)) >> 25; h8 += carry7; h7 -= carry7 << 25;

    carry0 = (h0 + (int64_t) (1<<25)) >> 26; h1 += carry0; h0 -= carry0 << 26;
    carry2 = (h2 + (int64_t) (1<<25)) >> 26; h3 += carry2; h2 -= carry2 << 26;
    carry4 = (h4 + (int64_t) (1<<25)) >> 26; h5 += carry4; h4 -= carry4 << 26;
    carry6 = (h6 + (int64_t) (1<<25)) >> 26; h7 += carry6; h6 -= carry6 << 26;
    carry8 = (h8 + (int64_t) (1<<25)) >> 26; h9 += carry8; h8 -= carry8 << 26;

    h[0] = (int32_t) h0;
    h[1] = (int32_t) h1;
    h[2] = (int32_t) h2;
    h[3] = (int32_t) h3;
    h[4] = (int32_t) h4;
    h[5] = (int32_t) h5;
    h[6] = (int32_t) h6;
    h[7] = (int32_t) h7;
    h[8] = (int32_t) h8;
    h[9] = (int32_t) h9;
}


/*
h = -f

Preconditions:
   |f| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.

Postconditions:
   |h| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.
*/

__device__ void fe_neg(fe h, const fe f) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t h0 = -f0;
    int32_t h1 = -f1;
    int32_t h2 = -f2;
    int32_t h3 = -f3;
    int32_t h4 = -f4;
    int32_t h5 = -f5;
    int32_t h6 = -f6;
    int32_t h7 = -f7;
    int32_t h8 = -f8;
    int32_t h9 = -f9;

    h[0] = h0;
    h[1] = h1;
    h[2] = h2;
    h[3] = h3;
    h[4] = h4;
    h[5] = h5;
    h[6] = h6;
    h[7] = h7;
    h[8] = h8;
    h[9] = h9;
}


__device__ void fe_pow22523(fe out, const fe z) {
    fe t0;
    fe t1;
    fe t2;
    int i;
    fe_sq(t0, z);

    for (i = 1; i < 1; ++i) {
        fe_sq(t0, t0);
    }

    fe_sq(t1, t0);

    for (i = 1; i < 2; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t1, z, t1);
    fe_mul(t0, t0, t1);
    fe_sq(t0, t0);

    for (i = 1; i < 1; ++i) {
        fe_sq(t0, t0);
    }

    fe_mul(t0, t1, t0);
    fe_sq(t1, t0);

    for (i = 1; i < 5; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t0, t1, t0);
    fe_sq(t1, t0);

    for (i = 1; i < 10; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t1, t1, t0);
    fe_sq(t2, t1);

    for (i = 1; i < 20; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t2, t1);
    fe_sq(t1, t1);

    for (i = 1; i < 10; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t0, t1, t0);
    fe_sq(t1, t0);

    for (i = 1; i < 50; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t1, t1, t0);
    fe_sq(t2, t1);

    for (i = 1; i < 100; ++i) {
        fe_sq(t2, t2);
    }

    fe_mul(t1, t2, t1);
    fe_sq(t1, t1);

    for (i = 1; i < 50; ++i) {
        fe_sq(t1, t1);
    }

    fe_mul(t0, t1, t0);
    fe_sq(t0, t0);

    for (i = 1; i < 2; ++i) {
        fe_sq(t0, t0);
    }

    fe_mul(out, t0, z);
    return;
}


/*
h = f * f
Can overlap h with f.

Preconditions:
   |f| bounded by 1.65*2^26,1.65*2^25,1.65*2^26,1.65*2^25,etc.

Postconditions:
   |h| bounded by 1.01*2^25,1.01*2^24,1.01*2^25,1.01*2^24,etc.
*/

/*
See fe_mul.c for discussion of implementation strategy.
*/

__device__ void fe_sq(fe h, const fe f) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t f0_2 = 2 * f0;
    int32_t f1_2 = 2 * f1;
    int32_t f2_2 = 2 * f2;
    int32_t f3_2 = 2 * f3;
    int32_t f4_2 = 2 * f4;
    int32_t f5_2 = 2 * f5;
    int32_t f6_2 = 2 * f6;
    int32_t f7_2 = 2 * f7;
    int32_t f5_38 = 38 * f5; /* 1.959375*2^30 */
    int32_t f6_19 = 19 * f6; /* 1.959375*2^30 */
    int32_t f7_38 = 38 * f7; /* 1.959375*2^30 */
    int32_t f8_19 = 19 * f8; /* 1.959375*2^30 */
    int32_t f9_38 = 38 * f9; /* 1.959375*2^30 */

    // Experimental streamed carry schedule. Same field product.
    int64_t carry=0;
    int64_t h0=((vrf_mulwide(f0,f0))  + (vrf_mulwide(f1_2,f9_38)) + (vrf_mulwide(f2_2,f8_19)) + (vrf_mulwide(f3_2,f7_38)) + (vrf_mulwide(f4_2,f6_19)) + (vrf_mulwide(f5,f5_38)))+carry;
    carry=(h0+(1L<<25))>>26;
    h[0]=(int32_t)(h0-carry*(1L<<26));
    int64_t h1=((vrf_mulwide(f0_2,f1)) + (vrf_mulwide(f2,f9_38)) + (vrf_mulwide(f3_2,f8_19)) + (vrf_mulwide(f4,f7_38)) + (vrf_mulwide(f5_2,f6_19)))+carry;
    carry=(h1+(1L<<24))>>25;
    h[1]=(int32_t)(h1-carry*(1L<<25));
    int64_t h2=((vrf_mulwide(f0_2,f2)) + (vrf_mulwide(f1_2,f1)) + (vrf_mulwide(f3_2,f9_38)) + (vrf_mulwide(f4_2,f8_19)) + (vrf_mulwide(f5_2,f7_38)) + (vrf_mulwide(f6,f6_19)))+carry;
    carry=(h2+(1L<<25))>>26;
    h[2]=(int32_t)(h2-carry*(1L<<26));
    int64_t h3=((vrf_mulwide(f0_2,f3)) + (vrf_mulwide(f1_2,f2)) + (vrf_mulwide(f4,f9_38)) + (vrf_mulwide(f5_2,f8_19)) + (vrf_mulwide(f6,f7_38)))+carry;
    carry=(h3+(1L<<24))>>25;
    h[3]=(int32_t)(h3-carry*(1L<<25));
    int64_t h4=((vrf_mulwide(f0_2,f4)) + (vrf_mulwide(f1_2,f3_2)) + (vrf_mulwide(f2,f2))   + (vrf_mulwide(f5_2,f9_38)) + (vrf_mulwide(f6_2,f8_19)) + (vrf_mulwide(f7,f7_38)))+carry;
    carry=(h4+(1L<<25))>>26;
    h[4]=(int32_t)(h4-carry*(1L<<26));
    int64_t h5=((vrf_mulwide(f0_2,f5)) + (vrf_mulwide(f1_2,f4)) + (vrf_mulwide(f2_2,f3)) + (vrf_mulwide(f6,f9_38)) + (vrf_mulwide(f7_2,f8_19)))+carry;
    carry=(h5+(1L<<24))>>25;
    h[5]=(int32_t)(h5-carry*(1L<<25));
    int64_t h6=((vrf_mulwide(f0_2,f6)) + (vrf_mulwide(f1_2,f5_2)) + (vrf_mulwide(f2_2,f4)) + (vrf_mulwide(f3_2,f3)) + (vrf_mulwide(f7_2,f9_38)) + (vrf_mulwide(f8,f8_19)))+carry;
    carry=(h6+(1L<<25))>>26;
    h[6]=(int32_t)(h6-carry*(1L<<26));
    int64_t h7=((vrf_mulwide(f0_2,f7)) + (vrf_mulwide(f1_2,f6)) + (vrf_mulwide(f2_2,f5)) + (vrf_mulwide(f3_2,f4)) + (vrf_mulwide(f8,f9_38)))+carry;
    carry=(h7+(1L<<24))>>25;
    h[7]=(int32_t)(h7-carry*(1L<<25));
    int64_t h8=((vrf_mulwide(f0_2,f8)) + (vrf_mulwide(f1_2,f7_2)) + (vrf_mulwide(f2_2,f6)) + (vrf_mulwide(f3_2,f5_2)) + (vrf_mulwide(f4,f4))   + (vrf_mulwide(f9,f9_38)))+carry;
    carry=(h8+(1L<<25))>>26;
    h[8]=(int32_t)(h8-carry*(1L<<26));
    int64_t h9=((vrf_mulwide(f0_2,f9)) + (vrf_mulwide(f1_2,f8)) + (vrf_mulwide(f2_2,f7)) + (vrf_mulwide(f3_2,f6)) + (vrf_mulwide(f4_2,f5)))+carry;
    carry=(h9+(1L<<24))>>25;
    h[9]=(int32_t)(h9-carry*(1L<<25));
    int64_t wrap=(int64_t)h[0]+carry*19;
    carry=(wrap+(1L<<25))>>26;
    h[0]=(int32_t)(wrap-carry*(1L<<26));
    h[1]+=(int32_t)carry;

}
__device__ void fe_sq_pair(fe a,fe b,const fe f,const fe g){

    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t f0_2 = 2 * f0;
    int32_t f1_2 = 2 * f1;
    int32_t f2_2 = 2 * f2;
    int32_t f3_2 = 2 * f3;
    int32_t f4_2 = 2 * f4;
    int32_t f5_2 = 2 * f5;
    int32_t f6_2 = 2 * f6;
    int32_t f7_2 = 2 * f7;
    int32_t f5_38 = 38 * f5; /* 1.959375*2^30 */
    int32_t f6_19 = 19 * f6; /* 1.959375*2^30 */
    int32_t f7_38 = 38 * f7; /* 1.959375*2^30 */
    int32_t f8_19 = 19 * f8; /* 1.959375*2^30 */
    int32_t f9_38 = 38 * f9; /* 1.959375*2^30 */

    

    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t g0_2 = 2 * g0;
    int32_t g1_2 = 2 * g1;
    int32_t g2_2 = 2 * g2;
    int32_t g3_2 = 2 * g3;
    int32_t g4_2 = 2 * g4;
    int32_t g5_2 = 2 * g5;
    int32_t g6_2 = 2 * g6;
    int32_t g7_2 = 2 * g7;
    int32_t g5_38 = 38 * g5; /* 1.959375*2^30 */
    int32_t g6_19 = 19 * g6; /* 1.959375*2^30 */
    int32_t g7_38 = 38 * g7; /* 1.959375*2^30 */
    int32_t g8_19 = 19 * g8; /* 1.959375*2^30 */
    int32_t g9_38 = 38 * g9; /* 1.959375*2^30 */

    
    int64_t ca=0,cb=0;
    int64_t ha0=((vrf_mulwide(f0,f0))  + (vrf_mulwide(f1_2,f9_38)) + (vrf_mulwide(f2_2,f8_19)) + (vrf_mulwide(f3_2,f7_38)) + (vrf_mulwide(f4_2,f6_19)) + (vrf_mulwide(f5,f5_38)))+ca;
    int64_t hb0=((vrf_mulwide(g0,g0))  + (vrf_mulwide(g1_2,g9_38)) + (vrf_mulwide(g2_2,g8_19)) + (vrf_mulwide(g3_2,g7_38)) + (vrf_mulwide(g4_2,g6_19)) + (vrf_mulwide(g5,g5_38)))+cb;
    ca=(ha0+(1LL<<25))>>26;cb=(hb0+(1LL<<25))>>26;
    a[0]=(int)(ha0-ca*(1LL<<26));b[0]=(int)(hb0-cb*(1LL<<26));
    int64_t ha1=((vrf_mulwide(f0_2,f1)) + (vrf_mulwide(f2,f9_38)) + (vrf_mulwide(f3_2,f8_19)) + (vrf_mulwide(f4,f7_38)) + (vrf_mulwide(f5_2,f6_19)))+ca;
    int64_t hb1=((vrf_mulwide(g0_2,g1)) + (vrf_mulwide(g2,g9_38)) + (vrf_mulwide(g3_2,g8_19)) + (vrf_mulwide(g4,g7_38)) + (vrf_mulwide(g5_2,g6_19)))+cb;
    ca=(ha1+(1LL<<24))>>25;cb=(hb1+(1LL<<24))>>25;
    a[1]=(int)(ha1-ca*(1LL<<25));b[1]=(int)(hb1-cb*(1LL<<25));
    int64_t ha2=((vrf_mulwide(f0_2,f2)) + (vrf_mulwide(f1_2,f1)) + (vrf_mulwide(f3_2,f9_38)) + (vrf_mulwide(f4_2,f8_19)) + (vrf_mulwide(f5_2,f7_38)) + (vrf_mulwide(f6,f6_19)))+ca;
    int64_t hb2=((vrf_mulwide(g0_2,g2)) + (vrf_mulwide(g1_2,g1)) + (vrf_mulwide(g3_2,g9_38)) + (vrf_mulwide(g4_2,g8_19)) + (vrf_mulwide(g5_2,g7_38)) + (vrf_mulwide(g6,g6_19)))+cb;
    ca=(ha2+(1LL<<25))>>26;cb=(hb2+(1LL<<25))>>26;
    a[2]=(int)(ha2-ca*(1LL<<26));b[2]=(int)(hb2-cb*(1LL<<26));
    int64_t ha3=((vrf_mulwide(f0_2,f3)) + (vrf_mulwide(f1_2,f2)) + (vrf_mulwide(f4,f9_38)) + (vrf_mulwide(f5_2,f8_19)) + (vrf_mulwide(f6,f7_38)))+ca;
    int64_t hb3=((vrf_mulwide(g0_2,g3)) + (vrf_mulwide(g1_2,g2)) + (vrf_mulwide(g4,g9_38)) + (vrf_mulwide(g5_2,g8_19)) + (vrf_mulwide(g6,g7_38)))+cb;
    ca=(ha3+(1LL<<24))>>25;cb=(hb3+(1LL<<24))>>25;
    a[3]=(int)(ha3-ca*(1LL<<25));b[3]=(int)(hb3-cb*(1LL<<25));
    int64_t ha4=((vrf_mulwide(f0_2,f4)) + (vrf_mulwide(f1_2,f3_2)) + (vrf_mulwide(f2,f2))   + (vrf_mulwide(f5_2,f9_38)) + (vrf_mulwide(f6_2,f8_19)) + (vrf_mulwide(f7,f7_38)))+ca;
    int64_t hb4=((vrf_mulwide(g0_2,g4)) + (vrf_mulwide(g1_2,g3_2)) + (vrf_mulwide(g2,g2))   + (vrf_mulwide(g5_2,g9_38)) + (vrf_mulwide(g6_2,g8_19)) + (vrf_mulwide(g7,g7_38)))+cb;
    ca=(ha4+(1LL<<25))>>26;cb=(hb4+(1LL<<25))>>26;
    a[4]=(int)(ha4-ca*(1LL<<26));b[4]=(int)(hb4-cb*(1LL<<26));
    int64_t ha5=((vrf_mulwide(f0_2,f5)) + (vrf_mulwide(f1_2,f4)) + (vrf_mulwide(f2_2,f3)) + (vrf_mulwide(f6,f9_38)) + (vrf_mulwide(f7_2,f8_19)))+ca;
    int64_t hb5=((vrf_mulwide(g0_2,g5)) + (vrf_mulwide(g1_2,g4)) + (vrf_mulwide(g2_2,g3)) + (vrf_mulwide(g6,g9_38)) + (vrf_mulwide(g7_2,g8_19)))+cb;
    ca=(ha5+(1LL<<24))>>25;cb=(hb5+(1LL<<24))>>25;
    a[5]=(int)(ha5-ca*(1LL<<25));b[5]=(int)(hb5-cb*(1LL<<25));
    int64_t ha6=((vrf_mulwide(f0_2,f6)) + (vrf_mulwide(f1_2,f5_2)) + (vrf_mulwide(f2_2,f4)) + (vrf_mulwide(f3_2,f3)) + (vrf_mulwide(f7_2,f9_38)) + (vrf_mulwide(f8,f8_19)))+ca;
    int64_t hb6=((vrf_mulwide(g0_2,g6)) + (vrf_mulwide(g1_2,g5_2)) + (vrf_mulwide(g2_2,g4)) + (vrf_mulwide(g3_2,g3)) + (vrf_mulwide(g7_2,g9_38)) + (vrf_mulwide(g8,g8_19)))+cb;
    ca=(ha6+(1LL<<25))>>26;cb=(hb6+(1LL<<25))>>26;
    a[6]=(int)(ha6-ca*(1LL<<26));b[6]=(int)(hb6-cb*(1LL<<26));
    int64_t ha7=((vrf_mulwide(f0_2,f7)) + (vrf_mulwide(f1_2,f6)) + (vrf_mulwide(f2_2,f5)) + (vrf_mulwide(f3_2,f4)) + (vrf_mulwide(f8,f9_38)))+ca;
    int64_t hb7=((vrf_mulwide(g0_2,g7)) + (vrf_mulwide(g1_2,g6)) + (vrf_mulwide(g2_2,g5)) + (vrf_mulwide(g3_2,g4)) + (vrf_mulwide(g8,g9_38)))+cb;
    ca=(ha7+(1LL<<24))>>25;cb=(hb7+(1LL<<24))>>25;
    a[7]=(int)(ha7-ca*(1LL<<25));b[7]=(int)(hb7-cb*(1LL<<25));
    int64_t ha8=((vrf_mulwide(f0_2,f8)) + (vrf_mulwide(f1_2,f7_2)) + (vrf_mulwide(f2_2,f6)) + (vrf_mulwide(f3_2,f5_2)) + (vrf_mulwide(f4,f4))   + (vrf_mulwide(f9,f9_38)))+ca;
    int64_t hb8=((vrf_mulwide(g0_2,g8)) + (vrf_mulwide(g1_2,g7_2)) + (vrf_mulwide(g2_2,g6)) + (vrf_mulwide(g3_2,g5_2)) + (vrf_mulwide(g4,g4))   + (vrf_mulwide(g9,g9_38)))+cb;
    ca=(ha8+(1LL<<25))>>26;cb=(hb8+(1LL<<25))>>26;
    a[8]=(int)(ha8-ca*(1LL<<26));b[8]=(int)(hb8-cb*(1LL<<26));
    int64_t ha9=((vrf_mulwide(f0_2,f9)) + (vrf_mulwide(f1_2,f8)) + (vrf_mulwide(f2_2,f7)) + (vrf_mulwide(f3_2,f6)) + (vrf_mulwide(f4_2,f5)))+ca;
    int64_t hb9=((vrf_mulwide(g0_2,g9)) + (vrf_mulwide(g1_2,g8)) + (vrf_mulwide(g2_2,g7)) + (vrf_mulwide(g3_2,g6)) + (vrf_mulwide(g4_2,g5)))+cb;
    ca=(ha9+(1LL<<24))>>25;cb=(hb9+(1LL<<24))>>25;
    a[9]=(int)(ha9-ca*(1LL<<25));b[9]=(int)(hb9-cb*(1LL<<25));
    int64_t wa=(int64_t)a[0]+ca*19,wb=(int64_t)b[0]+cb*19;
    ca=(wa+(1LL<<25))>>26;cb=(wb+(1LL<<25))>>26;
    a[0]=(int)(wa-ca*(1LL<<26));b[0]=(int)(wb-cb*(1LL<<26));
    a[1]+=(int)ca;b[1]+=(int)cb;
}

__device__ void fe_sq_pair_two_a(fe a,fe b,const fe f,const fe g){

    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t f0_2 = 2 * f0;
    int32_t f1_2 = 2 * f1;
    int32_t f2_2 = 2 * f2;
    int32_t f3_2 = 2 * f3;
    int32_t f4_2 = 2 * f4;
    int32_t f5_2 = 2 * f5;
    int32_t f6_2 = 2 * f6;
    int32_t f7_2 = 2 * f7;
    int32_t f5_38 = 38 * f5; /* 1.959375*2^30 */
    int32_t f6_19 = 19 * f6; /* 1.959375*2^30 */
    int32_t f7_38 = 38 * f7; /* 1.959375*2^30 */
    int32_t f8_19 = 19 * f8; /* 1.959375*2^30 */
    int32_t f9_38 = 38 * f9; /* 1.959375*2^30 */

    

    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t g0_2 = 2 * g0;
    int32_t g1_2 = 2 * g1;
    int32_t g2_2 = 2 * g2;
    int32_t g3_2 = 2 * g3;
    int32_t g4_2 = 2 * g4;
    int32_t g5_2 = 2 * g5;
    int32_t g6_2 = 2 * g6;
    int32_t g7_2 = 2 * g7;
    int32_t g5_38 = 38 * g5; /* 1.959375*2^30 */
    int32_t g6_19 = 19 * g6; /* 1.959375*2^30 */
    int32_t g7_38 = 38 * g7; /* 1.959375*2^30 */
    int32_t g8_19 = 19 * g8; /* 1.959375*2^30 */
    int32_t g9_38 = 38 * g9; /* 1.959375*2^30 */

    
    int64_t ca=0,cb=0;
    int64_t ha0=(2*((vrf_mulwide(f0,f0))  + (vrf_mulwide(f1_2,f9_38)) + (vrf_mulwide(f2_2,f8_19)) + (vrf_mulwide(f3_2,f7_38)) + (vrf_mulwide(f4_2,f6_19)) + (vrf_mulwide(f5,f5_38))))+ca;
    int64_t hb0=((vrf_mulwide(g0,g0))  + (vrf_mulwide(g1_2,g9_38)) + (vrf_mulwide(g2_2,g8_19)) + (vrf_mulwide(g3_2,g7_38)) + (vrf_mulwide(g4_2,g6_19)) + (vrf_mulwide(g5,g5_38)))+cb;
    ca=(ha0+(1LL<<25))>>26;cb=(hb0+(1LL<<25))>>26;
    a[0]=(int)(ha0-ca*(1LL<<26));b[0]=(int)(hb0-cb*(1LL<<26));
    int64_t ha1=(2*((vrf_mulwide(f0_2,f1)) + (vrf_mulwide(f2,f9_38)) + (vrf_mulwide(f3_2,f8_19)) + (vrf_mulwide(f4,f7_38)) + (vrf_mulwide(f5_2,f6_19))))+ca;
    int64_t hb1=((vrf_mulwide(g0_2,g1)) + (vrf_mulwide(g2,g9_38)) + (vrf_mulwide(g3_2,g8_19)) + (vrf_mulwide(g4,g7_38)) + (vrf_mulwide(g5_2,g6_19)))+cb;
    ca=(ha1+(1LL<<24))>>25;cb=(hb1+(1LL<<24))>>25;
    a[1]=(int)(ha1-ca*(1LL<<25));b[1]=(int)(hb1-cb*(1LL<<25));
    int64_t ha2=(2*((vrf_mulwide(f0_2,f2)) + (vrf_mulwide(f1_2,f1)) + (vrf_mulwide(f3_2,f9_38)) + (vrf_mulwide(f4_2,f8_19)) + (vrf_mulwide(f5_2,f7_38)) + (vrf_mulwide(f6,f6_19))))+ca;
    int64_t hb2=((vrf_mulwide(g0_2,g2)) + (vrf_mulwide(g1_2,g1)) + (vrf_mulwide(g3_2,g9_38)) + (vrf_mulwide(g4_2,g8_19)) + (vrf_mulwide(g5_2,g7_38)) + (vrf_mulwide(g6,g6_19)))+cb;
    ca=(ha2+(1LL<<25))>>26;cb=(hb2+(1LL<<25))>>26;
    a[2]=(int)(ha2-ca*(1LL<<26));b[2]=(int)(hb2-cb*(1LL<<26));
    int64_t ha3=(2*((vrf_mulwide(f0_2,f3)) + (vrf_mulwide(f1_2,f2)) + (vrf_mulwide(f4,f9_38)) + (vrf_mulwide(f5_2,f8_19)) + (vrf_mulwide(f6,f7_38))))+ca;
    int64_t hb3=((vrf_mulwide(g0_2,g3)) + (vrf_mulwide(g1_2,g2)) + (vrf_mulwide(g4,g9_38)) + (vrf_mulwide(g5_2,g8_19)) + (vrf_mulwide(g6,g7_38)))+cb;
    ca=(ha3+(1LL<<24))>>25;cb=(hb3+(1LL<<24))>>25;
    a[3]=(int)(ha3-ca*(1LL<<25));b[3]=(int)(hb3-cb*(1LL<<25));
    int64_t ha4=(2*((vrf_mulwide(f0_2,f4)) + (vrf_mulwide(f1_2,f3_2)) + (vrf_mulwide(f2,f2))   + (vrf_mulwide(f5_2,f9_38)) + (vrf_mulwide(f6_2,f8_19)) + (vrf_mulwide(f7,f7_38))))+ca;
    int64_t hb4=((vrf_mulwide(g0_2,g4)) + (vrf_mulwide(g1_2,g3_2)) + (vrf_mulwide(g2,g2))   + (vrf_mulwide(g5_2,g9_38)) + (vrf_mulwide(g6_2,g8_19)) + (vrf_mulwide(g7,g7_38)))+cb;
    ca=(ha4+(1LL<<25))>>26;cb=(hb4+(1LL<<25))>>26;
    a[4]=(int)(ha4-ca*(1LL<<26));b[4]=(int)(hb4-cb*(1LL<<26));
    int64_t ha5=(2*((vrf_mulwide(f0_2,f5)) + (vrf_mulwide(f1_2,f4)) + (vrf_mulwide(f2_2,f3)) + (vrf_mulwide(f6,f9_38)) + (vrf_mulwide(f7_2,f8_19))))+ca;
    int64_t hb5=((vrf_mulwide(g0_2,g5)) + (vrf_mulwide(g1_2,g4)) + (vrf_mulwide(g2_2,g3)) + (vrf_mulwide(g6,g9_38)) + (vrf_mulwide(g7_2,g8_19)))+cb;
    ca=(ha5+(1LL<<24))>>25;cb=(hb5+(1LL<<24))>>25;
    a[5]=(int)(ha5-ca*(1LL<<25));b[5]=(int)(hb5-cb*(1LL<<25));
    int64_t ha6=(2*((vrf_mulwide(f0_2,f6)) + (vrf_mulwide(f1_2,f5_2)) + (vrf_mulwide(f2_2,f4)) + (vrf_mulwide(f3_2,f3)) + (vrf_mulwide(f7_2,f9_38)) + (vrf_mulwide(f8,f8_19))))+ca;
    int64_t hb6=((vrf_mulwide(g0_2,g6)) + (vrf_mulwide(g1_2,g5_2)) + (vrf_mulwide(g2_2,g4)) + (vrf_mulwide(g3_2,g3)) + (vrf_mulwide(g7_2,g9_38)) + (vrf_mulwide(g8,g8_19)))+cb;
    ca=(ha6+(1LL<<25))>>26;cb=(hb6+(1LL<<25))>>26;
    a[6]=(int)(ha6-ca*(1LL<<26));b[6]=(int)(hb6-cb*(1LL<<26));
    int64_t ha7=(2*((vrf_mulwide(f0_2,f7)) + (vrf_mulwide(f1_2,f6)) + (vrf_mulwide(f2_2,f5)) + (vrf_mulwide(f3_2,f4)) + (vrf_mulwide(f8,f9_38))))+ca;
    int64_t hb7=((vrf_mulwide(g0_2,g7)) + (vrf_mulwide(g1_2,g6)) + (vrf_mulwide(g2_2,g5)) + (vrf_mulwide(g3_2,g4)) + (vrf_mulwide(g8,g9_38)))+cb;
    ca=(ha7+(1LL<<24))>>25;cb=(hb7+(1LL<<24))>>25;
    a[7]=(int)(ha7-ca*(1LL<<25));b[7]=(int)(hb7-cb*(1LL<<25));
    int64_t ha8=(2*((vrf_mulwide(f0_2,f8)) + (vrf_mulwide(f1_2,f7_2)) + (vrf_mulwide(f2_2,f6)) + (vrf_mulwide(f3_2,f5_2)) + (vrf_mulwide(f4,f4))   + (vrf_mulwide(f9,f9_38))))+ca;
    int64_t hb8=((vrf_mulwide(g0_2,g8)) + (vrf_mulwide(g1_2,g7_2)) + (vrf_mulwide(g2_2,g6)) + (vrf_mulwide(g3_2,g5_2)) + (vrf_mulwide(g4,g4))   + (vrf_mulwide(g9,g9_38)))+cb;
    ca=(ha8+(1LL<<25))>>26;cb=(hb8+(1LL<<25))>>26;
    a[8]=(int)(ha8-ca*(1LL<<26));b[8]=(int)(hb8-cb*(1LL<<26));
    int64_t ha9=(2*((vrf_mulwide(f0_2,f9)) + (vrf_mulwide(f1_2,f8)) + (vrf_mulwide(f2_2,f7)) + (vrf_mulwide(f3_2,f6)) + (vrf_mulwide(f4_2,f5))))+ca;
    int64_t hb9=((vrf_mulwide(g0_2,g9)) + (vrf_mulwide(g1_2,g8)) + (vrf_mulwide(g2_2,g7)) + (vrf_mulwide(g3_2,g6)) + (vrf_mulwide(g4_2,g5)))+cb;
    ca=(ha9+(1LL<<24))>>25;cb=(hb9+(1LL<<24))>>25;
    a[9]=(int)(ha9-ca*(1LL<<25));b[9]=(int)(hb9-cb*(1LL<<25));
    int64_t wa=(int64_t)a[0]+ca*19,wb=(int64_t)b[0]+cb*19;
    ca=(wa+(1LL<<25))>>26;cb=(wb+(1LL<<25))>>26;
    a[0]=(int)(wa-ca*(1LL<<26));b[0]=(int)(wb-cb*(1LL<<26));
    a[1]+=(int)ca;b[1]+=(int)cb;
}


/*
h = 2 * f * f
Can overlap h with f.

Preconditions:
   |f| bounded by 1.65*2^26,1.65*2^25,1.65*2^26,1.65*2^25,etc.

Postconditions:
   |h| bounded by 1.01*2^25,1.01*2^24,1.01*2^25,1.01*2^24,etc.
*/

/*
See fe_mul.c for discussion of implementation strategy.
*/

__device__ void fe_sq2(fe h, const fe f) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t f0_2 = 2 * f0;
    int32_t f1_2 = 2 * f1;
    int32_t f2_2 = 2 * f2;
    int32_t f3_2 = 2 * f3;
    int32_t f4_2 = 2 * f4;
    int32_t f5_2 = 2 * f5;
    int32_t f6_2 = 2 * f6;
    int32_t f7_2 = 2 * f7;
    int32_t f5_38 = 38 * f5; /* 1.959375*2^30 */
    int32_t f6_19 = 19 * f6; /* 1.959375*2^30 */
    int32_t f7_38 = 38 * f7; /* 1.959375*2^30 */
    int32_t f8_19 = 19 * f8; /* 1.959375*2^30 */
    int32_t f9_38 = 38 * f9; /* 1.959375*2^30 */

    // Experimental streamed carry schedule. Same field product.
    int64_t carry=0;
    int64_t h0=(2*((vrf_mulwide(f0,f0))  + (vrf_mulwide(f1_2,f9_38)) + (vrf_mulwide(f2_2,f8_19)) + (vrf_mulwide(f3_2,f7_38)) + (vrf_mulwide(f4_2,f6_19)) + (vrf_mulwide(f5,f5_38))))+carry;
    carry=(h0+(1L<<25))>>26;
    h[0]=(int32_t)(h0-carry*(1L<<26));
    int64_t h1=(2*((vrf_mulwide(f0_2,f1)) + (vrf_mulwide(f2,f9_38)) + (vrf_mulwide(f3_2,f8_19)) + (vrf_mulwide(f4,f7_38)) + (vrf_mulwide(f5_2,f6_19))))+carry;
    carry=(h1+(1L<<24))>>25;
    h[1]=(int32_t)(h1-carry*(1L<<25));
    int64_t h2=(2*((vrf_mulwide(f0_2,f2)) + (vrf_mulwide(f1_2,f1)) + (vrf_mulwide(f3_2,f9_38)) + (vrf_mulwide(f4_2,f8_19)) + (vrf_mulwide(f5_2,f7_38)) + (vrf_mulwide(f6,f6_19))))+carry;
    carry=(h2+(1L<<25))>>26;
    h[2]=(int32_t)(h2-carry*(1L<<26));
    int64_t h3=(2*((vrf_mulwide(f0_2,f3)) + (vrf_mulwide(f1_2,f2)) + (vrf_mulwide(f4,f9_38)) + (vrf_mulwide(f5_2,f8_19)) + (vrf_mulwide(f6,f7_38))))+carry;
    carry=(h3+(1L<<24))>>25;
    h[3]=(int32_t)(h3-carry*(1L<<25));
    int64_t h4=(2*((vrf_mulwide(f0_2,f4)) + (vrf_mulwide(f1_2,f3_2)) + (vrf_mulwide(f2,f2))   + (vrf_mulwide(f5_2,f9_38)) + (vrf_mulwide(f6_2,f8_19)) + (vrf_mulwide(f7,f7_38))))+carry;
    carry=(h4+(1L<<25))>>26;
    h[4]=(int32_t)(h4-carry*(1L<<26));
    int64_t h5=(2*((vrf_mulwide(f0_2,f5)) + (vrf_mulwide(f1_2,f4)) + (vrf_mulwide(f2_2,f3)) + (vrf_mulwide(f6,f9_38)) + (vrf_mulwide(f7_2,f8_19))))+carry;
    carry=(h5+(1L<<24))>>25;
    h[5]=(int32_t)(h5-carry*(1L<<25));
    int64_t h6=(2*((vrf_mulwide(f0_2,f6)) + (vrf_mulwide(f1_2,f5_2)) + (vrf_mulwide(f2_2,f4)) + (vrf_mulwide(f3_2,f3)) + (vrf_mulwide(f7_2,f9_38)) + (vrf_mulwide(f8,f8_19))))+carry;
    carry=(h6+(1L<<25))>>26;
    h[6]=(int32_t)(h6-carry*(1L<<26));
    int64_t h7=(2*((vrf_mulwide(f0_2,f7)) + (vrf_mulwide(f1_2,f6)) + (vrf_mulwide(f2_2,f5)) + (vrf_mulwide(f3_2,f4)) + (vrf_mulwide(f8,f9_38))))+carry;
    carry=(h7+(1L<<24))>>25;
    h[7]=(int32_t)(h7-carry*(1L<<25));
    int64_t h8=(2*((vrf_mulwide(f0_2,f8)) + (vrf_mulwide(f1_2,f7_2)) + (vrf_mulwide(f2_2,f6)) + (vrf_mulwide(f3_2,f5_2)) + (vrf_mulwide(f4,f4))   + (vrf_mulwide(f9,f9_38))))+carry;
    carry=(h8+(1L<<25))>>26;
    h[8]=(int32_t)(h8-carry*(1L<<26));
    int64_t h9=(2*((vrf_mulwide(f0_2,f9)) + (vrf_mulwide(f1_2,f8)) + (vrf_mulwide(f2_2,f7)) + (vrf_mulwide(f3_2,f6)) + (vrf_mulwide(f4_2,f5))))+carry;
    carry=(h9+(1L<<24))>>25;
    h[9]=(int32_t)(h9-carry*(1L<<25));
    int64_t wrap=(int64_t)h[0]+carry*19;
    carry=(wrap+(1L<<25))>>26;
    h[0]=(int32_t)(wrap-carry*(1L<<26));
    h[1]+=(int32_t)carry;

}


/*
h = f - g
Can overlap h with f or g.

Preconditions:
   |f| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.
   |g| bounded by 1.1*2^25,1.1*2^24,1.1*2^25,1.1*2^24,etc.

Postconditions:
   |h| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.
*/

__device__ void fe_sub(fe h, const fe f, const fe g) {
    int32_t f0 = f[0];
    int32_t f1 = f[1];
    int32_t f2 = f[2];
    int32_t f3 = f[3];
    int32_t f4 = f[4];
    int32_t f5 = f[5];
    int32_t f6 = f[6];
    int32_t f7 = f[7];
    int32_t f8 = f[8];
    int32_t f9 = f[9];
    int32_t g0 = g[0];
    int32_t g1 = g[1];
    int32_t g2 = g[2];
    int32_t g3 = g[3];
    int32_t g4 = g[4];
    int32_t g5 = g[5];
    int32_t g6 = g[6];
    int32_t g7 = g[7];
    int32_t g8 = g[8];
    int32_t g9 = g[9];
    int32_t h0 = f0 - g0;
    int32_t h1 = f1 - g1;
    int32_t h2 = f2 - g2;
    int32_t h3 = f3 - g3;
    int32_t h4 = f4 - g4;
    int32_t h5 = f5 - g5;
    int32_t h6 = f6 - g6;
    int32_t h7 = f7 - g7;
    int32_t h8 = f8 - g8;
    int32_t h9 = f9 - g9;

    h[0] = h0;
    h[1] = h1;
    h[2] = h2;
    h[3] = h3;
    h[4] = h4;
    h[5] = h5;
    h[6] = h6;
    h[7] = h7;
    h[8] = h8;
    h[9] = h9;
}



/*
Preconditions:
  |h| bounded by 1.1*2^26,1.1*2^25,1.1*2^26,1.1*2^25,etc.

Write p=2^255-19; q=floor(h/p).
Basic claim: q = floor(2^(-255)(h + 19 2^(-25)h9 + 2^(-1))).

Proof:
  Have |h|<=p so |q|<=1 so |19^2 2^(-255) q|<1/4.
  Also have |h-2^230 h9|<2^231 so |19 2^(-255)(h-2^230 h9)|<1/4.

  Write y=2^(-1)-19^2 2^(-255)q-19 2^(-255)(h-2^230 h9).
  Then 0<y<1.

  Write r=h-pq.
  Have 0<=r<=p-1=2^255-20.
  Thus 0<=r+19(2^-255)r<r+19(2^-255)2^255<=2^255-1.

  Write x=r+19(2^-255)r+y.
  Then 0<x<2^255 so floor(2^(-255)x) = 0 so floor(q+2^(-255)x) = q.

  Have q+2^(-255)x = 2^(-255)(h + 19 2^(-25) h9 + 2^(-1))
  so floor(2^(-255)(h + 19 2^(-25) h9 + 2^(-1))) = q.
*/

__device__ void fe_tobytes(unsigned char *s, const fe h) {
    int32_t h0 = h[0];
    int32_t h1 = h[1];
    int32_t h2 = h[2];
    int32_t h3 = h[3];
    int32_t h4 = h[4];
    int32_t h5 = h[5];
    int32_t h6 = h[6];
    int32_t h7 = h[7];
    int32_t h8 = h[8];
    int32_t h9 = h[9];
    int32_t q;
    int32_t carry0;
    int32_t carry1;
    int32_t carry2;
    int32_t carry3;
    int32_t carry4;
    int32_t carry5;
    int32_t carry6;
    int32_t carry7;
    int32_t carry8;
    int32_t carry9;
    q = (19 * h9 + (((int32_t) 1) << 24)) >> 25;
    q = (h0 + q) >> 26;
    q = (h1 + q) >> 25;
    q = (h2 + q) >> 26;
    q = (h3 + q) >> 25;
    q = (h4 + q) >> 26;
    q = (h5 + q) >> 25;
    q = (h6 + q) >> 26;
    q = (h7 + q) >> 25;
    q = (h8 + q) >> 26;
    q = (h9 + q) >> 25;
    /* Goal: Output h-(2^255-19)q, which is between 0 and 2^255-20. */
    h0 += 19 * q;
    /* Goal: Output h-2^255 q, which is between 0 and 2^255-20. */
    carry0 = h0 >> 26;
    h1 += carry0;
    h0 -= carry0 << 26;
    carry1 = h1 >> 25;
    h2 += carry1;
    h1 -= carry1 << 25;
    carry2 = h2 >> 26;
    h3 += carry2;
    h2 -= carry2 << 26;
    carry3 = h3 >> 25;
    h4 += carry3;
    h3 -= carry3 << 25;
    carry4 = h4 >> 26;
    h5 += carry4;
    h4 -= carry4 << 26;
    carry5 = h5 >> 25;
    h6 += carry5;
    h5 -= carry5 << 25;
    carry6 = h6 >> 26;
    h7 += carry6;
    h6 -= carry6 << 26;
    carry7 = h7 >> 25;
    h8 += carry7;
    h7 -= carry7 << 25;
    carry8 = h8 >> 26;
    h9 += carry8;
    h8 -= carry8 << 26;
    carry9 = h9 >> 25;
    h9 -= carry9 << 25;

    /* h10 = carry9 */
    /*
    Goal: Output h0+...+2^255 h10-2^255 q, which is between 0 and 2^255-20.
    Have h0+...+2^230 h9 between 0 and 2^255-1;
    evidently 2^255 h10-2^255 q = 0.
    Goal: Output h0+...+2^230 h9.
    */
    s[0] = (unsigned char) (h0 >> 0);
    s[1] = (unsigned char) (h0 >> 8);
    s[2] = (unsigned char) (h0 >> 16);
    s[3] = (unsigned char) ((h0 >> 24) | (h1 << 2));
    s[4] = (unsigned char) (h1 >> 6);
    s[5] = (unsigned char) (h1 >> 14);
    s[6] = (unsigned char) ((h1 >> 22) | (h2 << 3));
    s[7] = (unsigned char) (h2 >> 5);
    s[8] = (unsigned char) (h2 >> 13);
    s[9] = (unsigned char) ((h2 >> 21) | (h3 << 5));
    s[10] = (unsigned char) (h3 >> 3);
    s[11] = (unsigned char) (h3 >> 11);
    s[12] = (unsigned char) ((h3 >> 19) | (h4 << 6));
    s[13] = (unsigned char) (h4 >> 2);
    s[14] = (unsigned char) (h4 >> 10);
    s[15] = (unsigned char) (h4 >> 18);
    s[16] = (unsigned char) (h5 >> 0);
    s[17] = (unsigned char) (h5 >> 8);
    s[18] = (unsigned char) (h5 >> 16);
    s[19] = (unsigned char) ((h5 >> 24) | (h6 << 1));
    s[20] = (unsigned char) (h6 >> 7);
    s[21] = (unsigned char) (h6 >> 15);
    s[22] = (unsigned char) ((h6 >> 23) | (h7 << 3));
    s[23] = (unsigned char) (h7 >> 5);
    s[24] = (unsigned char) (h7 >> 13);
    s[25] = (unsigned char) ((h7 >> 21) | (h8 << 4));
    s[26] = (unsigned char) (h8 >> 4);
    s[27] = (unsigned char) (h8 >> 12);
    s[28] = (unsigned char) ((h8 >> 20) | (h9 << 6));
    s[29] = (unsigned char) (h9 >> 2);
    s[30] = (unsigned char) (h9 >> 10);
    s[31] = (unsigned char) (h9 >> 18);
}
#endif

__device__ void ge_add(ge_p1p1 *r, const ge_p3 *p, const ge_cached *q) {
    fe t0;
    fe_add(r->X, p->Y, p->X);
    fe_sub(r->Y, p->Y, p->X);
    fe_mul(r->Z, r->X, q->YplusX);
    fe_mul(r->Y, r->Y, q->YminusX);
    fe_mul(r->T, q->T2d, p->T);
    fe_mul(r->X, p->Z, q->Z);
    fe_add(t0, r->X, r->X);
    fe_sub(r->X, r->Z, r->Y);
    fe_add(r->Y, r->Z, r->Y);
    fe_add(r->Z, t0, r->T);
    fe_sub(r->T, t0, r->T);
}
__device__ void ge_sub(ge_p1p1 *r, const ge_p3 *p, const ge_cached *q) {
    fe t0;
    
    fe_add(r->X, p->Y, p->X);
    fe_sub(r->Y, p->Y, p->X);
    fe_mul(r->Z, r->X, q->YminusX);
    fe_mul(r->Y, r->Y, q->YplusX);
    fe_mul(r->T, q->T2d, p->T);
    fe_mul(r->X, p->Z, q->Z);
    fe_add(t0, r->X, r->X);
    fe_sub(r->X, r->Z, r->Y);
    fe_add(r->Y, r->Z, r->Y);
    fe_sub(r->Z, t0, r->T);
    fe_add(r->T, t0, r->T);
}
__device__ void ge_p1p1_to_p2(ge_p2 *r, const ge_p1p1 *p) {
    fe_mul_pair(r->X,r->Y,p->X,p->T,p->Y,p->Z);
    fe_mul(r->Z, p->Z, p->T);
}
__device__ void ge_p1p1_to_p3(ge_p3 *r, const ge_p1p1 *p) {
    fe_mul_pair(r->X,r->Y,p->X,p->T,p->Y,p->Z);
    fe_mul_pair(r->Z,r->T,p->Z,p->T,p->X,p->Y);
}
__device__ void ge_p2_0(ge_p2 *h) {
    fe_0(h->X);
    fe_1(h->Y);
    fe_1(h->Z);
}
__device__ void ge_p2_dbl(ge_p1p1 *r, const ge_p2 *p) {
    fe t0;

    fe_sq_pair(r->X,r->Z,p->X,p->Y);
    fe_add(r->Y,p->X,p->Y);
    fe_sq_pair_two_a(r->T,t0,p->Z,r->Y);
    fe_add(r->Y, r->Z, r->X);
    fe_sub(r->Z, r->Z, r->X);
    fe_sub(r->X, t0, r->Y);
    fe_sub(r->T, r->T, r->Z);
}
__device__ void ge_p3_0(ge_p3 *h) {
    fe_0(h->X);
    fe_1(h->Y);
    fe_1(h->Z);
    fe_0(h->T);
}
__device__ void ge_p3_dbl(ge_p1p1 *r, const ge_p3 *p) {
    ge_p2 q;
    ge_p3_to_p2(&q, p);
    ge_p2_dbl(r, &q);
}
__device__ void ge_p3_to_cached(ge_cached *r, const ge_p3 *p) {
 const fe d2 = {-21827239,-5839606,-30745221,13898782,229458,15978800,-12551817,-6495438,29715968,9444199};
    fe_add(r->YplusX, p->Y, p->X);
    fe_sub(r->YminusX, p->Y, p->X);
    fe_copy(r->Z, p->Z);
    fe_mul(r->T2d, p->T, d2);
}
__device__ void ge_p3_to_p2(ge_p2 *r, const ge_p3 *p) {
    fe_copy(r->X, p->X);
    fe_copy(r->Y, p->Y);
    fe_copy(r->Z, p->Z);
}
__device__ void ge_p3_tobytes(unsigned char *s, const ge_p3 *h) {
    fe recip;
    fe x;
    fe y;
    fe_invert(recip, h->Z);
    fe_mul(x, h->X, recip);
    fe_mul(y, h->Y, recip);
    fe_tobytes(s, y);
    s[31] ^= fe_isnegative(x) << 7;
}
__device__ int ge_frombytes_negate_vartime(ge_p3 *h, const unsigned char *s) {
 const fe d={-10913610,13857413,-15372611,6949391,114729,-8787816,-6275908,-3247719,-18696448,-12055116}; const fe sqrtm1={-32595792,-7943725,9377950,3500415,12389472,-272473,-25146209,-2005654,326686,11406482}; 

    fe u;
    fe v;
    fe v3;
    fe vxx;
    fe check;
    fe_frombytes(h->Y, s);
    fe_1(h->Z);
    fe_sq(u, h->Y);
    fe_mul(v, u, d);
    fe_sub(u, u, h->Z);     /* u = y^2-1 */
    fe_add(v, v, h->Z);     /* v = dy^2+1 */
    fe_sq(v3, v);
    fe_mul(v3, v3, v);      /* v3 = v^3 */
    fe_sq(h->X, v3);
    fe_mul(h->X, h->X, v);
    fe_mul(h->X, h->X, u);  /* x = uv^7 */
    fe_pow22523(h->X, h->X); /* x = (uv^7)^((q-5)/8) */
    fe_mul(h->X, h->X, v3);
    fe_mul(h->X, h->X, u);  /* x = uv^3(uv^7)^((q-5)/8) */
    fe_sq(vxx, h->X);
    fe_mul(vxx, vxx, v);
    fe_sub(check, vxx, u);  /* vx^2-u */

    if (fe_isnonzero(check)) {
        fe_add(check, vxx, u); /* vx^2+u */

        if (fe_isnonzero(check)) {
            return -1;
        }

        fe_mul(h->X, h->X, sqrtm1);
    }

    if (fe_isnegative(h->X) != (s[31] >> 7)) {
        fe_neg(h->X, h->X);
    }

    fe_mul(h->T, h->X, h->Y);
    return 0;
}
__device__ static u64 dl64(const u8 *x)
{
  u64 i,u=0;
  FOR(i,8) u=(u<<8)|x[i];
  return u;
}
__device__ void ts64(u8 *x,u64 u)
{
  int i;
  for (i = 7;i >= 0;--i) { x[i] = u; u >>= 8; }
}
__device__ static u64 R(u64 x,int c) {
    // ccminer-inspired split-word rotation, independently written for OpenCL.
    uint lo=(uint)x,hi=(uint)(x>>32),a,b;uint n=(uint)c;
    if(n==32){a=hi;b=lo;}
    else if(n<32){a=(lo>>n)|(hi<<(32-n));b=(hi>>n)|(lo<<(32-n));}
    else{n-=32;a=(hi>>n)|(lo<<(32-n));b=(lo>>n)|(hi<<(32-n));}
    return ((u64)b<<32)|a;
}
__device__ static u64 Ch(u64 x,u64 y,u64 z) { return (x & y) ^ (~x & z); }
__device__ static u64 Maj(u64 x,u64 y,u64 z) { return (x & y) ^ (x & z) ^ (y & z); }
__device__ static u64 Sigma0(u64 x) { return R(x,28) ^ R(x,34) ^ R(x,39); }
__device__ static u64 Sigma1(u64 x) { return R(x,14) ^ R(x,18) ^ R(x,41); }
__device__ static u64 sigma0(u64 x) { return R(x, 1) ^ R(x, 8) ^ (x >> 7); }
__device__ static u64 sigma1(u64 x) { return R(x,19) ^ R(x,61) ^ (x >> 6); }

__device__ __constant__ u64 K[80] = 
{
  0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
  0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
  0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
  0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
  0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
  0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
  0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
  0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
  0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
  0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
  0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
  0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
  0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
  0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
  0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
  0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
  0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
  0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
  0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
  0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

__device__ int crypto_hashblocks(u8 *x,const u8 *m,u64 n)
{
  u64 z[8],b[8],a[8],w[16],t;
  int i,j;

  FOR(i,8) z[i] = a[i] = dl64(x + 8 * i);

  while (n >= 128) {
    FOR(i,16) w[i] = dl64(m + 8 * i);

    FOR(i,80) {
      FOR(j,8) b[j] = a[j];
      t = a[7] + Sigma1(a[4]) + Ch(a[4],a[5],a[6]) + K[i] + w[i%16];
      b[7] = t + Sigma0(a[0]) + Maj(a[0],a[1],a[2]);
      b[3] += t;
      FOR(j,8) a[(j+1)%8] = b[j];
      if (i%16 == 15)
	FOR(j,16)
	  w[j] += w[(j+9)%16] + sigma0(w[(j+1)%16]) + sigma1(w[(j+14)%16]);
    }

    FOR(i,8) { a[i] += z[i]; z[i] = a[i]; }

    m += 128;
    n -= 128;
  }

  FOR(i,8) ts64(x+8*i,z[i]);

  return n;
}

__device__ __constant__ u8 iv[64] = {
  0x6a,0x09,0xe6,0x67,0xf3,0xbc,0xc9,0x08,
  0xbb,0x67,0xae,0x85,0x84,0xca,0xa7,0x3b,
  0x3c,0x6e,0xf3,0x72,0xfe,0x94,0xf8,0x2b,
  0xa5,0x4f,0xf5,0x3a,0x5f,0x1d,0x36,0xf1,
  0x51,0x0e,0x52,0x7f,0xad,0xe6,0x82,0xd1,
  0x9b,0x05,0x68,0x8c,0x2b,0x3e,0x6c,0x1f,
  0x1f,0x83,0xd9,0xab,0xfb,0x41,0xbd,0x6b,
  0x5b,0xe0,0xcd,0x19,0x13,0x7e,0x21,0x79
} ;

__device__ int crypto_hash(u8 *out,const u8 *m,u64 n)
{
  // Proxima's only two hash inputs are 81 and 35 bytes. Both fit a
  // single padded SHA-512 block; avoid the generic two-block workspace.
  u8 h[64],x[128];
  u64 i,b = n;

  FOR(i,64) h[i] = iv[i];

  FOR(i,128) x[i] = 0;
  FOR(i,n) x[i] = m[i];
  x[n] = 128;

  n = 128;
  x[n-9] = b >> 61;
  ts64(x+n-8,b<<3);
  crypto_hashblocks(h,x,n);

  FOR(i,64) out[i] = h[i];

  return 0;
}


// Scalar is constant across work items; conditional additions are uniform
// within a launch. For a trusted local GPU; not a hardened key API.
// Window 5 caches odd multiples through 15H. Rust supplies signed odd digits.
__device__ void fe_normalize_tight(fe value) {
    int64_t carry=0;
    #pragma unroll
    for(int i=0;i<10;i++) {
        int bits=26-(i&1);int64_t v=(int64_t)value[i]+carry;
        carry=(v+(1LL<<(bits-1)))>>bits;
        value[i]=(int)(v-carry*(1LL<<bits));
    }
    int64_t wrap=(int64_t)value[0]+carry*19;
    carry=(wrap+(1LL<<25))>>26;
    value[0]=(int)(wrap-carry*(1LL<<26));value[1]+=(int)carry;
}

__device__ void variable_scalar_mul(ge_p3 *result,const ge_p3 *point,const u8 *plan) {
    ge_cached table[8],twice_cached;ge_p1p1 completed;ge_p2 projective;ge_p3 twice,odd;
    ge_p3_to_cached(&table[0],point);
    ge_p3_dbl(&completed,point);ge_p1p1_to_p3(&twice,&completed);
    ge_p3_to_cached(&twice_cached,&twice);odd=*point;
    for(int q=1;q<8;q++) {
        ge_add(&completed,&odd,&twice_cached);ge_p1p1_to_p3(&odd,&completed);
        ge_p3_to_cached(&table[q],&odd);
    }
    int first=(int)((char)plan[2]);uint which=(abs(first)-1)/2;
    fe_sub(projective.X,table[which].YplusX,table[which].YminusX);
    fe_add(projective.Y,table[which].YplusX,table[which].YminusX);
    fe_add(projective.Z,table[which].Z,table[which].Z);
    if(first<0)fe_neg(projective.X,projective.X);
    fe_normalize_tight(projective.X);fe_normalize_tight(projective.Y);fe_normalize_tight(projective.Z);
    uint n=plan[0];
    #pragma unroll 1
    for(uint op=1;op<n;op++) {
        uint gap=plan[2*op+1];
        #pragma unroll 1
        for(uint j=1;j<gap;j++){ge_p2_dbl(&completed,&projective);ge_p1p1_to_p2(&projective,&completed);}
        ge_p2_dbl(&completed,&projective);ge_p1p1_to_p3(result,&completed);
        int digit=(int)((char)plan[2*op+2]);which=(abs(digit)-1)/2;
        if(digit>0)ge_add(&completed,result,&table[which]);else ge_sub(&completed,result,&table[which]);
        ge_p1p1_to_p2(&projective,&completed);
    }
    #pragma unroll 1
    for(uint j=0;j<plan[1];j++){ge_p2_dbl(&completed,&projective);ge_p1p1_to_p2(&projective,&completed);}
    fe_copy(result->X,projective.X);fe_copy(result->Y,projective.Y);fe_copy(result->Z,projective.Z);fe_0(result->T);
}

__device__ void cofactor(ge_p3 *point) {
    ge_p2 p;ge_p1p1 t;ge_p3_to_p2(&p,point);
    for(int i=0;i<3;i++) {
        ge_p2_dbl(&t,&p);
        if(i==2)ge_p1p1_to_p3(point,&t);else ge_p1p1_to_p2(&p,&t);
    }
}
// The final pass filters completed VRF outputs without changing curve kernels.
// The complete output stays on the GPU; only this 80-byte record is read back.
extern "C" __global__ void vrf_seeker(const u8 *outputs, uint *result,
                         u64 nonceBase, uint k, uint hasBeat,
                         const u8 *job, uint prefixLen, uint count) {
    size_t gid=get_global_id(0);if(gid>=count)return;
    const u8 *digest=outputs+gid*65;
    uint tz=digest[64];
    if(tz==254){int allzero=1;for(int i=0;i<64;i++)if(digest[i]){allzero=0;break;}if(allzero){atomicOr(result+19,1u);return;}}
    if(tz==255){tz=0;for(int i=63;i>=0;i--){u8 b=digest[i];if(b==0){tz+=8;continue;}while((b&1)==0){tz++;b>>=1;}break;}}
    if(tz<k)return;
    if(hasBeat){const u8 *beat=job+64+prefixLen+256;int smaller=0;for(int i=0;i<64;i++){if(digest[i]!=beat[i]){smaller=digest[i]<beat[i];break;}}if(!smaller)return;}
    if(atomicCAS(result,0u,1u)==0u){u64 nonce=nonceBase+gid;result[1]=(uint)nonce;result[2]=(uint)(nonce>>32);u8 *bytes=(u8 *)result;for(int i=0;i<64;i++)bytes[12+i]=digest[i];}
}

// Projective points are laid out by field limb so that
// adjacent GPU lanes read/write adjacent words. T is unnecessary for encoding.
__device__ void finish_projective(const int *points, u8 *outputs,
                       uint count, size_t gid, const fe inverse) {
    if(!points[30*count+gid]) {
        for(int i=0;i<64;i++)outputs[gid*65+i]=0;
        outputs[gid*65+64]=254;return;
    }
    fe x,y,a,b;
    for(int i=0;i<10;i++){a[i]=points[i*count+gid];b[i]=points[(i+10)*count+gid];}
    fe_mul(x,a,inverse);fe_mul(y,b,inverse);
    u8 packed[32],message[35],digest[64];
    fe_tobytes(packed,y);packed[31]^=fe_isnegative(x)<<7;
    message[0]=3;message[1]=3;message[34]=0;
    for(int i=0;i<32;i++)message[i+2]=packed[i];
    crypto_hash(digest,message,35);
    for(int i=0;i<64;i++)outputs[gid*65+i]=digest[i];
    int tz=0;
    for(int i=63;i>=0;i--){u8 b=digest[i];if(b==0){tz+=8;continue;}while((b&1)==0){tz++;b>>=1;}break;}
    outputs[gid*65+64]=(u8)min(tz,255);
}

__device__ void finish_projective_filter(const int *points,uint *result,
                     uint count,size_t gid,const fe inverse,u64 nonceBase,
                     uint k,uint hasBeat,const u8 *job,uint prefixLen) {
    if(!points[30*count+gid]){atomicOr(result+19,1u);return;}
    fe x,y,a,b;
    for(int i=0;i<10;i++){a[i]=points[i*count+gid];b[i]=points[(i+10)*count+gid];}
    fe_mul(x,a,inverse);fe_mul(y,b,inverse);
    u8 packed[32],message[35],digest[64];
    fe_tobytes(packed,y);packed[31]^=fe_isnegative(x)<<7;
    message[0]=3;message[1]=3;message[34]=0;
    for(int i=0;i<32;i++)message[i+2]=packed[i];
    crypto_hash(digest,message,35);
    uint tz=0;
    for(int i=63;i>=0;i--){u8 b=digest[i];if(b==0){tz+=8;continue;}while((b&1)==0){tz++;b>>=1;}break;}
    if(tz<k)return;
    if(hasBeat){const u8 *beat=job+64+prefixLen+256;int smaller=0;for(int i=0;i<64;i++){if(digest[i]!=beat[i]){smaller=digest[i]<beat[i];break;}}if(!smaller)return;}
    if(atomicCAS(result,0u,1u)==0u){u64 nonce=nonceBase+gid;result[1]=(uint)nonce;result[2]=(uint)(nonce>>32);u8 *bytes=(u8 *)result;for(int i=0;i<64;i++)bytes[12+i]=digest[i];}
}

// Montgomery batch inversion using a product tree. Each workgroup performs
// one inversion; the downward pass supplies the reciprocal of every leaf.
// Out-of-range padding uses Z=1 and still participates in every barrier.
__device__ void tree_read(fe value, const int *tree, uint width, uint node) {
    for(int i=0;i<10;i++)value[i]=tree[i*width+node];
}
__device__ void tree_write(int *tree, uint width, uint node, const fe value) {
    for(int i=0;i<10;i++)tree[i*width+node]=value[i];
}
extern "C" __global__ void vrf_finish_batch(const int *points, u8 *outputs,
                               uint count) {
    extern __shared__ int tree[];
    uint lid=get_local_id(0), group=get_local_size(0), width=2*group;
    size_t gid=get_global_id(0);
    fe value,left,right;
    if(gid<count){for(int i=0;i<10;i++)value[i]=points[(i+20)*count+gid];}
    else fe_1(value);
    tree_write(tree,width,group+lid,value);
    __syncthreads();
    for(uint nodes=group/2;nodes>0;nodes/=2) {
        if(lid<nodes) {
            uint node=nodes+lid;
            tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);
            fe_mul(value,left,right);tree_write(tree,width,node,value);
        }
        __syncthreads();
    }
    if(lid==0){tree_read(value,tree,width,1);fe_invert(left,value);tree_write(tree,width,1,left);}
    __syncthreads();
    for(uint nodes=1;nodes<group;nodes*=2) {
        if(lid<nodes) {
            uint node=nodes+lid;
            tree_read(value,tree,width,node);
            tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);
            fe result;fe_mul(result,value,right);tree_write(tree,width,node*2,result);
            fe_mul(result,value,left);tree_write(tree,width,node*2+1,result);
        }
        __syncthreads();
    }
    tree_read(value,tree,width,group+lid);
    if(gid<count)finish_projective(points,outputs,count,gid,value);
}


// Separate hash-to-curve and scalar multiplication for timing and occupancy.
// Preserve all four extended point coordinates; no affine inversion here.
extern "C" __global__ void vrf_scalar_projective(const u8 *job,
                                    const int *curves,
                                    int *points,
                                    uint prefixLen, uint count) {
    size_t gid=get_global_id(0);if(gid>=count)return;ge_p3 h,gamma;
    int found=curves[40*count+gid];
    if(found) {
        for(int i=0;i<10;i++) {
            h.X[i]=curves[(i+0)*count+gid];h.Y[i]=curves[(i+10)*count+gid];
            h.Z[i]=curves[(i+20)*count+gid];h.T[i]=curves[(i+30)*count+gid];
        }
        variable_scalar_mul(&gamma,&h,job+64+prefixLen);
    }else {fe_0(gamma.X);fe_1(gamma.Y);fe_1(gamma.Z);}
    for(int i=0;i<10;i++) {
        points[(i+0)*count+gid]=gamma.X[i];points[(i+10)*count+gid]=gamma.Y[i];
        points[(i+20)*count+gid]=gamma.Z[i];
    }
    points[30*count+gid]=found;
}

// Retry only failed nonces in a dense GPU queue. Counters advance in order,
// so every nonce still uses its first valid TAI point, exactly as the reference.
__device__ void save_curve(int *curves, uint count, uint index, const ge_p3 *h) {
    for(int i=0;i<10;i++) {
        curves[(i+0)*count+index]=h->X[i];curves[(i+10)*count+index]=h->Y[i];
        curves[(i+20)*count+index]=h->Z[i];curves[(i+30)*count+index]=h->T[i];
    }
    curves[40*count+index]=1;
}

// Public job prefix only: first 64 TAI input bytes have no nonce or counter.
// Storage at byte 424 is aligned, stays within the existing 512-byte job.
extern "C" __global__ void vrf_job_sha_init(u8 *job) {
    if(blockIdx.x||threadIdx.x)return;
    u8 message[64];message[0]=3;message[1]=1;
    for(int i=0;i<32;i++)message[2+i]=job[32+i];
    for(int i=0;i<30;i++)message[34+i]=job[64+i];
    u64 a[8],b[8];for(int i=0;i<8;i++)a[i]=dl64(iv+8*i);
    for(int i=0;i<8;i++) {
        for(int j=0;j<8;j++)b[j]=a[j];
        u64 t=a[7]+Sigma1(a[4])+Ch(a[4],a[5],a[6])+K[i]+dl64(message+8*i);
        b[7]=t+Sigma0(a[0])+Maj(a[0],a[1],a[2]);b[3]+=t;
        for(int j=0;j<8;j++)a[(j+1)%8]=b[j];
    }
    u64 *saved=(u64 *)(job+424);for(int i=0;i<8;i++)saved[i]=a[i];
}
__device__ void crypto_hash_tai_midstate(u8 *out,const u8 *message,const u8 *job) {
    u64 a[8],b[8],w[16];const u64 *saved=(const u64 *)(job+424);
    for(int i=0;i<8;i++)a[i]=saved[i];
    for(int i=0;i<10;i++)w[i]=dl64(message+8*i);
    w[10]=((u64)message[80]<<56)|(0x80ULL<<48);
    for(int i=11;i<15;i++)w[i]=0;w[15]=81ULL*8;
    for(int i=8;i<80;i++) {
        for(int j=0;j<8;j++)b[j]=a[j];
        u64 t=a[7]+Sigma1(a[4])+Ch(a[4],a[5],a[6])+K[i]+w[i%16];
        b[7]=t+Sigma0(a[0])+Maj(a[0],a[1],a[2]);b[3]+=t;
        for(int j=0;j<8;j++)a[(j+1)%8]=b[j];
        if(i%16==15)for(int j=0;j<16;j++)w[j]+=w[(j+9)%16]+sigma0(w[(j+1)%16])+sigma1(w[(j+14)%16]);
    }
    for(int i=0;i<8;i++)ts64(out+8*i,a[i]+dl64(iv+8*i));
}

__device__ int curve_candidate(ge_p3 *h, const u8 *job, u64 nonce,
                     uint prefixLen, uint counter) {
    u8 message[128],digest[64];message[0]=3;message[1]=1;
    for(int i=0;i<32;i++)message[2+i]=job[32+i];
    for(uint i=0;i<prefixLen;i++)message[34+i]=job[64+i];
    for(int i=0;i<8;i++)message[34+prefixLen+i]=(u8)(nonce>>(56-8*i));
    uint ctrIndex=34+prefixLen+8;message[ctrIndex]=(u8)counter;message[ctrIndex+1]=0;
    crypto_hash_tai_midstate(digest,message,job);
    if(ge_frombytes_negate_vartime(h,digest)!=0)return 0;
    cofactor(h);fe yz;fe_sub(yz,h->Y,h->Z);
    return fe_isnonzero(h->X)||fe_isnonzero(yz);
}
extern "C" __global__ void vrf_init_curves(int *curves, uint *indices,
                              uint *counts, uint count) {
    uint gid=get_global_id(0);if(gid>=count)return;indices[gid]=gid;curves[40*count+gid]=0;
    if(gid==0){counts[0]=count;counts[1]=0;}
}
extern "C" __global__ void vrf_curve_attempt(const u8 *job, int *curves,
                                const uint *input,
                                uint *output, uint *counts,
                                u64 nonceBase, uint prefixLen, uint count,
                                uint counter, uint inputSlot) {
    uint gid=get_global_id(0);if(gid>=counts[inputSlot])return;
    uint index=input[gid];ge_p3 h;
    if(curve_candidate(&h,job,nonceBase+(u64)index,prefixLen,counter)) {
        save_curve(curves,count,index,&h);
    }else {uint position=atomicAdd(counts+(1-inputSlot),1u);output[position]=index;}
}
extern "C" __global__ void vrf_curve_fallback(const u8 *job, int *curves,
                                 const uint *indices,
                                 const uint *counts, u64 nonceBase,
                                 uint prefixLen, uint count, uint inputSlot,
                                 uint counterStart) {
    uint gid=get_global_id(0);if(gid>=counts[inputSlot])return;
    uint index=indices[gid];ge_p3 h;
    #pragma unroll 1
    for(uint counter=counterStart;counter<256;counter++) {
        if(curve_candidate(&h,job,nonceBase+(u64)index,prefixLen,counter)) {
            save_curve(curves,count,index,&h);return;
        }
    }
    // Exhausted nonces retain flag 0. The later scalar and filter kernels
    // safely propagate the original failure marker instead of a fake output.
}

extern "C" __global__ void vrf_finish_filter(const int *points,uint *result,u64 nonceBase,uint k,uint hasBeat,const u8 *job,uint prefixLen,uint count){
    extern __shared__ int tree[];
    uint lid=get_local_id(0), group=get_local_size(0), width=2*group;
    size_t gid=get_global_id(0);
    fe value,left,right;
    if(gid<count){for(int i=0;i<10;i++)value[i]=points[(i+20)*count+gid];}
    else fe_1(value);
    tree_write(tree,width,group+lid,value);
    __syncthreads();
    for(uint nodes=group/2;nodes>0;nodes/=2) {
        if(lid<nodes) {
            uint node=nodes+lid;
            tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);
            fe_mul(value,left,right);tree_write(tree,width,node,value);
        }
        __syncthreads();
    }
    if(lid==0){tree_read(value,tree,width,1);fe_invert(left,value);tree_write(tree,width,1,left);}
    __syncthreads();
    for(uint nodes=1;nodes<group;nodes*=2) {
        if(lid<nodes) {
            uint node=nodes+lid;
            tree_read(value,tree,width,node);
            tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);
            fe result;fe_mul(result,value,right);tree_write(tree,width,node*2,result);
            fe_mul(result,value,left);tree_write(tree,width,node*2+1,result);
        }
        __syncthreads();
    }
    tree_read(value,tree,width,group+lid);
    if(gid<count)finish_projective_filter(points,result,count,gid,value,nonceBase,k,hasBeat,job,prefixLen);
}


// Persist only product trees; densely scheduled threads invert their roots.
extern "C" __global__ void vrf_tree_build(const int *points,int *globalTree,
                                         int *roots,uint count) {
    extern __shared__ int tree[];
    uint lid=threadIdx.x,group=blockDim.x,width=2*group;
    size_t gid=get_global_id(0);
    fe value,left,right;
    if(gid<count){for(int i=0;i<10;i++)value[i]=points[(i+20)*count+gid];}
    else fe_1(value);
    tree_write(tree,width,group+lid,value);__syncthreads();
    for(uint nodes=group/2;nodes>0;nodes/=2) {
        if(lid<nodes){uint node=nodes+lid;tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);fe_mul(value,left,right);tree_write(tree,width,node,value);}
        __syncthreads();
    }
    if(lid==0){for(int i=0;i<10;i++)roots[i*gridDim.x+blockIdx.x]=tree[i*width+1];}
    for(int i=0;i<10;i++){
        if(lid!=0)globalTree[blockIdx.x*width*10+i*width+lid]=tree[i*width+lid];
        globalTree[blockIdx.x*width*10+i*width+group+lid]=tree[i*width+group+lid];
    }
}
extern "C" __global__ void vrf_tree_invert(int *roots,uint rootCount) {
    uint gid=get_global_id(0);if(gid>=rootCount)return;
    fe value,inverse;
    for(int i=0;i<10;i++)value[i]=roots[i*rootCount+gid];
    fe_invert(inverse,value);
    for(int i=0;i<10;i++)roots[i*rootCount+gid]=inverse[i];
}
extern "C" __global__ void vrf_tree_finish(const int *points,u8 *outputs,
       const int *globalTree,const int *roots,uint count,uint *result,
       u64 nonceBase,uint k,uint hasBeat,const u8 *job,uint prefixLen,uint filter) {
    extern __shared__ int tree[];
    uint lid=threadIdx.x,group=blockDim.x,width=2*group;
    size_t gid=get_global_id(0);
    fe value,left,right;
    for(int i=0;i<10;i++){
        if(lid!=0)tree[i*width+lid]=globalTree[blockIdx.x*width*10+i*width+lid];
        tree[i*width+group+lid]=globalTree[blockIdx.x*width*10+i*width+group+lid];
    }
    __syncthreads();
    if(lid==0){for(int i=0;i<10;i++)tree[i*width+1]=roots[i*gridDim.x+blockIdx.x];}
    __syncthreads();
    for(uint nodes=1;nodes<group;nodes*=2) {
        if(lid<nodes) {
            uint node=nodes+lid;
            tree_read(value,tree,width,node);
            tree_read(left,tree,width,node*2);tree_read(right,tree,width,node*2+1);
            fe out;fe_mul(out,value,right);tree_write(tree,width,node*2,out);
            fe_mul(out,value,left);tree_write(tree,width,node*2+1,out);
        }
        __syncthreads();
    }
    tree_read(value,tree,width,group+lid);
    if(gid<count){
        if(filter)finish_projective_filter(points,result,count,gid,value,nonceBase,k,hasBeat,job,prefixLen);
        else finish_projective(points,outputs,count,gid,value);
    }
}
