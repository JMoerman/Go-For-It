prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include
 
Name: Go For It!
Description: Go For It! headers
Version: @VERSION@
Cflags: -I@DOLLAR@{includedir}/go-for-it
Requires: gtk+-3.0 libpeas-1.0 gee-0.8

