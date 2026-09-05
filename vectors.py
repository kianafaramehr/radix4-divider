import random

NUM_TESTS = 10000

def generate_vectors(filename, mode_bits):
    with open(filename, "w") as f:
        for _ in range(NUM_TESTS):
            # Y must be normalized (0.5 to 1.0) -> MSB must be 1
            y = random.randint(0x80000000, 0xFFFFFFFF)
            
            # MATHEMATICAL LIMIT OF RADIX-4 SRT {-2, 2}:
            # The maximum representable quotient is 2/3.
            # Therefore, X MUST be strictly less than or equal to (2/3) * Y
            max_x = (y * 2) // 3
            x = random.randint(0x00000000, max_x)
            
            # The hardware shifts X left by the number of output quotient bits
            x_shifted = x << mode_bits
            
            # Integer division and remainder
            q = x_shifted // y
            r = x_shifted % y
            
            # Mask to 32 bits
            q = q & 0xFFFFFFFF
            r = r & 0xFFFFFFFF
            
            # Write 128-bit hex string: X Y Q R
            f.write(f"{x:08x}{y:08x}{q:08x}{r:08x}\n")
            
    print(f"Generated {NUM_TESTS} test vectors for {mode_bits}-bit mode in {filename}")

if __name__ == "__main__":
    generate_vectors("vectors_8.txt", 8)
    generate_vectors("vectors_16.txt", 16)
    generate_vectors("vectors_32.txt", 32)