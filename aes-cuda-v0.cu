#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
// Define plaintext: 00112233445566778899aabbccddeeff
unsigned char plaintext[16] = {
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
};

// Define key for AES-128: 000102030405060708090a0b0c0d0e0f
unsigned char key[16] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
};

// Print bytes in hexadecimal format
void print_hex(unsigned char *bytes, size_t length) {
    for (size_t i = 0; i < length; ++i) {
        printf("%02x", bytes[i]);
    }
    printf("\n");
}

__device__ __constant__ unsigned char sbox[256] = {
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
    0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
    0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
    0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
    0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
    0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
    0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
    0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
    0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
    0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
    0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
    0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
    0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
    0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
    0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16
};

__device__ void SubBytes(unsigned char *state) {
    for (int i = 0; i < 16; ++i) {
        state[i] = sbox[state[i]];
    }
}

__device__ void ShiftRows(unsigned char *state) {
    unsigned char tmp[16];

    /* Column 1 */
    tmp[0] = state[0];
    tmp[1] = state[5];
    tmp[2] = state[10];
    tmp[3] = state[15];
    /* Column 2 */
    tmp[4] = state[4];
    tmp[5] = state[9];
    tmp[6] = state[14];
    tmp[7] = state[3];
    /* Column 3 */
    tmp[8] = state[8];
    tmp[9] = state[13];
    tmp[10] = state[2];
    tmp[11] = state[7];
    /* Column 4 */
    tmp[12] = state[12];
    tmp[13] = state[1];
    tmp[14] = state[6];
    tmp[15] = state[11];

    memcpy(state, tmp, 16);
}

__device__ void MixColumns(unsigned char *state) {
    unsigned char tmp[16];

    for (int i = 0; i < 4; ++i) {
        tmp[i*4] = (unsigned char)(mul(0x02, state[i*4]) ^ mul(0x03, state[i*4+1]) ^ state[i*4+2] ^ state[i*4+3]);
        tmp[i*4+1] = (unsigned char)(state[i*4] ^ mul(0x02, state[i*4+1]) ^ mul(0x03, state[i*4+2]) ^ state[i*4+3]);
        tmp[i*4+2] = (unsigned char)(state[i*4] ^ state[i*4+1] ^ mul(0x02, state[i*4+2]) ^ mul(0x03, state[i*4+3]));
        tmp[i*4+3] = (unsigned char)(mul(0x03, state[i*4]) ^ state[i*4+1] ^ state[i*4+2] ^ mul(0x02, state[i*4+3]));
    }

    memcpy(state, tmp, 16);
}

__device__ void AddRoundKey(unsigned char *state, const unsigned char *roundKey) {
    for (int i = 0; i < 16; ++i) {
        state[i] ^= roundKey[i];
    }
}

__device__ unsigned char mul(unsigned char a, unsigned char b) {
    unsigned char p = 0;
    unsigned char high_bit_mask = 0x80;
    unsigned char high_bit = 0;
    unsigned char modulo = 0x1B; /* x^8 + x^4 + x^3 + x + 1 */

    for (int i = 0; i < 8; i++) {
        if (b & 1) {
            p ^= a;
        }

        high_bit = a & high_bit_mask;
        a <<= 1;
        if (high_bit) {
            a ^= modulo;
        }
        b >>= 1;
    }

    return p;
}

__global__ void aes_encrypt_ctr(unsigned char *input, unsigned char *output, unsigned char *expandedKey, unsigned long long int *nonceCounter, int dataSize) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < dataSize) {
        // Each thread handles one block of input data
        unsigned char state[16]; // AES block size is 128 bits = 16 bytes

        // Prepare the input block (CTR mode: encrypt the counter, then XOR with plaintext)
        // Need to initialize the state with the counter value and nonce, then encrypt it
        for (int i = 0; i < 16; ++i) {
            state[i] = ((unsigned char*)nonceCounter)[i % 8]; // Assuming nonceCounter is 64 bits
            if (i < 8) state[i] ^= input[idx * 16 + i]; // XOR with input
        }

        for (int round = 0; round < 10; ++round) { // Assuming AES-128 for simplicity
            SubBytes(state);
            ShiftRows(state);
            if (round < 9) MixColumns(state); // Skip in the final round
            AddRoundKey(state, expandedKey + round * 16);
        }

        // XOR the encrypted counter block with the plaintext block to produce the ciphertext block
        for (int i = 0; i < 16; ++i) {
            output[idx * 16 + i] = state[i] ^ input[idx * 16 + i];
        }
    }
}

