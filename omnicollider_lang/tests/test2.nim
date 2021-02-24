
#omni_debug_macros:
params:
    one; two

buffers:
    buf1 "something"
    buf2
    buf3 "somethingElse"

init:
    discard

sample:
    buf1.samplerate = 2