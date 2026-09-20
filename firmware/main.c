#define ACCEL_BASE 0x10000000UL

#define ACCEL_CTRL   (*(volatile unsigned int *)(ACCEL_BASE + 0x00))
#define ACCEL_STATUS (*(volatile unsigned int *)(ACCEL_BASE + 0x04))
#define ACCEL_A_BASE (ACCEL_BASE + 0x08)
#define ACCEL_B_BASE (ACCEL_BASE + 0x48)
#define ACCEL_RESULT_BASE (ACCEL_BASE + 0x88)

int main(void)
{
    static volatile unsigned int results[16];
    static const unsigned int a_stream[8][2] = {
        {0x00000001, 0x00000000},
        {0x00020005, 0x00000000},
        {0x00060009, 0x00000003},
        {0x000a000d, 0x00040007},
        {0x000e0000, 0x0008000b},
        {0x00000000, 0x000c000f},
        {0x00000000, 0x00100000},
        {0x00000000, 0x00000000}
    };
    static const unsigned int b_stream[8][2] = {
        {0x00000001, 0x00000000},
        {0x00050002, 0x00000000},
        {0x00060003, 0x00000009},
        {0x00070004, 0x000d000a},
        {0x00080000, 0x000e000b},
        {0x00000000, 0x000f000c},
        {0x00000000, 0x00100000},
        {0x00000000, 0x00000000}
    };

    for (unsigned int i = 0; i < 8; i++) {
        ((volatile unsigned int *)(ACCEL_A_BASE + i * 8))[0] = a_stream[i][0];
        ((volatile unsigned int *)(ACCEL_A_BASE + i * 8))[1] = a_stream[i][1];
        ((volatile unsigned int *)(ACCEL_B_BASE + i * 8))[0] = b_stream[i][0];
        ((volatile unsigned int *)(ACCEL_B_BASE + i * 8))[1] = b_stream[i][1];
    }

    ACCEL_CTRL = 1;

    while ((ACCEL_STATUS & 1) == 0)
        ;

    for (unsigned int i = 0; i < 16; i++)
        results[i] = *((volatile unsigned int *)(ACCEL_RESULT_BASE + i * 4));

    while (1)
        ;

    return 0;
}
