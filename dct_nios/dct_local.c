#include <math.h>
#include <stdio.h>
#include <assert.h>

/*Boilerplate fixed-point code*/

typedef int fixed;

int Q_M = 0;
int Q_N = 0;
int F_ONE = 0;

void SET_Q_FORMAT(int M, int N) {
    Q_M = M;
    Q_N = N;
    F_ONE = 1 << N;
}

fixed FLOAT_TO_FIXED(float f) {
    return (fixed)(f * F_ONE);
}

float FIXED_TO_FLOAT(fixed f){
    return (float)(f)/F_ONE;
}

fixed FIXED_MULT(fixed op1, fixed op2) {
    return (fixed)op1*op2 >> Q_N;
}

float float_abs(float x) {
    if (x >= 0) return x;
    else return -x;
}


/*DCT code - FLOATING*/
#define MAX_SIZE 64
#define COS_TERMS 2*MAX_SIZE
#define FLOAT_PI 3.14159265
#define NBITS 16
float cos_terms[COS_TERMS];
fixed cos_q15[COS_TERMS];

void ALLOC_DCT_PRECOMP_ARRAY() {
    int i;
    //for ((i,int(math.cos(math.pi*float(i)/MAX_SIZE)*(1<<(NBITS-1)))))
    for (i = 0; i < COS_TERMS; i++) {
        cos_terms[i] = cos(FLOAT_PI * i / MAX_SIZE);
        cos_q15[i] = (int)(cos_terms[i]*(1<<(NBITS-1)));
    }
}

void dct_float_raw(float* signal, float* result, int N) {
    for (int K = 0; K < N; K++) {
        result[K] = 0;
        for (int n = 0; n < N; n++) {
            result[K] += signal[n] * cos((FLOAT_PI/N)*(n+0.5)*K);
        }
    }
}

void dct_float(float* signal, float* result, int N) {
    int power = (int)log2(N);
    assert(powl(2,power) == N);//must be power of 2 for the optimized version
    for (int K = 0; K < N; K++) {
        result[K] = 0;
        for (int n = 0; n < N; n++) {
            // signal[n]*cos_q15[(((2*n+1) * K * MAX_SIZE) >> (power+1)) & (COS_TERMS - 1)] >>> (NBITS-1);
            result[K] += signal[n] * cos_terms[(((int)((n+0.5)*K*MAX_SIZE))>>power) & (COS_TERMS-1)];
        }
    }
}

void dct_fixed(fixed* signal, fixed* result, int N) {    
    int power = (int)log2(N);
    assert(powl(2,power) == N);//must be power of 2 for the optimized version
    for (int K = 0; K < N; K++) {
        result[K] = 0;
        for (int n = 0; n < N; n++) {
            // signal[n]*cos_q15[(((2*n+1) * K * MAX_SIZE) >> (power+1)) & (COS_TERMS - 1)] >>> (NBITS-1);
            result[K] += (signal[n] * cos_q15[(((int)((n+0.5)*K*MAX_SIZE))>>power) & (COS_TERMS-1)]) >> (NBITS-1);
        }
    }
}

/*TESTBENCH FUNCTIONS*/
//Test both fixed and float and compare error against raw
void dct_test_signal(float* signal, int N) {
    //construct the fixed signal
    fixed fixed_signal[MAX_SIZE];
    for (int i = 0; i < N; i++) { fixed_signal[i] = FLOAT_TO_FIXED(signal[i]); }
    //calculate the expected true result
    float result_raw[MAX_SIZE];
    dct_float_raw(signal, result_raw, N);
    printf("\n\n\nTrue Result: ");
    for (int i = 0; i < N; i++) {
        printf("%f, ", result_raw[i]);
    }
    //Calculate the floating point optimized version
    float result_float[MAX_SIZE];
    float error_float;
    dct_float(signal, result_float, N);
    printf("\n\nFloat Result: ");
    for (int i = 0; i < N; i++) {
        printf("%f, ", result_float[i]);
        error_float += float_abs(result_float[i]-result_raw[i]);
    }
    error_float /= N;
    //calculate the fixed result just like our unit would
    fixed result_fixed[MAX_SIZE];
    float error_fixed;
    dct_fixed(fixed_signal, result_fixed, N);
    printf("\n\nFixed Result: ");
    for (int i = 0; i < N; i++) {
        float value = FIXED_TO_FLOAT(result_fixed[i]);
        error_fixed += float_abs(value-result_raw[i]);
        printf("%f, ", value);
    }
    error_fixed /= N;
    printf("\n\nMean Float Error: %f\nMean Fixed Error: %f\n", error_float, error_fixed);
}


void dct_test_func(float(*func)(int, int), int N) {
    float signal[MAX_SIZE];
    for (int i = 0; i < N; i++) {
        signal[i] = func(i, N);
    }
    dct_test_signal(signal, N);
}

/*The testbench*/

float test1(int i, int N) {
    return 8;
} 
float test_cos(int i, int N, int freq) {
    return cos(freq*FLOAT_PI*i/N);
}
float test2(int i, int N) {
    return test_cos(i, N, 1);
} 
float test3(int i, int N) {
    return test_cos(i, N, 2);
} 
float test4(int i, int N) {
    return test_cos(i, N, 2) + test_cos(i, N, 5) + test_cos(i, N, 7);
} 


void dct_testbench(int N) {
    dct_test_func(test1, N);
    dct_test_func(test2, N);
    dct_test_func(test3, N);
    dct_test_func(test4, N);
}


int main(void) {
    ALLOC_DCT_PRECOMP_ARRAY();
    SET_Q_FORMAT(8, 8);
    dct_testbench(32);
    return 0;
}