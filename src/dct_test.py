import scipy
import scipy.fftpack
import math

def main():
    N = 20
    print("N=%d" % N)
    print("y=1: => " +  str(0.5*scipy.fftpack.dct([1 for x in range(N)])))
    print("y=cos(i/PI): => " +  str(0.5*scipy.fftpack.dct([math.cos(3.14159265*x/N) for x in range(N)])))

if __name__ == "__main__":
    main()