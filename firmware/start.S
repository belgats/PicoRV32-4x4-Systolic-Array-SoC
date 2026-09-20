.section .text
.global _start

_start:
    li sp, 0x00010000
    call main

1:
    j 1b
