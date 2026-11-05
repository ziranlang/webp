/* Independent stage diagnosis. RFC6386 section14.4 uses short inter-pass
 * storage and 32-bit second-pass sums before shift, then section14.5 clamps.
 * This test computes that process separately from product and native kernels. */
#include "src/dec/vp8i_dec.h"
#include "src/dsp/dsp.h"
#include "vp8_transform_native.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern VP8CPUInfo VP8GetCPUInfo;
static int mul1(int x) { return x + (int)(((int64_t)x * 20091) >> 16); }
static int mul2(int x) { return (int)(((int64_t)x * 35468) >> 16); }
static unsigned clip(int x) { return x < 0 ? 0 : x > 255 ? 255 : (unsigned)x; }
static void reference(const int16_t* in, uint8_t* out, int* minimum, int* maximum, int* sums) {
    int16_t tmp[16];
    for (int col = 0; col < 4; col++) {
        int a = in[col] + in[col+8], b = in[col] - in[col+8];
        int c = mul2(in[col+4]) - mul1(in[col+12]);
        int d = mul1(in[col+4]) + mul2(in[col+12]);
        int values[4] = {a+d,b+c,b-c,a-d};
        for (int row = 0; row < 4; row++) {
            if (values[row] < *minimum) *minimum = values[row];
            if (values[row] > *maximum) *maximum = values[row];
            tmp[row*4+col] = (int16_t)values[row];
        }
    }
    for (int row = 0; row < 4; row++) {
        const int16_t* p = tmp+4*row;
        int a=p[0]+p[2], b=p[0]-p[2];
        int c=mul2(p[1])-mul1(p[3]), d=mul1(p[1])+mul2(p[3]);
        int values[4]={a+d,b+c,b-c,a-d};
        for (int col=0;col<4;col++) {
            sums[row*4+col]=values[col]+4;
            int16_t residual=(int16_t)((values[col]+4)>>3);
            out[row*BPS+col]=(uint8_t)clip(128+(int)residual);
        }
    }
}
int main(int argc, char** argv) {
    if(argc!=2) return 1;
    uint8_t input[65536]; FILE* file=fopen(argv[1],"rb"); if(!file)return 2;
    size_t size=fread(input,1,sizeof(input),file); int extra=fgetc(file);fclose(file);if(extra!=EOF)return 3;
    VP8DspInit(); VP8DecIdct2 simd=VP8Transform;
    int (*cpu)(CPUFeature)=VP8GetCPUInfo; VP8GetCPUInfo=NULL; VP8DspInit(); VP8DecIdct2 scalar=VP8Transform;
    VP8GetCPUInfo=cpu; VP8DspInit();
    VP8Decoder* dec=VP8New(); VP8Io io; if(!dec||!VP8InitIo(&io))return 4;
    io.data=input;io.data_size=size;
    if(!VP8GetHeaders(dec,&io)||!VP8InitFrame(dec,&io))return 5;
    int differences=0;
    for(dec->mb_y=0;dec->mb_y<dec->mb_h;dec->mb_y++) {
        if(!VP8ParseIntraModeRow(&dec->br,dec))return 6;
        for(dec->mb_x=0;dec->mb_x<dec->mb_w;dec->mb_x++) {
            if(!VP8DecodeMB(dec,&dec->parts[dec->mb_y&dec->num_parts_minus_one]))return 7;
            VP8MBData* mb=dec->mb_data+dec->mb_x;
            for(int block=0;block<24;block++) {
                int16_t* coefficients=mb->coeffs+block*16;
                uint8_t rfc[BPS*4], c[BPS*4], optimized[BPS*4];
                memset(rfc,128,sizeof(rfc));memset(c,128,sizeof(c));memset(optimized,128,sizeof(optimized));
                int minimum=0,maximum=0,sums[16];
                reference(coefficients,rfc,&minimum,&maximum,sums); scalar(coefficients,c,0);simd(coefficients,optimized,0);
                uint8_t authored[1024];memset(authored,128,sizeof(authored));
                if(TransformDct(coefficients,authored))return 9;
                for(int i=0;i<16;i++)if(authored[33+(i/4)*BPS+i%4]!=rfc[(i/4)*BPS+i%4])return 10;
                if(memcmp(c,optimized,sizeof(c))) {
                    printf("macroblock=(%d,%d) subblock=%d first_pass_min=%d max=%d RFC_matches_C=%d RFC_matches_SIMD=%d coeffs=",dec->mb_x,dec->mb_y,block,minimum,maximum,!memcmp(rfc,c,sizeof(c)),!memcmp(rfc,optimized,sizeof(c)));
                    for(int i=0;i<16;i++)printf("%s%d",i?",":"",coefficients[i]);
                    printf("\nsecond_pass_sums_with_rounder=");for(int i=0;i<16;i++)printf("%s%d",i?",":"",sums[i]);
                    printf("\nRFC_pixels_with_prediction128=");for(int i=0;i<16;i++)printf("%s%d",i?",":"",rfc[(i/4)*BPS+i%4]);
                    printf("\nSIMD_pixels_with_prediction128=");for(int i=0;i<16;i++)printf("%s%d",i?",":"",optimized[(i/4)*BPS+i%4]);
                    printf("\nAuthored_matches_independent_RFC=1 uv_ac_quantizer=%d coded_coefficient=%d\n",dec->dqm[mb->segment].uv_mat[1],coefficients[3]/dec->dqm[mb->segment].uv_mat[1]);
                    puts("");differences++;
                }
            }
        }
        VP8InitScanline(dec);
    }
    VP8Delete(dec);
    printf("independent differing DCT blocks=%d; actual feature probes SSE2=%d SSE4.1=%d AVX2=%d\n",differences,cpu?cpu(kSSE2):-1,cpu?cpu(kSSE4_1):-1,cpu?cpu(kAVX2):-1);
    return differences==1?0:8;
}
