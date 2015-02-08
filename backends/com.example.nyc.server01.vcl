#
# Server01 @ NYC Varnish config file
#

probe nyc_server01_alive {
  .request =
    "GET /status.php HTTP/1.1"
    "Host: server01.nyc.example.com"
    "Connection: close";
  .interval    = 1s;
  .timeout     = 1s;
  .window      = 5;
  .threshold   = 2;
  .expected_response = 200;
}

backend myc_server01 {
  .probe = nyc_server01_alive;

  .host = "x.x.x.x";
  .port = "80";

  .connect_timeout       = 1s;
  .first_byte_timeout    = 10s;
  .between_bytes_timeout = 150ms;
} 


