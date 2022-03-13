import scipy
import scipy.fftpack
import math


def dct_generate(MAX_SIZE=64, NBITS=16):
    f = open("dct_rom.sv", 'w')

    COS_TERMS = 2*MAX_SIZE
    f.write("module dct_rom(output logic signed [%d:0] cos_q15[%d]);\n" % (NBITS-1, MAX_SIZE+1))
    f.write("\tassign cos_q15[0] = %d;\n" % ((1<<(NBITS-1))-1))
    for i in range(1, MAX_SIZE+1):
        f.write("\tassign cos_q15[%d] = %s;\n" % (i,int(math.cos(math.pi*float(i)/MAX_SIZE)*(1<<(NBITS-1)))))
    f.write("endmodule\n")
    f.close()
    pass

def main():
    N = 64
    print("N=%d" % N)
    print("y=1: => " +  str(0.5*scipy.fftpack.dct([1 for x in range(N)])))
    print("y=cos(i/PI): => " +  str(0.5*scipy.fftpack.dct([math.cos(3.14159265*x/N) for x in range(N)])))

if __name__ == "__main__":
    # dct_generate()
    main()
