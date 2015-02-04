# Ramsalt ACL.vcl
#
# Allow access only to local network
#
acl privileged {
  "localhost";
  "127.0.0.1"/24;
  "::1"/24;

  "192.168.0.0"/16;
}
