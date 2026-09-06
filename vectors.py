import random

NUM_TESTS = 10000

def generate_vectors(filename, mode_bits):
    with open(filename, "w") as f:
        for _ in range(NUM_TESTS):
            # 1. Y raw can be any 32-bit integer (excluding 0 to avoid div-by-zero deadlock)
            y_raw = random.randint(1, 0xFFFFFFFF)
            
            # 2. Emulate the hardware pre-processor (find leading 1 and normalize)
            y_norm = y_raw
            while (y_norm & 0x80000000) == 0:
                y_norm = (y_norm << 1) & 0xFFFFFFFF
                
            # 3. Apply SRT Radix-4 convergence condition on X relative to Y_NORM
            # X MUST be strictly less than or equal to (2/3) * Y_NORM
            max_x = (y_norm * 2) // 3
            x = random.randint(0, max_x)
            
            # 4. Hardware divides the shifted X by the NORMALIZED Y
            x_shifted = x << mode_bits
            q = x_shifted // y_norm
            r = x_shifted % y_norm
            
            q = q & 0xFFFFFFFF
            r = r & 0xFFFFFFFF
            
            # 5. Write vectors: Note we pass y_raw to hardware, let the hardware normalize it!
            f.write(f"{x:08x}{y_raw:08x}{q:08x}{r:08x}\n")
            
    print(f"Generated {NUM_TESTS} test vectors for {mode_bits}-bit mode in {filename}")

if __name__ == "__main__":
    generate_vectors("vectors_8.txt", 8)
    generate_vectors("vectors_16.txt", 16)
    generate_vectors("vectors_32.txt", 32)