int main() {
    unsigned char *plaintext;  // Host plaintext
    unsigned char *ciphertext; // Host ciphertext
    unsigned char *d_plaintext, *d_ciphertext, *d_key;
    unsigned long long int *d_nonceCounter;
    int dataSize = 1024; // Example data size, adjust as needed
    unsigned char key[AES_KEY_SIZE]; // AESi key, ensure AES_KEY_SIZE is defined
    unsigned long long int nonceCounter = 0; // Example nonceCounter, initialize appropriately

    // Allocate host memory
    plaintext = (unsigned char*)malloc(dataSize * sizeof(unsigned char));
    ciphertext = (unsigned char*)malloc(dataSize * sizeof(unsigned char));

    // Initialize plaintext and key as needed

    // Allocate device memory
    cudaMalloc((void **)&d_plaintext, dataSize * sizeof(unsigned char));
    cudaMalloc((void **)&d_ciphertext, dataSize * sizeof(unsigned char));
    cudaMalloc((void **)&d_key, AES_KEY_SIZE * sizeof(unsigned char));
    cudaMalloc((void **)&d_nonceCounter, sizeof(unsigned long long int));

    // Copy host memory to device
    cudaMemcpy(d_plaintext, plaintext, dataSize * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_key, key, AES_KEY_SIZE * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_nonceCounter, &nonceCounter, sizeof(unsigned long long int), cudaMemcpyHostToDevice);

    // Define block and grid sizes
    int blockSize = 256; // Example, can be optimized
    int numBlocks = (dataSize + blockSize - 1) / blockSize;

    // Launch AES-CTR encryption kernel
    aes_ctr_encrypt_kernel<<<numBlocks, blockSize>>>(d_plaintext, d_ciphertext, d_key, d_nonceCounter, dataSize);

    // Copy device ciphertext back to host
    cudaMemcpy(ciphertext, d_ciphertext, dataSize * sizeof(unsigned char), cudaMemcpyDeviceToHost);

    // Cleanup
    cudaFree(d_plaintext);
    cudaFree(d_ciphertext);
    cudaFree(d_key);
    cudaFree(d_nonceCounter);
    free(plaintext);
    free(ciphertext);

    return 0;
}
int main() {
    unsigned char *plaintext;  // Host plaintext
    unsigned char *ciphertext; // Host ciphertext
    unsigned char *d_plaintext, *d_ciphertext, *d_key;
    unsigned long long int *d_nonceCounter;
    int dataSize = 1024; // Example data size, adjust as needed
    unsigned char key[AES_KEY_SIZE]; // AESi key, ensure AES_KEY_SIZE is defined
    unsigned long long int nonceCounter = 0; // Example nonceCounter, initialize appropriately

    // Allocate host memory
    plaintext = (unsigned char*)malloc(dataSize * sizeof(unsigned char));
    ciphertext = (unsigned char*)malloc(dataSize * sizeof(unsigned char));

    // Initialize plaintext and key as needed

    // Allocate device memory
    cudaMalloc((void **)&d_plaintext, dataSize * sizeof(unsigned char));
    cudaMalloc((void **)&d_ciphertext, dataSize * sizeof(unsigned char));
    cudaMalloc((void **)&d_key, AES_KEY_SIZE * sizeof(unsigned char));
    cudaMalloc((void **)&d_nonceCounter, sizeof(unsigned long long int));

    // Copy host memory to device
    cudaMemcpy(d_plaintext, plaintext, dataSize * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_key, key, AES_KEY_SIZE * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_nonceCounter, &nonceCounter, sizeof(unsigned long long int), cudaMemcpyHostToDevice);

    // Define block and grid sizes
    int blockSize = 256; // Example, can be optimized
    int numBlocks = (dataSize + blockSize - 1) / blockSize;

    // Launch AES-CTR encryption kernel
    aes_ctr_encrypt_kernel<<<numBlocks, blockSize>>>(d_plaintext, d_ciphertext, d_key, d_nonceCounter, dataSize);

    // Copy device ciphertext back to host
    cudaMemcpy(ciphertext, d_ciphertext, dataSize * sizeof(unsigned char), cudaMemcpyDeviceToHost);

    print_hex(plaintext, 16);

    // Cleanup
    cudaFree(d_plaintext);
    cudaFree(d_ciphertext);
    cudaFree(d_key);
    cudaFree(d_nonceCounter);
    free(plaintext);
    free(ciphertext);

    return 0;
}
