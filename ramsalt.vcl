#
# Ramsalt VARNISH configuration
#
# Derived from lullabot config and others.
# see: https://github.com/Lullabot/varnish/blob/varnish-4.x/drupal-ha.vcl
# 
# ref: https://www.lullabot.com/blog/article/configuring-varnish-high-availability-multiple-web-servers

# Access Control Lists
include "acl.vcl";

# Backends and Directors
include "backends.vcl";

# Including host definition, used to switch through the backends based on the v-host
include "hosts.vcl";

# Drupal related tasks
include "drupal.vcl";

# As last include: Extra Files
include "extra/esi_blocks.vcl";


sub vcl_recv {

  # Set a funny header, just to assure that we're using this server
  set req.http.X-Ramsalt = "42 69 666: Varnish-New";
    
  if (req.request == "GET" && req.url ~ "^/varnishcheck$") {
    error 200 "Varnish is Ready";
  } 

  # Switch the backend based on the host
  call virtualhost__recv;


  # Allow the backend to serve up stale content if it is responding slowly.
  ## We archieve this allowing to keep the content one extra hour
  if (req.backend.healthy) {
    set req.grace = 1h;
  } else {
    # On the other hand is the backend is not healthy keep the pages
    # as long as possible and serve cached pages also to non legged in users!
    set req.grace = 6h;
    unset req.http.Cookie;
  }

  # Handle compression correctly. Different browsers send different
  # "Accept-Encoding" headers, even though they mostly all support the same
  # compression mechanisms. By consolidating these compression headers into
  # a consistent format, we can reduce the size of the cache and get more hits.=
  # @see: http:// varnish.projects.linpro.no/wiki/FAQ/Compression
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      # If the browser supports it, we'll use gzip.
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      # Next, try deflate if it is supported.
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      # Unknown algorithm. Remove it and send unencoded.
      unset req.http.Accept-Encoding;
    }
  }

  # Always cache the following file types for all users.
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    unset req.http.Cookie;
  }



  # Handling all the drupal-related stuff in a separate function
  call drupal__recv;
  # Handling the ESI items
  call esi_block__recv;

  # If we arrived here without a return, le'ts handle it!
  return (lookup);  
}




# Routine used to determine the cache key if storing/retrieving a cached page.
sub vcl_hash {

  hash_data(req.url);
  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }
  # Use special internal SSL hash for https content
  # X-Forwarded-Proto is set to https by Pound
  if (req.http.X-Forwarded-Proto ~ "https") {
    hash_data(req.http.X-Forwarded-Proto);
  }

  # Calling routine to hash the content per role
  call esi_block__hash;


  return (hash); 
}




# Code determining what to do when serving items from the Apache servers.
sub vcl_fetch {

  # Don't allow static files to set cookies.
  if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    # beresp == Back-end response from the web server.
    unset beresp.http.set-cookie;
  }
  else if (beresp.http.Content-Type ~ "html") {
    # Enable ESI (Edge Side Include) for (only) html pages.
    set beresp.do_esi = true;
  }
  else if (beresp.http.Cache-Control) {
    unset beresp.http.Expires;
  }

  call esi_block__fetch;

  # Allow items to be stale if needed.
  set beresp.grace = 6h;
}


sub vcl_deliver {
  set resp.http.X-Varnish-Server = "Stack1 Varnish1";

  # Add an header to mark HITs or MISSes on the current request.
  if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "HIT";
  }
  else {
    set resp.http.X-Varnish-Cache = "MISS";
  }

  return (deliver);
}


# In the event of an error, show friendlier messages.
sub vcl_error {

  # Redirect to some other URL in the case of a homepage failure.
  #if (req.url ~ "^/?$") {
  #  set obj.status = 302;
  #  set obj.http.Location = "http://backup.example.com/";
  #}

  if (obj.status == 750) {
    set obj.http.Location = obj.response;
    set obj.status = 302;
    return(deliver);
  }

  # Otherwise redirect to the homepage, which will likely be in the cache.
  set obj.http.Content-Type = "text/html; charset=utf-8";
  synthetic {"
<html>
<head>
  <title>Page Temporary Unavailable</title>
  <style>
    body { background: #303030; text-align: center; color: white; }
    #page { border: 1px solid #CCC; width: 500px; margin: 100px auto 0; padding: 30px; background: #323232; }
    a, a:link, a:visited { color: #CCC; }
    .error { color: #222; }
  </style>
</head>
<body onload="setTimeout(function() { window.location = '/' }, 3000)">
  <div id="page">
    <h1 class="title">Page Temporary Unavailable</h1>
    <p>The page you requested is temporarily unavailable.</p>
    <p>We're redirecting you to the <a href="/">homepage</a> in 3 seconds.</p>
    <div style="display:none" class="error">(Error "} + obj.status + " " + obj.response + {")</div>
  </div>
</body>
</html>
"};
  return (deliver);
}

