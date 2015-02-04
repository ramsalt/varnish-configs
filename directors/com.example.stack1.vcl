#
# Stack1 Directors
#

director stack1_default client {
  { .backend = nyc_server01; .weight = 1; }
}

