#
# Ramsalt Drupal's Varnish Configuration
#


sub drupal__recv {

  # Pipe these paths directly to Apache for streaming.
  if (
      req.url ~ "^/admin/content/backup_migrate/.*\.gz"
     ) {
    return (pipe);
  
}
  # Do not cache these paths.
  if (
      req.url ~ "^/status\.php$" ||
      req.url ~ "^/update\.php$" ||
      req.url ~ "^/ooyala/ping$" ||
      req.url ~ "^/admin/" ||
      req.url ~ "^/info/.*$" ||
      req.url ~ "^/flag/.*$" ||
      req.url ~ "^.*/ajax/.*$" ||
      req.url ~ "^.*/ahah/.*$" ||
      # Google Login Auth
      req.url ~ "^/gauth/.*$"
     ) {
    return (pass);
  }

  # Do not allow outside access to cron.php or install.php.
  if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ privileged ) {
    error 404 "Page not found.";
  }

  # Remove all cookies that Drupal doesn't need to know about. ANY remaining
  # cookie will cause the request to pass-through to Apache. For the most part
  # we always set the NO_CACHE cookie after any POST request, disabling the
  # Varnish cache temporarily. The session cookie allows all authenticated users
  # to pass through as long as they're logged in.
  if (req.http.Cookie) {
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    set req.http.Cookie = regsuball(req.http.Cookie, ";(S?SESS[a-z0-9]+|NO_CACHE)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
    # Remove the "Drupal.toolbar.collapsed" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "Drupal.toolbar.collapsed=[^;]+(; )?", "");
    # Remove any Google Analytics based cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
  
    set req.http.Cookie = regsuball(req.http.Cookie, "_gat?=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "__atuvc=[^;]+(; )?", "");
  
    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "pa-submit=[^;]+(; )?", "");
  
    # Remove pollanon cookies.
    # set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(pa(.*))=[^;]*", "");

    ########   SITE SPECIFIC COOKIES    ##############################
      # Add the site-specific cookie removel in this section

      #ND
      set req.http.Cookie = regsuball(req.http.Cookie, "(C|CfP|GCM|JEB2|TPC|au|cd|cid|cs.|guest_id|lm|put.|rdk.|rpb|rsid|ruid|ses.|uid|vis.|cX_P|__at.|__cf.|ut.|__zlcmid)=[^;]+(; )?", "");

      #KR
      set req.http.Cookie = regsuball(req.http.Cookie, "owa.=[^;]+(; )?", "");

   ###### END OF:   SITE SPECIFIC COOKIES   #########################


    # Unset the cookie theader if there are no other cookies or if the cookie string is empty.
    if (  req.http.Cookie == "" ||  req.http.cookie ~ "^\s+$" ) {
      unset req.http.Cookie;
    }
    else {
      # If there is any cookies left (a session or NO_CACHE cookie), do not
      # cache the page. Pass it on to Apache directly.
      return (pass);
    }
  }
  # END of Cookie-handling section

}

sub drupal__pass {

  if (
      req.url ~ "^/status\.php$" ||
      req.url ~ "^/update\.php$" ||
      req.url ~ "^/admin/" 
     ) {
    set bereq.first_byte_timeout = 120s;
  }

}

sub drupal__hash {

  # Since Drupal 7.21 the images are loaded with a "iotok", which is always different
  #  to mitigeate this problem we remove the token to calculate the hash for the content
  #hash_data(req.http.host);
  hash_data( regsub(req.url, "\?(.*)itok=.+[^&]", "\1") );

}

# EOF: Nothing should be added after this line.

