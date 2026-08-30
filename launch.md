~/rejoin $ su -c "ps -A | grep -i apengjers"
u0_a104       8738   556 27341040 1282728 futex_wait_queue_me 0 S com.apengjers.v3
u0_a110       9921   556 27588076 1254980 futex_wait_queue_me 0 S com.apengjers.v5
u0_a111      11000   556 27068612 643396 futex_wait_queue_me 0 S com.apengjers.v6
u0_a109      17190   556 7313184 146260 SyS_epoll_wait      0 S com.apengjers.v4
~/rejoin $ su -c "pgrep -af 'com.apengjers'"
~/rejoin $ su -c "pidof com.apengjers.v4"
17190

ini padahal yang v4 harusnya udah ke close alias ga jalan