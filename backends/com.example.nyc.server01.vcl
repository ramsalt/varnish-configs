#
# Web1.Stack1 Varnish config file
#

probe stack1_web1_alive {
  .request =
    "GET /utils/varnish/status.php HTTP/1.1"
    "Host: web1.stack1.ramsalt.com"
    "Connection: close";
  .interval    = 1s;
  .timeout     = 1s;
  .window      = 5;
  .threshold   = 2;
  .expected_response = 200;
}

backend stack1_web1 {
  .probe = stack1_web1_alive;

  .host = "192.168.151.69";
  .port = "80";

  .connect_timeout       = 5s;
  .first_byte_timeout    = 20s;
  .between_bytes_timeout = 150ms;
} 


